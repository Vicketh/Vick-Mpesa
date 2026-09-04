from datetime import datetime, timezone
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.core.exceptions import DarajaError, TransactionNotFoundError
from app.core.logging import get_logger
from app.models.transaction import Transaction, TransactionStatus, TransactionType
from app.schemas.payment import StkPushRequest, mask_phone
from app.services.daraja import stk as daraja_stk

logger = get_logger(__name__)

# Valid state transitions
_TRANSITIONS: dict[TransactionStatus, set[TransactionStatus]] = {
    TransactionStatus.CREATED: {TransactionStatus.INITIATED, TransactionStatus.FAILED},
    TransactionStatus.INITIATED: {
        TransactionStatus.PENDING,
        TransactionStatus.SUCCESS,
        TransactionStatus.FAILED,
        TransactionStatus.CANCELLED,
        TransactionStatus.TIMEOUT,
    },
    TransactionStatus.PENDING: {TransactionStatus.SUCCESS, TransactionStatus.FAILED, TransactionStatus.CANCELLED, TransactionStatus.TIMEOUT},
    TransactionStatus.SUCCESS: set(),
    TransactionStatus.FAILED: set(),
    TransactionStatus.CANCELLED: set(),
    TransactionStatus.TIMEOUT: set(),
    TransactionStatus.UNKNOWN: {TransactionStatus.SUCCESS, TransactionStatus.FAILED},
}


def _can_transition(current: TransactionStatus, next_: TransactionStatus) -> bool:
    return next_ in _TRANSITIONS.get(current, set())


def _status_from_result_code(result_code: int) -> TransactionStatus:
    if result_code == 0:
        return TransactionStatus.SUCCESS
    if result_code == 1032:
        return TransactionStatus.CANCELLED
    if result_code == 1037:
        return TransactionStatus.TIMEOUT
    if result_code in {1, 2001}:
        return TransactionStatus.FAILED
    return TransactionStatus.FAILED


def _terminal(status: TransactionStatus) -> bool:
    return status in {
        TransactionStatus.SUCCESS,
        TransactionStatus.FAILED,
        TransactionStatus.CANCELLED,
        TransactionStatus.TIMEOUT,
    }


async def initiate_stk_push(db: AsyncSession, req: StkPushRequest) -> Transaction:
    # Idempotency check
    if req.idempotency_key:
        existing = await db.scalar(
            select(Transaction).where(Transaction.idempotency_key == req.idempotency_key)
        )
        if existing:
            logger.info("idempotent_request", transaction_id=existing.id)
            return existing

    settings = get_settings()
    txn = Transaction(
        id=str(uuid.uuid4()),
        idempotency_key=req.idempotency_key,
        client_reference=str(uuid.uuid4())[:8].upper(),
        phone_number=req.phone_number,
        amount=float(req.amount),
        transaction_type=TransactionType.STK_PUSH,
        status=TransactionStatus.CREATED,
        account_reference=req.account_reference,
        description=req.description,
    )
    db.add(txn)
    await db.flush()

    try:
        daraja_resp = await daraja_stk.initiate_stk_push(
            phone_number=req.phone_number,
            amount=int(req.amount),
            account_reference=req.account_reference,
            description=req.description,
            callback_url=settings.daraja_callback_url,
        )
        txn.checkout_request_id = daraja_resp.get("CheckoutRequestID")
        txn.status = TransactionStatus.INITIATED
        txn.provider_response_code = daraja_resp.get("ResponseCode")
        txn.provider_response_description = daraja_resp.get("ResponseDescription")
    except Exception as exc:
        txn.status = TransactionStatus.FAILED
        txn.provider_response_description = str(exc)
        logger.error("stk_initiation_failed", transaction_id=txn.id, error=str(exc))
        await db.commit()
        raise

    await db.commit()
    await db.refresh(txn)
    logger.info("stk_push_created", transaction_id=txn.id, masked_phone=mask_phone(req.phone_number))
    return txn


async def process_stk_callback(db: AsyncSession, payload: dict) -> None:
    """
    Process Daraja STK callback. Idempotent — safe to call multiple times.
    """
    try:
        stk_callback = payload["Body"]["stkCallback"]
        checkout_request_id: str = stk_callback["CheckoutRequestID"]
        result_code: int = stk_callback["ResultCode"]
        result_desc: str = stk_callback["ResultDesc"]
    except (KeyError, TypeError) as exc:
        logger.error("callback_parse_error", error=str(exc))
        return

    txn = await db.scalar(
        select(Transaction).where(Transaction.checkout_request_id == checkout_request_id)
    )
    if not txn:
        logger.warning("callback_unknown_transaction", checkout_request_id=checkout_request_id)
        return

    # Idempotency: if already terminal, skip
    if _terminal(txn.status):
        logger.info("callback_already_terminal", transaction_id=txn.id, status=txn.status)
        return

    new_status = _status_from_result_code(result_code)
    if new_status == TransactionStatus.SUCCESS:
        # Extract MpesaReceiptNumber from metadata
        metadata = stk_callback.get("CallbackMetadata", {}).get("Item", [])
        for item in metadata:
            if item.get("Name") == "MpesaReceiptNumber":
                txn.provider_reference = str(item.get("Value", ""))

    if _can_transition(txn.status, new_status):
        txn.status = new_status
        txn.provider_response_code = str(result_code)
        txn.provider_response_description = result_desc
        txn.completed_at = datetime.now(timezone.utc)
        await db.commit()
        logger.info("transaction_updated", transaction_id=txn.id, status=new_status)
    else:
        logger.warning(
            "invalid_state_transition",
            transaction_id=txn.id,
            from_status=txn.status,
            to_status=new_status,
        )


async def sync_stk_status(db: AsyncSession, transaction_id: str) -> Transaction:
    txn = await get_transaction(db, transaction_id)
    if _terminal(txn.status) or not txn.checkout_request_id:
        return txn

    data = await daraja_stk.query_stk_status(txn.checkout_request_id)
    result_code_raw = data.get("ResultCode")
    result_desc = data.get("ResultDesc") or data.get("ResponseDescription") or "Status checked"
    if result_code_raw is None:
        raise DarajaError("Daraja status query returned no result code")

    new_status = _status_from_result_code(int(result_code_raw))
    if _can_transition(txn.status, new_status):
        txn.status = new_status
        txn.provider_response_code = str(result_code_raw)
        txn.provider_response_description = result_desc
        txn.completed_at = datetime.now(timezone.utc)
        await db.commit()
        await db.refresh(txn)
        logger.info("transaction_synced", transaction_id=txn.id, status=new_status)

    return txn


async def get_transaction(db: AsyncSession, transaction_id: str) -> Transaction:
    txn = await db.get(Transaction, transaction_id)
    if not txn:
        raise TransactionNotFoundError(f"Transaction {transaction_id} not found")
    return txn


async def list_transactions(
    db: AsyncSession, limit: int = 20, offset: int = 0
) -> tuple[list[Transaction], int]:
    from sqlalchemy import func
    total = await db.scalar(select(func.count()).select_from(Transaction))
    result = await db.scalars(
        select(Transaction).order_by(Transaction.created_at.desc()).limit(limit).offset(offset)
    )
    return list(result.all()), total or 0
