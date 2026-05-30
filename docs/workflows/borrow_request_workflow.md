# Borrow Request Workflow — LendLoop

## Request States

```
pending → approved → [Transaction created]
       → rejected
       → cancelled (by borrower)
       → expired (auto, after 48hrs if no response)
```

## Step-by-Step Workflow

### Step 1: Borrower Initiates Request
- Borrower views item detail page
- Clicks "Request to Borrow"
- Selects proposed start date and end date
- Optionally adds a message to the lender
- POST /api/v1/borrow with: item_id, proposed_start_date, proposed_end_date, message

### Step 2: Lender Notification
- Lender receives FCM push notification: "New Borrow Request"
- In-app notification created in DB
- Lender sees request in GET /api/v1/borrow/received

### Step 3: Lender Decision
**Approve:**
- POST /api/v1/borrow/{id}/approve
- Transaction record created automatically
- Item status → reserved
- QR codes generated for pickup
- Borrower notified via FCM

**Reject:**
- POST /api/v1/borrow/{id}/reject with rejection_reason
- Item remains available
- Borrower notified via FCM with reason

### Step 4: Pickup (QR Verification)
- Lender generates pickup QR: POST /api/v1/qr/generate {type: pickup}
- Borrower scans lender's QR at pickup location
- POST /api/v1/qr/verify {token}
- Transaction status → picked_up
- Both parties notified

### Step 5: Return (QR Verification)
- Borrower generates return QR: POST /api/v1/qr/generate {type: return}
- Lender scans borrower's QR at return
- Transaction status → returned
- Both parties notified
- Review prompts sent to both

### Step 6: Post-Transaction
- Both parties can leave reviews
- Trust scores recalculated
- Item becomes available again

---

## Business Rules

1. A user cannot borrow their own item
2. A user cannot have more than 3 active borrows simultaneously (configurable)
3. Proposed borrow period cannot exceed item's max_borrow_days
4. Requests expire after 48 hours if not responded to
5. QR tokens expire in 30 minutes
6. Each QR token is single-use only
