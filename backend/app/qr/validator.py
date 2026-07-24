"""
QR Code Validator

Verifies a scanned QR token:
1. Decodes and verifies HMAC signature
2. Checks expiry
3. Checks single-use (not already used)
4. Verifies scanning user is a transaction participant
5. Updates transaction status accordingly with idempotency
"""

import hmac
import hashlib
import base64
import json
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from fastapi import HTTPException, status
from app.models.qr_verification import QRVerification
from app.models.transaction import Transaction, TransactionStatus
from app.models.item import Item, ItemStatus
from app.models.user import User
from app.core.config import settings
from app.services.trust_score_service import record_trust_score_event
from app.services.notification_service import send_notification_to_user
from app.models.notification import NotificationType
from loguru import logger
import uuid


async def verify_qr_token(
    token: str,
    scanning_user_id: uuid.UUID,
    db: AsyncSession,
) -> dict:
    """
    Verifies a QR token and updates the transaction status.
    Returns a success dict or raises HTTPException.
    """
    # Decode token
    try:
        decoded = json.loads(base64.urlsafe_b64decode(token.encode()).decode())
        payload = decoded["payload"]
        provided_sig = decoded["sig"]
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid QR token format.")

    # Verify signature
    payload_bytes = json.dumps(payload, sort_keys=True, default=str).encode()
    expected_sig = hmac.new(
        settings.QR_TOKEN_SECRET.encode(), payload_bytes, hashlib.sha256
    ).hexdigest()
    if not hmac.compare_digest(provided_sig, expected_sig):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="QR token signature invalid.")

    # Check expiry
    expires_at = datetime.fromisoformat(payload["expires_at"])
    if datetime.now(timezone.utc) > expires_at:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="QR token has expired.")

    # Find DB record with locking
    result = await db.execute(
        select(QRVerification).where(QRVerification.token == token).with_for_update()
    )
    qr_record = result.scalar_one_or_none()
    if not qr_record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="QR record not found.")
    if qr_record.is_used:
        # Idempotency: if already used by same transaction, return success without modifying
        return {
            "success": True,
            "transaction_id": qr_record.transaction_id,
            "qr_type": qr_record.qr_type,
            "message": "QR was already verified.",
        }

    # Get transaction with locking
    tx_result = await db.execute(
        select(Transaction).where(Transaction.id == qr_record.transaction_id).with_for_update()
    )
    transaction = tx_result.scalar_one()

    # Participant authorization
    if scanning_user_id not in (transaction.borrower_id, transaction.lender_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not authorized to verify this QR code."
        )

    # State machine validation
    qr_type_str = qr_record.qr_type.value

    if qr_type_str == "pickup":
        if transaction.status != TransactionStatus.awaiting_pickup:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Transaction is not awaiting pickup (current status: {transaction.status.value})."
            )
        transaction.status = TransactionStatus.borrowed
        transaction.pickup_time = datetime.now(timezone.utc)

        # Update item to borrowed
        item_result = await db.execute(select(Item).where(Item.id == transaction.item_id))
        item = item_result.scalar_one_or_none()
        if item:
            item.status = ItemStatus.borrowed

        # Update borrower stats
        borrower_result = await db.execute(select(User).where(User.id == transaction.borrower_id))
        borrower = borrower_result.scalar_one_or_none()
        if borrower:
            borrower.total_borrows += 1

        # Update lender stats
        lender_result = await db.execute(select(User).where(User.id == transaction.lender_id))
        lender = lender_result.scalar_one_or_none()
        if lender:
            lender.total_lends += 1

    elif qr_type_str == "return":
        if transaction.status != TransactionStatus.return_pending:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Return not initiated or already completed (current status: {transaction.status.value})."
            )
        transaction.status = TransactionStatus.completed
        transaction.return_time = datetime.now(timezone.utc)

        # Update item back to available
        item_result = await db.execute(select(Item).where(Item.id == transaction.item_id))
        item = item_result.scalar_one_or_none()
        if item:
            item.status = ItemStatus.available

        # Update borrower successful returns
        borrower_result = await db.execute(select(User).where(User.id == transaction.borrower_id))
        borrower = borrower_result.scalar_one_or_none()
        if borrower:
            borrower.successful_returns += 1

        # Record trust score event for on-time return (if not already updated)
        if not transaction.trust_score_updated:
            await record_trust_score_event(
                user_id=transaction.borrower_id,
                transaction_id=transaction.id,
                event_type="on_time_return",
                score_change=3.0,
                db=db,
            )
            await record_trust_score_event(
                user_id=transaction.lender_id,
                transaction_id=transaction.id,
                event_type="successful_lend",
                score_change=2.0,
                db=db,
            )
            transaction.trust_score_updated = True

        # Notify both parties
        await send_notification_to_user(
            user_id=transaction.borrower_id,
            notification_type=NotificationType.item_returned,
            title="Item Returned",
            body="The item has been successfully returned and the transaction is complete.",
            reference_id=str(transaction.id),
            reference_type="transaction",
            db=db,
        )
        await send_notification_to_user(
            user_id=transaction.lender_id,
            notification_type=NotificationType.item_returned,
            title="Item Received",
            body="The borrowed item has been returned. You can now leave a review.",
            reference_id=str(transaction.id),
            reference_type="transaction",
            db=db,
        )

    # Mark QR as used
    qr_record.is_used = True
    qr_record.used_at = datetime.now(timezone.utc)

    await db.flush()

    return {
        "success": True,
        "transaction_id": qr_record.transaction_id,
        "qr_type": qr_record.qr_type,
        "message": "QR verification successful",
    }
