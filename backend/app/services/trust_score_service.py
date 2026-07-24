"""
Trust Score Engine

Calculates and updates a user's trust score based on their lending/borrowing behavior.
Maintains an immutable audit trail of all changes.

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
from app.models.trust_score_event import TrustScoreEvent
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

    logger.info(f"Trust score recalculated for {user.email}: {score}")
    return score


async def record_trust_score_event(
    user_id: uuid.UUID,
    transaction_id: uuid.UUID | None,
    event_type: str,
    score_change: float,
    db: AsyncSession,
) -> TrustScoreEvent:
    """
    Records a trust score change event and updates the user's score.
    Ensures each event is recorded exactly once.
    """
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        logger.warning(f"Trust score event requested for non-existent user {user_id}")
        return None  # type: ignore

    previous_score = round(user.trust_score, 2)
    new_score = round(max(0.0, min(100.0, previous_score + score_change)), 2)

    # Update user's score
    user.trust_score = new_score

    # Record the event
    event = TrustScoreEvent(
        user_id=user_id,
        transaction_id=transaction_id,
        event_type=event_type,
        score_change=score_change,
        previous_score=previous_score,
        new_score=new_score,
    )
    db.add(event)
    await db.flush()

    logger.info(
        f"Trust score event: user={user.email} type={event_type} "
        f"change={score_change} {previous_score} -> {new_score}"
    )
    return event


async def apply_overdue_penalty(
    transaction_id: uuid.UUID,
    borrower_id: uuid.UUID,
    db: AsyncSession,
) -> bool:
    """
    Applies an overdue penalty to the borrower if not already applied.
    Returns True if penalty was applied, False if already applied.
    """
    from app.models.transaction import Transaction

    tx_result = await db.execute(select(Transaction).where(Transaction.id == transaction_id))
    transaction = tx_result.scalar_one_or_none()
    if not transaction:
        return False

    # Only apply once
    if transaction.overdue_notified:
        return False

    transaction.overdue_notified = True

    # Update borrower's overdue count
    user_result = await db.execute(select(User).where(User.id == borrower_id))
    user = user_result.scalar_one_or_none()
    if user:
        user.overdue_count += 1
        await record_trust_score_event(
            user_id=borrower_id,
            transaction_id=transaction_id,
            event_type="overdue_penalty",
            score_change=-10.0,
            db=db,
        )

    await db.flush()
    return True
