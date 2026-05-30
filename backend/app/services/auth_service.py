"""
Authentication Service

Handles user registration and login business logic.
Coordinates Firebase token verification, domain validation,
JWT issuance, and user record creation/lookup.
"""

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from fastapi import HTTPException, status
from loguru import logger
from app.models.user import User, UserStatus
from app.schemas.user import UserCreate
from app.auth.firebase_auth import verify_firebase_token, validate_email_domain
from app.auth.jwt_handler import create_access_token, create_refresh_token
import uuid


async def register_or_login_user(
    firebase_id_token: str,
    db: AsyncSession,
    full_name: str = "",
    reg_number: str = ""
) -> dict:
    """
    Core auth flow:
    1. Verify Firebase ID token
    2. Validate VIT email domain
    3. Find or create user in DB
    4. Issue JWT tokens
    """
    # Step 1: Verify Firebase token
    decoded = await verify_firebase_token(firebase_id_token)
    firebase_uid = decoded["uid"]
    email = decoded.get("email", "")

    if not email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email not found in Firebase token."
        )

    # Step 2: Domain restriction
    validate_email_domain(email)

    # Step 3: Find or create user
    try:
        result = await db.execute(select(User).where(User.firebase_uid == firebase_uid))
        user = result.scalar_one_or_none()

        if not user:
            # New user registration
            user = User(
                firebase_uid=firebase_uid,
                email=email,
                full_name=full_name or decoded.get("name", email.split("@")[0]),
                is_email_verified=decoded.get("email_verified", False),
                status=UserStatus.active,
                reg_number=reg_number if reg_number else None,
            )
            db.add(user)
            await db.flush()
            await db.refresh(user)
            logger.info(f"New user registered: {email}")
        else:
            # Update email verification status
            user.is_email_verified = decoded.get("email_verified", user.is_email_verified)
            user.status = UserStatus.active  # Ensure active on login
            # Update reg_number if provided and not already set
            if reg_number and not user.reg_number:
                user.reg_number = reg_number
            await db.flush()
            logger.info(f"Existing user logged in: {email}")

    except Exception as e:
        logger.error(f"DB error during user creation/lookup: {type(e).__name__}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error: {str(e)}"
        )

    # Step 4: Issue JWT
    token_data = {"sub": str(user.id), "email": user.email, "role": user.role.value}
    access_token = create_access_token(token_data)
    refresh_token = create_refresh_token(token_data)

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user": user,
    }
