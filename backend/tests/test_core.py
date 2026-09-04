import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.schemas.payment import normalize_phone, mask_phone, StkPushRequest
from app.models.transaction import TransactionStatus
from app.services.transaction_service import _can_transition


# ---------------------------------------------------------------------------
# Phone normalization
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("raw,expected", [
    ("0712345678", "254712345678"),
    ("+254712345678", "254712345678"),
    ("254712345678", "254712345678"),
    ("0112345678", "254112345678"),
])
def test_normalize_phone(raw, expected):
    assert normalize_phone(raw) == expected


@pytest.mark.parametrize("bad", ["0812345678", "123", "07123456789", "+1234567890"])
def test_normalize_phone_invalid(bad):
    with pytest.raises(ValueError):
        normalize_phone(bad)


def test_mask_phone():
    assert mask_phone("254712345678") == "2547••••78"


# ---------------------------------------------------------------------------
# STK Push request validation
# ---------------------------------------------------------------------------

def test_stk_request_valid():
    req = StkPushRequest(
        phone_number="0712345678",
        amount=100,
        account_reference="Rent",
        description="Monthly rent",
    )
    assert req.phone_number == "254712345678"
    assert req.amount == 100


def test_stk_request_invalid_amount():
    with pytest.raises(Exception):
        StkPushRequest(phone_number="0712345678", amount=-1, account_reference="X", description="Y")


def test_stk_request_amount_too_large():
    with pytest.raises(Exception):
        StkPushRequest(phone_number="0712345678", amount=200_000, account_reference="X", description="Y")


def test_stk_request_reference_too_long():
    with pytest.raises(Exception):
        StkPushRequest(
            phone_number="0712345678", amount=100,
            account_reference="A" * 13,  # max 12
            description="Y"
        )


# ---------------------------------------------------------------------------
# State machine
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("from_s,to_s,expected", [
    (TransactionStatus.CREATED, TransactionStatus.INITIATED, True),
    (TransactionStatus.INITIATED, TransactionStatus.SUCCESS, True),
    (TransactionStatus.INITIATED, TransactionStatus.PENDING, True),
    (TransactionStatus.PENDING, TransactionStatus.SUCCESS, True),
    (TransactionStatus.PENDING, TransactionStatus.FAILED, True),
    (TransactionStatus.SUCCESS, TransactionStatus.FAILED, False),  # terminal
    (TransactionStatus.FAILED, TransactionStatus.SUCCESS, False),  # terminal
    (TransactionStatus.CREATED, TransactionStatus.SUCCESS, False),  # skip
])
def test_state_transitions(from_s, to_s, expected):
    assert _can_transition(from_s, to_s) == expected


# ---------------------------------------------------------------------------
# Health endpoint
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_health():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.get("/api/v1/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "healthy"


# ---------------------------------------------------------------------------
# Callback processing (unit)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_callback_unknown_transaction(tmp_path):
    """Callback for unknown checkout_request_id should not raise."""
    from unittest.mock import AsyncMock, MagicMock
    from app.services.transaction_service import process_stk_callback

    db = AsyncMock()
    db.scalar = AsyncMock(return_value=None)

    payload = {
        "Body": {
            "stkCallback": {
                "MerchantRequestID": "x",
                "CheckoutRequestID": "ws_CO_unknown",
                "ResultCode": 0,
                "ResultDesc": "Success",
            }
        }
    }
    # Should complete without error
    await process_stk_callback(db, payload)


@pytest.mark.asyncio
async def test_callback_idempotent():
    """Callback on already-terminal transaction should be a no-op."""
    from unittest.mock import AsyncMock, MagicMock
    from app.services.transaction_service import process_stk_callback
    from app.models.transaction import Transaction

    txn = Transaction()
    txn.id = "test-id"
    txn.status = TransactionStatus.SUCCESS
    txn.checkout_request_id = "ws_CO_123"

    db = AsyncMock()
    db.scalar = AsyncMock(return_value=txn)

    payload = {
        "Body": {
            "stkCallback": {
                "CheckoutRequestID": "ws_CO_123",
                "ResultCode": 0,
                "ResultDesc": "Success",
            }
        }
    }
    await process_stk_callback(db, payload)
    db.commit.assert_not_called()


@pytest.mark.asyncio
async def test_callback_success_from_initiated():
    """A normal Daraja callback can move INITIATED directly to SUCCESS."""
    from unittest.mock import AsyncMock
    from app.services.transaction_service import process_stk_callback
    from app.models.transaction import Transaction

    txn = Transaction()
    txn.id = "test-id"
    txn.status = TransactionStatus.INITIATED
    txn.checkout_request_id = "ws_CO_123"

    db = AsyncMock()
    db.scalar = AsyncMock(return_value=txn)

    payload = {
        "Body": {
            "stkCallback": {
                "CheckoutRequestID": "ws_CO_123",
                "ResultCode": 0,
                "ResultDesc": "Success",
                "CallbackMetadata": {
                    "Item": [
                        {"Name": "MpesaReceiptNumber", "Value": "TST123"},
                    ],
                },
            }
        }
    }

    await process_stk_callback(db, payload)

    assert txn.status == TransactionStatus.SUCCESS
    assert txn.provider_reference == "TST123"
    db.commit.assert_called_once()
