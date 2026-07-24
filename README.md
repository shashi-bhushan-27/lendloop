# 🔄 LendLoop

> A university-based item lending and borrowing platform — restricted to verified VIT domain users.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110-green)](https://fastapi.tiangolo.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-blue)](https://postgresql.org)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%2B%20FCM-orange)](https://firebase.google.com)

---

## 🎯 What is LendLoop?

LendLoop is a production-grade mobile application where students at VIT University can securely lend and borrow physical items — books, equipment, stationery, calculators, and more — within a trusted, verified ecosystem.

Only users with **@vit.ac.in** or **@vitstudent.ac.in** email addresses can register and access the platform.

---

## 🏗️ Tech Stack

| Layer | Technology |
|---|---|
| Mobile Frontend | Flutter 3.x + Riverpod |
| Backend API | FastAPI (Python 3.11+) |
| Database | PostgreSQL 15 (Neon/Supabase) |
| Authentication | Firebase Authentication |
| Push Notifications | Firebase Cloud Messaging |
| Media Storage | Cloudinary |
| Deployment | Render / Railway + Firebase Hosting |

---

## 📁 Project Structure

```
LendLoop/
├── frontend/          # Flutter mobile application
├── backend/           # FastAPI REST API server
│   ├── alembic/       # Database migrations
│   ├── app/           # Application code
│   ├── tests/         # Pytest test suite
│   ├── .env.example   # Environment template
│   └── alembic.ini    # Alembic config
├── docs/              # Technical documentation
├── diagrams/          # Architecture & workflow diagrams
├── deployment/        # Deployment configurations
├── README.md
├── AUDIT_REPORT.md    # Pre-implementation audit
├── IMPLEMENTATION_REPORT.md
├── LICENSE
└── .gitignore
```

---

## 🚀 Quick Start

### Prerequisites

- Flutter SDK 3.x
- Python 3.11+
- PostgreSQL 15 (or Neon cloud)
- Firebase project with Auth + FCM enabled
- Cloudinary account

### Backend Setup

```bash
cd backend

# 1. Create virtual environment
python -m venv venv

# 2. Activate (Windows)
venv\Scripts\activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Create .env from template
copy .env.example .env
# Edit .env with your credentials

# 5. Run Alembic migrations
alembic upgrade head

# 6. Start server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Visit [http://localhost:8000/docs](http://localhost:8000/docs) for interactive API documentation.

### Frontend Setup

```bash
cd frontend

# 1. Update API base URL for local development
# Edit lib/core/constants/app_constants.dart:
# static const String baseUrl = 'http://10.0.2.2:8000/api/v1';  # Android emulator
# static const String baseUrl = 'http://YOUR_PC_IP:8000/api/v1'; # Physical device

# 2. Get dependencies
flutter pub get

# 3. Run on device/emulator
flutter run
```

> **Note:** Ensure `google-services.json` is placed at `frontend/android/app/google-services.json` before running.

---

## ✨ Core Features

- 🔐 **Domain-Restricted Auth** — Only @vit.ac.in / @vitstudent.ac.in emails allowed
- 📱 **Phone Verification** — OTP-based phone number verification (backend ready)
- 📦 **Item Listings** — Post items with images, categories, conditions, deposits
- 🔍 **Marketplace** — Browse, search, and filter available items
- 🤝 **Borrow Request Flow** — Request → Approve/Reject → Cancel
- 📷 **QR-Based Verification** — Secure pickup and return with signed, expiring, single-use QR codes
- 📸 **Condition Photos** — Upload pickup/return evidence photos
- ⏰ **Return Workflow** — Initiate return → QR verify → lender confirms → complete
- ⏱️ **Overdue Detection** — Automatic overdue marking with trust score penalties
- ⭐ **Trust Score System** — Transparent scoring with immutable audit trail
- 🌟 **Review System** — Post-transaction ratings and comments
- 🔔 **Real-Time Notifications** — FCM push + in-app notification history

---

## 🧪 Testing

```bash
cd backend
venv\Scripts\activate
pytest tests/ -v
```

Tests cover:
- Authentication and domain restriction
- Item ownership and borrow request validation
- QR security (signature, expiry, participant authorization)
- Trust score idempotency
- Overdue penalty application
- IDOR prevention

---

## 🗄️ Database Migrations

```bash
cd backend

# Create new migration after model changes
alembic revision --autogenerate -m "description"

# Apply all migrations
alembic upgrade head

# Rollback one migration
alembic downgrade -1
```

---

## 📖 Documentation

| Document | Path |
|---|---|
| Architecture Overview | `docs/architecture/overview.md` |
| API Reference | `docs/api-documentation/endpoints.md` |
| Database Schema | `docs/database-design/schema.md` |
| Local Setup Guide | `docs/setup-guide/local_setup.md` |
| Authentication Flow | `docs/workflows/authentication_flow.md` |
| Borrow Workflow | `docs/workflows/borrow_request_workflow.md` |
| Item Lifecycle | `docs/workflows/item_lifecycle.md` |
| QR Verification | `docs/technical-notes/qr_verification_logic.md` |
| Trust Score | `docs/technical-notes/trust_score_calculation.md` |
| Notifications | `docs/technical-notes/notification_system.md` |
| Audit Report | `AUDIT_REPORT.md` |
| Implementation Report | `IMPLEMENTATION_REPORT.md` |

---

## 🔒 Security Model

- Firebase Authentication as identity provider
- Domain-restricted signup enforced at API level
- JWT-based session management
- Role-based access control (Student, Admin)
- QR tokens are HMAC-SHA256 signed, time-limited (30 min), and single-use
- All API routes protected by auth middleware
- Contact details (phone, exact address) only visible to confirmed transaction participants
- Row-level locking on critical operations (borrow approval)
- Immutable trust score audit trail

---

## 👥 Contributors

Built as a Capstone Project at **VIT University**.

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.
