from pydantic import BaseModel, UUID4
from typing import Optional
from datetime import datetime


class TrustScoreEventResponse(BaseModel):
    id: UUID4
    user_id: UUID4
    transaction_id: Optional[UUID4]
    event_type: str
    score_change: float
    previous_score: float
    new_score: float
    created_at: datetime

    class Config:
        from_attributes = True
