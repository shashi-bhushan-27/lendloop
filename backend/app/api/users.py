"""
Users Router

Endpoints:
  GET  /users/me              — Current user profile
  PUT  /users/me              — Update own profile
  GET  /users/{user_id}       — Public user profile (restricted visibility)
  GET  /users/{user_id}/contact — Contact info (transaction participants only)
  GET  /users/{user_id}/trust — Trust score details
  POST /users/me/avatar       — Upload profile avatar
"""

from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, and_
from app.database.connection import get_db
from app.auth.dependencies import get_current_user
from app.models.user import User
from app.models.transaction import Transaction, TransactionStatus
from app.database.connection import get_db
from app.auth.dependencies import get_current_user
from app.models.user import User
from app.models.transaction import Transaction
from app.schemas.user import UserResponse, UserPublicResponse, UserUpdate, UserContactResponse, TrustScoreResponse
from app.services.trust_score_service import recalculate_trust_score
import cloudinary.uploader
import uuid

router = APIRouter()


@router.get("/me", response_model=UserResponse)
async def get_my_profile(current_user: User = Depends(get_current_user)):
    return current_user


@router.put("/me", response_model=UserResponse)
async def update_my_profile(
    update_data: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    for field, value in update_data.model_dump(exclude_none=True).items():
        setattr(current_user, field, value)
    await db.flush()
    await db.refresh(current_user)
    return current_user


@router.get("/{user_id}", response_model=UserPublicResponse)
async def get_public_profile(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),  # Auth required to view profiles
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.get("/{user_id}/contact", response_model=UserContactResponse)
async def get_contact_info(
    user_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Returns contact details (phone, email, pickup location) only if:
    - The requester has an active or completed transaction with this user.
    """
    # Check for shared transaction
    tx_result = await db.execute(
        select(Transaction).where(
            or_(
                and_(Transaction.borrower_id == current_user.id, Transaction.lender_id == user_id),
                and_(Transaction.borrower_id == user_id, Transaction.lender_id == current_user.id),
            ),
            Transaction.status.in_([
                TransactionStatus.awaiting_pickup,
                TransactionStatus.borrowed,
                TransactionStatus.return_pending,
                TransactionStatus.completed,
            ])
        )
    )
    tx = tx_result.scalar_one_or_none()
    if not tx:
        raise HTTPException(status_code=403, detail="Contact details are only available to transaction participants.")

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return UserContactResponse(
        phone_number=user.phone_number,
        phone_verified=user.phone_verified,
        preferred_pickup_location=user.preferred_pickup_location,
        email=user.email,
    )


@router.get("/{user_id}/trust", response_model=TrustScoreResponse)
async def get_trust_score(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return TrustScoreResponse(
        user_id=user.id,
        trust_score=user.trust_score,
        total_lends=user.total_lends,
        total_borrows=user.total_borrows,
        successful_returns=user.successful_returns,
        overdue_count=user.overdue_count,
    )


@router.post("/me/avatar", summary="Upload Profile Avatar")
async def upload_avatar(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    contents = await file.read()
    result = cloudinary.uploader.upload(
        contents,
        folder=f"lendloop/avatars/{current_user.id}",
        transformation=[{"width": 300, "height": 300, "crop": "fill"}]
    )
    current_user.avatar_url = result["secure_url"]
    await db.flush()
    return {"avatar_url": current_user.avatar_url}
