# Vick Mpesa

A legitimate M-PESA companion Android app built on Safaricom's official Daraja APIs.

```
Flutter (Android)
      |  HTTPS
      v
FastAPI Backend
      |  OAuth + server-to-server
      v
Safaricom Daraja
```

## What is implemented

- STK Push (Lipa Na M-Pesa Online) — initiate payments from the app
- Daraja OAuth token caching and automatic refresh
- Callback processing with idempotency and state machine
- Transaction history, detail view, and receipt
- Phone number normalization and masking
- Dark/light theme with persistence
- Offline-aware UI (no silent background payments)
- API key protection for mobile-facing endpoints
- Structured logging with secret redaction

## What requires Safaricom production onboarding

- Account balance query
- Full M-PESA transaction history/statement
- B2C (business to customer disbursements)
- B2B transfers
- C2B paybill/till registration

See `docs/daraja-capability-matrix.md` for the full matrix.

---

## Prerequisites

| Tool | Version |
|------|---------|
| Python | 3.12 (via `uv`) |
| Flutter | 3.32+ |
| Java | 21 (for Gradle) |
| Android SDK | API 36 |
| Git | any |

---

## Backend setup

```sh
cp .env.example .env
# Fill in your Daraja sandbox credentials in .env

cd backend
uv venv --python 3.12
source .venv/bin/activate
uv pip install -r requirements.txt

# Run database migrations
alembic upgrade head

# Start the server
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

API docs available at: http://localhost:8000/docs

### Docker (Postgres)

```sh
docker compose up --build
```

### Daraja callback (local dev)

Safaricom must reach your callback URL. Use a tunnel:

```sh
ngrok http 8000
# Then set in .env:
# DARAJA_CALLBACK_URL=https://xxxx.ngrok.io/api/v1/payments/callback
```

---

## Mobile setup

### Emulator

```sh
cd mobile
flutter run
```

### Physical device (Samsung Galaxy A71 or any Android on same Wi-Fi)

```sh
cd mobile
flutter run \
  --dart-define=API_BASE_URL=http://192.168.1.X:8000
```

Replace `192.168.1.X` with your machine's LAN IP.

---

## Running tests

```sh
# Backend
cd backend
source .venv/bin/activate
pytest

# Flutter
cd mobile
flutter test
flutter analyze
```

---

## Building the APK

```sh
export JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"
export PATH="$JAVA_HOME/bin:$PATH"

cd mobile
flutter build apk --release \
  --dart-define=API_BASE_URL=https://your-backend.example
```

Output: `mobile/build/app/outputs/flutter-apk/app-release.apk`

Or use the script:

```sh
./scripts/build-apk.sh https://your-backend.example
```

---

## Environment variables

See `.env.example` for all variables. Key ones:

| Variable | Description |
|----------|-------------|
| `DARAJA_CONSUMER_KEY` | From Daraja developer portal |
| `DARAJA_CONSUMER_SECRET` | From Daraja developer portal |
| `DARAJA_PASSKEY` | Lipa Na M-Pesa passkey |
| `DARAJA_SHORTCODE` | Your paybill/till shortcode |
| `DARAJA_CALLBACK_URL` | Publicly reachable callback URL |
| `DATABASE_URL` | SQLite (dev) or PostgreSQL (prod) |
| `JWT_SECRET_KEY` | Long random secret for JWT signing |

---

## Security

- Daraja credentials never leave the backend
- M-PESA PIN is never collected or stored
- Phone numbers are masked in logs and UI
- Secrets are redacted from all log output
- HTTPS enforced in production (cleartext only to localhost in debug)
- See `docs/security.md` for full details

---

## Deployment

See `docs/deployment.md` for Render, Railway, Fly.io, and VPS instructions.

---

## Known limitations

- Balance display requires Safaricom production onboarding
- Transaction history only shows transactions initiated through this app
- B2C/B2B require separate Safaricom business approval
- Sandbox phone numbers must be from the Daraja test credentials
