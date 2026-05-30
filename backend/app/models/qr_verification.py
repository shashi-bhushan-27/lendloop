"""
QR Verification Model

Tracks QR code usage for pickup and return verification.
Each QR token is single-use and time-limited.
"""

import uuid
from datetime import datetime
from sqlalchemy import String, Boolean, DateTime, ForeignKey, Enum, Text, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.database.base import Base
import enum


class QRType(str, enum.Enum):
    pickup = "pickup"
    return_ = "return"


class QRVerification(Base):
    __tablename__ = "qr_verifications"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    transaction_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("transactions.id", ondelete="CASCADE"), nullable=False
    )

    token: Mapped[str] = mapped_column(String(512), unique=True, nullable=False)
    qr_type: Mapped[QRType] = mapped_column(Enum(QRType), nullable=False)
    qr_image_url: Mapped[str | None] = mapped_column(Text, nullable=True)  # Cloudinary URL of QR image

    # Lifecycle
    is_used: Mapped[bool] = mapped_column(Boolean, default=False)
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    transaction = relationship("Transaction", back_populates="qr_verifications")

    __table_args__ = (
        Index("ix_qr_token", "token"),
        Index("ix_qr_transaction", "transaction_id"),
    )
