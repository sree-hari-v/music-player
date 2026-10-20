# 🎵 Shadow Player (Music Player)

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://developer.android.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)
[![Riverpod](https://img.shields.io/badge/State-Riverpod%202.x-blueviolet?style=for-the-badge)](https://riverpod.dev)

> A sleek, modern, offline music player for Android built with Flutter. Inspired by Spotify's design language, featuring synchronized karaoke lyrics, lyrics translation, full-screen interactive Canvas visuals, and modern Android Storage Access Framework (SAF) integration.

---

## ✨ Features

- **🎧 High-Fidelity Offline Audio Playback**
  - Powered by [`just_audio`](https://pub.dev/packages/just_audio) for responsive, low-latency audio.
  - Full playback controls: play/pause, seek, next/previous track, shuffle, and repeat modes (all / single).
  - Background playback with native Android `MediaSession` and lock screen controls.

- **🎤 Synchronized & Plain Lyrics (LRCLIB Integration)**
  - Real-time, karaoke-style auto-scrolling synced lyrics powered by the [LRCLIB API](https://lrclib.net).
  - Smart multi-level fallback: exact tag lookup &rarr; search query &rarr; local disk cache.
  - Full offline caching so previously fetched lyrics work without an internet connection.

- **🌐 In-App Lyrics Translation**
  - Seamlessly translates non-English lyrics into English subtitles.
  - Cached alongside lyrics for instant offline access.

- **🖼️ Spotify-Inspired Canvas Visuals**
  - Fullscreen immersive visualizer & artwork display.
  - Interactive gesture controls: swipe down to dismiss, tap to toggle overlay controls.
  - Aspect ratio toggle: switch between **Cover (Fill Screen)** and **Fit (Contain)** modes.

- **📂 Modern Android Scoped Storage (SAF)**
  - Fully compatible with modern Android permissions using the Storage Access Framework (`saf`).
  - Users can select and authorize custom music folders without granting full storage permissions.
  - Automatic recursive scanning of audio files and embedded ID3 metadata extraction.

- **📋 Dynamic Queue & Track Management**
  - Interactive Now Playing screen with expandable bottom sheets.
  - Drag-and-drop reorderable playback queue.
  - Quick track metadata inspector (sample rate, bit rate, album art, duration).

- **🎨 Spotify-Grade Dark Aesthetic**
  - Dark-mode first UI with smooth gradients sampled dynamically from album art.
  - Persistent mini-player with quick play/pause and progress indicator.
  - Instant search across songs, artists, albums, and directories.

---

## 🏗️ Project Architecture

The codebase follows a feature-driven, clean architectural pattern:

```plaintext
lib/
├── app/                  # Application-level configurations, routes, and themes
├── core/                 # Shared utilities, constants, themes, and extensions
├── data/
│   ├── models/           # Data models (LocalTrack, LyricsModel, etc.)
│   ├── repositories/     # Data repositories bridging providers & services
│   └── services/         # Core services:
│       ├── audio_player_service.dart      # Audio playback engine
│       ├── audio_metadata_service.dart    # ID3 tag extraction
│       ├── lyrics_service.dart            # LRCLIB API client
│       ├── lyrics_cache_service.dart      # Disk caching for lyrics
│       ├── lyrics_translation_service.dart# Translation handling
│       ├── saf_folder_service.dart        # Android SAF folder manager
│       └── notification_service.dart      # Media notification service
├── features/             # Feature modules (UI & state logic)
│   ├── folder_picker/    # Storage permission & folder picker screen
│   ├── home/             # Home dashboard & category browser
│   ├── library/          # Songs list, folders, and track options
│   ├── lyrics/           # Synced lyrics presentation screen
│   ├── navigation/       # Root bottom navigation bar
│   ├── player/           # Mini-player & full Now Playing screen (Canvas)
│   ├── search/           # Real-time track search
│   ├── settings/         # App configuration & preferences
│   └── track_details/    # Metadata dialogs & file info
├── providers/            # Riverpod state notifiers & global providers
├── shared/               # Reusable UI widgets & components
└── main.dart             # Application entry point
```

---

## 🚀 Getting Started

### Prerequisites

Ensure you have the following installed on your machine:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.13.5` or higher)
- [Dart SDK](https://dart.dev/get-dart)
- [Android Studio](https://developer.android.com/studio) with Android SDK and Command-line Tools
- A physical Android device (API 21+) or an Android Emulator

---

### Installation & Setup

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/sree-hari-v/music-player.git
   cd music-player/music
   ```

2. **Install Flutter Dependencies:**
   ```bash
   flutter pub get
   ```

3. **Verify Flutter Environment:**
   ```bash
   flutter doctor
   ```

4. **Connect an Android Device / Launch Emulator:**
   Check recognized devices:
   ```bash
   flutter devices
   ```

5. **Run the Application:**
   ```bash
   flutter run
   ```

---

## 📦 Building for Production

To create an optimized release build for Android:

### Build APK
```bash
flutter build apk --release
```
The output file will be generated at:
`build/app/outputs/flutter-apk/app-release.apk`

### Build App Bundle (Google Play)
```bash
flutter build appbundle --release
```
The output file will be generated at:
`build/app/outputs/bundle/release/app-release.aab`

---

## 📱 Android Permissions

Shadow Player requires minimal permissions configured in `android/app/src/main/AndroidManifest.xml`:

| Permission | Purpose |
| :--- | :--- |
| `INTERNET` | Fetch online synchronized lyrics & translations |
| `ACCESS_NETWORK_STATE` | Check connectivity before online requests |
| `WAKE_LOCK` | Maintain background audio playback without sleep interruptions |
| `FOREGROUND_SERVICE` | Android background media playback service |
| `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Android 14+ specific media playback requirement |
| `POST_NOTIFICATIONS` | Android 13+ lock screen and shade media controls |

*Note: Storage access uses the Android Storage Access Framework (SAF), eliminating the need for invasive broad storage permissions on modern Android versions.*

---

## 🛠️ Tech Stack & Key Libraries

- **Framework**: [Flutter](https://flutter.dev)
- **Language**: [Dart](https://dart.dev)
- **State Management**: [Riverpod 2.x (`flutter_riverpod`)](https://pub.dev/packages/flutter_riverpod)
- **Audio Engine**: [`just_audio`](https://pub.dev/packages/just_audio)
- **Folder & Storage Access**: [`saf`](https://pub.dev/packages/saf)
- **Tag & Metadata Reader**: [`audio_metadata_reader`](https://pub.dev/packages/audio_metadata_reader)
- **Local Persistence**: [`shared_preferences`](https://pub.dev/packages/shared_preferences) & [`path_provider`](https://pub.dev/packages/path_provider)
- **Networking**: [`http`](https://pub.dev/packages/http)
- **Lyrics Provider**: [LRCLIB API](https://lrclib.net)

---

## 🤝 Contributing

Contributions are welcome! If you have ideas for new features or bug fixes:

1. Fork the Project.
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`).
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to the Branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
