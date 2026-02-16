# 🎧 Spotify Downloader (Android)

Full offline Spotify downloader for Android with multi‑queue, analytics, and in‑app preview. Built with **Flutter**, **Kotlin**, and **Python (Chaquopy)** using **yt‑dlp**, **ffmpeg**, and **mutagen**.

## ✨ Features

- 📥 Download Spotify tracks/playlists (via yt‑dlp search)
- 🧵 Multi download queue (pause/resume/cancel)
- 🎛️ Quality selection (128/192/320 kbps)
- 🧠 Metadata tagging + album art (mutagen)
- 🎶 Built‑in preview player (just_audio)
- 📊 Analytics dashboard (sqflite + fl_chart)
- 🔔 Foreground service notifications
- 🌙 Premium dark UI with Spotify theme

## 🧱 Architecture

```
Flutter UI
   ↓
Queue Manager (Flutter)
   ↓
MethodChannel
   ↓
Kotlin Bridge + Foreground Service
   ↓
Chaquopy (Python 3.10)
   ↓
yt-dlp → ffmpeg → mutagen → MP3
```

## 📁 Project Structure

```
lib/
├── core/            # Theme, constants
├── managers/        # Queue + analytics
├── models/          # DownloadItem, DownloadOptions, DownloadTask
├── screens/         # Home, Library, Analytics, Settings, About
├── services/        # PythonService, AudioService, StorageService
├── widgets/         # UI components
└── main.dart        # App entry point

android/
├── app/src/main/
│   ├── kotlin/      # MainActivity, Foreground service
│   └── python/      # downloader.py, bridge module

backend/python/
└── downloader.py    # Reference engine (same logic as Android)
```

## 🚀 Build & Run

```bash
flutter pub get
flutter run
```

Release build:
```bash
flutter build apk --release --target-platform=android-arm64,android-x64
```

## ⚙️ Requirements

- Flutter 3.4+
- Android SDK 24+
- Java 17
- Python 3.10 (embedded via Chaquopy)

## 🔄 CI/CD

- `test.yml`: widget + integration tests
- `build.yml`: release build on tag `v*`

```bash
git tag v1.0.0
git push origin v1.0.0
```

## 📝 Notes

- ffmpeg is bundled in APK assets for `arm64-v8a` and `x86_64`, extracted on first run, then used by Python engine.
- mutagen is bundled through Chaquopy pip requirements (`android/app/build.gradle.kts`).
- Spotdl is not used on Android because of native dependency conflicts.

## 📜 License

MIT
