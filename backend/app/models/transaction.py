import enum
import uuid
from datetime import datetime, timezone
from sqlalchemy import DateTime, Enum, Index, Numeric, String, Text
from sqlalchemy.orm import Mapped, mapped_column
from app.db.database import Base


class TransactionStatus(str, enum.Enum):
    CREATED = "CREATED"
    INITIATED = "INITIATED"
    PENDING = "PENDING"
    SUCCESS = "SUCCESS"
    FAILED = "FAILED"
    CANCELLED = "CANCELLED"
    TIMEOUT = "TIMEOUT"
    UNKNOWN = "UNKNOWN"


class TransactionType(str, enum.Enum):
    STK_PUSH = "STK_PUSH"
    C2B = "C2B"
    B2C = "B2C"
    B2B = "B2B"


def _now() -> datetime:
    return datetime.now(timezone.utc)


class Transaction(Base):
    __tablename__ = "transactions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    idempotency_key: Mapped[str | None] = mapped_column(String(128), unique=True, nullable=True)

    # Client-facing reference
    client_reference: Mapped[str] = mapped_column(String(64), index=True)
    # Safaricom-assigned reference (MpesaReceiptNumber etc.)
    provider_reference: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    # CheckoutRequestID from STK push
    checkout_request_id: Mapped[str | None] = mapped_column(String(128), nullable=True, unique=True)

    phone_number: Mapped[str] = mapped_column(String(20))
    amount: Mapped[float] = mapped_column(Numeric(12, 2))
    currency: Mapped[str] = mapped_column(String(3), default="KES")

    transaction_type: Mapped[TransactionType] = mapped_column(Enum(TransactionType))
    status: Mapped[TransactionStatus] = mapped_column(
        Enum(TransactionStatus), default=TransactionStatus.CREATED, index=True
    )

    account_reference: Mapped[str] = mapped_column(String(12))
    description: Mapped[str] = mapped_column(String(13))

    provider_response_code: Mapped[str | None] = mapped_column(String(10), nullable=True)
    provider_response_description: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, onupdate=_now)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        Index("ix_transactions_created_at", "created_at"),
    )
