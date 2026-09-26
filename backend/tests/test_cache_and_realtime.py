"""
Tests for the after-commit hook, the Upstash cache wrapper, and the push
notification payload. No network: Redis and FCM are faked.
"""

import asyncio
import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import cache
from app.database import connection
from app.models.notification import NotificationType
from app.services import notification_service


class _FakeSession:
    def __init__(self):
        self.info = {}
        self.committed = False
        self.rolled_back = False

    async def commit(self):
        self.committed = True

    async def rollback(self):
        self.rolled_back = True

    async def close(self):
        pass

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        return False


class _FakeRedis:
    def __init__(self):
        self.store: dict[str, dict[str, str]] = {}

    async def hget(self, key, field):
        return self.store.get(key, {}).get(field)

    async def hset(self, key, field, value):
        self.store.setdefault(key, {})[field] = value

    async def expire(self, key, seconds, nx=False):
        return 1

    async def delete(self, *keys):
        for k in keys:
            self.store.pop(k, None)


# ── after-commit hook ────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_after_commit_callbacks_run_only_after_commit():
    session = _FakeSession()
    ran = []

    async def callback():
        ran.append(session.committed)

    with patch.object(connection, "AsyncSessionLocal", return_value=session):
        gen = connection.get_db()
        s = await gen.__anext__()
        connection.run_after_commit(s, callback)
        assert ran == []  # nothing fires while the request is still running
        with pytest.raises(StopAsyncIteration):
            await gen.__anext__()
        await asyncio.sleep(0)  # let the background task run

    assert ran == [True]  # fired exactly once, and saw the committed state


@pytest.mark.asyncio
async def test_after_commit_callbacks_discarded_on_rollback():
    session = _FakeSession()
    callback = AsyncMock()

    with patch.object(connection, "AsyncSessionLocal", return_value=session):
        gen = connection.get_db()
        s = await gen.__anext__()
        connection.run_after_commit(s, callback)
        with pytest.raises(RuntimeError):
            await gen.athrow(RuntimeError("request failed"))
        await asyncio.sleep(0)

    assert session.rolled_back
    callback.assert_not_awaited()


# ── cache ────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_cache_round_trip_and_invalidation():
    with patch.object(cache, "_redis", _FakeRedis()):
        assert await cache.get_items_list("v1") is None
        await cache.set_items_list("v1", {"items": [], "total": 0})
        assert await cache.get_items_list("v1") == {"items": [], "total": 0}
        await cache.invalidate_items_list()
        assert await cache.get_items_list("v1") is None


@pytest.mark.asyncio
async def test_cache_fails_open_on_error_and_timeout():
    broken = MagicMock()
    broken.hget = AsyncMock(side_effect=ConnectionError("upstash down"))
    broken.delete = AsyncMock(side_effect=ConnectionError("upstash down"))
    with patch.object(cache, "_redis", broken):
        assert await cache.get_items_list("v1") is None
        await cache.invalidate_items_list()  # must not raise

    async def hang(*_):
        await asyncio.sleep(5)

    slow = MagicMock()
    slow.hget = hang
    with patch.object(cache, "_redis", slow), patch.object(cache, "_TIMEOUT_SECONDS", 0.05):
        assert await cache.get_items_list("v1") is None


@pytest.mark.asyncio
async def test_cache_disabled_is_a_no_op():
    with patch.object(cache, "_redis", None):
        assert not cache.is_enabled()
        assert await cache.get_items_list("v1") is None
        db = MagicMock()
        db.info = {}
        cache.invalidate_items_list_after_commit(db)
        assert db.info == {}  # nothing queued when there's no cache


@pytest.mark.asyncio
async def test_items_endpoint_serves_repeat_request_from_cache():
    import httpx
    from app.main import app
    from app.auth.dependencies import get_current_user
    from app.api import items as items_api

    fake_redis = _FakeRedis()
    app.dependency_overrides[get_current_user] = lambda: MagicMock()
    db_query = AsyncMock(return_value=([], 0))
    try:
        with patch.object(cache, "_redis", fake_redis), \
             patch.object(connection, "AsyncSessionLocal", side_effect=lambda: _FakeSession()), \
             patch.object(items_api, "get_available_items", db_query):
            transport = httpx.ASGITransport(app=app)
            async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
                first = await client.get("/api/v1/items", params={"category": "books"})
                await asyncio.sleep(0)  # let the after-commit cache write run
                second = await client.get("/api/v1/items", params={"category": "books"})
                other = await client.get("/api/v1/items", params={"category": "tools"})
    finally:
        app.dependency_overrides.clear()

    assert first.status_code == second.status_code == other.status_code == 200
    assert first.json() == second.json()
    # books: one DB hit then a cache hit; tools: a different variant, so a miss
    assert db_query.await_count == 2


# ── push notifications ───────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_push_is_queued_for_after_commit_with_routing_data():
    db = AsyncMock(spec=AsyncSession)
    db.info = {}
    db.add = MagicMock()
    token_result = MagicMock()
    token_result.scalars.return_value.all.return_value = ["device-token-1"]
    db.execute.return_value = token_result

    reference_id = str(uuid.uuid4())
    with patch.object(notification_service, "_send_fcm", new=AsyncMock()) as send:
        await notification_service.send_notification_to_user(
            user_id=uuid.uuid4(),
            notification_type=NotificationType.request_approved,
            title="Request Approved",
            body="Proceed to pickup.",
            reference_id=reference_id,
            reference_type="transaction",
            db=db,
        )
        send.assert_not_awaited()  # not sent inline — must wait for commit

        callbacks = db.info["after_commit"]
        assert len(callbacks) == 1
        await callbacks[0]()

    tokens, title, body, data = send.await_args.args
    assert tokens == ["device-token-1"]
    assert data["type"] == "request_approved"
    assert data["reference_id"] == reference_id
    assert data["reference_type"] == "transaction"


@pytest.mark.asyncio
async def test_no_push_queued_without_device_tokens():
    db = AsyncMock(spec=AsyncSession)
    db.info = {}
    db.add = MagicMock()
    empty = MagicMock()
    empty.scalars.return_value.all.return_value = []
    db.execute.return_value = empty

    await notification_service.send_notification_to_user(
        user_id=uuid.uuid4(),
        notification_type=NotificationType.system,
        title="t",
        body="b",
        db=db,
    )
    assert "after_commit" not in db.info
