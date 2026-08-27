"""
Database Connection & Session Management

Uses async SQLAlchemy engine with asyncpg driver.
Provides async session dependency for FastAPI route handlers.
"""

from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from app.core.config import settings
from app.database.base import Base
from loguru import logger

# Create async engine
engine = create_async_engine(
    settings.DATABASE_URL,
    pool_size=settings.DATABASE_POOL_SIZE,
    max_overflow=settings.DATABASE_MAX_OVERFLOW,
    echo=settings.DEBUG,
    future=True,
    pool_pre_ping=True,      # Test connections before using — fixes "connection is closed"
    pool_recycle=300,        # Recycle connections every 5 mins to avoid Neon timeouts
    connect_args={"timeout": 60}, # Increase timeout for Neon cold starts
)

# Session factory
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
    autocommit=False,
)


async def get_db() -> AsyncSession:
    """
    FastAPI dependency — yields a database session per request.
    Session is automatically closed after the request completes.
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception as e:
            await session.rollback()
            logger.error(f"Database session error: {e}")
            raise
        finally:
            await session.close()
