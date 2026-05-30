"""
Notifications Router

Endpoints:
  GET  /notifications          — Get user's notifications
  POST /notifications/read     — Mark notifications as read
  DELETE /notifications/{id}   — Delete a notification
"""

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from app.database.connection import get_db
from app.auth.dependencies import get_current_user
from app.models.user import User
from app.models.notification import Notification
from app.schemas.notification import NotificationResponse, MarkReadRequest
from typing import List
import uuid

router = APIRouter()


@router.get("", response_model=List[NotificationResponse])
async def get_notifications(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Notification)
        .where(Notification.user_id == current_user.id)
        .order_by(Notification.created_at.desc())
        .limit(50)
    )
    return result.scalars().all()


@router.post("/read")
async def mark_read(
    payload: MarkReadRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await db.execute(
        update(Notification)
        .where(
            Notification.id.in_(payload.notification_ids),
            Notification.user_id == current_user.id,
        )
        .values(is_read=True)
    )
    return {"message": "Marked as read"}
