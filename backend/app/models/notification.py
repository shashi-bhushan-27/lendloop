"""
Notification Model

Stores in-app notifications for users.
FCM push notifications are sent separately via notification_service.
"""

import uuid
from datetime import datetime
from sqlalchemy import String, Boolean, Text, ForeignKey, DateTime, Enum, JSON, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.database.base import Base
import enum


class NotificationType(str, enum.Enum):
    borrow_request = "borrow_request"
    request_approved = "request_approved"
    request_rejected = "request_rejected"
    pickup_reminder = "pickup_reminder"
    return_reminder = "return_reminder"
    overdue_alert = "overdue_alert"
    item_returned = "item_returned"
    review_received = "review_received"
    trust_score_update = "trust_score_update"
    system = "system"


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )

    type: Mapped[NotificationType] = mapped_column(Enum(NotificationType), nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    data: Mapped[dict | None] = mapped_column(JSON, nullable=True)  # Extra metadata
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)

    # Optional reference to entity
    reference_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    reference_type: Mapped[str | None] = mapped_column(String(50), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    user = relationship("User", back_populates="notifications")

    __table_args__ = (
        Index("ix_notifications_user", "user_id"),
        Index("ix_notifications_is_read", "is_read"),
    )


class FCMToken(Base):
    """Stores Firebase Cloud Messaging device tokens per user."""
    __tablename__ = "fcm_tokens"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    token: Mapped[str] = mapped_column(Text, nullable=False, unique=True)
    device_type: Mapped[str] = mapped_column(String(20), default="android")  # android/ios
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="fcm_tokens")
