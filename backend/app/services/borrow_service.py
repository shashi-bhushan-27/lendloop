"""
Borrow Request Service

Manages the full lifecycle of a borrow request:
pending → approved/rejected → transaction created.
"""

from datetime import datetime, timezone, date
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from sqlalchemy.orm import selectinload
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
    """Create a new borrow request with validation."""
    item_result = await db.execute(
        select(Item).where(Item.id == data.item_id)
    )
    item = item_result.scalar_one_or_none()

    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found.")
    if item.owner_id == borrower.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot borrow your own item.")
    if item.status != ItemStatus.available:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Item is not available.")

    # Check for duplicate active requests from this user for this item
    existing_result = await db.execute(
        select(BorrowRequest).where(
            and_(
                BorrowRequest.item_id == data.item_id,
                BorrowRequest.borrower_id == borrower.id,
                BorrowRequest.status == RequestStatus.pending,
            )
        )
    )
    if existing_result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="You already have a pending request for this item."
        )

    # Validate borrow duration doesn't exceed item's max
    requested_days = (data.proposed_end_date - data.proposed_start_date).days + 1
    if requested_days > item.max_borrow_days:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Borrow period exceeds item's maximum of {item.max_borrow_days} days."
        )
    if data.proposed_end_date < data.proposed_start_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="End date must be after start date."
        )

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
    """
    Approve a borrow request and create a transaction.
    Uses pessimistic locking to prevent race conditions.
    """
    # Lock the borrow request row
    result = await db.execute(
        select(BorrowRequest)
        .where(BorrowRequest.id == request_id)
        .with_for_update()
    )
    request = result.scalar_one_or_none()

    if not request or request.lender_id != lender.id:
        raise HTTPException(status_code=404, detail="Request not found.")
    if request.status != RequestStatus.pending:
        raise HTTPException(status_code=409, detail="Request is no longer pending.")

    # Lock the item row to prevent concurrent approvals
    item_result = await db.execute(
        select(Item)
        .where(Item.id == request.item_id)
        .with_for_update()
    )
    item = item_result.scalar_one_or_none()
    if not item or item.status != ItemStatus.available:
        raise HTTPException(status_code=409, detail="Item is no longer available.")

    # Approve this request
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
        status=TransactionStatus.awaiting_pickup,
    )
    db.add(transaction)

    # Update item status
    item.status = ItemStatus.reserved
    item.borrow_count += 1

    # Reject all other pending requests for this item
    other_requests_result = await db.execute(
        select(BorrowRequest).where(
            and_(
                BorrowRequest.item_id == request.item_id,
                BorrowRequest.id != request.id,
                BorrowRequest.status == RequestStatus.pending,
            )
        )
    )
    other_requests = other_requests_result.scalars().all()
    for other in other_requests:
        other.status = RequestStatus.rejected
        other.rejection_reason = "Another request was approved for this item."
        other.responded_at = datetime.now(timezone.utc)
        # Notify other borrowers
        await send_notification_to_user(
            user_id=other.borrower_id,
            notification_type=NotificationType.request_rejected,
            title="Request Not Approved",
            body=f"Your request for {item.title} was not approved — another borrower was selected.",
            reference_id=str(other.id),
            reference_type="borrow_request",
            db=db,
        )

    await db.flush()

    # Notify approved borrower
    await send_notification_to_user(
        user_id=request.borrower_id,
        notification_type=NotificationType.request_approved,
        title="Request Approved! 🎉",
        body=f"Your request for {item.title} has been approved. Proceed to pickup.",
        reference_id=str(transaction.id),
        reference_type="transaction",
        db=db,
    )

    # Notify lender
    await send_notification_to_user(
        user_id=lender.id,
        notification_type=NotificationType.request_approved,
        title="Request Approved",
        body=f"You approved the request for {item.title}. Awaiting pickup.",
        reference_id=str(transaction.id),
        reference_type="transaction",
        db=db,
    )

    return transaction


async def cancel_request(request_id: uuid.UUID, borrower: User, db: AsyncSession) -> dict:
    """Allow borrower to cancel their pending request."""
    result = await db.execute(
        select(BorrowRequest).where(BorrowRequest.id == request_id)
    )
    request = result.scalar_one_or_none()

    if not request or request.borrower_id != borrower.id:
        raise HTTPException(status_code=404, detail="Request not found.")
    if request.status != RequestStatus.pending:
        raise HTTPException(status_code=409, detail="Only pending requests can be cancelled.")

    request.status = RequestStatus.cancelled
    request.responded_at = datetime.now(timezone.utc)

    return {"message": "Request cancelled successfully."}
