# Troubleshooting

## Backend

### `pydantic-core` build fails
Python 3.14 is not yet supported by pydantic-core's Rust bindings.
Use Python 3.12 via `uv`:
```sh
uv python install 3.12
uv venv --python 3.12
```

### Daraja returns 401
- Check `DARAJA_CONSUMER_KEY` and `DARAJA_CONSUMER_SECRET` in `.env`
- Ensure you are using sandbox credentials with `DARAJA_BASE_URL=https://sandbox.safaricom.co.ke`
- Credentials are base64-encoded as `key:secret` — do not encode them manually

### Daraja returns `errorCode: 404.001.03`
The STK Push shortcode or passkey is wrong. Verify in your Daraja app settings.

### Callback never arrives
- The callback URL must be publicly reachable by Safaricom servers
- Use ngrok: `ngrok http 8000`
- Set `DARAJA_CALLBACK_URL=https://xxxx.ngrok.io/api/v1/payments/callback`
- Safaricom does not call `localhost` or private IPs

### `alembic upgrade head` fails
```sh
# Ensure DATABASE_URL is set correctly in .env
# For SQLite:
DATABASE_URL=sqlite+aiosqlite:///./vick_mpesa.db
# Then:
alembic upgrade head
```

---

## Android / Flutter

### Gradle build fails with Java version error
Gradle 8.x requires Java 17 or 21. Java 25 is not supported.
```sh
export JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"
export PATH="$JAVA_HOME/bin:$PATH"
flutter build apk --release
```

### App cannot connect to backend on physical device
Use your machine's LAN IP, not `localhost`:
```sh
flutter run --dart-define=API_BASE_URL=http://192.168.1.X:8000
```
Find your LAN IP: `ip addr show | grep "inet " | grep -v 127`

### `flutter pub get` fails
```sh
flutter clean
flutter pub get
```

### `CLEARTEXT communication not permitted`
You are using HTTP in a release build. Either:
- Use HTTPS backend, or
- Use a debug build for local testing: `flutter run` (not `flutter run --release`)

---

## Common Daraja error codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Insufficient funds |
| 17 | Risk management decline |
| 1032 | Request cancelled by user |
| 1037 | Timeout — user did not respond |
| 2001 | Wrong PIN entered |
| 404.001.03 | Invalid shortcode or passkey |
| 400.002.02 | Bad request — check payload format |
