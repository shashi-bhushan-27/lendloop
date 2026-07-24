"""
Trust Score Event Model

Immutable audit trail of every trust score change.
Prevents duplicate penalties/rewards and provides transparency.
"""

import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, ForeignKey, Float, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.database.base import Base


class TrustScoreEvent(Base):
    __tablename__ = "trust_score_events"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    transaction_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("transactions.id", ondelete="SET NULL"), nullable=True
    )

    event_type: Mapped[str] = mapped_column(String(50), nullable=False)
    # Examples: "on_time_return", "late_return", "successful_lend", "positive_review", "overdue_penalty", "phone_verified"

    score_change: Mapped[float] = mapped_column(Float, nullable=False)
    previous_score: Mapped[float] = mapped_column(Float, nullable=False)
    new_score: Mapped[float] = mapped_column(Float, nullable=False)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="trust_score_events")
    transaction = relationship("Transaction", back_populates="trust_score_events")

    __table_args__ = (
        Index("ix_trust_events_user", "user_id"),
        Index("ix_trust_events_transaction", "transaction_id"),
        Index("ix_trust_events_type", "event_type"),
    )
