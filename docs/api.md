# API Reference

Base URL: `https://your-backend.example/api/v1`  
Interactive docs (dev only): `http://localhost:8000/docs`

---

## Health

### GET /health

Returns application health status.

**Response 200:**
```json
{
  "status": "healthy",
  "environment": "sandbox",
  "daraja_configured": true
}
```

---

## Payments

### POST /payments/stk

Initiate an STK Push payment request.

**Request:**
```json
{
  "phone_number": "0712345678",
  "amount": 1500,
  "account_reference": "Rent",
  "description": "Monthly rent",
  "idempotency_key": "optional-unique-key"
}
```

**Validation:**
- `phone_number`: valid Kenyan number (07XX, 01XX, +254XX, 254XX)
- `amount`: 1 – 150,000 KES
- `account_reference`: 1–12 alphanumeric characters
- `description`: 1–13 alphanumeric characters

**Response 202:**
```json
{
  "transaction_id": "uuid",
  "checkout_request_id": "ws_CO_...",
  "status": "INITIATED",
  "message": "Payment request sent. Check your phone for the M-PESA prompt."
}
```

**Error responses:**
- `422` — validation error
- `502` — Daraja rejected the request

---

### POST /payments/callback

Daraja STK Push callback. Called by Safaricom servers — not by the mobile app.

Must be publicly reachable. Always returns `{"ResultCode": 0}` to prevent Daraja retries.

---

### GET /payments/{transaction_id}

Get a single payment by ID.

**Response 200:** See Transaction schema below.  
**Response 404:** Transaction not found.

---

## Transactions

### GET /transactions

List transactions, newest first.

**Query params:**
- `limit` (default 20, max 100)
- `offset` (default 0)

**Response 200:**
```json
{
  "items": [...],
  "total": 42
}
```

### GET /transactions/{transaction_id}

Get a single transaction.

---

## Transaction schema

```json
{
  "id": "uuid",
  "client_reference": "ABC12345",
  "provider_reference": "MPE123456789",
  "phone_number": "2547••••78",
  "amount": "1500.00",
  "currency": "KES",
  "transaction_type": "STK_PUSH",
  "status": "SUCCESS",
  "account_reference": "Rent",
  "description": "Monthly rent",
  "provider_response_description": "The service request is processed successfully.",
  "created_at": "2026-09-03T09:45:00Z",
  "updated_at": "2026-09-03T09:46:00Z",
  "completed_at": "2026-09-03T09:46:00Z"
}
```

## Transaction statuses

| Status | Meaning |
|--------|---------|
| `CREATED` | Record created, not yet sent to Daraja |
| `INITIATED` | Daraja accepted the request, prompt sent to phone |
| `PENDING` | Awaiting callback from Daraja |
| `SUCCESS` | Daraja confirmed payment completed |
| `FAILED` | Daraja reported failure or customer cancelled |
| `CANCELLED` | Cancelled before completion |
| `TIMEOUT` | No callback received within expected window |
| `UNKNOWN` | Status could not be determined |

**Important:** `INITIATED` does not mean payment succeeded. Only `SUCCESS` (confirmed
via Daraja callback) means the financial transaction completed.
