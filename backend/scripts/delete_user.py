"""
Safely Delete User Script

Deletes a user from the LendLoop database by email.
Handles foreign keys (reviews, transactions, items, borrow requests, etc.) 
to prevent constraint violation errors.

Usage:
    python scripts/delete_user.py <email>
"""

import asyncio
import sys
import os

# Add parent directory to path so we can import app modules
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from sqlalchemy import select, delete
from app.database.connection import AsyncSessionLocal
from app.models.user import User
from app.models.item import Item
from app.models.borrow_request import BorrowRequest
from app.models.transaction import Transaction
from app.models.review import Review
from app.models.notification import Notification
from app.models.notification import FCMToken
from app.models.trust_score_event import TrustScoreEvent
from app.models.evidence_photo import TransactionEvidencePhoto
from app.models.email_otp import EmailOTP
from app.auth.firebase_auth import get_firebase_app, firebase_auth_module


async def delete_user_by_email(email: str):
    print(f"Connecting to database to delete user: {email}...")
    async with AsyncSessionLocal() as session:
        # Find user
        stmt = select(User).where(User.email == email)
        result = await session.execute(stmt)
        user = result.scalar_one_or_none()

        if not user:
            print(f"Error: User with email '{email}' not found.")
            return

        user_id = user.id
        print(f"Found User ID: {user_id}")

        try:
            # 1. Delete associated OTP records
            print("Deleting OTP records...")
            await session.execute(delete(EmailOTP).where(EmailOTP.email == email))

            # 2. Delete reviews given/received by user
            print("Deleting reviews...")
            await session.execute(delete(Review).where(
                (Review.reviewer_id == user_id) | (Review.reviewee_id == user_id)
            ))

            # 3. Delete evidence photos uploaded by user or linked to user's transactions
            print("Deleting transaction evidence photos...")
            # Subquery to get all transaction IDs involving user
            user_txs_stmt = select(Transaction.id).where(
                (Transaction.borrower_id == user_id) | (Transaction.lender_id == user_id)
            )
            tx_result = await session.execute(user_txs_stmt)
            user_tx_ids = [r[0] for r in tx_result.all()]

            if user_tx_ids:
                await session.execute(delete(TransactionEvidencePhoto).where(
                    TransactionEvidencePhoto.transaction_id.in_(user_tx_ids)
                ))
            await session.execute(delete(TransactionEvidencePhoto).where(
                TransactionEvidencePhoto.uploaded_by == user_id
            ))

            # 4. Delete transactions involving user
            print("Deleting transactions...")
            await session.execute(delete(Transaction).where(
                (Transaction.borrower_id == user_id) | (Transaction.lender_id == user_id)
            ))

            # 5. Delete borrow requests
            print("Deleting borrow requests...")
            await session.execute(delete(BorrowRequest).where(
                (BorrowRequest.borrower_id == user_id) | (BorrowRequest.lender_id == user_id)
            ))

            # 6. Delete items owned by user
            print("Deleting items...")
            await session.execute(delete(Item).where(Item.owner_id == user_id))

            # 7. Delete trust score events
            print("Deleting trust score events...")
            await session.execute(delete(TrustScoreEvent).where(TrustScoreEvent.user_id == user_id))

            # 8. Delete notifications and tokens (cascaded but good to clean manually)
            print("Deleting notifications & FCM tokens...")
            await session.execute(delete(Notification).where(Notification.user_id == user_id))
            await session.execute(delete(FCMToken).where(FCMToken.user_id == user_id))

            # 9. Delete the user
            print("Deleting user record...")
            firebase_uid = user.firebase_uid
            await session.execute(delete(User).where(User.id == user_id))

            await session.commit()
            print(f"Successfully deleted user '{email}' and all associated database records.")

            # 10. Delete from Firebase Auth
            try:
                get_firebase_app()
                firebase_auth_module.delete_user(firebase_uid)
                print(f"Successfully deleted user from Firebase Auth (UID: {firebase_uid}).")
            except Exception as fe:
                print(f"Warning: Could not delete user from Firebase Auth: {fe}")

        except Exception as e:
            await session.rollback()
            print(f"Transaction failed: {e}")
            raise


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python scripts/delete_user.py <email>")
        sys.exit(1)
        
    email_to_delete = sys.argv[1].strip()
    asyncio.run(delete_user_by_email(email_to_delete))
