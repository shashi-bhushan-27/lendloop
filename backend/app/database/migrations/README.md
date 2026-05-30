# Alembic Migrations

This directory contains Alembic database migration files.

## Setup

```bash
# Initialize Alembic (already done)
alembic init migrations

# Create a new migration
alembic revision --autogenerate -m "description_of_change"

# Apply migrations
alembic upgrade head

# Rollback one version
alembic downgrade -1

# View migration history
alembic history
```

## Configuration

Alembic reads `DATABASE_URL` from the `.env` file via `alembic.ini`.
The `env.py` file in this directory connects Alembic to SQLAlchemy models.
