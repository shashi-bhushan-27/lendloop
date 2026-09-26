"""
Notification Service

Handles:
1. In-app notifications (stored in DB)
2. FCM push notifications to user devices

Pushes double as the app's real-time channel: the Flutter client refreshes the
relevant screens whenever one arrives in the foreground, so every state change
the *other* party needs to see (request received/approved/rejected/cancelled,
pickup confirmed, return initiated/completed) should go through here.
"""

import asyncio
from typing import Optional, Dict, Any
import uuid

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from loguru import logger

from app.models.notification import Notification, NotificationType, FCMToken
from app.database.connection import run_after_commit


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
    """Create an in-app notification and queue an FCM push for after commit."""
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

    result = await db.execute(select(FCMToken.token).where(FCMToken.user_id == user_id))
    tokens = list(result.scalars().all())
    if tokens:
        # The client uses these fields to decide which screens to refresh and
        # where a tap should navigate — previously only `data` was sent, which
        # every caller left empty.
        payload = {
            **(data or {}),
            "type": notification_type.value,
            "reference_id": reference_id or "",
            "reference_type": reference_type or "",
            "notification_id": str(notification.id),
        }
        # After commit, not now: the push makes the other device refetch, and
        # if it arrives before the commit that refetch still sees the old state.
        run_after_commit(db, lambda: _send_fcm(tokens, title, body, payload))

    return notification


async def _send_fcm(tokens: list[str], title: str, body: str, data: Dict[str, Any]) -> None:
    from firebase_admin import messaging
    from app.auth.firebase_auth import get_firebase_app

    # Firebase is otherwise only initialized lazily on login, so after a server
    # restart every push silently failed until someone happened to log in.
    get_firebase_app()

    messages = [
        messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={str(k): str(v) for k, v in data.items()},
            android=messaging.AndroidConfig(priority="high"),
            token=token,
        )
        for token in tokens
    ]
    # firebase_admin is synchronous; running it on the event loop blocked every
    # other request for the duration of each HTTP call to FCM.
    response = await asyncio.to_thread(messaging.send_each, messages)
    if response.failure_count:
        logger.warning(f"FCM: {response.failure_count}/{len(messages)} sends failed")
