# Notification System — LendLoop

## Overview

LendLoop uses a two-channel notification system:
1. **FCM Push Notifications** — Real-time device alerts even when app is closed
2. **In-App Notifications** — Stored in PostgreSQL, displayed in notification center

## Notification Types

| Type | Trigger | Recipients |
|---|---|---|
| borrow_request | Borrower sends request | Lender |
| request_approved | Lender approves | Borrower |
| request_rejected | Lender rejects | Borrower |
| pickup_reminder | 1 hour before agreed pickup | Both |
| return_reminder | 2 days, 1 day, same day before due | Borrower |
| overdue_alert | Day after due date | Both |
| item_returned | Return QR scanned | Lender |
| review_received | Review posted | Reviewee |
| trust_score_update | Score recalculated | User |
| system | Admin broadcast | All users |

## FCM Integration

### Device Token Registration
```
1. App launches → FCM.getToken()
2. Token stored in FlutterSecureStorage
3. POST /api/v1/auth/fcm-token {token, device_type}
4. Backend stores in fcm_tokens table
5. Token refreshed automatically via FCM.onTokenRefresh
```

### Sending FCM Message
```python
message = messaging.Message(
    notification=messaging.Notification(
        title="New Borrow Request",
        body="Alice wants to borrow your Calculator"
    ),
    data={"reference_id": "request-uuid", "type": "borrow_request"},
    token=device_fcm_token
)
messaging.send(message)
```

## Due Date Reminder Schedule

The system should run a scheduled job (cron) to:
1. Find transactions where due_date = today + 2 → send 2-day reminder
2. Find transactions where due_date = today + 1 → send 1-day reminder
3. Find transactions where due_date = today → send same-day reminder
4. Find transactions where due_date < today AND status != returned → mark overdue + send alert

## In-App Notification Schema

```json
{
  "id": "uuid",
  "user_id": "uuid",
  "type": "borrow_request",
  "title": "New Borrow Request",
  "body": "Alice wants to borrow your Calculator",
  "data": {"item_id": "uuid", "request_id": "uuid"},
  "is_read": false,
  "reference_id": "request-uuid",
  "reference_type": "borrow_request",
  "created_at": "2024-01-15T10:30:00Z"
}
```
