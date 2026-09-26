"""
Borrow Requests Router

Endpoints:
  POST /borrow                       — Create borrow request
  GET  /borrow/sent                  — My sent requests
  GET  /borrow/received              — Received requests (lender view)
  POST /borrow/{id}/approve          — Approve a request
  POST /borrow/{id}/reject           — Reject a request
  DELETE /borrow/{id}                — Cancel a request (borrower only)
"""

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database.connection import get_db
from app.auth.dependencies import get_current_user
from app.models.user import User
from app.models.borrow_request import BorrowRequest, RequestStatus
from app.models.item import Item
from app.models.notification import NotificationType
from app.schemas.borrow_request import BorrowRequestCreate, BorrowRequestReject, BorrowRequestResponse
from app.services.borrow_service import create_borrow_request, approve_request, cancel_request
from app.services.notification_service import send_notification_to_user
from app.schemas.transaction import TransactionResponse
from typing import List
import uuid

router = APIRouter()


@router.post("", response_model=BorrowRequestResponse, status_code=status.HTTP_201_CREATED)
async def create_request(
    data: BorrowRequestCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await create_borrow_request(data, current_user, db)


@router.get("/sent", response_model=List[BorrowRequestResponse])
async def my_sent_requests(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(BorrowRequest).where(BorrowRequest.borrower_id == current_user.id)
    )
    return result.scalars().all()


@router.get("/received", response_model=List[BorrowRequestResponse])
async def received_requests(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(BorrowRequest).where(BorrowRequest.lender_id == current_user.id)
    )
    return result.scalars().all()


@router.post("/{request_id}/approve", response_model=TransactionResponse)
async def approve(
    request_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await approve_request(request_id, current_user, db)


@router.post("/{request_id}/reject")
async def reject(
    request_id: uuid.UUID,
    data: BorrowRequestReject,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from datetime import datetime, timezone
    result = await db.execute(
        select(BorrowRequest).where(
            BorrowRequest.id == request_id,
            BorrowRequest.lender_id == current_user.id,
        )
    )
    req = result.scalar_one_or_none()
    from fastapi import HTTPException
    if not req:
        raise HTTPException(status_code=404, detail="Request not found.")
    if req.status != RequestStatus.pending:
        raise HTTPException(status_code=409, detail="Only pending requests can be declined.")
    req.status = RequestStatus.rejected
    req.rejection_reason = data.rejection_reason
    req.responded_at = datetime.now(timezone.utc)

    item_result = await db.execute(select(Item.title).where(Item.id == req.item_id))
    item_title = item_result.scalar_one_or_none() or "the item"
    await send_notification_to_user(
        user_id=req.borrower_id,
        notification_type=NotificationType.request_rejected,
        title="Request Declined",
        body=f"Your request for {item_title} was declined: {data.rejection_reason}",
        reference_id=str(req.id),
        reference_type="borrow_request",
        db=db,
    )
    return {"message": "Request rejected"}


@router.delete("/{request_id}")
async def cancel(
    request_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await cancel_request(request_id, current_user, db)
