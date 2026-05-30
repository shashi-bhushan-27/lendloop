"""
Borrow Request Service

Manages the full lifecycle of a borrow request:
pending → approved/rejected → transaction created.
"""

from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from fastapi import HTTPException, status
from app.models.borrow_request import BorrowRequest, RequestStatus
from app.models.item import Item, ItemStatus
from app.models.transaction import Transaction, TransactionStatus
from app.models.user import User
from app.schemas.borrow_request import BorrowRequestCreate
from app.services.notification_service import send_notification_to_user
from app.models.notification import NotificationType
from loguru import logger
import uuid


async def create_borrow_request(
    data: BorrowRequestCreate,
    borrower: User,
    db: AsyncSession,
) -> BorrowRequest:
    """Create a new borrow request."""
    item_result = await db.execute(select(Item).where(Item.id == data.item_id))
    item = item_result.scalar_one_or_none()

    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found.")
    if item.owner_id == borrower.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot borrow your own item.")
    if item.status != ItemStatus.available:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Item is not available.")

    request = BorrowRequest(
        item_id=data.item_id,
        borrower_id=borrower.id,
        lender_id=item.owner_id,
        message=data.message,
        proposed_start_date=data.proposed_start_date,
        proposed_end_date=data.proposed_end_date,
    )
    db.add(request)
    await db.flush()

    # Notify lender
    await send_notification_to_user(
        user_id=item.owner_id,
        notification_type=NotificationType.borrow_request,
        title="New Borrow Request",
        body=f"{borrower.full_name} wants to borrow your item: {item.title}",
        reference_id=str(request.id),
        reference_type="borrow_request",
        db=db,
    )

    return request


async def approve_request(request_id: uuid.UUID, lender: User, db: AsyncSession) -> Transaction:
    """Approve a borrow request and create a transaction."""
    result = await db.execute(select(BorrowRequest).where(BorrowRequest.id == request_id))
    request = result.scalar_one_or_none()

    if not request or request.lender_id != lender.id:
        raise HTTPException(status_code=404, detail="Request not found.")
    if request.status != RequestStatus.pending:
        raise HTTPException(status_code=409, detail="Request is no longer pending.")

    request.status = RequestStatus.approved
    request.responded_at = datetime.now(timezone.utc)

    # Create transaction
    transaction = Transaction(
        borrow_request_id=request.id,
        item_id=request.item_id,
        borrower_id=request.borrower_id,
        lender_id=request.lender_id,
        start_date=request.proposed_start_date,
        due_date=request.proposed_end_date,
        status=TransactionStatus.active,
    )
    db.add(transaction)

    # Update item status
    item_result = await db.execute(select(Item).where(Item.id == request.item_id))
    item = item_result.scalar_one()
    item.status = ItemStatus.reserved
    item.borrow_count += 1

    await db.flush()

    # Notify borrower
    await send_notification_to_user(
        user_id=request.borrower_id,
        notification_type=NotificationType.request_approved,
        title="Request Approved! 🎉",
        body=f"Your request for {item.title} has been approved. Proceed to pickup.",
        reference_id=str(transaction.id),
        reference_type="transaction",
        db=db,
    )

    return transaction
