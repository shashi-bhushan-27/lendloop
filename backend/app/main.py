"""
LendLoop FastAPI Application Entry Point

This module initializes the FastAPI application, registers all middleware,
routers, event handlers, and startup/shutdown lifecycle hooks.
"""

from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse
from loguru import logger
import time

from app.core.config import settings
from app.database.connection import engine, Base
from app.api import auth, users, items, borrow_requests, transactions, reviews, notifications, qr
from app.middleware.logging_middleware import LoggingMiddleware


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler — runs on startup and shutdown."""
    logger.info("🚀 LendLoop API starting up...")
    # Create all database tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("✅ Database tables initialized")
    yield
    logger.info("🔻 LendLoop API shutting down...")
    await engine.dispose()


def create_application() -> FastAPI:
    """Application factory function."""
    app = FastAPI(
        title="LendLoop API",
        description="University-based item lending and borrowing platform — VIT ecosystem",
        version="1.0.0",
        docs_url="/docs" if settings.DEBUG else None,
        redoc_url="/redoc" if settings.DEBUG else None,
        openapi_url="/openapi.json" if settings.DEBUG else None,
        lifespan=lifespan,
    )

    # ── Middleware ────────────────────────────────────────────────────────────
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.add_middleware(LoggingMiddleware)

    # ── Routers ───────────────────────────────────────────────────────────────
    api_prefix = "/api/v1"
    app.include_router(auth.router,            prefix=f"{api_prefix}/auth",          tags=["Authentication"])
    app.include_router(users.router,           prefix=f"{api_prefix}/users",         tags=["Users"])
    app.include_router(items.router,           prefix=f"{api_prefix}/items",         tags=["Items"])
    app.include_router(borrow_requests.router, prefix=f"{api_prefix}/borrow",        tags=["Borrow Requests"])
    app.include_router(transactions.router,    prefix=f"{api_prefix}/transactions",  tags=["Transactions"])
    app.include_router(reviews.router,         prefix=f"{api_prefix}/reviews",       tags=["Reviews"])
    app.include_router(notifications.router,   prefix=f"{api_prefix}/notifications", tags=["Notifications"])
    app.include_router(qr.router,              prefix=f"{api_prefix}/qr",            tags=["QR Verification"])

    # ── Health Check ─────────────────────────────────────────────────────────
    @app.get("/health", tags=["Health"])
    async def health_check():
        return {"status": "healthy", "service": "LendLoop API", "version": "1.0.0"}

    # ── Global Exception Handler ──────────────────────────────────────────────
    @app.exception_handler(Exception)
    async def global_exception_handler(request: Request, exc: Exception):
        logger.error(f"Unhandled exception: {exc}")
        return JSONResponse(
            status_code=500,
            content={"detail": "An internal server error occurred."},
        )

    return app


app = create_application()
