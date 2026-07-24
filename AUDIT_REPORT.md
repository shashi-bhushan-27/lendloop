# LendLoop Repository Audit Report

## Audit Date: 2026-07-23

---

## Feature Classification

| Feature | Status | Notes |
|---|---|---|
| **Authentication** | IMPLEMENTED | Firebase Auth + JWT exchange working. Domain validation on both client and server. |
| **Registration** | IMPLEMENTED | Email/password via Firebase, profile creation on backend. |
| **Email Verification** | PARTIALLY | Firebase sends verification email; backend reads `email_verified` claim. No enforcement gate. |
| **Domain Validation** | IMPLEMENTED | Client + backend both enforce `@vit.ac.in` / `@vitstudent.ac.in`. |
| **Phone Verification** | STUBBED | Model has `phone_verified` field. No OTP flow implemented in Flutter. |
| **Profiles** | PARTIALLY | Full profile fields exist. Public profile API returns too much data (no privacy gating). No hostel/block/area fields. |
| **Profile Privacy** | MISSING | Phone and exact pickup location should be hidden until transaction approved. Not implemented. |
| **Item CRUD** | IMPLEMENTED | Create, edit, delete/deactivate, list, get. Ownership checks present. |
| **Image Uploads** | IMPLEMENTED | Cloudinary upload for items and avatars. Max 5 images. |
| **Marketplace** | IMPLEMENTED | Browse, search by title, category filters. Availability filter present. |
| **Search/Filtering** | PARTIALLY | Title search, category filter. No location/hostel filtering. |
| **Borrow Requests** | PARTIALLY | Create, approve, reject work. Missing: cancel, duplicate prevention, concurrency safety, auto-reject others. |
| **Approval/Rejection** | PARTIALLY | Works but no row-level locking. Race condition possible on simultaneous approvals. |
| **Cancellation** | MISSING | No borrower cancel endpoint. |
| **Transactions** | PARTIALLY | Created on approval. States use `active/picked_up/returned` instead of required `AWAITING_PICKUP/BORROWED/RETURN_PENDING/COMPLETED`. |
| **QR Generation** | IMPLEMENTED | Signed HMAC tokens with expiry. |
| **QR Validation** | PARTIALLY | Signature and expiry verified. Missing: participant authorization check, idempotency concerns (no unique constraint on confirmation). |
| **Pickup Photos** | MISSING | No transaction evidence photo model or endpoints. |
| **Return Flow** | MISSING | No "initiate return", return QR, return photos, or lender confirmation flow. QR only handles instant status change. |
| **Due Dates** | IMPLEMENTED | Stored in transaction. No reminder system. |
| **Overdue Detection** | MISSING | No scheduled job or background check. `is_overdue` field exists but never updated. |
| **Trust Score** | PARTIALLY | Recalculation service exists. No event history. Default is 50 (docs say 80). No penalty/reward hooks connected to return flow. |
| **Reviews** | PARTIALLY | Create and list work. Missing: structured tags, duplicate review prevention (DB has unique constraint but no pre-check), self-review prevention. |
| **Notifications (In-App)** | IMPLEMENTED | Stored in PostgreSQL, read/unread state, list endpoint. |
| **FCM Push** | PARTIALLY | Sending works. Token registration missing `await db.commit()` — tokens may not persist. Background handler is stub. |
| **FCM Token Management** | PARTIALLY | Register/delete endpoints exist. Registration doesn't commit to DB. |
| **Authorization** | PARTIALLY | JWT auth on all routes. Ownership checks on items. Missing: transaction participant checks on QR, profile privacy, IDOR on reviews. |
| **Admin Permissions** | STUBBED | `require_admin` dependency exists. No admin endpoints or routes. |

---

## Critical Gaps (Must Fix for MVP)

1. **Transaction State Model Mismatch** — Current states (`active`, `picked_up`, `returned`) don't support the required return workflow with lender confirmation.
2. **Return Workflow Missing** — No way for borrower to initiate return, upload return photos, or for lender to confirm receipt.
3. **QR Security** — No participant validation. Anyone with a valid token could scan it.
4. **Concurrency on Approval** — No row locking; two lenders could theoretically approve the same item (though lender_id check makes this less likely, item status is not locked).
5. **Overdue System** — Completely missing.
6. **Trust Score Events** — No audit trail; score could be corrupted by retries.
7. **Transaction Evidence Photos** — No model or API for pickup/return condition photos.
8. **Profile Privacy** — Public API exposes all fields.
9. **FCM Token Persistence** — `register_fcm_token` doesn't await `db.commit()`.
10. **No Alembic Migrations** — Production uses `create_all()` which is dangerous.
11. **No `.env.example`** — Makes onboarding difficult.
12. **Missing Tests** — Zero test files.

## Security Issues Found

1. **QR endpoint doesn't check participant** — `verify_qr_token` doesn't verify the scanning user is a transaction participant.
2. **Profile privacy leak** — `GET /users/{user_id}` returns all fields via `UserPublicResponse`, but schema doesn't exclude phone_number or other private fields (actually it does, but the backend model has more fields and no explicit filtering).
3. **No IDOR on transaction access** — `GET /transactions/{id}` checks participant, good. But QR generate doesn't check participant.
4. **Debug endpoint exposed** — `/auth/debug-token` should be removed before production.
5. **Firebase credentials in repo** — `lendloop-f8a88-firebase-adminsdk-fbsvc-119f2d4a55.json` exists; `.gitignore` blocks it but verify it's not committed.
6. **No rate limiting on auth** — Brute force possible on login.

## Architecture Strengths

- Clean separation of routers/services/models
- Async SQLAlchemy with proper session handling
- JWT + Firebase dual auth is correctly designed
- Cloudinary integration is clean
- Flutter UI is well-structured with Riverpod + GoRouter
- Good use of enums and type safety
