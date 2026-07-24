"""
Notification Service

Handles:
1. In-app notifications (stored in DB)
2. FCM push notifications to user devices
"""

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.notification import Notification, NotificationType, FCMToken
from loguru import logger
from typing import Optional, Dict, Any
import uuid


async def send_notification_to_user(
    user_id: uuid.UUID,
    notification_type: NotificationType,
    title: str,
    body: str,
    db: AsyncSession,
    data: Optional[Dict[str, Any]] = None,
    reference_id: Optional[str] = None,
    reference_type: Optional[str] = None,
) -> Notification:
    """Create an in-app notification and optionally send FCM push."""
    # Store in DB
    notification = Notification(
        user_id=user_id,
        type=notification_type,
        title=title,
        body=body,
        data=data,
        reference_id=reference_id,
        reference_type=reference_type,
    )
    db.add(notification)
    await db.flush()

    # Send FCM push (fire-and-forget, don't let it break the transaction)
    try:
        await send_fcm_to_user(user_id, title, body, data or {}, db)
    except Exception as e:
        logger.warning(f"FCM send failed for user {user_id}: {e}")

    return notification


async def send_fcm_to_user(
    user_id: uuid.UUID,
    title: str,
    body: str,
    data: Dict[str, Any],
    db: AsyncSession,
) -> None:
    """Send FCM push notification to all registered devices of a user."""
    result = await db.execute(
        select(FCMToken).where(FCMToken.user_id == user_id)
    )
    tokens = result.scalars().all()

    if not tokens:
        return

    for token_record in tokens:
        try:
            from firebase_admin import messaging
            message = messaging.Message(
                notification=messaging.Notification(title=title, body=body),
                data={str(k): str(v) for k, v in data.items()},
                token=token_record.token,
            )
            messaging.send(message)
            logger.debug(f"FCM sent to device {token_record.token[:20]}...")
        except Exception as e:
            logger.warning(f"FCM send failed for token: {e}")
