# Database Schema — LendLoop

## Overview

PostgreSQL relational database with 7 core tables.
All primary keys use UUID v4 for security and distribution compatibility.
All timestamps use `TIMESTAMP WITH TIME ZONE`.

---

## Entity Relationship Summary

```
Users ──< Items (owner)
Users ──< BorrowRequests (borrower + lender)
Users ──< Transactions (borrower + lender)
Users ──< Reviews (reviewer + reviewee)
Users ──< Notifications
Users ──< FCMTokens
Items ──< BorrowRequests
Items ──< Transactions
BorrowRequests ──< Transactions (1:1)
Transactions ──< QRVerifications
Transactions ──< Reviews
```

---

## Tables

### users
| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | UUID | PK | uuid4 |
| firebase_uid | VARCHAR(128) | UNIQUE, NOT NULL | Firebase UID |
| email | VARCHAR(255) | UNIQUE, NOT NULL | VIT email |
| full_name | VARCHAR(255) | NOT NULL | |
| phone_number | VARCHAR(20) | UNIQUE | |
| phone_verified | BOOLEAN | DEFAULT false | |
| avatar_url | TEXT | | Cloudinary URL |
| bio | TEXT | | |
| department | VARCHAR(100) | | |
| reg_number | VARCHAR(50) | UNIQUE | VIT reg number |
| trust_score | FLOAT | DEFAULT 50.0 | 0-100 |
| total_lends | INT | DEFAULT 0 | |
| total_borrows | INT | DEFAULT 0 | |
| successful_returns | INT | DEFAULT 0 | |
| overdue_count | INT | DEFAULT 0 | |
| role | ENUM | DEFAULT student | student/admin |
| status | ENUM | DEFAULT pending | active/suspended/pending |
| is_email_verified | BOOLEAN | DEFAULT false | |
| created_at | TIMESTAMPTZ | DEFAULT now() | |
| updated_at | TIMESTAMPTZ | DEFAULT now() | |

**Indexes:** firebase_uid, email, role, status

---

### items
| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | UUID | PK | |
| owner_id | UUID | FK → users.id | |
| title | VARCHAR(255) | NOT NULL | |
| description | TEXT | NOT NULL | |
| category | ENUM | NOT NULL | |
| condition | ENUM | NOT NULL | |
| tags | JSON | DEFAULT [] | |
| image_urls | JSON | DEFAULT [] | Cloudinary URLs |
| max_borrow_days | INT | DEFAULT 7 | |
| requires_deposit | BOOLEAN | DEFAULT false | |
| deposit_amount | FLOAT | | |
| pickup_location | VARCHAR(255) | NOT NULL | |
| status | ENUM | DEFAULT available | |
| is_active | BOOLEAN | DEFAULT true | |
| view_count | INT | DEFAULT 0 | |
| borrow_count | INT | DEFAULT 0 | |
| created_at | TIMESTAMPTZ | DEFAULT now() | |

**Indexes:** owner_id, category, status

---

### borrow_requests
| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | UUID | PK | |
| item_id | UUID | FK → items.id | |
| borrower_id | UUID | FK → users.id | |
| lender_id | UUID | FK → users.id | |
| message | TEXT | | Optional note |
| proposed_start_date | DATE | NOT NULL | |
| proposed_end_date | DATE | NOT NULL | |
| status | ENUM | DEFAULT pending | |
| rejection_reason | TEXT | | |
| created_at | TIMESTAMPTZ | | |
| responded_at | TIMESTAMPTZ | | |

**Indexes:** borrower_id, lender_id, status

---

### transactions
| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | UUID | PK | |
| borrow_request_id | UUID | FK → borrow_requests.id, UNIQUE | 1:1 |
| item_id | UUID | FK → items.id | |
| borrower_id | UUID | FK → users.id | |
| lender_id | UUID | FK → users.id | |
| start_date | DATE | NOT NULL | |
| due_date | DATE | NOT NULL | |
| pickup_time | TIMESTAMPTZ | | QR confirmed |
| return_time | TIMESTAMPTZ | | QR confirmed |
| status | ENUM | DEFAULT active | |
| is_overdue | BOOLEAN | DEFAULT false | |
| return_image_url | TEXT | | |
| return_notes | TEXT | | |

**Indexes:** borrower_id, lender_id, status, due_date

---

### reviews
| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | UUID | PK | |
| transaction_id | UUID | FK → transactions.id | |
| reviewer_id | UUID | FK → users.id | |
| reviewee_id | UUID | FK → users.id | |
| rating | INT | CHECK 1-5 | |
| comment | TEXT | | |
| created_at | TIMESTAMPTZ | | |

**Unique:** (transaction_id, reviewer_id) — one review per person per transaction
**Index:** reviewee_id

---

### notifications
| Column | Type | Notes |
|---|---|---|
| id | UUID PK | |
| user_id | UUID FK → users.id | |
| type | ENUM | NotificationType |
| title | VARCHAR(255) | |
| body | TEXT | |
| data | JSON | Extra metadata |
| is_read | BOOLEAN DEFAULT false | |
| reference_id | VARCHAR(255) | Related entity ID |
| reference_type | VARCHAR(50) | borrow_request, transaction... |
| created_at | TIMESTAMPTZ | |

**Indexes:** user_id, is_read

---

### qr_verifications
| Column | Type | Notes |
|---|---|---|
| id | UUID PK | |
| transaction_id | UUID FK → transactions.id | |
| token | VARCHAR(512) UNIQUE | Signed QR token |
| qr_type | ENUM | pickup/return |
| qr_image_url | TEXT | Cloudinary URL |
| is_used | BOOLEAN DEFAULT false | |
| used_at | TIMESTAMPTZ | |
| expires_at | TIMESTAMPTZ NOT NULL | 30-min window |
| created_at | TIMESTAMPTZ | |

**Indexes:** token, transaction_id
