# LendLoop API Reference

Base URL: `https://your-backend.onrender.com/api/v1`

All endpoints (except `/auth/login`) require:
```
Authorization: Bearer <jwt_access_token>
```

---

## Authentication

### POST /auth/login
Exchange a Firebase ID token for LendLoop JWT tokens.

**Request:**
```json
{
  "firebase_token": "Firebase-ID-token-from-client",
  "full_name": "John Doe"
}
```

**Response:**
```json
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "token_type": "bearer",
  "user": { ... }
}
```

### POST /auth/fcm-token
Register a device FCM token for push notifications.

```json
{ "token": "fcm-device-token", "device_type": "android" }
```

### DELETE /auth/fcm-token
Remove a device FCM token on logout.

---

## Users

### GET /users/me
Get current user's full profile.

### PUT /users/me
Update current user's profile.
```json
{
  "full_name": "Updated Name",
  "bio": "Updated bio",
  "department": "CSE"
}
```

### GET /users/{user_id}
Get a user's public profile (restricted visibility).

### GET /users/{user_id}/trust
Get trust score details for a user.

### POST /users/me/avatar
Upload a profile picture (multipart/form-data).

---

## Items

### GET /items
List available items.

**Query Parameters:**
- `search` — Search by title/description
- `category` — Filter by category
- `page` — Page number (default: 1)
- `page_size` — Items per page (default: 20)

### POST /items
Create a new item listing.
```json
{
  "title": "Casio Scientific Calculator",
  "description": "FX-991EX, barely used",
  "category": "electronics",
  "condition": "like_new",
  "max_borrow_days": 7,
  "pickup_location": "AB2 Room 302",
  "tags": ["calculator", "math"]
}
```

### GET /items/{item_id}
Get item details.

### PUT /items/{item_id}
Update an item (owner only).

### DELETE /items/{item_id}
Deactivate an item (owner only).

### POST /items/{item_id}/images
Upload item images (multipart/form-data, max 5 images).

### GET /items/my
Get current user's listed items.

---

## Borrow Requests

### POST /borrow
Create a borrow request.
```json
{
  "item_id": "uuid",
  "proposed_start_date": "2024-02-01",
  "proposed_end_date": "2024-02-07",
  "message": "I need it for my exams"
}
```

### GET /borrow/sent
Get all borrow requests sent by current user.

### GET /borrow/received
Get all borrow requests received by current user (as lender).

### POST /borrow/{request_id}/approve
Approve a borrow request (lender only).

### POST /borrow/{request_id}/reject
Reject a borrow request (lender only).
```json
{ "rejection_reason": "Item is needed this week" }
```

---

## Transactions

### GET /transactions
Get all transactions for current user.

### GET /transactions/{transaction_id}
Get transaction details.

---

## QR Verification

### POST /qr/generate
Generate a QR token.
```json
{
  "transaction_id": "uuid",
  "qr_type": "pickup"
}
```

**Response:**
```json
{
  "id": "uuid",
  "transaction_id": "uuid",
  "qr_type": "pickup",
  "qr_image_url": null,
  "expires_at": "2024-02-01T11:30:00Z",
  "is_used": false
}
```

### POST /qr/verify
Verify a scanned QR token.
```json
{ "token": "base64url-encoded-token" }
```

---

## Reviews

### POST /reviews
Submit a review (only for returned transactions).
```json
{
  "transaction_id": "uuid",
  "reviewee_id": "uuid",
  "rating": 5,
  "comment": "Very responsible borrower!"
}
```

### GET /reviews/user/{user_id}
Get all reviews for a user.

---

## Notifications

### GET /notifications
Get current user's notifications (last 50).

### POST /notifications/read
Mark notifications as read.
```json
{ "notification_ids": ["uuid1", "uuid2"] }
```

---

## Error Responses

All errors follow this format:
```json
{
  "detail": "Human-readable error message"
}
```

| Status | Meaning |
|---|---|
| 400 | Bad Request — Invalid input |
| 401 | Unauthorized — Missing or invalid JWT |
| 403 | Forbidden — Not allowed (domain/role) |
| 404 | Not Found |
| 409 | Conflict — Resource state conflict |
| 422 | Validation Error |
| 500 | Internal Server Error |
