"""
Item Model

Represents a physical item listed for lending by a verified user.
"""

import uuid
from datetime import datetime
from typing import List
from sqlalchemy import String, Boolean, Float, DateTime, Enum, Text, Integer, ForeignKey, Index, JSON
from sqlalchemy.dialects.postgresql import UUID, ARRAY
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.database.base import Base
import enum


class ItemCategory(str, enum.Enum):
    electronics = "electronics"
    books = "books"
    stationery = "stationery"
    equipment = "equipment"
    clothing = "clothing"
    sports = "sports"
    tools = "tools"
    other = "other"


class ItemCondition(str, enum.Enum):
    new_item = "new_item"
    like_new = "like_new"
    good = "good"
    fair = "fair"
    poor = "poor"


class ItemStatus(str, enum.Enum):
    available = "available"
    borrowed = "borrowed"
    reserved = "reserved"
    unavailable = "unavailable"


class Item(Base):
    __tablename__ = "items"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    owner_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )

    # Item Details
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    category: Mapped[ItemCategory] = mapped_column(Enum(ItemCategory), nullable=False)
    condition: Mapped[ItemCondition] = mapped_column(Enum(ItemCondition), nullable=False)
    tags: Mapped[list] = mapped_column(JSON, default=list)
    image_urls: Mapped[list] = mapped_column(JSON, default=list)  # List of Cloudinary URLs

    # Lending Terms
    max_borrow_days: Mapped[int] = mapped_column(Integer, default=7)
    requires_deposit: Mapped[bool] = mapped_column(Boolean, default=False)
    deposit_amount: Mapped[float | None] = mapped_column(Float, nullable=True)
    pickup_location: Mapped[str] = mapped_column(String(255), nullable=False)

    # Status
    status: Mapped[ItemStatus] = mapped_column(Enum(ItemStatus), default=ItemStatus.available)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    view_count: Mapped[int] = mapped_column(Integer, default=0)
    borrow_count: Mapped[int] = mapped_column(Integer, default=0)

    # Timestamps
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Relationships
    owner = relationship("User", back_populates="items", foreign_keys=[owner_id])
    borrow_requests = relationship("BorrowRequest", back_populates="item")
    transactions = relationship("Transaction", back_populates="item")

    __table_args__ = (
        Index("ix_items_category", "category"),
        Index("ix_items_status", "status"),
        Index("ix_items_owner_id", "owner_id"),
    )

    def __repr__(self) -> str:
        return f"<Item {self.title}>"
