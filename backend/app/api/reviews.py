"""
Reviews Router

Endpoints:
  POST /reviews                  — Submit a review
  GET  /reviews/user/{user_id}   — Reviews for a user
"""

from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database.connection import get_db
from app.auth.dependencies import get_current_user
from app.models.user import User
from app.models.review import Review
from app.models.transaction import Transaction, TransactionStatus
from app.schemas.review import ReviewCreate, ReviewResponse
from app.services.trust_score_service import recalculate_trust_score
from typing import List
import uuid

router = APIRouter()


@router.post("", response_model=ReviewResponse, status_code=status.HTTP_201_CREATED)
async def submit_review(
    data: ReviewCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Validate transaction exists and is complete
    tx_result = await db.execute(select(Transaction).where(Transaction.id == data.transaction_id))
    tx = tx_result.scalar_one_or_none()
    if not tx or tx.status != TransactionStatus.returned:
        raise HTTPException(status_code=400, detail="Can only review completed transactions.")
    if current_user.id not in (tx.borrower_id, tx.lender_id):
        raise HTTPException(status_code=403, detail="Not part of this transaction.")

    review = Review(
        transaction_id=data.transaction_id,
        reviewer_id=current_user.id,
        reviewee_id=data.reviewee_id,
        rating=data.rating,
        comment=data.comment,
    )
    db.add(review)
    await db.flush()

    # Recalculate trust score for reviewee
    await recalculate_trust_score(data.reviewee_id, db)

    await db.refresh(review)
    return review


@router.get("/user/{user_id}", response_model=List[ReviewResponse])
async def get_user_reviews(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Review).where(Review.reviewee_id == user_id).order_by(Review.created_at.desc())
    )
    return result.scalars().all()
