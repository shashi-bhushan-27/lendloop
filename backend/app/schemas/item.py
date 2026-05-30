from pydantic import BaseModel, Field, UUID4
from typing import Optional, List
from datetime import datetime
from app.models.item import ItemCategory, ItemCondition, ItemStatus


class ItemCreate(BaseModel):
    title: str = Field(..., min_length=3, max_length=255)
    description: str = Field(..., min_length=10)
    category: ItemCategory
    condition: ItemCondition
    tags: List[str] = []
    max_borrow_days: int = Field(default=7, ge=1, le=90)
    requires_deposit: bool = False
    deposit_amount: Optional[float] = None
    pickup_location: str = Field(..., min_length=3)


class ItemUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    condition: Optional[ItemCondition] = None
    tags: Optional[List[str]] = None
    max_borrow_days: Optional[int] = None
    pickup_location: Optional[str] = None
    is_active: Optional[bool] = None


class ItemResponse(BaseModel):
    id: UUID4
    owner_id: UUID4
    title: str
    description: str
    category: ItemCategory
    condition: ItemCondition
    tags: List[str]
    image_urls: List[str]
    max_borrow_days: int
    requires_deposit: bool
    deposit_amount: Optional[float]
    pickup_location: str
    status: ItemStatus
    is_active: bool
    view_count: int
    borrow_count: int
    created_at: datetime

    class Config:
        from_attributes = True


class ItemListResponse(BaseModel):
    items: List[ItemResponse]
    total: int
    page: int
    page_size: int
