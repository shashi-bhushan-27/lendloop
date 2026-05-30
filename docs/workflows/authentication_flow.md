# Authentication Flow — LendLoop

## Overview

LendLoop uses a dual-layer authentication system:
1. **Firebase Authentication** handles identity (email verification, Google OAuth, phone OTP)
2. **JWT tokens** handle API sessions

## Domain Restriction

Only two email domains are accepted:
- `@vit.ac.in` (faculty/staff)
- `@vitstudent.ac.in` (students)

This is enforced at **two levels**:
1. Flutter client-side validation before Firebase call
2. Backend API domain check after Firebase token verification

---

## Registration Flow

```
1. User opens app → LendLoop registration screen
2. User enters: Full Name, VIT Email, Password
3. Flutter validates: email domain check (client-side)
4. Firebase: createUserWithEmailAndPassword(email, password)
5. Firebase: sendEmailVerification()
6. Flutter calls POST /api/v1/auth/login with Firebase ID token
7. Backend: verify_firebase_token(id_token)
8. Backend: validate_email_domain(email) — domain restriction
9. Backend: CREATE new User record in PostgreSQL
10. Backend: issue JWT access_token + refresh_token
11. Flutter: store tokens in FlutterSecureStorage
12. Flutter: navigate to home screen
```

---

## Login Flow

```
1. User enters: VIT Email, Password
2. Flutter validates: email domain check
3. Firebase: signInWithEmailAndPassword(email, password)
4. Firebase: returns User with ID token
5. Flutter calls POST /api/v1/auth/login
6. Backend: verify + domain check + FIND user in DB
7. Backend: issue new JWT tokens
8. Flutter: store tokens + navigate to home
```

---

## Token Refresh Flow

```
1. API call returns 401 Unauthorized
2. Dio interceptor detects 401
3. Flutter calls POST /api/v1/auth/refresh with refresh_token
4. Backend: verify refresh token, issue new access token
5. Original request retried with new token
6. If refresh also fails → force logout
```

---

## Phone Verification Flow

```
1. User navigates to Profile → Add Phone
2. Flutter: FirebaseAuth.verifyPhoneNumber(phoneNumber)
3. Firebase: sends OTP SMS
4. User enters OTP
5. Firebase: verifyOTP → returns PhoneAuthCredential
6. Firebase: linkWithCredential → links phone to account
7. Flutter: calls PATCH /api/v1/users/me with phone_verified=true
8. Backend: updates user record, triggers trust score recalculation
```

---

## JWT Token Structure

```json
{
  "sub": "uuid-of-user",
  "email": "student@vitstudent.ac.in",
  "role": "student",
  "type": "access",
  "exp": 1234567890
}
```

## Security Notes

- Access tokens expire in **60 minutes**
- Refresh tokens expire in **30 days**
- All tokens are signed with HS256 using a secret key
- Tokens are stored in **FlutterSecureStorage** (encrypted on device)
- On logout: Firebase sign out + delete all local tokens + remove FCM token
