"""
OTP Service

Handles generation, storage, rate-limiting, and verification
of 6-digit email OTPs for account verification.

Isolated: uses its own model (EmailOTP) and does not modify
the existing auth flow. Existing login/register continues to
work even if OTP endpoints fail.
"""

import secrets
from datetime import datetime, timedelta, timezone
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func as sa_func, update
from loguru import logger
from passlib.hash import bcrypt

from app.models.email_otp import EmailOTP
from app.models.user import User
from app.services.postmark_client import send_otp_email
from app.core.config import settings


def generate_otp() -> str:
    """Generate a cryptographically secure 6-digit OTP."""
    return f"{secrets.randbelow(1000000):06d}"


async def create_and_send_otp(db: AsyncSession, email: str) -> dict:
    """
    Generate an OTP, store it (hashed), and send it via Postmark.

    Rate-limits: max OTP_RATE_LIMIT_COUNT OTPs per email per
    OTP_RATE_LIMIT_WINDOW_MINUTES minutes.
    """
    # Rate-limit check
    window_start = datetime.now(timezone.utc) - timedelta(
        minutes=settings.OTP_RATE_LIMIT_WINDOW_MINUTES
    )
    count_stmt = select(sa_func.count()).where(
        EmailOTP.email == email,
        EmailOTP.created_at >= window_start,
    )
    result = await db.execute(count_stmt)
    recent_count = result.scalar() or 0

    if recent_count >= settings.OTP_RATE_LIMIT_COUNT:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Too many verification codes requested. Please wait {settings.OTP_RATE_LIMIT_WINDOW_MINUTES} minutes.",
        )

    # Invalidate any previous unused OTPs for this email
    await db.execute(
        update(EmailOTP)
        .where(EmailOTP.email == email, EmailOTP.is_used == False)  # noqa: E712
        .values(is_used=True)
    )

    # Generate and store new OTP
    otp_code = generate_otp()
    otp_hash = bcrypt.hash(otp_code)
    expires_at = datetime.now(timezone.utc) + timedelta(
        minutes=settings.OTP_EXPIRE_MINUTES
    )

    otp_entry = EmailOTP(
        email=email,
        otp_hash=otp_hash,
        expires_at=expires_at,
    )
    db.add(otp_entry)
    await db.flush()

    # Send via Postmark
    sent = await send_otp_email(email, otp_code)
    if not sent:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to send verification email. Please try again.",
        )

    logger.info(f"OTP created and sent to {email}")
    return {"message": "Verification code sent to your email."}


async def verify_otp(db: AsyncSession, email: str, otp_code: str) -> User:
    """
    Verify a submitted OTP code.

    Returns the verified User on success.
    Raises HTTPException on failure.
    """
    # Find latest unused, non-expired OTP for this email
    stmt = (
        select(EmailOTP)
        .where(
            EmailOTP.email == email,
            EmailOTP.is_used == False,  # noqa: E712
            EmailOTP.expires_at > datetime.now(timezone.utc),
        )
        .order_by(EmailOTP.id.desc())
        .limit(1)
    )
    result = await db.execute(stmt)
    otp_record = result.scalar_one_or_none()

    if not otp_record:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired verification code. Please request a new one.",
        )

    # Brute-force protection
    if otp_record.attempts >= settings.OTP_MAX_ATTEMPTS:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many failed attempts. Please request a new code.",
        )

    # Verify OTP
    if not bcrypt.verify(otp_code, otp_record.otp_hash):
        otp_record.attempts += 1
        await db.flush()
        remaining = settings.OTP_MAX_ATTEMPTS - otp_record.attempts
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Incorrect verification code. {remaining} attempts remaining.",
        )

    # Success — mark OTP as used
    otp_record.is_used = True

    # Mark the user's email as verified
    user_stmt = select(User).where(User.email == email)
    user_result = await db.execute(user_stmt)
    user = user_result.scalar_one_or_none()

    if user:
        user.is_email_verified = True
        await db.flush()
        logger.info(f"Email verified for {email}")
    else:
        logger.warning(f"OTP verified but no user found for {email}")

    return user
