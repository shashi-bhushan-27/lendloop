"""
Application Configuration

Centralized settings using Pydantic BaseSettings.
All configuration is loaded from environment variables.
"""

from pydantic import field_validator
from pydantic_settings import BaseSettings
from typing import List, Any
from functools import lru_cache



class Settings(BaseSettings):
    # App
    APP_NAME: str = "LendLoop"
    APP_ENV: str = "development"
    DEBUG: bool = True
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Database
    DATABASE_URL: str
    DATABASE_POOL_SIZE: int = 10
    DATABASE_MAX_OVERFLOW: int = 20

    # Firebase
    FIREBASE_CREDENTIALS_PATH: str
    FIREBASE_PROJECT_ID: str

    # Cloudinary
    CLOUDINARY_CLOUD_NAME: str = ""
    CLOUDINARY_API_KEY: str = ""
    CLOUDINARY_API_SECRET: str = ""
    CLOUDINARY_UPLOAD_PRESET: str = "lendloop_items"

    # Domain Restriction
    ALLOWED_EMAIL_DOMAINS: str = "vit.ac.in,vitstudent.ac.in"

    @property
    def allowed_domains_list(self) -> List[str]:
        return [d.strip() for d in self.ALLOWED_EMAIL_DOMAINS.split(",")]

    # CORS
    CORS_ORIGINS: Any = ["http://localhost:3000", "http://localhost:8080"]

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def parse_cors_origins(cls, v):
        if isinstance(v, str):
            v = v.strip()
            if not v:
                return []
            if v.startswith("[") and v.endswith("]"):
                import json
                try:
                    return json.loads(v)
                except Exception:
                    pass
            return [x.strip() for x in v.split(",")]
        return v

    # QR
    QR_TOKEN_SECRET: str = ""
    QR_TOKEN_EXPIRE_MINUTES: int = 30

    # FCM
    FCM_SERVER_KEY: str = ""

    # Firebase (extra)
    FIREBASE_API_KEY: str = ""

    # Rate Limiting
    RATE_LIMIT_REQUESTS: int = 100
    RATE_LIMIT_WINDOW: int = 60

    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "ignore"  # Ignore any extra keys in .env that aren't declared here


@lru_cache()
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
