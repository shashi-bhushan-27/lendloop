# Neon PostgreSQL Setup Guide

## What is Neon?
Neon is a serverless PostgreSQL platform with a generous free tier — perfect for a capstone project backend.

---

## Setup Steps

### 1. Create Account
Go to [neon.tech](https://neon.tech) → Sign up with GitHub

### 2. Create Project
- Project Name: `lendloop`
- PostgreSQL Version: 15
- Region: Asia Pacific (Singapore) — closest to VIT Chennai

### 3. Get Connection String
- Dashboard → Project → Connection Details
- Copy the **asyncpg** connection string:
  ```
  postgresql+asyncpg://user:password@ep-xxx.ap-southeast-1.aws.neon.tech/lendloop?ssl=require
  ```

### 4. Set in Backend .env
```env
DATABASE_URL=postgresql+asyncpg://user:password@ep-xxx.ap-southeast-1.aws.neon.tech/lendloop?ssl=require
```

### 5. Tables Auto-Created
LendLoop's FastAPI backend auto-creates all tables on startup via SQLAlchemy.

---

## Database Configuration Notes

- **SSL Required:** Neon requires SSL; the `?ssl=require` suffix handles this
- **Connection Pooling:** Neon has built-in PgBouncer; set `DATABASE_POOL_SIZE=5` for free tier
- **Branching:** Neon supports DB branching — create a `dev` branch for testing
- **Backups:** Neon auto-backs up daily on paid plans

---

## Free Tier Limits
| Resource | Free Tier |
|---|---|
| Compute | 0.25 vCPU |
| RAM | 1 GB |
| Storage | 3 GB |
| Branches | 10 |
| Connections | 100 |
