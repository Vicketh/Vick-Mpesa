from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.core.logging import configure_logging, get_logger
from app.db.database import create_tables
from app.api.routes import health, payments, transactions
from app.services.daraja.http import close_daraja_client

logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    configure_logging("DEBUG" if not settings.is_production else "INFO")
    logger.info("startup", environment=settings.environment)
    await create_tables()
    yield
    await close_daraja_client()
    logger.info("shutdown")


def create_app() -> FastAPI:
    settings = get_settings()

    app = FastAPI(
        title="Vick Mpesa API",
        version="0.1.0",
        docs_url=None if settings.is_production else "/docs",
        redoc_url=None if settings.is_production else "/redoc",
        lifespan=lifespan,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.origins_list,
        allow_methods=["GET", "POST"],
        allow_headers=["*"],
    )

    app.include_router(health.router, prefix="/api/v1")
    app.include_router(payments.router, prefix="/api/v1")
    app.include_router(transactions.router, prefix="/api/v1")

    return app


app = create_app()
