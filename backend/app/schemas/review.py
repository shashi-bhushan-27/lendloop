from pydantic import BaseModel, Field, UUID4
from typing import Optional
from datetime import datetime


class ReviewCreate(BaseModel):
    transaction_id: UUID4
    reviewee_id: UUID4
    rating: int = Field(..., ge=1, le=5)
    comment: Optional[str] = None


class ReviewResponse(BaseModel):
    id: UUID4
    transaction_id: UUID4
    reviewer_id: UUID4
    reviewee_id: UUID4
    rating: int
    comment: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True
