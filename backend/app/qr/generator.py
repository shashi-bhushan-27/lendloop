"""
QR Code Generator

Generates signed QR tokens for pickup and return verification.
Tokens are:
- Signed with HMAC-SHA256
- Time-limited (configurable expiry)
- Single-use (tracked in DB)
"""

import qrcode
import io
import hmac
import hashlib
import base64
import json
from datetime import datetime, timedelta, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.qr_verification import QRVerification, QRType
from app.core.config import settings
from loguru import logger
import uuid


def _sign_token(payload: dict) -> str:
    """Sign a payload dictionary and return a base64-encoded token."""
    payload_bytes = json.dumps(payload, sort_keys=True, default=str).encode()
    sig = hmac.new(
        settings.QR_TOKEN_SECRET.encode(),
        payload_bytes,
        hashlib.sha256
    ).hexdigest()
    token_data = {"payload": payload, "sig": sig}
    return base64.urlsafe_b64encode(
        json.dumps(token_data).encode()
    ).decode()


def generate_qr_image_bytes(token: str) -> bytes:
    """Generate a QR code image from a token string. Returns PNG bytes."""
    qr = qrcode.QRCode(version=1, box_size=10, border=4)
    qr.add_data(token)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")
    buffer = io.BytesIO()
    img.save(buffer, format="PNG")
    return buffer.getvalue()


async def create_qr_token(
    transaction_id: uuid.UUID,
    qr_type: QRType,
    db: AsyncSession,
) -> QRVerification:
    """Create a signed QR token for a transaction and store in DB."""
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.QR_TOKEN_EXPIRE_MINUTES)

    payload = {
        "transaction_id": str(transaction_id),
        "type": qr_type.value,
        "expires_at": expires_at.isoformat(),
        "nonce": str(uuid.uuid4()),
    }
    token = _sign_token(payload)

    qr_record = QRVerification(
        transaction_id=transaction_id,
        token=token,
        qr_type=qr_type,
        expires_at=expires_at,
    )
    db.add(qr_record)
    await db.flush()
    await db.refresh(qr_record)

    return qr_record
