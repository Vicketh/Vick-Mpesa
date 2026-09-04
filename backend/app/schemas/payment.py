from datetime import datetime
from decimal import Decimal
from pydantic import BaseModel, Field, field_validator
import re
from app.models.transaction import TransactionStatus, TransactionType


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_KE_PHONE_RE = re.compile(r"^(?:254|\+254|0)(7\d{8}|1\d{8})$")


def normalize_phone(raw: str) -> str:
    """Normalize Kenyan phone number to 2547XXXXXXXX format."""
    cleaned = re.sub(r"\s+", "", raw)
    m = _KE_PHONE_RE.match(cleaned)
    if not m:
        raise ValueError(f"Invalid Kenyan phone number: {raw!r}")
    digits = m.group(1)
    return f"254{digits}"


def mask_phone(phone: str) -> str:
    """Return masked phone for display: 2547••••34"""
    if len(phone) < 6:
        return "••••••"
    return phone[:4] + "••••" + phone[-2:]


# ---------------------------------------------------------------------------
# STK Push
# ---------------------------------------------------------------------------

class StkPushRequest(BaseModel):
    phone_number: str = Field(..., description="Kenyan phone number (any common format)")
    amount: Decimal = Field(..., gt=0, le=150_000, description="Amount in KES")
    account_reference: str = Field(..., min_length=1, max_length=12)
    description: str = Field(..., min_length=1, max_length=13)
    idempotency_key: str | None = Field(None, max_length=128)

    @field_validator("phone_number")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        return normalize_phone(v)

    @field_validator("account_reference", "description")
    @classmethod
    def no_special_chars(cls, v: str) -> str:
        if not re.match(r"^[A-Za-z0-9 _\-\.]+$", v):
            raise ValueError("Only alphanumeric characters, spaces, hyphens, underscores, and dots allowed")
        return v


class StkPushResponse(BaseModel):
    transaction_id: str
    checkout_request_id: str | None
    status: TransactionStatus
    message: str


# ---------------------------------------------------------------------------
# Transaction
# ---------------------------------------------------------------------------

class TransactionOut(BaseModel):
    id: str
    client_reference: str
    provider_reference: str | None
    phone_number: str  # masked
    amount: Decimal
    currency: str
    transaction_type: TransactionType
    status: TransactionStatus
    account_reference: str
    description: str
    provider_response_description: str | None
    created_at: datetime
    updated_at: datetime
    completed_at: datetime | None

    model_config = {"from_attributes": True}


class TransactionListResponse(BaseModel):
    items: list[TransactionOut]
    total: int


# ---------------------------------------------------------------------------
# Daraja callback (internal — not exposed to mobile clients)
# ---------------------------------------------------------------------------

class StkCallbackMetadataItem(BaseModel):
    Name: str
    Value: str | int | float | None = None


class StkCallbackBody(BaseModel):
    MerchantRequestID: str
    CheckoutRequestID: str
    ResultCode: int
    ResultDesc: str
    CallbackMetadata: dict | None = None


class StkCallbackPayload(BaseModel):
    Body: dict
