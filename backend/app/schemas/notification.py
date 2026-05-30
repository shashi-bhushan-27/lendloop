from pydantic import BaseModel, UUID4
from typing import Optional, Dict, Any
from datetime import datetime
from app.models.notification import NotificationType


class NotificationResponse(BaseModel):
    id: UUID4
    user_id: UUID4
    type: NotificationType
    title: str
    body: str
    data: Optional[Dict[str, Any]]
    is_read: bool
    reference_id: Optional[str]
    reference_type: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class FCMTokenRegister(BaseModel):
    token: str
    device_type: str = "android"


class MarkReadRequest(BaseModel):
    notification_ids: list[UUID4]
