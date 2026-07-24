from pydantic import BaseModel, UUID4
from typing import Optional
from datetime import datetime
from app.models.evidence_photo import EvidenceType


class EvidencePhotoResponse(BaseModel):
    id: UUID4
    transaction_id: UUID4
    image_url: str
    evidence_type: EvidenceType
    uploaded_by: UUID4
    created_at: datetime

    class Config:
        from_attributes = True
