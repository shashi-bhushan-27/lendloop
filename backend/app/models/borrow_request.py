"""
Borrow Request Model

Lifecycle: pending → approved/rejected → (if approved) → Transaction created.
"""

import uuid
from datetime import date, datetime
from sqlalchemy import String, Date, DateTime, Enum, Text, ForeignKey, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.database.base import Base
import enum


class RequestStatus(str, enum.Enum):
    pending = "pending"
    approved = "approved"
    rejected = "rejected"
    cancelled = "cancelled"
    expired = "expired"


class BorrowRequest(Base):
    __tablename__ = "borrow_requests"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    item_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("items.id", ondelete="CASCADE"), nullable=False
    )
    borrower_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    lender_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )

    # Request Details
    message: Mapped[str | None] = mapped_column(Text, nullable=True)
    proposed_start_date: Mapped[date] = mapped_column(Date, nullable=False)
    proposed_end_date: Mapped[date] = mapped_column(Date, nullable=False)
    status: Mapped[RequestStatus] = mapped_column(Enum(RequestStatus), default=RequestStatus.pending)
    rejection_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Timestamps
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
    responded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Relationships
    item = relationship("Item", back_populates="borrow_requests")
    borrower = relationship("User", back_populates="sent_borrow_requests", foreign_keys=[borrower_id])
    lender = relationship("User", back_populates="received_borrow_requests", foreign_keys=[lender_id])
    transaction = relationship("Transaction", back_populates="borrow_request", uselist=False)

    __table_args__ = (
        Index("ix_borrow_requests_borrower", "borrower_id"),
        Index("ix_borrow_requests_lender", "lender_id"),
        Index("ix_borrow_requests_status", "status"),
    )
