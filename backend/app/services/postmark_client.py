"""
Postmark Email Client

Sends transactional emails via the Postmark API.
Used for OTP verification codes.

Isolated: all errors are caught and logged — never propagates
exceptions that could crash the calling code.
"""

import httpx
from loguru import logger
from app.core.config import settings

POSTMARK_API_URL = "https://api.postmarkapp.com/email"


async def send_otp_email(to_email: str, otp_code: str) -> bool:
    """
    Send a branded OTP verification email via Postmark.
    Returns True if sent successfully, False otherwise.
    """
    html_body = f"""
    <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px;">
        <div style="text-align: center; margin-bottom: 24px;">
            <h1 style="color: #6C63FF; margin: 0; font-size: 28px;">LendLoop</h1>
            <p style="color: #666; margin-top: 4px;">Campus Lending Platform</p>
        </div>
        <div style="background: #f8f9fa; border-radius: 12px; padding: 32px; text-align: center;">
            <h2 style="color: #333; margin-top: 0;">Verify Your Email</h2>
            <p style="color: #666; font-size: 15px;">Enter this code in the app to verify your VIT email address:</p>
            <div style="background: #fff; border: 2px solid #6C63FF; border-radius: 8px; padding: 16px 24px; margin: 24px auto; display: inline-block;">
                <span style="font-size: 36px; font-weight: 700; letter-spacing: 8px; color: #6C63FF;">{otp_code}</span>
            </div>
            <p style="color: #999; font-size: 13px; margin-top: 16px;">This code expires in <strong>10 minutes</strong>.</p>
            <p style="color: #999; font-size: 13px;">If you didn't request this, you can safely ignore this email.</p>
        </div>
        <p style="color: #bbb; font-size: 11px; text-align: center; margin-top: 24px;">
            &copy; LendLoop &mdash; VIT University
        </p>
    </div>
    """

    text_body = f"""LendLoop Email Verification

Your verification code is: {otp_code}

This code expires in 10 minutes.
If you didn't request this, please ignore this email.
"""

    payload = {
        "From": settings.POSTMARK_FROM_EMAIL,
        "To": to_email,
        "Subject": f"LendLoop — Your verification code is {otp_code}",
        "HtmlBody": html_body,
        "TextBody": text_body,
        "MessageStream": "otp",
        "Tag": "email-verification",
    }

    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                POSTMARK_API_URL,
                json=payload,
                headers={
                    "Accept": "application/json",
                    "Content-Type": "application/json",
                    "X-Postmark-Server-Token": settings.POSTMARK_SERVER_TOKEN,
                },
                timeout=10.0,
            )
            if response.status_code == 200:
                data = response.json()
                logger.info(f"OTP email sent to {to_email}, MessageID={data.get('MessageID')}")
                return True
            else:
                logger.error(f"Postmark error {response.status_code}: {response.text}")
                return False
    except Exception as e:
        logger.error(f"Failed to send OTP email to {to_email}: {e}")
        return False
