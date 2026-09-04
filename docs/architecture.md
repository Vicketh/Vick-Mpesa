# Architecture

## Overview

```
┌─────────────────────────────────────────┐
│           Flutter Android App           │
│  Riverpod │ go_router │ Dio │ Material  │
└──────────────────┬──────────────────────┘
                   │ HTTPS
┌──────────────────▼──────────────────────┐
│           FastAPI Backend               │
│  Routes → Services → Daraja Client      │
│  SQLAlchemy │ Alembic │ structlog        │
└──────────────────┬──────────────────────┘
                   │ OAuth + HTTPS
┌──────────────────▼──────────────────────┐
│         Safaricom Daraja                │
│  STK Push │ Callbacks │ OAuth           │
└─────────────────────────────────────────┘
```

## Backend layers

```
HTTP Request
    │
    ▼
FastAPI Router          (app/api/routes/)
    │  validates schema
    ▼
Pydantic Schema         (app/schemas/)
    │  calls service
    ▼
Transaction Service     (app/services/transaction_service.py)
    │  calls Daraja
    ▼
Daraja Service          (app/services/daraja/)
    │  auth + HTTP
    ▼
Safaricom Daraja API
    │
    ▼  (async callback)
Callback Route          (app/api/routes/payments.py)
    │
    ▼
Transaction Service     (process_stk_callback)
    │
    ▼
Database                (SQLAlchemy async + SQLite/Postgres)
```

## Mobile layers

```
Screen (UI)
    │
    ▼
Riverpod Provider       (providers/providers.dart)
    │
    ▼
Service                 (services/payment_service.dart)
    │
    ▼
ApiClient               (services/api_client.dart)
    │  HTTPS
    ▼
Backend API
```

## Transaction state machine

```
CREATED → INITIATED → PENDING → SUCCESS
                    ↘          ↘ FAILED
                      TIMEOUT    CANCELLED
                      FAILED
UNKNOWN → SUCCESS | FAILED
```

Terminal states: SUCCESS, FAILED, CANCELLED  
No transitions out of terminal states.

## Idempotency

STK Push requests accept an optional `idempotency_key`.  
If a request with the same key arrives twice, the existing transaction is returned.  
The callback handler is also idempotent — processing a callback on an already-terminal
transaction is a no-op.

## Database

Development: SQLite via `aiosqlite`  
Production: PostgreSQL via `asyncpg`  
Migrations: Alembic

Key indexes: `id`, `checkout_request_id` (unique), `idempotency_key` (unique),
`client_reference`, `provider_reference`, `status`, `created_at`
