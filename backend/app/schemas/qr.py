from pydantic import BaseModel, UUID4
from typing import Optional
from datetime import datetime
from app.models.qr_verification import QRType


class QRGenerateRequest(BaseModel):
    transaction_id: UUID4
    qr_type: QRType


class QRVerifyRequest(BaseModel):
    token: str


class QRResponse(BaseModel):
    id: UUID4
    transaction_id: UUID4
    qr_type: QRType
    qr_image_url: Optional[str]
    expires_at: datetime
    is_used: bool

    class Config:
        from_attributes = True


class QRVerifyResponse(BaseModel):
    success: bool
    message: str
    transaction_id: Optional[UUID4] = None
    qr_type: Optional[QRType] = None
