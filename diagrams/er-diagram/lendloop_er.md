```mermaid
erDiagram
    users {
        UUID id PK
        string firebase_uid UK
        string email UK
        string full_name
        string phone_number
        bool phone_verified
        string avatar_url
        string department
        string reg_number UK
        float trust_score
        int total_lends
        int total_borrows
        int successful_returns
        int overdue_count
        enum role
        enum status
        bool is_email_verified
        timestamp created_at
        timestamp updated_at
    }

    items {
        UUID id PK
        UUID owner_id FK
        string title
        text description
        enum category
        enum condition
        json tags
        json image_urls
        int max_borrow_days
        bool requires_deposit
        float deposit_amount
        string pickup_location
        enum status
        bool is_active
        int view_count
        int borrow_count
        timestamp created_at
    }

    borrow_requests {
        UUID id PK
        UUID item_id FK
        UUID borrower_id FK
        UUID lender_id FK
        text message
        date proposed_start_date
        date proposed_end_date
        enum status
        text rejection_reason
        timestamp created_at
        timestamp responded_at
    }

    transactions {
        UUID id PK
        UUID borrow_request_id FK UK
        UUID item_id FK
        UUID borrower_id FK
        UUID lender_id FK
        date start_date
        date due_date
        timestamp pickup_time
        timestamp return_time
        enum status
        bool is_overdue
        text return_image_url
        text return_notes
        timestamp created_at
    }

    reviews {
        UUID id PK
        UUID transaction_id FK
        UUID reviewer_id FK
        UUID reviewee_id FK
        int rating
        text comment
        timestamp created_at
    }

    notifications {
        UUID id PK
        UUID user_id FK
        enum type
        string title
        text body
        json data
        bool is_read
        string reference_id
        string reference_type
        timestamp created_at
    }

    qr_verifications {
        UUID id PK
        UUID transaction_id FK
        string token UK
        enum qr_type
        string qr_image_url
        bool is_used
        timestamp used_at
        timestamp expires_at
        timestamp created_at
    }

    fcm_tokens {
        UUID id PK
        UUID user_id FK
        string token UK
        string device_type
        timestamp created_at
    }

    users ||--o{ items : "owns"
    users ||--o{ borrow_requests : "sends (borrower)"
    users ||--o{ borrow_requests : "receives (lender)"
    users ||--o{ transactions : "borrows in"
    users ||--o{ transactions : "lends in"
    users ||--o{ reviews : "gives"
    users ||--o{ reviews : "receives"
    users ||--o{ notifications : "receives"
    users ||--o{ fcm_tokens : "registers"
    items ||--o{ borrow_requests : "requested for"
    items ||--o{ transactions : "transacted in"
    borrow_requests ||--o| transactions : "creates"
    transactions ||--o{ qr_verifications : "verified by"
    transactions ||--o{ reviews : "reviewed in"
```
