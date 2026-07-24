"""
QR Router

Endpoints:
  POST /qr/generate   — Generate QR token for pickup/return
  POST /qr/verify     — Verify a scanned QR token
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database.connection import get_db
from app.auth.dependencies import get_current_user
from app.models.user import User
from app.models.transaction import Transaction, TransactionStatus
from app.schemas.qr import QRGenerateRequest, QRVerifyRequest, QRResponse, QRVerifyResponse
from app.qr.generator import create_qr_token
from app.qr.validator import verify_qr_token

router = APIRouter()


@router.post("/generate", response_model=QRResponse)
async def generate_qr(
    data: QRGenerateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Generates a signed QR token for a transaction.
    Only transaction participants may generate QR codes.
    """
    # Verify transaction exists and user is a participant
    tx_result = await db.execute(
        select(Transaction).where(Transaction.id == data.transaction_id)
    )
    transaction = tx_result.scalar_one_or_none()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found.")
    if current_user.id not in (transaction.borrower_id, transaction.lender_id):
        raise HTTPException(status_code=403, detail="Not authorized for this transaction.")

    # Validate state allows QR generation
    if data.qr_type.value == "pickup" and transaction.status != TransactionStatus.awaiting_pickup:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Cannot generate pickup QR — transaction status is {transaction.status.value}"
        )
    if data.qr_type.value == "return" and transaction.status != TransactionStatus.return_pending:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Cannot generate return QR — transaction status is {transaction.status.value}"
        )

    qr_record = await create_qr_token(data.transaction_id, data.qr_type, db)
    return qr_record


@router.post("/verify", response_model=QRVerifyResponse)
async def verify_qr(
    data: QRVerifyRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Verifies a scanned QR token and updates transaction status.
    """
    result = await verify_qr_token(data.token, current_user.id, db)
    return QRVerifyResponse(
        success=result["success"],
        message=result.get("message", "QR verification successful"),
        transaction_id=result["transaction_id"],
        qr_type=result["qr_type"],
    )
