from pydantic import BaseModel, Field, UUID4
from typing import Optional
from datetime import date, datetime
from app.models.borrow_request import RequestStatus


class BorrowRequestCreate(BaseModel):
    item_id: UUID4
    message: Optional[str] = None
    proposed_start_date: date
    proposed_end_date: date


class BorrowRequestApprove(BaseModel):
    pass  # Lender simply approves


class BorrowRequestReject(BaseModel):
    rejection_reason: str = Field(..., min_length=5)


class BorrowRequestResponse(BaseModel):
    id: UUID4
    item_id: UUID4
    borrower_id: UUID4
    lender_id: UUID4
    message: Optional[str]
    proposed_start_date: date
    proposed_end_date: date
    status: RequestStatus
    rejection_reason: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
