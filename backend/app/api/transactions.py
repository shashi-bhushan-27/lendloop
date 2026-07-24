"""
Transactions Router

Endpoints:
  GET  /transactions              — Current user's transactions
  GET  /transactions/{id}         — Transaction detail
  POST /transactions/{id}/initiate-return  — Borrower initiates return
  POST /transactions/{id}/confirm-return   — Lender confirms return (QR)
  POST /transactions/{id}/evidence         — Upload condition photos
  GET  /transactions/{id}/evidence         — List evidence photos
  POST /transactions/check-overdue         — Check and mark overdue transactions
"""

from fastapi import APIRouter, Depends, UploadFile, File, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_
from app.database.connection import get_db
from app.auth.dependencies import get_current_user
from app.models.user import User
from app.models.transaction import Transaction, TransactionStatus
from app.models.item import Item, ItemStatus
from app.models.evidence_photo import TransactionEvidencePhoto, EvidenceType
from app.schemas.transaction import TransactionResponse, ReturnInitiateRequest
from app.schemas.evidence_photo import EvidencePhotoResponse
from app.services.notification_service import send_notification_to_user
from app.services.trust_score_service import apply_overdue_penalty
from app.models.notification import NotificationType
from app.services.item_service import upload_item_image
from typing import List
from datetime import date
import uuid

router = APIRouter()


@router.get("", response_model=List[TransactionResponse])
async def get_my_transactions(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Transaction).where(
            or_(
                Transaction.borrower_id == current_user.id,
                Transaction.lender_id == current_user.id,
            )
        ).order_by(Transaction.created_at.desc())
    )
    return result.scalars().all()


@router.get("/{transaction_id}", response_model=TransactionResponse)
async def get_transaction(
    transaction_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id))
    tx = result.scalar_one_or_none()
    if not tx or (tx.borrower_id != current_user.id and tx.lender_id != current_user.id):
        raise HTTPException(status_code=404, detail="Transaction not found.")
    return tx


@router.post("/{transaction_id}/initiate-return")
async def initiate_return(
    transaction_id: uuid.UUID,
    data: ReturnInitiateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Borrower initiates the return process."""
    result = await db.execute(
        select(Transaction).where(Transaction.id == transaction_id).with_for_update()
    )
    tx = result.scalar_one_or_none()
    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found.")
    if tx.borrower_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the borrower can initiate return.")
    if tx.status != TransactionStatus.borrowed:
        raise HTTPException(
            status_code=409,
            detail=f"Cannot initiate return — transaction status is {tx.status.value}"
        )

    tx.status = TransactionStatus.return_pending
    if data.return_notes:
        tx.return_notes = data.return_notes

    await db.flush()

    # Notify lender
    await send_notification_to_user(
        user_id=tx.lender_id,
        notification_type=NotificationType.item_returned,
        title="Return Initiated",
        body="The borrower has initiated the return process. Meet to complete the handover.",
        reference_id=str(tx.id),
        reference_type="transaction",
        db=db,
    )

    return {"message": "Return initiated. Please meet the lender and show the return QR code."}


@router.post("/{transaction_id}/evidence")
async def upload_evidence(
    transaction_id: uuid.UUID,
    evidence_type: str,  # "pickup" or "return"
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Upload a condition photo for pickup or return."""
    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id))
    tx = result.scalar_one_or_none()
    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found.")
    if current_user.id not in (tx.borrower_id, tx.lender_id):
        raise HTTPException(status_code=403, detail="Not authorized for this transaction.")

    # Validate evidence type
    try:
        ev_type = EvidenceType(evidence_type)
    except ValueError:
        raise HTTPException(status_code=400, detail="Evidence type must be 'pickup' or 'return'.")

    # Upload to Cloudinary
    image_url = await upload_item_image(file, f"evidence/{transaction_id}")

    photo = TransactionEvidencePhoto(
        transaction_id=transaction_id,
        image_url=image_url,
        evidence_type=ev_type,
        uploaded_by=current_user.id,
    )
    db.add(photo)
    await db.flush()
    await db.refresh(photo)

    return EvidencePhotoResponse(
        id=photo.id,
        transaction_id=photo.transaction_id,
        image_url=photo.image_url,
        evidence_type=photo.evidence_type,
        uploaded_by=photo.uploaded_by,
        created_at=photo.created_at,
    )


@router.get("/{transaction_id}/evidence", response_model=List[EvidencePhotoResponse])
async def list_evidence(
    transaction_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List evidence photos for a transaction. Only participants may view."""
    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id))
    tx = result.scalar_one_or_none()
    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found.")
    if current_user.id not in (tx.borrower_id, tx.lender_id):
        raise HTTPException(status_code=403, detail="Not authorized for this transaction.")

    photos_result = await db.execute(
        select(TransactionEvidencePhoto)
        .where(TransactionEvidencePhoto.transaction_id == transaction_id)
        .order_by(TransactionEvidencePhoto.created_at.desc())
    )
    photos = photos_result.scalars().all()
    return [
        EvidencePhotoResponse(
            id=p.id,
            transaction_id=p.transaction_id,
            image_url=p.image_url,
            evidence_type=p.evidence_type,
            uploaded_by=p.uploaded_by,
            created_at=p.created_at,
        )
        for p in photos
    ]


@router.post("/check-overdue")
async def check_overdue(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Check for overdue transactions and apply penalties.
    In production, this should be called by a scheduled cron job.
    """
    today = date.today()

    result = await db.execute(
        select(Transaction).where(
            Transaction.due_date < today,
            Transaction.status == TransactionStatus.borrowed,
            Transaction.is_overdue == False,
        )
    )
    overdue_transactions = result.scalars().all()

    processed = 0
    for tx in overdue_transactions:
        tx.is_overdue = True
        tx.status = TransactionStatus.overdue

        penalty_applied = await apply_overdue_penalty(tx.id, tx.borrower_id, db)
        if penalty_applied:
            processed += 1
            await send_notification_to_user(
                user_id=tx.borrower_id,
                notification_type=NotificationType.overdue_alert,
                title="Item Overdue",
                body="Your borrowed item is overdue. Please return it as soon as possible to avoid further penalties.",
                reference_id=str(tx.id),
                reference_type="transaction",
                db=db,
            )
            await send_notification_to_user(
                user_id=tx.lender_id,
                notification_type=NotificationType.overdue_alert,
                title="Borrowed Item Overdue",
                body="An item you lent out is overdue. The borrower has been notified.",
                reference_id=str(tx.id),
                reference_type="transaction",
                db=db,
            )

    return {"overdue_found": len(overdue_transactions), "penalties_applied": processed}
