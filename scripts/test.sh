#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="/home/vick/.local/bin:/home/vick/flutter/bin:$PATH"

FAILED=0

echo "=== Backend Tests ==="
cd "$ROOT/backend"
source .venv/bin/activate
pytest -v || FAILED=1

echo ""
echo "=== Flutter Analyze ==="
cd "$ROOT/mobile"
flutter analyze || FAILED=1

echo ""
echo "=== Flutter Tests ==="
flutter test || FAILED=1

echo ""
if [ $FAILED -eq 0 ]; then
  echo "=== All tests passed ==="
else
  echo "=== Some tests failed ==="
  exit 1
fi
