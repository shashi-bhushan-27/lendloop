# QR Verification Logic — LendLoop

## Overview

QR codes are used for two critical verification points:
1. **Pickup verification** — Confirms the borrower received the item
2. **Return verification** — Confirms the lender received the item back

## Security Properties

- **Signed tokens:** HMAC-SHA256 signed payload
- **Time-limited:** 30-minute expiry window
- **Single-use:** Invalidated immediately upon first successful scan
- **Transaction-bound:** Each QR is tied to a specific transaction
- **Type-safe:** Separate tokens for pickup vs return

## Token Generation

### Process
```
1. Generate payload:
   {
     "transaction_id": "uuid",
     "type": "pickup" | "return",
     "expires_at": "ISO-8601 timestamp",
     "nonce": "random UUID (prevents replay)"
   }

2. Sign with HMAC-SHA256:
   signature = HMAC(QR_TOKEN_SECRET, sorted_payload_json)

3. Encode:
   token = base64url({ "payload": payload, "sig": signature })

4. Store in DB:
   QRVerification record with token, is_used=False, expires_at

5. Generate QR image:
   qrcode.QRCode(token) → PNG image
```

## Token Verification

### Process
```
1. Decode base64url → extract payload + signature
2. Recompute HMAC signature from payload
3. compare_digest(provided_sig, expected_sig) — constant-time
4. Check expires_at > now()
5. Lookup QRVerification record by token
6. Check is_used == False
7. Mark is_used = True, used_at = now()
8. Update transaction status:
   - pickup → TransactionStatus.picked_up
   - return → TransactionStatus.returned
9. Return success
```

## Error Cases

| Error | HTTP Status | Cause |
|---|---|---|
| Invalid format | 400 | Corrupted QR data |
| Invalid signature | 400 | Tampered token |
| Expired | 400 | Scanned after 30-min window |
| Not found | 404 | Token not in DB |
| Already used | 409 | QR scanned more than once |

## UI Flow

### Lender (Pickup)
```
Lender: Transaction screen → Generate Pickup QR
→ QR displayed on lender's phone
→ Borrower: opens QR Scanner
→ Scans lender's QR
→ API verifies → pickup_time recorded
→ Both see "Pickup Confirmed" status
```

### Borrower (Return)
```
Borrower: Transaction screen → Generate Return QR
→ QR displayed on borrower's phone
→ Lender: opens QR Scanner
→ Scans borrower's QR
→ API verifies → return_time recorded
→ Item set back to available
→ Review prompts sent to both
```
