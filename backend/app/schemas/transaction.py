from pydantic import BaseModel, UUID4
from typing import Optional
from datetime import date, datetime
from app.models.transaction import TransactionStatus


class TransactionResponse(BaseModel):
    id: UUID4
    borrow_request_id: UUID4
    item_id: UUID4
    borrower_id: UUID4
    lender_id: UUID4
    start_date: date
    due_date: date
    pickup_time: Optional[datetime]
    return_time: Optional[datetime]
    status: TransactionStatus
    is_overdue: bool
    return_image_url: Optional[str]
    return_notes: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class ReturnInitiateRequest(BaseModel):
    return_notes: Optional[str] = None


class ReturnConfirmRequest(BaseModel):
    token: str
