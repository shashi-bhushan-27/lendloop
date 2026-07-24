"""
User Model

Represents a verified VIT student or staff member.
Domain restriction: only @vit.ac.in and @vitstudent.ac.in emails.
"""

import uuid
from datetime import datetime
from sqlalchemy import String, Boolean, Float, DateTime, Enum, Text, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.database.base import Base
import enum


class UserRole(str, enum.Enum):
    student = "student"
    admin = "admin"


class UserStatus(str, enum.Enum):
    active = "active"
    suspended = "suspended"
    pending = "pending"


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    firebase_uid: Mapped[str] = mapped_column(String(128), unique=True, nullable=False, index=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    phone_number: Mapped[str | None] = mapped_column(String(20), unique=True, nullable=True)
    phone_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    avatar_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    bio: Mapped[str | None] = mapped_column(Text, nullable=True)
    department: Mapped[str | None] = mapped_column(String(100), nullable=True)
    reg_number: Mapped[str | None] = mapped_column(String(50), unique=True, nullable=True)

    # Location / Privacy
    hostel_block: Mapped[str | None] = mapped_column(String(100), nullable=True)  # General area only
    preferred_pickup_location: Mapped[str | None] = mapped_column(String(255), nullable=True)  # Exact location, private

    # Trust & Status
    trust_score: Mapped[float] = mapped_column(Float, default=80.0)
    total_lends: Mapped[int] = mapped_column(default=0)
    total_borrows: Mapped[int] = mapped_column(default=0)
    successful_returns: Mapped[int] = mapped_column(default=0)
    overdue_count: Mapped[int] = mapped_column(default=0)
    role: Mapped[UserRole] = mapped_column(Enum(UserRole), default=UserRole.student)
    status: Mapped[UserStatus] = mapped_column(Enum(UserStatus), default=UserStatus.pending)
    is_email_verified: Mapped[bool] = mapped_column(Boolean, default=False)

    # Timestamps
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
    last_active: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Relationships
    items = relationship("Item", back_populates="owner", foreign_keys="Item.owner_id")
    sent_borrow_requests = relationship("BorrowRequest", back_populates="borrower", foreign_keys="BorrowRequest.borrower_id")
    received_borrow_requests = relationship("BorrowRequest", back_populates="lender", foreign_keys="BorrowRequest.lender_id")
    transactions_as_borrower = relationship("Transaction", back_populates="borrower", foreign_keys="Transaction.borrower_id")
    transactions_as_lender = relationship("Transaction", back_populates="lender", foreign_keys="Transaction.lender_id")
    reviews_given = relationship("Review", back_populates="reviewer", foreign_keys="Review.reviewer_id")
    reviews_received = relationship("Review", back_populates="reviewee", foreign_keys="Review.reviewee_id")
    notifications = relationship("Notification", back_populates="user")
    fcm_tokens = relationship("FCMToken", back_populates="user")
    trust_score_events = relationship("TrustScoreEvent", back_populates="user")

    __table_args__ = (
        Index("ix_users_email_domain", func.split_part(email, "@", 2)),
    )

    def __repr__(self) -> str:
        return f"<User {self.email}>"
