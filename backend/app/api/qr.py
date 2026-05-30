"""
QR Router

Endpoints:
  POST /qr/generate   — Generate QR token for pickup/return
  POST /qr/verify     — Verify a scanned QR token
"""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.database.connection import get_db
from app.auth.dependencies import get_current_user
from app.models.user import User
from app.schemas.qr import QRGenerateRequest, QRVerifyRequest, QRResponse, QRVerifyResponse
from app.qr.generator import create_qr_token
from app.qr.validator import verify_qr_token

router = APIRouter()


@router.post("/generate", response_model=QRResponse)
async def generate_qr(
    data: QRGenerateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Generates a signed QR token for a given transaction.
    The lender generates pickup QR; borrower generates return QR.
    """
    qr_record = await create_qr_token(data.transaction_id, data.qr_type, db)
    return qr_record


@router.post("/verify", response_model=QRVerifyResponse)
async def verify_qr(
    data: QRVerifyRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Verifies a scanned QR token and updates transaction status.
    """
    result = await verify_qr_token(data.token, db)
    return QRVerifyResponse(
        success=result["success"],
        message="QR verification successful",
        transaction_id=result["transaction_id"],
        qr_type=result["qr_type"],
    )
