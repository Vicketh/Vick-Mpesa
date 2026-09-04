from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_db, require_api_key
from app.core.exceptions import TransactionNotFoundError
from app.schemas.payment import TransactionListResponse, TransactionOut, mask_phone
from app.services import transaction_service

router = APIRouter(prefix="/transactions")


@router.get("", response_model=TransactionListResponse)
async def list_transactions(
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    _: None = Depends(require_api_key),
):
    items, total = await transaction_service.list_transactions(db, limit=limit, offset=offset)
    out = []
    for txn in items:
        t = TransactionOut.model_validate(txn)
        t.phone_number = mask_phone(txn.phone_number)
        out.append(t)
    return TransactionListResponse(items=out, total=total)


@router.get("/{transaction_id}", response_model=TransactionOut)
async def get_transaction(
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
