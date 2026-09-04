import base64
import time
from dataclasses import dataclass, field
import httpx
from app.config import get_settings
from app.core.exceptions import DarajaAuthError, DarajaTimeoutError
from app.core.logging import get_logger
from app.services.daraja.http import get_daraja_client

logger = get_logger(__name__)

_TOKEN_BUFFER_SECONDS = 60  # refresh this many seconds before expiry


@dataclass
class _CachedToken:
    access_token: str
    expires_at: float = field(default=0.0)

    def is_valid(self) -> bool:
        return time.monotonic() < self.expires_at


_cache = _CachedToken(access_token="")


async def get_access_token() -> str:
    """Return a valid Daraja access token, refreshing if necessary."""
    if _cache.is_valid():
        return _cache.access_token
    return await _refresh_token()


async def _refresh_token() -> str:
    settings = get_settings()
    credentials = base64.b64encode(
        f"{settings.daraja_consumer_key}:{settings.daraja_consumer_secret}".encode()
    ).decode()

    url = f"{settings.daraja_base_url}/oauth/v1/generate?grant_type=client_credentials"

    try:
        client = get_daraja_client()
        response = await client.get(
            url,
            headers={"Authorization": f"Basic {credentials}"},
            timeout=10.0,
        )
    except httpx.TimeoutException as exc:
        raise DarajaTimeoutError("Daraja auth timed out") from exc
    except httpx.RequestError as exc:
        raise DarajaAuthError(f"Network error during Daraja auth: {exc}") from exc

    if response.status_code != 200:
        logger.warning("daraja_auth_failed", status=response.status_code)
        raise DarajaAuthError("Daraja authentication failed", provider_code=str(response.status_code))

    data = response.json()
    token = data.get("access_token")
    expires_in = int(data.get("expires_in", 3600))

    if not token:
        raise DarajaAuthError("Daraja returned empty access token")

    _cache.access_token = token
    _cache.expires_at = time.monotonic() + expires_in - _TOKEN_BUFFER_SECONDS

    logger.info("daraja_token_refreshed", expires_in=expires_in)
    return token
