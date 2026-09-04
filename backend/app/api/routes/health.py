from fastapi import APIRouter
from app.config import get_settings

router = APIRouter()


@router.get("/health")
async def health():
    settings = get_settings()
    return {
        "status": "healthy",
        "environment": settings.environment,
        "daraja_configured": bool(settings.daraja_consumer_key and settings.daraja_consumer_secret),
    }
