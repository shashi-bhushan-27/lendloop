# Item Lifecycle — LendLoop

## Item States

```
available → reserved → borrowed → available
    ↓
unavailable (manually set by owner)
```

## Full Item Lifecycle

### 1. Listing Phase
- Owner creates item listing with: title, description, category, condition, images, pickup location, max borrow days
- Images uploaded to Cloudinary via POST /api/v1/items/{id}/images
- Item status: `available`

### 2. Discovery Phase
- Other users browse items via GET /api/v1/items (with search + category filters)
- Item view_count incremented on each view
- Items owned by the logged-in user are excluded from borrow requests

### 3. Request Phase
- Borrower sends request → Item status remains `available` (multiple requests allowed)
- When lender approves one request → Item status changes to `reserved`
- All other pending requests for that item auto-expire

### 4. Active Lending Phase
- Item status: `reserved` → `borrowed` (after QR pickup scan)
- Due date tracked; reminders sent D-2, D-1, D-day

### 5. Return Phase
- Item status: `borrowed` → `available` (after QR return scan)
- borrow_count incremented

### 6. Overdue Phase
- If return_date passes without return: item flagged as overdue
- Overdue notifications sent to both parties
- Borrower's trust score penalized
- Admin can escalate overdue cases

---

## Item Categories

| Category | Examples |
|---|---|
| electronics | Calculator, laptop, charger |
| books | Textbooks, reference books |
| stationery | Pens, notebooks, stapler |
| equipment | Lab equipment, projector |
| clothing | Lab coat, formal wear |
| sports | Sports equipment |
| tools | Screwdrivers, measurement tools |
| other | Miscellaneous |

## Item Conditions

| Condition | Description |
|---|---|
| new | Brand new, unused |
| like_new | Barely used, no visible wear |
| good | Used but well-maintained |
| fair | Some visible wear, fully functional |
| poor | Heavy wear, may have minor defects |
