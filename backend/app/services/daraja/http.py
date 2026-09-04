import httpx

_client: httpx.AsyncClient | None = None


def get_daraja_client() -> httpx.AsyncClient:
    global _client
    if _client is None or _client.is_closed:
        _client = httpx.AsyncClient(
            timeout=30.0,
            limits=httpx.Limits(max_connections=20, max_keepalive_connections=10),
        )
    return _client


async def close_daraja_client() -> None:
    if _client is not None and not _client.is_closed:
        await _client.aclose()
