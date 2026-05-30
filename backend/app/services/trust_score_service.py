"""
Trust Score Engine

Calculates and updates a user's trust score based on their lending/borrowing behavior.

Formula:
  trust_score = base_score
    + (successful_returns / max(total_borrows, 1)) * 40   # Return rate (0-40)
    + (avg_rating / 5.0) * 30                              # Review quality (0-30)
    - (overdue_count * 5)                                  # Overdue penalty (-5 per)
    + (total_lends / 10) * 5                               # Lender activity bonus (0-15, capped)
    + 5 if phone_verified                                  # Phone verification bonus

Final score is clamped between 0 and 100.
"""

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.models.user import User
from app.models.review import Review
from loguru import logger
import uuid


async def recalculate_trust_score(user_id: uuid.UUID, db: AsyncSession) -> float:
    """
    Recalculates and persists a user's trust score.
    Call this after any significant user action (return, review, overdue).
    """
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        return 0.0

    # Get average rating from reviews received
    rating_result = await db.execute(
        select(func.avg(Review.rating)).where(Review.reviewee_id == user_id)
    )
    avg_rating = rating_result.scalar() or 3.0  # Default neutral

    # Component calculations
    base = 10.0
    return_rate_score = (user.successful_returns / max(user.total_borrows, 1)) * 40
    review_score = (float(avg_rating) / 5.0) * 30
    overdue_penalty = min(user.overdue_count * 5, 30)  # Cap at -30
    lender_bonus = min((user.total_lends / 10) * 5, 15)
    phone_bonus = 5.0 if user.phone_verified else 0.0

    score = base + return_rate_score + review_score - overdue_penalty + lender_bonus + phone_bonus
    score = round(max(0.0, min(100.0, score)), 2)

    user.trust_score = score
    await db.flush()

    logger.info(f"Trust score updated for {user.email}: {score}")
    return score
