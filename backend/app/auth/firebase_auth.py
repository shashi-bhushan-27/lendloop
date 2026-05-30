"""
Firebase Authentication Integration

Verifies Firebase ID tokens sent by the Flutter client.
Enforces domain restriction at the server level.
"""

import firebase_admin
from firebase_admin import credentials, auth as firebase_auth_module
from loguru import logger
from app.core.config import settings
from fastapi import HTTPException, status

# Initialize Firebase Admin SDK once
_firebase_app = None


def get_firebase_app():
    global _firebase_app
    if _firebase_app is None:
        try:
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
            _firebase_app = firebase_admin.initialize_app(cred)
            logger.info("✅ Firebase Admin SDK initialized")
        except Exception as e:
            logger.error(f"Firebase init error: {e}")
            raise
    return _firebase_app


async def verify_firebase_token(id_token: str) -> dict:
    """
    Verify a Firebase ID token.
    Returns decoded token claims if valid.
    Raises HTTPException if invalid or expired.
    """
    try:
        get_firebase_app()
        logger.debug(f"Verifying token (first 40 chars): {id_token[:40]}...")
        decoded_token = firebase_auth_module.verify_id_token(
            id_token,
            check_revoked=False,
            clock_skew_seconds=60,   # Allow up to 60s clock drift between phone and server
        )
        logger.info(f"Token verified OK for uid={decoded_token.get('uid')}, email={decoded_token.get('email')}")
        return decoded_token
    except firebase_auth_module.ExpiredIdTokenError as e:
        logger.error(f"Firebase token EXPIRED: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Firebase token has expired. Please sign in again."
        )
    except firebase_auth_module.InvalidIdTokenError as e:
        logger.error(f"Firebase token INVALID — full error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid Firebase token: {str(e)}"
        )
    except Exception as e:
        logger.error(f"Firebase token verification UNEXPECTED error type={type(e).__name__}: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication failed."
        )


def validate_email_domain(email: str) -> bool:
    """
    Validates that the email belongs to an allowed VIT domain.
    Returns True if valid, raises HTTPException if not.
    """
    domain = email.split("@")[-1].lower()
    allowed = settings.allowed_domains_list
    if domain not in allowed:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Access restricted. Only {', '.join(allowed)} email addresses are allowed."
        )
    return True
