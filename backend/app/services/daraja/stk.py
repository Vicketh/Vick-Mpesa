import base64
from datetime import datetime, timezone
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit
import httpx
from app.config import get_settings
from app.core.exceptions import DarajaError, DarajaTimeoutError
from app.core.logging import get_logger
from app.services.daraja.auth import get_access_token
from app.services.daraja.http import get_daraja_client

logger = get_logger(__name__)


def _timestamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")


def _password(shortcode: str, passkey: str, timestamp: str) -> str:
    raw = f"{shortcode}{passkey}{timestamp}"
    return base64.b64encode(raw.encode()).decode()


def callback_url_with_secret(callback_url: str, secret: str) -> str:
    if not secret:
        return callback_url
    parts = urlsplit(callback_url)
    query = dict(parse_qsl(parts.query, keep_blank_values=True))
    query.setdefault("secret", secret)
    return urlunsplit((parts.scheme, parts.netloc, parts.path, urlencode(query), parts.fragment))


async def initiate_stk_push(
    phone_number: str,
    amount: int,
    account_reference: str,
    description: str,
    callback_url: str,
) -> dict:
    """
    Initiate Lipa Na M-Pesa Online (STK Push).

    Returns the raw Daraja response dict on success.
    Raises DarajaError on failure.

    Reference: https://developer.safaricom.co.ke/APIs/MpesaExpressSimulate
    """
    settings = get_settings()
    token = await get_access_token()
    ts = _timestamp()
    pwd = _password(settings.daraja_shortcode, settings.daraja_passkey, ts)

    payload = {
        "BusinessShortCode": settings.daraja_shortcode,
        "Password": pwd,
        "Timestamp": ts,
        "TransactionType": "CustomerPayBillOnline",
        "Amount": amount,
        "PartyA": phone_number,
        "PartyB": settings.daraja_shortcode,
        "PhoneNumber": phone_number,
        "CallBackURL": callback_url_with_secret(callback_url, settings.daraja_callback_secret),
        "AccountReference": account_reference,
        "TransactionDesc": description,
    }

    url = f"{settings.daraja_base_url}/mpesa/stkpush/v1/processrequest"

    try:
        client = get_daraja_client()
        response = await client.post(
            url,
            json=payload,
            headers={"Authorization": f"Bearer {token}"},
            timeout=30.0,
        )
    except httpx.TimeoutException as exc:
        raise DarajaTimeoutError("STK Push request timed out") from exc
    except httpx.RequestError as exc:
        raise DarajaError(f"Network error during STK Push: {exc}") from exc

    data = response.json()

    if response.status_code != 200:
        code = data.get("errorCode", str(response.status_code))
        desc = data.get("errorMessage", "Unknown error")
        logger.warning("stk_push_failed", status=response.status_code, code=code)
        raise DarajaError(f"STK Push rejected: {desc}", provider_code=code)

    response_code = data.get("ResponseCode", "")
    if response_code != "0":
        desc = data.get("ResponseDescription", "Unknown")
        raise DarajaError(f"STK Push not accepted: {desc}", provider_code=response_code)

    logger.info(
        "stk_push_initiated",
        checkout_request_id=data.get("CheckoutRequestID"),
        merchant_request_id=data.get("MerchantRequestID"),
    )
    return data


async def query_stk_status(checkout_request_id: str) -> dict:
    """Query Daraja for the final status of an STK Push request."""
    settings = get_settings()
    token = await get_access_token()
    ts = _timestamp()
    pwd = _password(settings.daraja_shortcode, settings.daraja_passkey, ts)

    payload = {
        "BusinessShortCode": settings.daraja_shortcode,
        "Password": pwd,
        "Timestamp": ts,
        "CheckoutRequestID": checkout_request_id,
    }
    url = f"{settings.daraja_base_url}/mpesa/stkpushquery/v1/query"

    try:
        client = get_daraja_client()
        response = await client.post(
            url,
            json=payload,
            headers={"Authorization": f"Bearer {token}"},
            timeout=20.0,
        )
    except httpx.TimeoutException as exc:
        raise DarajaTimeoutError("STK status query timed out") from exc
    except httpx.RequestError as exc:
        raise DarajaError(f"Network error during STK status query: {exc}") from exc

    data = response.json()
    if response.status_code != 200:
        code = data.get("errorCode", str(response.status_code))
        desc = data.get("errorMessage", "Unknown error")
        logger.warning("stk_query_failed", status=response.status_code, code=code)
        raise DarajaError(f"STK status query rejected: {desc}", provider_code=code)

    return data
