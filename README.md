# 🎧 Cross-Platform CLI Media Manager

Flutter UI + platform adapters + CLI engines. Current phase: **Android first**.

## ✨ Goals (Target)

- 📥 CLI download engine (spotdl)
- 🧵 Multi queue: FIFO + priority + persistence
- 🎛️ Quality selection
- 🎶 Built‑in player (just_audio)
- 📊 Analytics dashboard + CSV export
- 🔔 Foreground/background where supported

## 🧱 Architecture (Planned)

```
Flutter UI
   ↓
Queue Engine (core)
   ↓
Platform Adapter
   ↓
Native OS Runtime
   ↓
spotdl CLI
```

## 📁 Project Structure (New)

```
lib/
├── core/            # QueueEngine, AnalyticsEngine, PlayerEngine
├── adapters/        # Platform adapters
├── platform_bridge/ # CommandExecutor interface
├── backend/         # Shared daemon (future)
├── screens/         # UI
└── services/        # App services
```

## 🚀 Build & Run (Phase 1)

```bash
flutter pub get
flutter run
```

Release build:
```bash
flutter build apk --release --target-platform=android-arm64,android-x64
```

## ⚙️ Requirements (Phase 1)

- Flutter 3.4+
- Android SDK 24+
- Java 17
- Termux + Termux:Tasker + spotdl installed by user

## 🔄 CI/CD

- `test.yml`: widget + integration tests
- `build.yml`: release build on tag `v*`

```bash
git tag v1.0.0
git push origin v1.0.0
```

## 📝 Notes

- Phase 1 is Android-only. Desktop adapters are placeholders.
- Termux is required on Android for spotdl execution.

## 📜 License

MIT
