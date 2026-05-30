# Trust Score Calculation — LendLoop

## Overview

The Trust Score is a dynamic 0-100 score that reflects a user's reliability and trustworthiness on the platform. It is recalculated after every significant event.

## Formula

```
trust_score = base_score
  + return_rate_score     (0 to 40 points)
  + review_score          (0 to 30 points)
  - overdue_penalty       (0 to 30 points deducted)
  + lender_activity_bonus (0 to 15 points)
  + phone_verification_bonus (0 or 5 points)

Final: clamp(score, 0, 100)
```

## Component Breakdown

### Base Score: 10
Every verified user starts with 10 points.

### Return Rate Score: 0–40
```
return_rate = successful_returns / max(total_borrows, 1)
return_rate_score = return_rate * 40
```
Users who return items on time earn up to 40 points.

### Review Score: 0–30
```
avg_rating = average of all received ratings (1-5)
review_score = (avg_rating / 5.0) * 30
```
Users with consistently high ratings earn up to 30 points.

### Overdue Penalty: 0–30 (deducted)
```
overdue_penalty = min(overdue_count * 5, 30)
```
Each overdue item deducts 5 points, capped at 30 deducted.

### Lender Activity Bonus: 0–15
```
lender_bonus = min((total_lends / 10) * 5, 15)
```
Active lenders earn bonus points for contributing to the platform.

### Phone Verification Bonus: 0 or 5
```
phone_bonus = 5 if phone_verified else 0
```

## Trigger Events

Trust score is recalculated when:
- A transaction is successfully returned (borrower benefits)
- A review is received
- A transaction becomes overdue
- A user verifies their phone number

## Trust Score Labels

| Score | Label | Badge Color |
|---|---|---|
| 75–100 | Trusted | Green |
| 40–74 | Moderate | Amber |
| 0–39 | New | Red |

## Example Calculation

User: 10 total borrows, 9 successful returns, avg rating 4.2, 1 overdue, 5 lends, phone verified

```
base = 10
return_rate_score = (9/10) * 40 = 36
review_score = (4.2/5) * 30 = 25.2
overdue_penalty = 1 * 5 = 5
lender_bonus = min((5/10) * 5, 15) = 2.5
phone_bonus = 5

trust_score = 10 + 36 + 25.2 - 5 + 2.5 + 5 = 73.7
```
