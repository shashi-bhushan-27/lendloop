from pydantic import BaseModel, UUID4
from typing import List, Optional
from datetime import date, datetime
from app.models.transaction import TransactionStatus
from app.models.item import ItemCategory


class TransactionItemSummary(BaseModel):
    """Just enough item info for a transaction card — title/photo/pickup
    location — without a second round-trip per transaction (the API
    eager-loads this in the same query as the transaction list)."""
    id: UUID4
    title: str
    category: ItemCategory
    image_urls: List[str]
    pickup_location: str

    class Config:
        from_attributes = True


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
    item: Optional[TransactionItemSummary] = None

    class Config:
        from_attributes = True


class ReturnInitiateRequest(BaseModel):
    return_notes: Optional[str] = None


class ReturnConfirmRequest(BaseModel):
    token: str
