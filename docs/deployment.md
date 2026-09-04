# Deployment

## Environment variables

Copy `.env.example` to `.env` and fill in all values before deploying.
Never commit `.env` to Git.

Production requires:
- `ENVIRONMENT=production`
- `DATABASE_URL=postgresql+asyncpg://...`
- `DARAJA_BASE_URL=https://api.safaricom.co.ke` (live)
- Real Daraja production credentials
- `DARAJA_CALLBACK_URL` pointing to your public domain
- Strong `JWT_SECRET_KEY`

---

## Render

1. Create a new Web Service, connect your repo
2. Set build command: `pip install -r backend/requirements.txt`
3. Set start command: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
4. Set root directory: `backend`
5. Add all environment variables in the Render dashboard
6. Add a PostgreSQL database and copy the connection string to `DATABASE_URL`

---

## Railway

1. Create project → Deploy from GitHub
2. Add a PostgreSQL plugin
3. Set environment variables
4. Set start command: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`

---

## Fly.io

```sh
cd backend
fly launch
fly secrets set DARAJA_CONSUMER_KEY=... DARAJA_CONSUMER_SECRET=... ...
fly deploy
```

---

## VPS (Ubuntu/Debian)

```sh
# Install uv and Python 3.12
curl -LsSf https://astral.sh/uv/install.sh | sh
uv python install 3.12

# Clone and set up
git clone https://github.com/youruser/vick-mpesa.git
cd vick-mpesa/backend
uv venv --python 3.12
source .venv/bin/activate
uv pip install -r requirements.txt

# Run migrations
alembic upgrade head

# Run with gunicorn + uvicorn workers
pip install gunicorn
gunicorn app.main:app -w 2 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

Use nginx as a reverse proxy with TLS (Let's Encrypt).

---

## Database migrations

Always run migrations before starting the server:

```sh
cd backend
source .venv/bin/activate
alembic upgrade head
```

To create a new migration after model changes:

```sh
alembic revision --autogenerate -m "describe the change"
alembic upgrade head
```

---

## Daraja production checklist

- [ ] Apply for production access on developer.safaricom.co.ke
- [ ] Submit business registration documents
- [ ] Get production Consumer Key and Secret
- [ ] Get production Passkey
- [ ] Register production callback URL with Safaricom
- [ ] Test with small amounts before going live
- [ ] Set `DARAJA_BASE_URL=https://api.safaricom.co.ke`
- [ ] Ensure callback URL is HTTPS with valid certificate
