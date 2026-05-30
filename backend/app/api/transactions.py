"""
Transactions Router

Endpoints:
  GET  /transactions              — Current user's transactions
  GET  /transactions/{id}         — Transaction detail
  GET  /transactions/active       — Active transactions
  GET  /transactions/history      — Completed/past transactions
"""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_
from app.database.connection import get_db
from app.auth.dependencies import get_current_user
from app.models.user import User
from app.models.transaction import Transaction, TransactionStatus
from app.schemas.transaction import TransactionResponse
from typing import List
import uuid

router = APIRouter()


@router.get("", response_model=List[TransactionResponse])
async def get_my_transactions(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Transaction).where(
            or_(
                Transaction.borrower_id == current_user.id,
                Transaction.lender_id == current_user.id,
            )
        ).order_by(Transaction.created_at.desc())
    )
    return result.scalars().all()


@router.get("/{transaction_id}", response_model=TransactionResponse)
async def get_transaction(
    transaction_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from fastapi import HTTPException
    result = await db.execute(select(Transaction).where(Transaction.id == transaction_id))
    tx = result.scalar_one_or_none()
    if not tx or (tx.borrower_id != current_user.id and tx.lender_id != current_user.id):
        raise HTTPException(status_code=404, detail="Transaction not found.")
    return tx
