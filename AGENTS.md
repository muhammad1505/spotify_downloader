# Repository Guidelines

## Project Structure & Module Organization
- `lib/` holds the Flutter app source.
- `lib/core/`, `lib/models/`, `lib/screens/`, `lib/services/`, `lib/widgets/` group UI, data models, services, and reusable components.
- `android/` contains native Android integration.
- `android/app/src/main/kotlin/` contains Kotlin bridge code (MethodChannel/EventChannel).
- `android/app/src/main/python/` contains the Chaquopy Python entry points.
- `test/` contains Flutter tests (currently `test/widget_test.dart`).

## Build, Test, and Development Commands
- `flutter pub get` installs Dart/Flutter dependencies.
- `flutter run` launches the app on a connected device/emulator.
- `flutter build apk --debug` builds a debug APK.
- `flutter build apk --release --split-per-abi` builds optimized per‑ABI release APKs.
- `flutter analyze` runs static analysis using `flutter_lints`.
- `flutter test` runs all tests (or `flutter test test/widget_test.dart`).

## Coding Style & Naming Conventions
- Follow `analysis_options.yaml` (includes `package:flutter_lints/flutter.yaml`).
- Format Dart with `dart format .` before committing.
- Naming: Dart files use `snake_case.dart`, classes `PascalCase`, methods/vars `lowerCamelCase`.
- Keep platform bridge boundaries clear: Flutter <-> Kotlin <-> Python changes should include matching updates in each layer.

## Testing Guidelines
- Framework: `flutter_test`.
- Place new tests in `test/` and name files `*_test.dart`.
- Add widget or service tests when touching UI flows or download/service logic.

## Commit & Pull Request Guidelines
- Commit messages follow a Conventional Commits style observed in history (e.g., `fix: ...`, `refactor: ...`).
- PRs should include:
  1. A brief summary of changes and motivation.
  2. Testing performed (commands and results).
  3. Screenshots/GIFs for UI changes.
  4. Linked issues if applicable.

## Configuration Notes
- Requires Flutter 3.4+, Android SDK 24+, and Java 17.
- Python dependencies are bundled via Chaquopy; update `android/app/src/main/python/` carefully and validate on device.
