# LendLoop — System Architecture Overview

## Introduction

LendLoop is a university-based item lending and borrowing platform designed as a closed ecosystem restricted to verified VIT University email addresses. The system follows a modern, scalable client-server architecture with clean separation of concerns.

## Architecture Style

**Pattern:** Client-Server with RESTful API
**Frontend:** Flutter mobile application (clean architecture + Riverpod)
**Backend:** FastAPI (Python) with async request handling
**Database:** PostgreSQL with async SQLAlchemy ORM
**Auth:** Firebase Authentication (identity) + JWT (session)
**Storage:** Cloudinary (media files)
**Notifications:** Firebase Cloud Messaging

---

## System Components

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter Mobile App                       │
│  ┌─────────────┐  ┌────────────┐  ┌──────────┐  ┌──────────┐  │
│  │    Auth     │  │   Items    │  │  Borrow  │  │   QR     │  │
│  │   Feature   │  │  Feature   │  │ Feature  │  │ Scanner  │  │
│  └─────────────┘  └────────────┘  └──────────┘  └──────────┘  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │             Riverpod State Management Layer               │ │
│  └────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │      API Client (Dio + Auth Interceptor)                  │ │
│  └────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬────────────────────────────────────┘
                             │ HTTPS REST API
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                     FastAPI Backend                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────────┐ │
│  │   Auth   │  │  Items   │  │  Borrow  │  │ Notifications  │ │
│  │  Router  │  │  Router  │  │  Router  │  │    Router      │ │
│  └──────────┘  └──────────┘  └──────────┘  └────────────────┘ │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Service Layer (Business Logic)              │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │            SQLAlchemy ORM (Async)                        │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────┬──────────────────┬──────────────────┬─────────────────┘
         │                  │                  │
         ▼                  ▼                  ▼
  ┌────────────┐   ┌──────────────┐   ┌──────────────┐
  │ PostgreSQL  │   │   Firebase   │   │  Cloudinary  │
  │  Database  │   │  Auth + FCM  │   │   Storage    │
  └────────────┘   └──────────────┘   └──────────────┘
```

---

## Security Architecture

### Dual Authentication Layer
1. **Firebase Authentication** — Identity provider. Manages email/password, Google OAuth, phone OTP.
2. **JWT Sessions** — After Firebase verification, the backend issues JWT access + refresh tokens.

### Domain Restriction
- Enforced at **both** Flutter client (email validation before Firebase call) and **backend API** (email domain check after Firebase token verification).
- Allowed domains: `vit.ac.in`, `vitstudent.ac.in`

### Route Protection
- All API routes except `/auth/login` require a valid JWT Bearer token.
- Role-based access: `student` vs `admin` roles.

---

## Data Flow

### Authentication Flow
```
User enters email → Flutter validates VIT domain
→ Firebase Auth (email/password)
→ Firebase returns ID token
→ Flutter sends ID token to POST /auth/login
→ Backend verifies Firebase token + domain
→ Backend creates/finds user record
→ Backend returns JWT access + refresh tokens
→ Flutter stores tokens in FlutterSecureStorage
→ All subsequent API calls include Bearer JWT
```

### Borrow Request Flow
```
Borrower finds item → Sends borrow request
→ Lender receives FCM notification
→ Lender approves → Transaction created
→ Both receive QR codes
→ Pickup: Lender scans borrower's QR → pickup confirmed
→ Return: Borrower scans lender's QR → return confirmed
→ Both leave reviews → Trust scores updated
```

---

## Scalability Considerations

- **Async everything:** FastAPI + asyncpg + SQLAlchemy async for non-blocking I/O
- **Connection pooling:** SQLAlchemy pool configured for production loads
- **Stateless API:** JWTs enable horizontal scaling (no server-side sessions)
- **CDN storage:** Cloudinary handles image delivery at scale
- **Database indexing:** Critical columns indexed (email, status, dates)
- **Modular architecture:** Each feature is independently extensible
