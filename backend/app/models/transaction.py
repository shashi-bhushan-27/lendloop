"""
Transaction Model

Created when a borrow request is approved.
Lifecycle: awaiting_pickup → borrowed → return_pending → completed / overdue.
"""

import uuid
from datetime import date, datetime
from sqlalchemy import String, Date, DateTime, Enum, Text, ForeignKey, Boolean, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.database.base import Base
import enum


class TransactionStatus(str, enum.Enum):
    awaiting_pickup = "awaiting_pickup"   # Approved, awaiting pickup
    borrowed = "borrowed"                 # QR pickup confirmed, item in use
    return_pending = "return_pending"     # Borrower initiated return
    completed = "completed"               # Return QR verified + lender confirmed
    overdue = "overdue"                   # Past due date, not returned
    disputed = "disputed"                 # Raised a dispute
    cancelled = "cancelled"


class Transaction(Base):
    __tablename__ = "transactions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    borrow_request_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("borrow_requests.id", ondelete="CASCADE"), nullable=False, unique=True
    )
    item_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("items.id", ondelete="CASCADE"), nullable=False
    )
    borrower_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    lender_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )

    # Timeline
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    due_date: Mapped[date] = mapped_column(Date, nullable=False)
    pickup_time: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    return_time: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Status
    status: Mapped[TransactionStatus] = mapped_column(Enum(TransactionStatus), default=TransactionStatus.awaiting_pickup)
    is_overdue: Mapped[bool] = mapped_column(Boolean, default=False)
    overdue_notified: Mapped[bool] = mapped_column(Boolean, default=False)  # Penalty applied exactly once
    trust_score_updated: Mapped[bool] = mapped_column(Boolean, default=False)  # Ensure score update happens once

    # Media (return condition photo)
    return_image_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    return_notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Timestamps
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # Relationships
    borrow_request = relationship("BorrowRequest", back_populates="transaction")
    item = relationship("Item", back_populates="transactions")
    borrower = relationship("User", back_populates="transactions_as_borrower", foreign_keys=[borrower_id])
    lender = relationship("User", back_populates="transactions_as_lender", foreign_keys=[lender_id])
    qr_verifications = relationship("QRVerification", back_populates="transaction")
    reviews = relationship("Review", back_populates="transaction")
    evidence_photos = relationship("TransactionEvidencePhoto", back_populates="transaction")
    trust_score_events = relationship("TrustScoreEvent", back_populates="transaction")

    __table_args__ = (
        Index("ix_transactions_borrower", "borrower_id"),
        Index("ix_transactions_lender", "lender_id"),
        Index("ix_transactions_status", "status"),
        Index("ix_transactions_due_date", "due_date"),
    )
