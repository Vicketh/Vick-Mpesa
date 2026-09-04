# Testing

## Backend tests

```sh
cd backend
source .venv/bin/activate
pytest -v
```

Current coverage:
- Phone number normalization (valid + invalid formats)
- Phone number masking
- STK Push request validation (amount, reference, description)
- Transaction state machine transitions
- Health endpoint
- Callback idempotency (unknown transaction, already-terminal transaction)

### Running with coverage

```sh
pytest --cov=app --cov-report=term-missing
```

---

## Flutter tests

```sh
cd mobile
flutter test
flutter analyze
```

Current coverage:
- TransactionStatus: fromString, isTerminal, isPending
- TransactionType: fromString, displayName
- Transaction.fromJson: valid JSON parsing
- PayScreen: form renders, phone validation, amount validation
- HomeScreen: loading state, empty state, populated state

---

## Sandbox end-to-end test

Prerequisites:
- Backend running with sandbox Daraja credentials
- Callback URL publicly reachable (ngrok or similar)
- Daraja sandbox test credentials from developer.safaricom.co.ke

Steps:
1. Start backend: `uvicorn app.main:app --reload`
2. Verify health: `curl http://localhost:8000/api/v1/health`
3. Initiate STK Push:
```sh
curl -X POST http://localhost:8000/api/v1/payments/stk \
  -H "Content-Type: application/json" \
  -d '{
    "phone_number": "254708374149",
    "amount": 1,
    "account_reference": "Test",
    "description": "Test pay"
  }'
```
4. Note the `transaction_id` in the response
5. Simulate callback (sandbox):
```sh
curl -X POST http://localhost:8000/api/v1/payments/callback \
  -H "Content-Type: application/json" \
  -d '{
    "Body": {
      "stkCallback": {
        "MerchantRequestID": "test",
        "CheckoutRequestID": "<from step 3>",
        "ResultCode": 0,
        "ResultDesc": "The service request is processed successfully.",
        "CallbackMetadata": {
          "Item": [
            {"Name": "Amount", "Value": 1},
            {"Name": "MpesaReceiptNumber", "Value": "MPE123TEST"},
            {"Name": "PhoneNumber", "Value": 254708374149}
          ]
        }
      }
    }
  }'
```
6. Check transaction status:
```sh
curl http://localhost:8000/api/v1/transactions/<transaction_id>
```
7. Verify status is `SUCCESS` and `provider_reference` is set

---

## Daraja sandbox test numbers

From the Daraja portal under "Lipa Na M-Pesa Sandbox":
- Test phone: `254708374149`
- Test shortcode: `174379`
- Test passkey: available in your Daraja app settings

---

## Security checks

```sh
# Check for secrets accidentally committed
git log --all --full-history -- "*.env"
grep -r "consumer_secret\|consumer_key" backend/app/ --include="*.py"

# Python dependency audit
cd backend && pip-audit

# Flutter dependency check
cd mobile && flutter pub outdated
```
