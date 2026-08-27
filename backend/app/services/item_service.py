"""
Item Service

Handles item CRUD, image upload to Cloudinary, and item search.
"""

import cloudinary
import cloudinary.uploader
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_
from fastapi import HTTPException, status, UploadFile
from app.models.item import Item, ItemStatus
from app.models.user import User
from app.schemas.item import ItemCreate, ItemUpdate
from app.core.config import settings
from loguru import logger
import uuid

# Configure Cloudinary
cloudinary.config(
    cloud_name=settings.CLOUDINARY_CLOUD_NAME,
    api_key=settings.CLOUDINARY_API_KEY,
    api_secret=settings.CLOUDINARY_API_SECRET,
)


async def upload_item_image(file: UploadFile, item_id: str) -> str:
    """Upload an item image to Cloudinary. Returns the secure URL."""
    try:
        contents = await file.read()
        result = cloudinary.uploader.upload(
            contents,
            folder=f"lendloop/items/{item_id}",
            resource_type="image",
            transformation=[{"width": 800, "height": 800, "crop": "limit"}],
        )
        return result["secure_url"]
    except Exception as e:
        logger.error(f"Cloudinary upload error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Image upload failed."
        )


async def create_item(
    item_data: ItemCreate,
    owner: User,
    db: AsyncSession,
) -> Item:
    """Create a new item listing."""
    item = Item(
        owner_id=owner.id,
        **item_data.model_dump()
    )
    db.add(item)
    await db.flush()
    await db.refresh(item)
    return item


async def get_available_items(
    db: AsyncSession,
    search: str | None = None,
    category: str | None = None,
    page: int = 1,
    page_size: int = 20,
) -> tuple[list[Item], int]:
    """Get paginated list of available items with optional search/filter."""
    query = select(Item).where(Item.status == ItemStatus.available, Item.is_active == True)

    if search:
        query = query.where(
            or_(
                Item.title.ilike(f"%{search}%"),
                Item.description.ilike(f"%{search}%"),
            )
        )
    if category:
        query = query.where(Item.category == category)

    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    query = query.offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    items = result.scalars().all()

    return list(items), total
