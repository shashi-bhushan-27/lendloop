from pydantic import BaseModel, EmailStr, Field, UUID4
from typing import Optional
from datetime import datetime
from app.models.user import UserRole, UserStatus


class UserBase(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=255)
    phone_number: Optional[str] = None
    bio: Optional[str] = None
    department: Optional[str] = None
    reg_number: Optional[str] = None


class UserCreate(UserBase):
    email: EmailStr
    firebase_uid: str


class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    bio: Optional[str] = None
    department: Optional[str] = None
    phone_number: Optional[str] = None
    avatar_url: Optional[str] = None


class UserResponse(UserBase):
    id: UUID4
    email: EmailStr
    avatar_url: Optional[str] = None
    trust_score: float
    total_lends: int
    total_borrows: int
    role: UserRole
    status: UserStatus
    is_email_verified: bool
    phone_verified: bool
    created_at: datetime

    class Config:
        from_attributes = True


class UserPublicResponse(BaseModel):
    """Limited profile visible to other users."""
    id: UUID4
    full_name: str
    avatar_url: Optional[str] = None
    trust_score: float
    total_lends: int
    total_borrows: int
    department: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class TrustScoreResponse(BaseModel):
    user_id: UUID4
    trust_score: float
    total_lends: int
    total_borrows: int
    successful_returns: int
    overdue_count: int
