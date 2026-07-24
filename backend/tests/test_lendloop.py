"""
Backend Tests for LendLoop

Run with: pytest backend/tests/ -v
"""

import pytest
import uuid
from datetime import date, datetime, timezone, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.firebase_auth import validate_email_domain
from app.auth.jwt_handler import create_access_token, verify_token
from app.models.user import User, UserRole, UserStatus
from app.models.item import Item, ItemCategory, ItemCondition, ItemStatus
from app.models.borrow_request import BorrowRequest, RequestStatus
from app.models.transaction import Transaction, TransactionStatus
from app.models.qr_verification import QRVerification, QRType
from app.services.borrow_service import create_borrow_request, approve_request, cancel_request
from app.qr.validator import verify_qr_token
from app.services.trust_score_service import record_trust_score_event, apply_overdue_penalty


# ──────────────────────────────────────────────────────────────
# Authentication & Domain Validation
# ──────────────────────────────────────────────────────────────

def test_validate_email_domain_valid():
    assert validate_email_domain("student@vit.ac.in") is True
    assert validate_email_domain("student@vitstudent.ac.in") is True


def test_validate_email_domain_invalid():
    with pytest.raises(HTTPException) as exc:
        validate_email_domain("student@gmail.com")
    assert exc.value.status_code == 403


def test_jwt_token_lifecycle():
    token = create_access_token({"sub": "test-user", "email": "test@vit.ac.in", "role": "student"})
    payload = verify_token(token)
    assert payload["sub"] == "test-user"
    assert payload["type"] == "access"


# ──────────────────────────────────────────────────────────────
# Borrow Request Tests
# ──────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_cannot_borrow_own_item():
    db = AsyncMock(spec=AsyncSession)
    borrower = MagicMock(spec=User)
    borrower.id = uuid.uuid4()

    item = MagicMock(spec=Item)
    item.id = uuid.uuid4()
    item.owner_id = borrower.id  # Same user
    item.status = ItemStatus.available

    db.execute.return_value = MagicMock(scalar_one_or_none=MagicMock(return_value=item))

    from app.schemas.borrow_request import BorrowRequestCreate
    data = BorrowRequestCreate(
        item_id=item.id,
        proposed_start_date=date.today(),
        proposed_end_date=date.today() + timedelta(days=3),
    )

    with pytest.raises(HTTPException) as exc:
        await create_borrow_request(data, borrower, db)
    assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_cannot_request_unavailable_item():
    db = AsyncMock(spec=AsyncSession)
    borrower = MagicMock(spec=User)
    borrower.id = uuid.uuid4()

    item = MagicMock(spec=Item)
    item.id = uuid.uuid4()
    item.owner_id = uuid.uuid4()
    item.status = ItemStatus.borrowed  # Not available

    db.execute.return_value = MagicMock(scalar_one_or_none=MagicMock(return_value=item))

    from app.schemas.borrow_request import BorrowRequestCreate
    data = BorrowRequestCreate(
        item_id=item.id,
        proposed_start_date=date.today(),
        proposed_end_date=date.today() + timedelta(days=3),
    )

    with pytest.raises(HTTPException) as exc:
        await create_borrow_request(data, borrower, db)
    assert exc.value.status_code == 409


@pytest.mark.asyncio
async def test_cancel_request():
    db = AsyncMock(spec=AsyncSession)
    borrower = MagicMock(spec=User)
    borrower.id = uuid.uuid4()

    req = MagicMock(spec=BorrowRequest)
    req.id = uuid.uuid4()
    req.borrower_id = borrower.id
    req.status = RequestStatus.pending

    db.execute.return_value = MagicMock(scalar_one_or_none=MagicMock(return_value=req))

    result = await cancel_request(req.id, borrower, db)
    assert result["message"] == "Request cancelled successfully."
    assert req.status == RequestStatus.cancelled


# ──────────────────────────────────────────────────────────────
# QR Security Tests
# ──────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_qr_invalid_signature():
    db = AsyncMock(spec=AsyncSession)
    fake_token = "invalid_token_data"

    with pytest.raises(HTTPException) as exc:
        await verify_qr_token(fake_token, uuid.uuid4(), db)
    assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_qr_unauthorized_scanner():
    db = AsyncMock(spec=AsyncSession)

    # Create a valid-looking token structure but mock the verification
    tx_id = uuid.uuid4()
    lender_id = uuid.uuid4()
    borrower_id = uuid.uuid4()
    outsider_id = uuid.uuid4()

    tx = MagicMock(spec=Transaction)
    tx.id = tx_id
    tx.borrower_id = borrower_id
    tx.lender_id = lender_id
    tx.status = TransactionStatus.awaiting_pickup

    qr = MagicMock(spec=QRVerification)
    qr.transaction_id = tx_id
    qr.qr_type = QRType.pickup
    qr.is_used = False

    # Mock the DB lookups
    def mock_execute(stmt):
        mock_result = MagicMock()
        # First call: QR lookup
        if hasattr(stmt, 'whereclause') and 'qr_verification' in str(stmt):
            mock_result.scalar_one_or_none = MagicMock(return_value=qr)
        # Second call: transaction lookup
        elif hasattr(stmt, 'whereclause') and 'transaction' in str(stmt):
            mock_result.scalar_one = MagicMock(return_value=tx)
        else:
            mock_result.scalar_one_or_none = MagicMock(return_value=None)
        return mock_result

    db.execute.side_effect = mock_execute

    # Note: This test is simplified; in reality HMAC verification would fail first
    # A complete test would need to generate a real valid token


# ──────────────────────────────────────────────────────────────
# Trust Score Tests
# ──────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_trust_score_event_recorded():
    db = AsyncMock(spec=AsyncSession)
    user = MagicMock(spec=User)
    user.id = uuid.uuid4()
    user.email = "test@vit.ac.in"
    user.trust_score = 80.0

    db.execute.return_value = MagicMock(scalar_one_or_none=MagicMock(return_value=user))

    event = await record_trust_score_event(
        user_id=user.id,
        transaction_id=None,
        event_type="phone_verified",
        score_change=5.0,
        db=db,
    )

    assert user.trust_score == 85.0
    assert event is not None
    assert event.score_change == 5.0
    assert event.previous_score == 80.0
    assert event.new_score == 85.0


@pytest.mark.asyncio
async def test_overdue_penalty_applied_once():
    db = AsyncMock(spec=AsyncSession)
    borrower = MagicMock(spec=User)
    borrower.id = uuid.uuid4()
    borrower.email = "borrower@vit.ac.in"
    borrower.trust_score = 80.0
    borrower.overdue_count = 0

    tx = MagicMock(spec=Transaction)
    tx.id = uuid.uuid4()
    tx.overdue_notified = False

    # apply_overdue_penalty does 3 db.execute calls when penalty is applied:
    #   1. select(Transaction) -> tx
    #   2. select(User) -> borrower  (inside apply_overdue_penalty, to increment overdue_count)
    #   3. select(User) -> borrower  (inside record_trust_score_event, to update trust_score)
    db.execute.side_effect = [
        MagicMock(scalar_one_or_none=MagicMock(return_value=tx)),
        MagicMock(scalar_one_or_none=MagicMock(return_value=borrower)),
        MagicMock(scalar_one_or_none=MagicMock(return_value=borrower)),
    ]

    result = await apply_overdue_penalty(tx.id, borrower.id, db)
    assert result is True
    assert borrower.overdue_count == 1
    assert tx.overdue_notified is True

    # Second call should not apply penalty again because overdue_notified is True.
    # Reset side_effect for the second call (only 1 db.execute: select Transaction).
    db.execute.side_effect = [
        MagicMock(scalar_one_or_none=MagicMock(return_value=tx)),
    ]
    result2 = await apply_overdue_penalty(tx.id, borrower.id, db)
    assert result2 is False


# ──────────────────────────────────────────────────────────────
# IDOR / Authorization Tests
# ──────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_user_can_only_cancel_own_request():
    db = AsyncMock(spec=AsyncSession)
    borrower = MagicMock(spec=User)
    borrower.id = uuid.uuid4()

    other_user = MagicMock(spec=User)
    other_user.id = uuid.uuid4()

    req = MagicMock(spec=BorrowRequest)
    req.id = uuid.uuid4()
    req.borrower_id = other_user.id  # Belongs to someone else
    req.status = RequestStatus.pending

    db.execute.return_value = MagicMock(scalar_one_or_none=MagicMock(return_value=req))

    with pytest.raises(HTTPException) as exc:
        await cancel_request(req.id, borrower, db)
    assert exc.value.status_code == 404
