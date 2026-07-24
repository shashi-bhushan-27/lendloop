"""
Authentication Router

Endpoints:
  POST /api/v1/auth/login       — Firebase token → JWT
  POST /api/v1/auth/refresh     — Refresh JWT
  POST /api/v1/auth/logout      — Revoke FCM token
  POST /api/v1/auth/fcm-token   — Register FCM device token
"""

from fastapi import APIRouter, Depends, Body
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
