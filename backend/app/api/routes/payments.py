from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_db, require_api_key
from app.config import get_settings
from app.core.exceptions import DarajaError, TransactionNotFoundError
from app.core.logging import get_logger
from app.models.transaction import TransactionStatus
from app.schemas.payment import StkPushRequest, StkPushResponse, TransactionOut, mask_phone
from app.services import transaction_service

router = APIRouter(prefix="/payments")
logger = get_logger(__name__)


@router.post("/stk", response_model=StkPushResponse, status_code=status.HTTP_202_ACCEPTED)
async def initiate_stk(
    req: StkPushRequest,
    db: AsyncSession = Depends(get_db),
    _: None = Depends(require_api_key),
):
    try:
        txn = await transaction_service.initiate_stk_push(db, req)
    except DarajaError as exc:
        raise HTTPException(status_code=502, detail="Payment initiation failed. Please try again.")
    except Exception:
        logger.exception("unexpected_stk_error")
        raise HTTPException(status_code=500, detail="An unexpected error occurred.")

    return StkPushResponse(
        transaction_id=txn.id,
        checkout_request_id=txn.checkout_request_id,
        status=txn.status,
        message="Payment request sent. Check your phone for the M-PESA prompt.",
    )


@router.post("/callback", status_code=status.HTTP_200_OK)
async def stk_callback(request: Request, db: AsyncSession = Depends(get_db)):
    """
    Daraja STK Push callback endpoint.
    Must be publicly reachable by Safaricom servers.
    """
    settings = get_settings()
    if settings.daraja_callback_secret:
        provided = request.query_params.get("secret", "")
        if provided != settings.daraja_callback_secret:
            logger.warning("callback_invalid_secret")
            return {"ResultCode": 0, "ResultDesc": "Accepted"}

    try:
        payload = await request.json()
    except Exception:
        logger.warning("callback_invalid_json")
        return {"ResultCode": 0, "ResultDesc": "Accepted"}

    await transaction_service.process_stk_callback(db, payload)
    # Always return success to Daraja to prevent retries on our processing errors
    return {"ResultCode": 0, "ResultDesc": "Accepted"}


@router.get("/{transaction_id}", response_model=TransactionOut)
async def get_payment(
    transaction_id: str,
    db: AsyncSession = Depends(get_db),
    _: None = Depends(require_api_key),
):
    try:
        txn = await transaction_service.get_transaction(db, transaction_id)
    except TransactionNotFoundError:
        raise HTTPException(status_code=404, detail="Transaction not found")

    out = TransactionOut.model_validate(txn)
    out.phone_number = mask_phone(txn.phone_number)
    return out


@router.post("/{transaction_id}/sync", response_model=TransactionOut)
async def sync_payment(
    transaction_id: str,
    db: AsyncSession = Depends(get_db),
    _: None = Depends(require_api_key),
):
    try:
        txn = await transaction_service.sync_stk_status(db, transaction_id)
    except TransactionNotFoundError:
        raise HTTPException(status_code=404, detail="Transaction not found")
    except DarajaError:
        raise HTTPException(status_code=502, detail="Could not confirm payment status.")

    out = TransactionOut.model_validate(txn)
    out.phone_number = mask_phone(txn.phone_number)
    return out
