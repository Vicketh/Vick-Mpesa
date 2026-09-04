#!/usr/bin/env bash
set -euo pipefail

API_BASE_URL="${1:-https://your-backend.example}"

echo "=== Vick Mpesa APK Build ==="
echo "Backend URL: $API_BASE_URL"

# Java 21 required for Gradle 8.x
export JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"
export PATH="$JAVA_HOME/bin:/home/vick/flutter/bin:$PATH"
export ANDROID_HOME="/home/vick/android-sdk"
export ANDROID_SDK_ROOT="/home/vick/android-sdk"

# Verify tools
command -v flutter >/dev/null || { echo "ERROR: flutter not found"; exit 1; }
java -version 2>&1 | grep -q "21\." || { echo "ERROR: Java 21 required"; exit 1; }

MOBILE_DIR="$(cd "$(dirname "$0")/.." && pwd)/mobile"
cd "$MOBILE_DIR"

echo ""
echo "--- Flutter analyze ---"
flutter analyze

echo ""
echo "--- Flutter test ---"
flutter test

echo ""
echo "--- Building release APK ---"
flutter build apk --release \
  --dart-define=API_BASE_URL="$API_BASE_URL"

APK="$MOBILE_DIR/build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK" ]; then
  SIZE=$(du -sh "$APK" | cut -f1)
  echo ""
  echo "=== Build successful ==="
  echo "APK: $APK"
  echo "Size: $SIZE"
else
  echo "ERROR: APK not found at expected path"
  exit 1
fi
