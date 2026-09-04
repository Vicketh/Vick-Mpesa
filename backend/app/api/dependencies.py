from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import Header, HTTPException, status

from app.config import get_settings
from app.db.database import get_db


async def require_api_key(x_api_key: str | None = Header(default=None)) -> None:
    settings = get_settings()
    if not settings.api_key:
        return
    if x_api_key != settings.api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key",
        )

# Re-export for convenience
__all__ = ["Depends", "AsyncSession", "get_db"]
