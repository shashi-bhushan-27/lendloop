"""
QR Code Validator

Verifies a scanned QR token:
1. Decodes and verifies HMAC signature
2. Checks expiry
3. Checks single-use (not already used)
4. Updates transaction status accordingly
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
from app.core.config import settings
from loguru import logger


async def verify_qr_token(
    token: str,
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

    # Find DB record
    result = await db.execute(select(QRVerification).where(QRVerification.token == token))
    qr_record = result.scalar_one_or_none()
    if not qr_record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="QR record not found.")
    if qr_record.is_used:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="QR token has already been used.")

    # Mark as used
    qr_record.is_used = True
    qr_record.used_at = datetime.now(timezone.utc)

    # Update transaction
    tx_result = await db.execute(select(Transaction).where(Transaction.id == qr_record.transaction_id))
    transaction = tx_result.scalar_one()

    if qr_record.qr_type.value == "pickup":
        transaction.status = TransactionStatus.picked_up
        transaction.pickup_time = datetime.now(timezone.utc)
    elif qr_record.qr_type.value == "return":
        transaction.status = TransactionStatus.returned
        transaction.return_time = datetime.now(timezone.utc)
        # Update item back to available
        from app.models.item import Item, ItemStatus
        item_result = await db.execute(select(Item).where(Item.id == transaction.item_id))
        item = item_result.scalar_one_or_none()
        if item:
            item.status = ItemStatus.available
        # Update borrower stats
        from app.models.user import User
        borrower_result = await db.execute(select(User).where(User.id == transaction.borrower_id))
        borrower = borrower_result.scalar_one_or_none()
        if borrower:
            borrower.successful_returns += 1

    await db.flush()

    return {
        "success": True,
        "transaction_id": qr_record.transaction_id,
        "qr_type": qr_record.qr_type,
    }
