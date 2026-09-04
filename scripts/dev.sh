#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND="$ROOT/backend"

export PATH="/home/vick/.local/bin:$PATH"

if [ ! -f "$ROOT/.env" ]; then
  echo "ERROR: .env not found. Copy .env.example and fill in your credentials:"
  echo "  cp .env.example .env"
  exit 1
fi

cd "$BACKEND"

if [ ! -d ".venv" ]; then
  echo "Creating virtualenv..."
  uv venv --python 3.12
fi

echo "Installing dependencies..."
uv pip install -q -r requirements.txt

echo "Running migrations..."
source .venv/bin/activate
alembic upgrade head

echo ""
echo "=== Starting Vick Mpesa Backend ==="
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
