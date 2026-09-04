# Vick-Mpesa Mobile

Flutter Android client for Vick-Mpesa.

## Run

Emulator:

```sh
flutter run
```

Physical Android phone:

```sh
flutter run \
  --dart-define=API_BASE_URL=http://YOUR_COMPUTER_LAN_IP:8000 \
  --dart-define=API_KEY=YOUR_API_KEY
```

## Build APK

```sh
flutter test
flutter analyze
flutter build apk \
  --dart-define=API_BASE_URL=https://YOUR_BACKEND_HOST \
  --dart-define=API_KEY=YOUR_API_KEY
```
