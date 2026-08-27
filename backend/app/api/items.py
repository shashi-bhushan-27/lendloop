"""
Items Router

Endpoints:
  GET    /items                 — List available items (with search/filter)
  POST   /items                 — Create new item listing
  GET    /items/{item_id}       — Item details
  PUT    /items/{item_id}       — Update item
  DELETE /items/{item_id}       — Deactivate item
  POST   /items/{item_id}/images — Upload item images
  GET    /items/my              — Current user's listed items
"""

from fastapi import APIRouter, Depends, Query, UploadFile, File, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database.connection import get_db
from app.auth.dependencies import get_current_user
from app.models.user import User
from app.models.item import Item, ItemStatus
from app.schemas.item import ItemCreate, ItemUpdate, ItemResponse, ItemListResponse
from app.services.item_service import create_item, get_available_items, upload_item_image
from typing import Optional, List
import uuid

router = APIRouter()


@router.get("", response_model=ItemListResponse)
async def list_items(
    search: Optional[str] = Query(None),
    category: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    items, total = await get_available_items(db, search, category, page, page_size)
    return ItemListResponse(items=items, total=total, page=page, page_size=page_size)


@router.post("", response_model=ItemResponse, status_code=status.HTTP_201_CREATED)
async def create_new_item(
    item_data: ItemCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await create_item(item_data, current_user, db)


@router.get("/my", response_model=List[ItemResponse])
async def my_items(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Item).where(Item.owner_id == current_user.id))
    return result.scalars().all()


@router.get("/{item_id}", response_model=ItemResponse)
async def get_item(
    item_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    result = await db.execute(select(Item).where(Item.id == item_id))
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    item.view_count += 1
    return item


@router.put("/{item_id}", response_model=ItemResponse)
async def update_item(
    item_id: uuid.UUID,
    update_data: ItemUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Item).where(Item.id == item_id))
    item = result.scalar_one_or_none()
    if not item or item.owner_id != current_user.id:
        raise HTTPException(status_code=404, detail="Item not found or unauthorized.")
    for field, value in update_data.model_dump(exclude_none=True).items():
        setattr(item, field, value)
    await db.flush()
    return item


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_item(
    item_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Item).where(Item.id == item_id))
    item = result.scalar_one_or_none()
    if not item or item.owner_id != current_user.id:
        raise HTTPException(status_code=404, detail="Not found or unauthorized.")
    item.is_active = False


@router.post("/{item_id}/images")
async def upload_images(
    item_id: uuid.UUID,
    files: List[UploadFile] = File(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Item).where(Item.id == item_id))
    item = result.scalar_one_or_none()
    if not item or item.owner_id != current_user.id:
        raise HTTPException(status_code=404, detail="Item not found.")

    urls = []
    for file in files[:5]:  # Max 5 images
        url = await upload_item_image(file, str(item_id))
        urls.append(url)

    item.image_urls = (item.image_urls or []) + urls
    return {"image_urls": item.image_urls}
