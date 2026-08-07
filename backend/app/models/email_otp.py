"""
Email OTP Model

Stores one-time verification codes for email verification.
OTPs are hashed with bcrypt before storage.
"""

from datetime import datetime
from sqlalchemy import String, DateTime, Integer, Boolean
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from app.database.base import Base


class EmailOTP(Base):
    __tablename__ = "email_otps"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    email: Mapped[str] = mapped_column(String(255), index=True, nullable=False)
    otp_hash: Mapped[str] = mapped_column(String(128), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    is_used: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
