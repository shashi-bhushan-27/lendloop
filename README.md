# 🔄 LendLoop

> A university-based item lending and borrowing platform — restricted to verified VIT domain users.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110-green)](https://fastapi.tiangolo.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-blue)](https://postgresql.org)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%2B%20FCM-orange)](https://firebase.google.com)

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
| Media Storage | Cloudinary / Firebase Storage |
| Deployment | Render / Railway + Firebase Hosting |

---

## 📁 Project Structure

```
LendLoop/
├── frontend/          # Flutter mobile application
├── backend/           # FastAPI REST API server
├── docs/              # Technical documentation
├── diagrams/          # Architecture & workflow diagrams
├── deployment/        # Deployment configurations
├── README.md
├── LICENSE
└── .gitignore
```

---

## 🚀 Quick Start

### Prerequisites

- Flutter SDK 3.x
- Python 3.11+
- PostgreSQL 15
- Firebase project with Auth + FCM enabled
- Cloudinary account

### Backend Setup

```bash
cd backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env    # Fill in your secrets
uvicorn app.main:app --reload
```

### Frontend Setup

```bash
cd frontend
flutter pub get
flutter run
```

> See `docs/setup-guide/local_setup.md` for the full setup guide.

---

## ✨ Core Features

- 🔐 **Domain-Restricted Auth** — Only @vit.ac.in / @vitstudent.ac.in emails allowed
- 📱 **Phone Verification** — OTP-based phone number verification
- 📦 **Item Listings** — Post items available for lending with images
- 🤝 **Borrow Request Flow** — Request → Approve/Reject → Pickup → Return
- 📷 **QR-Based Verification** — Secure pickup and return using QR codes
- ⭐ **Trust Score System** — Dynamic scoring based on user behavior
- 🔔 **Real-Time Notifications** — FCM push notifications for all events
- 📊 **Transaction History** — Full audit trail of all lending activity
- ⏰ **Overdue Handling** — Automatic reminders and overdue flagging
- 🌟 **Review System** — Post-transaction reviews for borrowers and lenders

---

## 📖 Documentation

| Document | Path |
|---|---|
| Architecture Overview | `docs/architecture/overview.md` |
| API Reference | `docs/api-documentation/endpoints.md` |
| Database Schema | `docs/database-design/schema.md` |
| Local Setup Guide | `docs/setup-guide/local_setup.md` |
| Authentication Flow | `docs/workflows/authentication_flow.md` |
| Trust Score Logic | `docs/technical-notes/trust_score_calculation.md` |
| QR Verification | `docs/technical-notes/qr_verification_logic.md` |

---

## 🔒 Security Model

- Firebase Authentication as identity provider
- Domain-restricted signup enforcement at API level
- JWT-based session management
- Role-based access control (Student, Admin)
- QR tokens are signed, time-limited, and single-use
- All API routes protected by auth middleware

---

## 👥 Contributors

Built as a Capstone Project at **VIT University**.

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.
