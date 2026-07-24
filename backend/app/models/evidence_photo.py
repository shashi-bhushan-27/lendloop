"""
Transaction Evidence Photo Model

Stores condition photos uploaded during pickup and return.
Only transaction participants may access these photos.
"""

import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, ForeignKey, Enum, Text, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.database.base import Base
import enum


class EvidenceType(str, enum.Enum):
    pickup = "pickup"
    return_ = "return"


class TransactionEvidencePhoto(Base):
    __tablename__ = "transaction_evidence_photos"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    transaction_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("transactions.id", ondelete="CASCADE"), nullable=False
    )
    image_url: Mapped[str] = mapped_column(Text, nullable=False)  # Cloudinary URL
    evidence_type: Mapped[EvidenceType] = mapped_column(Enum(EvidenceType), nullable=False)
    uploaded_by: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    transaction = relationship("Transaction", back_populates="evidence_photos")

    __table_args__ = (
        Index("ix_evidence_transaction", "transaction_id"),
        Index("ix_evidence_type", "evidence_type"),
    )
