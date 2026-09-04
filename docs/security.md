# Security

## Principles

1. Daraja credentials never leave the backend
2. M-PESA PIN is never collected, transmitted, or stored
3. Secrets are redacted from all log output
4. Phone numbers are masked in logs and UI display
5. HTTPS enforced in production
6. Financial operations require explicit user confirmation

## Credentials

| Secret | Location | Never in |
|--------|----------|---------|
| DARAJA_CONSUMER_KEY | Backend `.env` | APK, logs, responses |
| DARAJA_CONSUMER_SECRET | Backend `.env` | APK, logs, responses |
| DARAJA_PASSKEY | Backend `.env` | APK, logs, responses |
| JWT_SECRET_KEY | Backend `.env` | APK, logs, responses |
| M-PESA PIN | Never stored | Anywhere |

## Log sanitization

The logging module (`app/core/logging.py`) redacts any field whose key matches:
`consumer_key`, `consumer_secret`, `access_token`, `authorization`,
`passkey`, `password`, `secret`, `token`, `pin`

These are replaced with `[REDACTED]` before any log output.

## Network security (Android)

`network_security_config.xml` enforces:
- Cleartext HTTP only to `localhost`, `10.0.2.2`, `127.0.0.1` (debug builds)
- All other traffic requires TLS
- Production builds must use HTTPS backend

## Phone number handling

- Normalized to `254XXXXXXXXX` format internally
- Displayed as `2547••••XX` in UI and logs
- Full number only used in Daraja API calls (server-side)

## Transaction safety

- Confirmation dialog before every payment
- Pending state clearly communicated — never shows success prematurely
- Retry button only shown when previous transaction status is known
- Idempotency keys prevent duplicate charges on network retry

## Rooted devices

Vick Mpesa does not:
- Exploit root access
- Hide root from Safaricom
- Hook or interfere with the official M-PESA application
- Bypass Safaricom authentication

The app functions normally on rooted devices. Root detection is not implemented
because it would not improve security for our threat model.

## Dependency security

Run periodically:
```sh
# Backend
cd backend && source .venv/bin/activate
pip-audit

# Flutter
cd mobile
flutter pub outdated
```
