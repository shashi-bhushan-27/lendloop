import pytest
import asyncio
from typing import AsyncGenerator
from urllib.parse import urlparse, urlunparse
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from app.database.base import Base
from app.core.config import settings

# Build a test database URL by appending _test to the database name,
# preserving query parameters like ?ssl=require.
_parsed = urlparse(settings.DATABASE_URL)
_test_path = _parsed.path.rstrip("/") + "_test"
TEST_DATABASE_URL = urlunparse(_parsed._replace(path=_test_path))

engine = create_async_engine(TEST_DATABASE_URL, echo=False)
AsyncTestingSessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="session", autouse=True)
async def setup_database():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncTestingSessionLocal() as session:
        yield session
        await session.rollback()
