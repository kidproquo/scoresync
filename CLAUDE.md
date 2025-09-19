# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Score Sync is a Flutter-based iOS and Android app that synchronizes YouTube videos with PDF music scores. The app allows musicians to create and follow along with synchronized sheet music and video performances.

## Core Features

- **Split-screen interface**: Left half displays PDF score viewer, right half shows YouTube player
- **Two modes**: Design mode for creating sync points, Playback mode for synchronized viewing
- **Sync points**: Rectangles on the score linked to video timestamps, stored in a red-black tree for efficient lookup
- **PDF score viewer**: Page navigation with next/previous/first/last controls
- **YouTube player**: Custom controls including play/pause, seek, speed adjustment, and 10s skip buttons

## Commands

### Project Setup
```bash
# Create Flutter project with specific app ID
flutter create --org me.princesamuel --project-name scoresync --platforms android,ios .

# Get dependencies
flutter pub get

# Run on connected device
flutter run
```

### Development Commands
```bash
# Analyze code for issues
flutter analyze

# Format code
dart format .

# Run tests
flutter test

# Build for iOS
flutter build ios

# Build for Android
flutter build apk
```

## Architecture Guidelines

### Project Structure
```
lib/
├── main.dart
├── models/
│   ├── sync_point.dart       # Sync point data model
│   └── rectangle.dart        # Rectangle with timestamps
├── providers/
│   ├── score_provider.dart   # PDF score state management
│   ├── video_provider.dart   # YouTube player state
│   └── sync_provider.dart    # Sync points and mode management
├── screens/
│   └── main_screen.dart      # Main split-screen interface
├── widgets/
│   ├── score_viewer/
│   │   ├── score_viewer.dart
│   │   ├── rectangle_overlay.dart
│   │   └── page_controls.dart
│   ├── video_player/
│   │   ├── youtube_player.dart
│   │   └── video_controls.dart
│   └── sync_point_list.dart
└── utils/
    └── timestamp_tree.dart   # Red-black tree implementation
```

### Key Implementation Details

1. **State Management**: Use Provider or Riverpod for managing app state across modes
2. **PDF Rendering**: Use `syncfusion_flutter_pdfviewer` or `flutter_pdfview` for PDF display
3. **YouTube Integration**: Use `youtube_player_flutter` for video playback
4. **Drawing Rectangles**: Implement using `CustomPainter` with gesture detection
5. **Data Structure**: Implement red-black tree for O(log n) timestamp lookup
6. **Orientation**: Lock to landscape mode in `main.dart` and platform-specific configurations

### Code Style Requirements

- Use `log` from `dart:developer` for logging (not `print` or `debugPrint`)
- Create small, composable widgets
- Use flex values in Row/Column widgets for responsive layouts
- Apply theming through `MaterialApp` theme property
- Follow proper separation of concerns with the folder structure above

### Platform Configuration

**Android** (`android/app/src/main/AndroidManifest.xml`):
- Add internet permission
- Set orientation to landscape

**iOS** (`ios/Runner/Info.plist`):
- Configure orientation support for landscape only
- Add necessary permissions for internet access

## Dependencies to Add

```yaml
dependencies:
  flutter:
    sdk: flutter
  youtube_player_flutter: ^latest
  syncfusion_flutter_pdfviewer: ^latest  # or flutter_pdfview
  provider: ^latest  # or riverpod
  file_picker: ^latest
```

## Testing Approach

- Unit tests for red-black tree implementation and sync point logic
- Widget tests for individual components
- Integration tests for mode switching and synchronization behavior