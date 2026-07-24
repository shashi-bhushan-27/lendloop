"""Initial schema creation for LendLoop.

Revision ID: 001_initial
Revises:
Create Date: 2026-07-24

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
import uuid

# revision identifiers, used by Alembic.
revision = '001_initial'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # users
    op.create_table(
        'users',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
        sa.Column('firebase_uid', sa.String(128), nullable=False, unique=True),
        sa.Column('email', sa.String(255), nullable=False, unique=True),
        sa.Column('full_name', sa.String(255), nullable=False),
        sa.Column('phone_number', sa.String(20), unique=True, nullable=True),
        sa.Column('phone_verified', sa.Boolean, default=False),
        sa.Column('avatar_url', sa.Text, nullable=True),
        sa.Column('bio', sa.Text, nullable=True),
        sa.Column('department', sa.String(100), nullable=True),
        sa.Column('reg_number', sa.String(50), unique=True, nullable=True),
        sa.Column('hostel_block', sa.String(100), nullable=True),
        sa.Column('preferred_pickup_location', sa.String(255), nullable=True),
        sa.Column('trust_score', sa.Float, default=80.0),
        sa.Column('total_lends', sa.Integer, default=0),
        sa.Column('total_borrows', sa.Integer, default=0),
        sa.Column('successful_returns', sa.Integer, default=0),
        sa.Column('overdue_count', sa.Integer, default=0),
        sa.Column('role', sa.Enum('student', 'admin', name='userrole'), default='student'),
        sa.Column('status', sa.Enum('active', 'suspended', 'pending', name='userstatus'), default='pending'),
        sa.Column('is_email_verified', sa.Boolean, default=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), onupdate=sa.func.now()),
        sa.Column('last_active', sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index('ix_users_firebase_uid', 'users', ['firebase_uid'])
    op.create_index('ix_users_email', 'users', ['email'])

    # items
    op.create_table(
        'items',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
        sa.Column('owner_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('title', sa.String(255), nullable=False),
        sa.Column('description', sa.Text, nullable=False),
        sa.Column('category', sa.Enum('electronics', 'books', 'stationery', 'equipment', 'clothing', 'sports', 'tools', 'other', name='itemcategory'), nullable=False),
        sa.Column('condition', sa.Enum('new_item', 'like_new', 'good', 'fair', 'poor', name='itemcondition'), nullable=False),
        sa.Column('tags', postgresql.JSON, default=list),
        sa.Column('image_urls', postgresql.JSON, default=list),
        sa.Column('max_borrow_days', sa.Integer, default=7),
        sa.Column('requires_deposit', sa.Boolean, default=False),
        sa.Column('deposit_amount', sa.Float, nullable=True),
        sa.Column('pickup_location', sa.String(255), nullable=False),
        sa.Column('status', sa.Enum('available', 'borrowed', 'reserved', 'unavailable', name='itemstatus'), default='available'),
        sa.Column('is_active', sa.Boolean, default=True),
        sa.Column('view_count', sa.Integer, default=0),
        sa.Column('borrow_count', sa.Integer, default=0),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), onupdate=sa.func.now()),
    )
    op.create_index('ix_items_owner_id', 'items', ['owner_id'])
    op.create_index('ix_items_category', 'items', ['category'])
    op.create_index('ix_items_status', 'items', ['status'])

    # borrow_requests
    op.create_table(
        'borrow_requests',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
        sa.Column('item_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('items.id', ondelete='CASCADE'), nullable=False),
        sa.Column('borrower_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('lender_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('message', sa.Text, nullable=True),
        sa.Column('proposed_start_date', sa.Date, nullable=False),
        sa.Column('proposed_end_date', sa.Date, nullable=False),
        sa.Column('status', sa.Enum('pending', 'approved', 'rejected', 'cancelled', 'expired', name='requeststatus'), default='pending'),
        sa.Column('rejection_reason', sa.Text, nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), onupdate=sa.func.now()),
        sa.Column('responded_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index('ix_borrow_requests_borrower', 'borrow_requests', ['borrower_id'])
    op.create_index('ix_borrow_requests_lender', 'borrow_requests', ['lender_id'])
    op.create_index('ix_borrow_requests_status', 'borrow_requests', ['status'])

    # transactions
    op.create_table(
        'transactions',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
        sa.Column('borrow_request_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('borrow_requests.id', ondelete='CASCADE'), nullable=False, unique=True),
        sa.Column('item_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('items.id', ondelete='CASCADE'), nullable=False),
        sa.Column('borrower_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('lender_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('start_date', sa.Date, nullable=False),
        sa.Column('due_date', sa.Date, nullable=False),
        sa.Column('pickup_time', sa.DateTime(timezone=True), nullable=True),
        sa.Column('return_time', sa.DateTime(timezone=True), nullable=True),
        sa.Column('status', sa.Enum('awaiting_pickup', 'borrowed', 'return_pending', 'completed', 'overdue', 'disputed', 'cancelled', name='transactionstatus'), default='awaiting_pickup'),
        sa.Column('is_overdue', sa.Boolean, default=False),
        sa.Column('overdue_notified', sa.Boolean, default=False),
        sa.Column('trust_score_updated', sa.Boolean, default=False),
        sa.Column('return_image_url', sa.Text, nullable=True),
        sa.Column('return_notes', sa.Text, nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), onupdate=sa.func.now()),
    )
    op.create_index('ix_transactions_borrower', 'transactions', ['borrower_id'])
    op.create_index('ix_transactions_lender', 'transactions', ['lender_id'])
    op.create_index('ix_transactions_status', 'transactions', ['status'])
    op.create_index('ix_transactions_due_date', 'transactions', ['due_date'])

    # reviews
    op.create_table(
        'reviews',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
        sa.Column('transaction_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('transactions.id', ondelete='CASCADE'), nullable=False),
        sa.Column('reviewer_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('reviewee_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('rating', sa.Integer, nullable=False),
        sa.Column('comment', sa.Text, nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.CheckConstraint('rating >= 1 AND rating <= 5', name='ck_reviews_rating_range'),
        sa.UniqueConstraint('transaction_id', 'reviewer_id', name='uq_review_per_reviewer'),
    )
    op.create_index('ix_reviews_reviewee', 'reviews', ['reviewee_id'])

    # notifications
    op.create_table(
        'notifications',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('type', sa.Enum('borrow_request', 'request_approved', 'request_rejected', 'pickup_reminder', 'return_reminder', 'overdue_alert', 'item_returned', 'review_received', 'trust_score_update', 'system', name='notificationtype'), nullable=False),
        sa.Column('title', sa.String(255), nullable=False),
        sa.Column('body', sa.Text, nullable=False),
        sa.Column('data', postgresql.JSON, nullable=True),
        sa.Column('is_read', sa.Boolean, default=False),
        sa.Column('reference_id', sa.String(255), nullable=True),
        sa.Column('reference_type', sa.String(50), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('ix_notifications_user', 'notifications', ['user_id'])
    op.create_index('ix_notifications_is_read', 'notifications', ['is_read'])

    # fcm_tokens
    op.create_table(
        'fcm_tokens',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('token', sa.Text, nullable=False, unique=True),
        sa.Column('device_type', sa.String(20), default='android'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    # qr_verifications
    op.create_table(
        'qr_verifications',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
        sa.Column('transaction_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('transactions.id', ondelete='CASCADE'), nullable=False),
        sa.Column('token', sa.String(512), unique=True, nullable=False),
        sa.Column('qr_type', sa.Enum('pickup', 'return', name='qrtype'), nullable=False),
        sa.Column('qr_image_url', sa.Text, nullable=True),
        sa.Column('is_used', sa.Boolean, default=False),
        sa.Column('used_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('ix_qr_token', 'qr_verifications', ['token'])
    op.create_index('ix_qr_transaction', 'qr_verifications', ['transaction_id'])

    # transaction_evidence_photos
    op.create_table(
        'transaction_evidence_photos',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
        sa.Column('transaction_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('transactions.id', ondelete='CASCADE'), nullable=False),
        sa.Column('image_url', sa.Text, nullable=False),
        sa.Column('evidence_type', sa.Enum('pickup', 'return', name='evidencetype'), nullable=False),
        sa.Column('uploaded_by', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('ix_evidence_transaction', 'transaction_evidence_photos', ['transaction_id'])
    op.create_index('ix_evidence_type', 'transaction_evidence_photos', ['evidence_type'])

    # trust_score_events
    op.create_table(
        'trust_score_events',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('transaction_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('transactions.id', ondelete='SET NULL'), nullable=True),
        sa.Column('event_type', sa.String(50), nullable=False),
        sa.Column('score_change', sa.Float, nullable=False),
        sa.Column('previous_score', sa.Float, nullable=False),
        sa.Column('new_score', sa.Float, nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('ix_trust_events_user', 'trust_score_events', ['user_id'])
    op.create_index('ix_trust_events_transaction', 'trust_score_events', ['transaction_id'])
    op.create_index('ix_trust_events_type', 'trust_score_events', ['event_type'])


def downgrade() -> None:
    op.drop_table('trust_score_events')
    op.drop_table('transaction_evidence_photos')
    op.drop_table('qr_verifications')
    op.drop_table('fcm_tokens')
    op.drop_table('notifications')
    op.drop_table('reviews')
    op.drop_table('transactions')
    op.drop_table('borrow_requests')
    op.drop_table('items')
    op.drop_table('users')
    # Drop enum types
    op.execute("DROP TYPE IF EXISTS userrole CASCADE")
    op.execute("DROP TYPE IF EXISTS userstatus CASCADE")
    op.execute("DROP TYPE IF EXISTS itemcategory CASCADE")
    op.execute("DROP TYPE IF EXISTS itemcondition CASCADE")
    op.execute("DROP TYPE IF EXISTS itemstatus CASCADE")
    op.execute("DROP TYPE IF EXISTS requeststatus CASCADE")
    op.execute("DROP TYPE IF EXISTS transactionstatus CASCADE")
    op.execute("DROP TYPE IF EXISTS notificationtype CASCADE")
    op.execute("DROP TYPE IF EXISTS qrtype CASCADE")
    op.execute("DROP TYPE IF EXISTS evidencetype CASCADE")
