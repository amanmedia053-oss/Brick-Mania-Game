# د خښتو اتل | Brick Mania Game

A colorful, offline-first Pashto brick-breaker game built with Flutter.

## Features
- Pashto interface and portrait gameplay.
- Paddle movement by touch.
- Increasing levels with stronger bricks and varied layouts.
- Falling power-ups: wider paddle, extra life, slow ball, and bonus points.
- Score and best score saved locally on the device.
- No login, internet connection, or online account required to play.
- GitHub Actions workflow builds a release APK automatically.

## Build
```bash
flutter pub get
flutter analyze
flutter build apk --release
```

The APK is created at `build/app/outputs/flutter-apk/app-release.apk`.
