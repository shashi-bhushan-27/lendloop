"""
Authentication Router

Endpoints:
  POST /api/v1/auth/login       — Firebase token → JWT
  POST /api/v1/auth/refresh     — Refresh JWT
  POST /api/v1/auth/logout      — Revoke FCM token
  POST /api/v1/auth/fcm-token   — Register FCM device token
  POST /api/v1/auth/send-otp    — Send 6-digit OTP via Postmark
  POST /api/v1/auth/verify-otp  — Verify OTP and mark email verified
"""

from fastapi import APIRouter, Depends, Body
from pydantic import BaseModel, EmailStr
from sqlalchemy.ext.asyncio import AsyncSession
from app.database.connection import get_db
from app.services.auth_service import register_or_login_user
from app.auth.dependencies import get_current_user
from app.schemas.user import UserResponse
from app.schemas.notification import FCMTokenRegister
from app.models.notification import FCMToken
from app.models.user import User
from sqlalchemy import select, delete

router = APIRouter()


# ── Schemas for OTP endpoints ─────────────────────────────────────────────────

class OTPRequest(BaseModel):
    email: EmailStr

class OTPVerifyRequest(BaseModel):
    email: EmailStr
    otp: str


@router.post("/login", summary="Login or Register with Firebase")
async def login(
    firebase_token: str = Body(..., embed=True),
    full_name: str = Body(default="", embed=True),
    reg_number: str = Body(default="", embed=True),
    db: AsyncSession = Depends(get_db),
):
    """
    Accepts a Firebase ID token from the Flutter client.
    Validates domain, creates/finds user, returns JWT tokens.
    """
    result = await register_or_login_user(firebase_token, db, full_name, reg_number)
    return {
        "access_token": result["access_token"],
        "refresh_token": result["refresh_token"],
        "token_type": "bearer",
        "user": UserResponse.model_validate(result["user"]),
    }


@router.post("/fcm-token", summary="Register FCM Device Token")
async def register_fcm_token(
    payload: FCMTokenRegister,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Register or update FCM token for push notifications."""
    existing = await db.execute(
        select(FCMToken).where(FCMToken.token == payload.token)
    )
    if not existing.scalar_one_or_none():
        fcm = FCMToken(
            user_id=current_user.id,
            token=payload.token,
            device_type=payload.device_type,
        )
        db.add(fcm)
        await db.flush()
    return {"message": "FCM token registered"}


@router.delete("/fcm-token", summary="Remove FCM Device Token")
async def remove_fcm_token(
    token: str = Body(..., embed=True),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await db.execute(
        delete(FCMToken).where(
            FCMToken.token == token,
            FCMToken.user_id == current_user.id
        )
    )
    await db.flush()
    return {"message": "FCM token removed"}


# ── OTP Endpoints (isolated — failures here don't affect login) ───────────────

@router.post("/send-otp", summary="Send OTP verification code")
async def send_otp(
    payload: OTPRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Send a 6-digit OTP to the user's email via Postmark.
    Validates VIT domain before sending.
    """
    from app.auth.firebase_auth import validate_email_domain
    from app.services.otp_service import create_and_send_otp

    validate_email_domain(payload.email)
    return await create_and_send_otp(db, payload.email)


@router.post("/verify-otp", summary="Verify OTP code")
async def verify_otp_endpoint(
    payload: OTPVerifyRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Verify a 6-digit OTP. On success, marks user email as verified
    and returns JWT tokens.
    """
    from app.services.otp_service import verify_otp
    from app.auth.jwt_handler import create_access_token, create_refresh_token

    user = await verify_otp(db, payload.email, payload.otp)
    if not user:
        return {"message": "Email verified. Please log in."}

    # Issue JWT tokens for the verified user
    token_data = {"sub": str(user.id), "email": user.email, "role": user.role.value}
    access_token = create_access_token(token_data)
    refresh_token = create_refresh_token(token_data)

    return {
        "message": "Email verified successfully!",
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
    }

