# Local Development Setup Guide

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Flutter SDK | 3.x | https://flutter.dev/docs/get-started/install |
| Python | 3.11+ | https://python.org/downloads |
| PostgreSQL | 15+ | https://postgresql.org/download or Neon (cloud) |
| Git | Latest | https://git-scm.com |
| VS Code / Android Studio | Latest | IDE of choice |

---

## Step 1 — Clone the Repository

```bash
git clone https://github.com/your-org/LendLoop.git
cd LendLoop
```

---

## Step 2 — Firebase Project Setup

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project named `LendLoop`
3. Enable **Authentication** → Sign-in methods → Email/Password
4. Enable **Cloud Messaging** (for FCM push notifications)
5. Add an **Android app**:
   - Package name: `com.lendloop.app`
   - Download `google-services.json` → place at `frontend/android/app/google-services.json`
6. Generate a **Service Account Key**:
   - Project Settings → Service Accounts → Generate new private key
   - Save as `backend/firebase-adminsdk.json` (never commit this!)

---

## Step 3 — Cloudinary Setup

1. Create a free account at [cloudinary.com](https://cloudinary.com)
2. From your Dashboard, note:
   - **Cloud Name**
   - **API Key**
   - **API Secret**
3. Create an unsigned upload preset named `lendloop_items`

---

## Step 4 — PostgreSQL Database

### Option A: Neon (Recommended — Cloud, Free tier)
1. Sign up at [neon.tech](https://neon.tech)
2. Create a new project → `lendloop`
3. Copy the connection string (format: `postgresql+asyncpg://...`)

### Option B: Local PostgreSQL
```bash
psql -U postgres
CREATE DATABASE lendloop;
CREATE USER lendloop_user WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE lendloop TO lendloop_user;
```
Connection string: `postgresql+asyncpg://lendloop_user:your_password@localhost:5432/lendloop`

---

## Step 5 — Backend Setup

```bash
cd backend

# Create virtual environment
python -m venv venv

# Activate (Windows)
venv\Scripts\activate

# Activate (macOS/Linux)
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Create .env from template
copy .env.example .env   # Windows
cp .env.example .env     # macOS/Linux
```

Edit `.env` with your credentials:

```env
SECRET_KEY=generate-a-strong-random-key-here
DATABASE_URL=postgresql+asyncpg://user:password@host:5432/lendloop
FIREBASE_CREDENTIALS_PATH=./firebase-adminsdk.json
FIREBASE_PROJECT_ID=your-firebase-project-id
CLOUDINARY_CLOUD_NAME=your-cloud-name
CLOUDINARY_API_KEY=your-api-key
CLOUDINARY_API_SECRET=your-api-secret
QR_TOKEN_SECRET=another-strong-random-key
```

Generate a secure key:
```bash
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

Start the backend:
```bash
uvicorn app.main:app --reload --port 8000
```

Visit [http://localhost:8000/docs](http://localhost:8000/docs) to see the interactive API documentation.

---

## Step 6 — Flutter Frontend Setup

```bash
cd frontend

# Get dependencies
flutter pub get

# Run code generation (for JSON serialization)
flutter pub run build_runner build --delete-conflicting-outputs

# Check connected devices
flutter devices

# Run on Android emulator or physical device
flutter run
```

> **Note:** Ensure `google-services.json` is placed at `frontend/android/app/google-services.json` before running.

---

## Step 7 — Configure API Base URL

In `frontend/lib/core/constants/app_constants.dart`, update the base URL:

```dart
// For local development (Android emulator)
static const String baseUrl = 'http://10.0.2.2:8000/api/v1';

// For physical device (use your machine's local IP)
static const String baseUrl = 'http://192.168.x.x:8000/api/v1';

// For production
static const String baseUrl = 'https://your-backend.onrender.com/api/v1';
```

---

## Step 8 — Run Database Migrations (Optional)

The app auto-creates tables on startup via SQLAlchemy. For production, use Alembic:

```bash
cd backend
alembic upgrade head
```

---

## Troubleshooting

| Problem | Solution |
|---|---|
| `firebase-adminsdk.json not found` | Download from Firebase Console → Project Settings → Service Accounts |
| `DATABASE_URL connection refused` | Check PostgreSQL is running; verify host/port in .env |
| `Domain not allowed` error | Ensure you're using a @vit.ac.in or @vitstudent.ac.in email |
| Flutter `package not found` | Run `flutter pub get` |
| Android build fails | Run `flutter clean && flutter pub get` |
| `CLOUDINARY_API_SECRET not set` | Ensure all Cloudinary env vars are set in .env |

---

## Environment Variables Reference

| Variable | Required | Description |
|---|---|---|
| `SECRET_KEY` | ✅ | JWT signing secret (min 32 chars) |
| `DATABASE_URL` | ✅ | PostgreSQL asyncpg connection string |
| `FIREBASE_CREDENTIALS_PATH` | ✅ | Path to Firebase Admin SDK JSON |
| `FIREBASE_PROJECT_ID` | ✅ | Firebase project ID |
| `CLOUDINARY_CLOUD_NAME` | ✅ | Cloudinary cloud name |
| `CLOUDINARY_API_KEY` | ✅ | Cloudinary API key |
| `CLOUDINARY_API_SECRET` | ✅ | Cloudinary API secret |
| `QR_TOKEN_SECRET` | ✅ | HMAC secret for QR signing |
| `ALLOWED_EMAIL_DOMAINS` | ❌ | Default: `vit.ac.in,vitstudent.ac.in` |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | ❌ | Default: 60 |
| `QR_TOKEN_EXPIRE_MINUTES` | ❌ | Default: 30 |
| `DEBUG` | ❌ | Default: True (disables Swagger in prod) |
