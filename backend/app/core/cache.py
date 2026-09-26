"""
Optional Upstash Redis read cache.

Fail-open by design: if Upstash isn't configured, is slow, or errors, every call
here is a no-op and callers fall straight through to Postgres. The cache can
only make a request faster, never make it fail.

Currently caches the public item listing (GET /items), the most frequently hit
read in the app (Home's Borrow tab, Browse, search). All list variants
(search / category / page) live as fields of a single Redis hash, so one DEL
invalidates every variant at once when any item changes.
"""

import asyncio
import json
from typing import Any, Optional

from loguru import logger
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.database.connection import run_after_commit

ITEMS_LIST_KEY = "lendloop:items:list"
_TIMEOUT_SECONDS = 0.8

_redis = None
if settings.UPSTASH_REDIS_REST_URL and settings.UPSTASH_REDIS_REST_TOKEN:
    from upstash_redis.asyncio import Redis

    # rest_retries=0: the SDK's default retry sleeps 3s before retrying, which is
    # the wrong trade-off for a cache sitting in the request path.
    _redis = Redis(
        url=settings.UPSTASH_REDIS_REST_URL,
        token=settings.UPSTASH_REDIS_REST_TOKEN,
        rest_retries=0,
        allow_telemetry=False,
    )


def is_enabled() -> bool:
    return _redis is not None


async def _call(coro) -> Any:
    try:
        return await asyncio.wait_for(coro, _TIMEOUT_SECONDS)
    except Exception as e:
        logger.warning(f"Cache unavailable, falling back to DB: {e}")
        return None


async def get_items_list(variant: str) -> Optional[dict]:
    if _redis is None:
        return None
    raw = await _call(_redis.hget(ITEMS_LIST_KEY, variant))
    if raw is None:
        return None
    try:
        return json.loads(raw)
    except (TypeError, ValueError):
        return None


async def set_items_list(variant: str, payload: dict) -> None:
    if _redis is None:
        return
    await _call(_redis.hset(ITEMS_LIST_KEY, variant, json.dumps(payload)))
    # nx=True: only set a TTL if none exists, so frequent misses on other
    # variants don't keep pushing the whole hash's expiry forward. The TTL is a
    # backstop — explicit invalidation below is what keeps it fresh.
    await _call(_redis.expire(ITEMS_LIST_KEY, settings.CACHE_ITEMS_TTL_SECONDS, nx=True))


async def invalidate_items_list() -> None:
    if _redis is None:
        return
    await _call(_redis.delete(ITEMS_LIST_KEY))


def invalidate_items_list_after_commit(db: AsyncSession) -> None:
    """Call from any write that changes what GET /items would return (create,
    edit, unlist, image upload, or an item's status changing)."""
    if _redis is not None:
        run_after_commit(db, invalidate_items_list)
