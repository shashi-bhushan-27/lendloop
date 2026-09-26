"""
Database Connection & Session Management

Uses async SQLAlchemy engine with asyncpg driver.
Provides async session dependency for FastAPI route handlers.
"""

import asyncio
import uuid
from typing import Awaitable, Callable

from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from app.core.config import settings
from app.database.base import Base
from loguru import logger

_db_url = make_url(settings.DATABASE_URL)
_connect_args: dict = {"timeout": 60}  # Increase timeout for Neon cold starts

# Neon's pooled endpoint (host contains "-pooler") runs PgBouncer in transaction
# mode, where a server connection can change between statements. asyncpg's
# prepared-statement caches assume a stable connection, so disable them and give
# every prepared statement a unique name to avoid "prepared statement already
# exists" errors. Direct (non-pooled) URLs are left untouched.
USING_PGBOUNCER = "-pooler" in (_db_url.host or "")
if USING_PGBOUNCER:
    _db_url = _db_url.update_query_dict({"prepared_statement_cache_size": "0"})
    _connect_args.update(
        statement_cache_size=0,
        prepared_statement_name_func=lambda: f"__asyncpg_{uuid.uuid4()}__",
    )

# Create async engine
engine = create_async_engine(
    _db_url,
    pool_size=settings.DATABASE_POOL_SIZE,
    max_overflow=settings.DATABASE_MAX_OVERFLOW,
    echo=settings.DEBUG,
    future=True,
    pool_pre_ping=True,      # Test connections before using — fixes "connection is closed"
    pool_recycle=300,        # Recycle connections every 5 mins to avoid Neon timeouts
    connect_args=_connect_args,
)

# Session factory
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
    autocommit=False,
)

_AFTER_COMMIT_KEY = "after_commit"
_background_tasks: set[asyncio.Task] = set()


def run_after_commit(session: AsyncSession, fn: Callable[[], Awaitable[None]]) -> None:
    """
    Schedule `fn` to run in the background once this request's transaction has
    committed — never before, and never if it rolls back.

    Used for side effects that other clients react to (push notifications, cache
    invalidation): firing them before commit lets the other party refetch and
    still see the old state.
    """
    session.info.setdefault(_AFTER_COMMIT_KEY, []).append(fn)


async def _run_logged(fn: Callable[[], Awaitable[None]]) -> None:
    try:
        await fn()
    except Exception as e:
        logger.warning(f"After-commit task failed: {e}")


def _dispatch_after_commit(session: AsyncSession) -> None:
    for fn in session.info.pop(_AFTER_COMMIT_KEY, []):
        task = asyncio.create_task(_run_logged(fn))
        _background_tasks.add(task)  # keep a reference so it isn't garbage-collected mid-run
        task.add_done_callback(_background_tasks.discard)


async def get_db() -> AsyncSession:
    """
    FastAPI dependency — yields a database session per request.
    Session is automatically closed after the request completes.
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
            _dispatch_after_commit(session)
        except Exception as e:
            session.info.pop(_AFTER_COMMIT_KEY, None)
            await session.rollback()
            logger.error(f"Database session error: {e}")
            raise
        finally:
            await session.close()
