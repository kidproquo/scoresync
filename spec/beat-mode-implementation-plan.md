# Beat Mode Implementation Plan

## Overview
Implement Beat Mode as an alternative to Video Mode, where the metronome's beat becomes the reference track for sync points instead of video timestamps.

---

## Phase 1: Data Model Changes

### 1.1 Add Beat Mode to MetronomeSettings
**File:** `lib/models/metronome_settings.dart`

- Add enum:
  ```dart
  enum MetronomeMode { video, beat }
  ```
- Add `MetronomeMode mode` field to `MetronomeSettings` class (default: `MetronomeMode.video`)
- Update `copyWith()` method to include `mode` parameter
- Update `toJson()` and `fromJson()` for serialization
  - Store as string: `'mode': mode.name`
  - Parse from string: `MetronomeMode.values.byName(json['mode'])`

### 1.2 Extend Rectangle Model for Beat Sync Points
**File:** `lib/models/rectangle.dart`

- Add new field: `List<int> beatNumbers = []` (parallel to existing `timestamps`)
- Update `copyWith()` to include optional `beatNumbers` parameter
- Add helper methods:
  ```dart
  void addBeatNumber(int beat) {
    if (!beatNumbers.contains(beat)) {
      beatNumbers.add(beat);
      beatNumbers.sort();
    }
  }

  void removeBeatNumber(int beat) {
    beatNumbers.remove(beat);
  }

  bool get hasBeatNumbers => beatNumbers.isNotEmpty;
  ```
- Update `toJson()` and `fromJson()` to include `beatNumbers` array
- Rectangles can have BOTH `timestamps` (video mode) AND `beatNumbers` (beat mode)

---

## Phase 2: Metronome Beat Tracking

### 2.1 Enable Tick Callback in MetronomeProvider
**File:** `lib/providers/metronome_provider.dart`

- Change `enableTickCallback: false` to `true` in `_initializeMetronome()`
- Add state variables:
  ```dart
  StreamSubscription<int>? _tickSubscription;
  int _totalBeats = 0;  // Total beats since start
  Function(int beat)? _onBeat;  // Callback for beat changes
  ```
- Add getters:
  ```dart
  int get totalBeats => _totalBeats;
  int get currentMeasure => (_totalBeats / _settings.timeSignature.numerator).floor() + 1;
  ```
- Implement tick stream listener in `startMetronome()`:
  ```dart
  _tickSubscription = _metronome.tickStream.listen((int tick) {
    _totalBeats++;
    _currentBeat = ((_totalBeats - 1) % _settings.timeSignature.numerator) + 1;
    _onBeat?.call(_totalBeats);
    notifyListeners();
  });
  ```
- Cancel subscription in `stopMetronome()` and `dispose()`
- Reset counters when stopped: `_totalBeats = 0; _currentBeat = 0;`

### 2.2 Add Seek-by-Measure Functionality
**File:** `lib/providers/metronome_provider.dart`

- Add method to seek to specific measure:
  ```dart
  void seekToMeasure(int measureNumber) {
    final beatsPerMeasure = _settings.timeSignature.numerator;
    final targetBeat = (measureNumber - 1) * beatsPerMeasure;
    _totalBeats = targetBeat;
    _currentBeat = 1; // Reset to first beat of measure
    developer.log('Seeked to measure $measureNumber (beat $_totalBeats)');
    notifyListeners();
  }
  ```
- Add method to set beat callback:
  ```dart
  void setOnBeatCallback(Function(int)? callback) {
    _onBeat = callback;
  }
  ```

---

## Phase 3: UI Changes

### 3.1 Add Mode Selector to Metronome Settings Panel
**File:** `lib/widgets/metronome/metronome_settings_panel.dart`

- Add at top of settings panel (above Enable Metronome toggle):
  ```dart
  // Mode Selection
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Metronome Mode', style: TextStyle(fontSize: 16)),
        SegmentedButton<MetronomeMode>(
          segments: const [
            ButtonSegment(value: MetronomeMode.video, label: Text('Video')),
            ButtonSegment(value: MetronomeMode.beat, label: Text('Beat')),
          ],
          selected: {settings.mode},
          onSelectionChanged: (Set<MetronomeMode> selection) {
            // Update mode in settings
          },
        ),
      ],
    ),
  )
  ```
- Consider disabling video-related settings when in Beat Mode (or show all settings regardless)

### 3.2 Create Beat Overlay Widget
**New File:** `lib/widgets/metronome/beat_overlay.dart`

**Widget Structure:**
```dart
class BeatOverlay extends StatelessWidget {
  const BeatOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<MetronomeProvider, AppModeProvider>(
      builder: (context, metronomeProvider, appModeProvider, _) {
        final isDesignMode = appModeProvider.isDesignMode;

        return Stack(
          children: [
            // Main content area
            Container(
              color: Colors.black,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMeasureDisplay(metronomeProvider),
                  const SizedBox(height: 16),
                  _buildBeatVisualization(metronomeProvider),
                  const SizedBox(height: 24),
                  _buildBPMDisplay(metronomeProvider),
                ],
              ),
            ),
            // Controls overlay at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildControls(metronomeProvider, isDesignMode),
            ),
          ],
        );
      },
    );
  }
}
```

**Components to build:**

**Measure Display:**
```dart
Widget _buildMeasureDisplay(MetronomeProvider provider) {
  return Text(
    'Measure ${provider.currentMeasure}',
    style: TextStyle(
      color: Colors.white,
      fontSize: 32,
      fontWeight: FontWeight.bold,
    ),
  );
}
```

**Beat Visualization:**
```dart
Widget _buildBeatVisualization(MetronomeProvider provider) {
  final beatsPerMeasure = provider.settings.timeSignature.numerator;
  final currentBeat = provider.currentBeat;

  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(beatsPerMeasure, (index) {
      final beatNumber = index + 1;
      final isCurrentBeat = beatNumber == currentBeat;
      final isAccented = beatNumber == 1;

      return Container(
        margin: EdgeInsets.symmetric(horizontal: 8),
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCurrentBeat
            ? (isAccented ? Colors.red : Colors.blue)
            : Colors.grey[700],
          border: Border.all(
            color: Colors.white,
            width: isCurrentBeat ? 3 : 1,
          ),
        ),
      );
    }),
  );
}
```

**BPM Display:**
```dart
Widget _buildBPMDisplay(MetronomeProvider provider) {
  return Text(
    '${provider.settings.bpm} BPM',
    style: TextStyle(
      color: Colors.grey[400],
      fontSize: 16,
    ),
  );
}
```

**Controls (Bottom Bar):**
```dart
Widget _buildControls(MetronomeProvider provider, bool isDesignMode) {
  return Container(
    padding: EdgeInsets.all(10),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Colors.black.withValues(alpha: 0.7),
          Colors.transparent,
        ],
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Control buttons row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Stop button
            IconButton(
              icon: Icon(Icons.stop, color: Colors.white, size: 20),
              onPressed: provider.isPlaying ? () => provider.stopMetronome() : null,
            ),
            SizedBox(width: 16),
            // Play/Pause button
            IconButton(
              icon: Icon(
                provider.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 28,
              ),
              onPressed: () {
                if (provider.isPlaying) {
                  provider.stopMetronome(); // Or add pauseMetronome()
                } else {
                  provider.startMetronome();
                }
              },
            ),
          ],
        ),
        // Measure slider (only in playback mode)
        if (!isDesignMode) _buildMeasureSlider(provider),
      ],
    ),
  );
}
```

**Measure Slider (Playback Mode Only):**
```dart
Widget _buildMeasureSlider(MetronomeProvider provider) {
  // TODO: Need to determine max measures
  // Option 1: User-defined in song settings
  // Option 2: Auto-calculate from highest beat sync point
  // For now, use placeholder max of 100
  final maxMeasures = 100; // TODO: Make this dynamic

  return Padding(
    padding: EdgeInsets.symmetric(horizontal: 8),
    child: Row(
      children: [
        Text(
          'M: ${provider.currentMeasure}',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
        Expanded(
          child: Slider(
            value: provider.currentMeasure.toDouble(),
            min: 1,
            max: maxMeasures.toDouble(),
            divisions: maxMeasures - 1,
            onChanged: (value) {
              provider.seekToMeasure(value.toInt());
            },
          ),
        ),
        Text(
          '/ $maxMeasures',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    ),
  );
}
```

### 3.3 Update Main Layout to Show Beat Overlay
**File:** `lib/main.dart`

In the video overlay section (around line 675), wrap with conditional:
```dart
// Video player overlay OR Beat overlay (depending on mode)
Builder(
  builder: (context) {
    final metronomeProvider = context.watch<MetronomeProvider>();
    final isBeatMode = metronomeProvider.settings.mode == MetronomeMode.beat;

    if (isBeatMode) {
      // Show Beat Overlay instead of video
      return Positioned(
        left: currentX,
        top: currentY,
        width: overlayWidth,
        height: overlayHeight,
        child: GestureDetector(
          // Same drag behavior as video overlay
          onPanStart: (details) { /* ... */ },
          onPanUpdate: (details) { /* ... */ },
          onPanEnd: (details) { /* ... */ },
          onDoubleTap: () { /* ... */ },
          child: Container(
            decoration: BoxDecoration(/* same as video overlay */),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  const BeatOverlay(),
                  // Drag indicator in top-right
                  Positioned(
                    top: 4,
                    right: 4,
                    child: /* drag indicator */,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      // Existing video overlay code
      return Positioned(/* existing video overlay */);
    }
  },
),
```

---

## Phase 4: Sync Points Bar for Beat Mode

### 4.1 Extend SyncPointsBar Widget
**File:** `lib/widgets/sync_points_bar.dart`

- Detect current mode in `_createSyncPoint()`:
```dart
void _createSyncPoint(BuildContext context, DrawnRectangle rectangle) {
  final videoProvider = context.read<VideoProvider>();
  final metronomeProvider = context.read<MetronomeProvider>();
  final rectangleProvider = context.read<RectangleProvider>();

  final isBeatMode = metronomeProvider.settings.mode == MetronomeMode.beat;

  if (isBeatMode) {
    // Beat Mode: Create beat sync point
    if (!metronomeProvider.settings.isEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enable metronome to create beat sync points'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final currentBeat = metronomeProvider.totalBeats;

    // Check for duplicate
    if (rectangle.beatNumbers.contains(currentBeat)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Beat sync point already exists at beat $currentBeat'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Add beat number
    rectangle.addBeatNumber(currentBeat);
    rectangleProvider.updateRectangleTimestamps();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Beat sync point added at beat $currentBeat'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  } else {
    // Video Mode: Existing timestamp logic
    if (!videoProvider.isPlayerReady) {
      // ... existing code
    }
    // ... rest of existing code
  }
}
```

### 4.2 Update Badge Display
**File:** `lib/widgets/sync_points_bar.dart`

- Modify the ListView builder to show different badges based on mode:
```dart
Expanded(
  child: Consumer<MetronomeProvider>(
    builder: (context, metronomeProvider, _) {
      final isBeatMode = metronomeProvider.settings.mode == MetronomeMode.beat;
      final syncPoints = isBeatMode
        ? selectedRectangle.beatNumbers
        : selectedRectangle.timestamps;

      if (syncPoints.isEmpty) {
        return const Center(
          child: Text(
            'No sync points',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        );
      }

      return ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: syncPoints.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (isBeatMode) {
            final beat = syncPoints[index] as int;
            return _buildBeatBadge(beat, selectedRectangle, rectangleProvider);
          } else {
            final timestamp = syncPoints[index] as Duration;
            return _buildTimestampBadge(timestamp, selectedRectangle, rectangleProvider);
          }
        },
      );
    },
  ),
)
```

- Create badge builders:
```dart
Widget _buildBeatBadge(int beat, DrawnRectangle rectangle, RectangleProvider provider) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.blue.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.blue.withValues(alpha: 0.6),
        width: 1,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'B: $beat',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => _deleteBeatSyncPoint(context, rectangle, beat),
          child: Icon(
            Icons.close,
            size: 16,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    ),
  );
}

Widget _buildTimestampBadge(Duration timestamp, DrawnRectangle rectangle, RectangleProvider provider) {
  // Existing timestamp badge code (change to green)
  return Container(
    // ... existing code but with green color instead of current color
    decoration: BoxDecoration(
      color: Colors.green.withValues(alpha: 0.3),
      border: Border.all(
        color: Colors.green.withValues(alpha: 0.6),
      ),
    ),
    // ... rest of existing badge
  );
}
```

- Add delete method for beat sync points:
```dart
void _deleteBeatSyncPoint(BuildContext context, DrawnRectangle rectangle, int beat) {
  final rectangleProvider = context.read<RectangleProvider>();

  rectangle.removeBeatNumber(beat);
  rectangleProvider.updateRectangleTimestamps();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Beat sync point removed: $beat'),
      backgroundColor: Colors.grey,
      duration: const Duration(seconds: 1),
    ),
  );
}
```

---

## Phase 5: Beat-Based Rectangle Highlighting (UPDATED)

### 5.1 Extend TimestampTree for Beat Numbers
**File:** `lib/utils/timestamp_tree.dart`

**Recommended: Generic Implementation**

Refactor `lib/utils/timestamp_tree.dart` to be generic:

```dart
class SyncTree<T extends Comparable<T>> {
  _Node<T>? _root;
  int _size = 0;

  int get size => _size;
  bool get isEmpty => _root == null;

  void insert(T key, String rectangleId, int pageNumber) {
    // ... existing red-black tree insertion logic
    // Replace Duration comparisons with generic compareTo
  }

  SyncPoint<T>? findClosest(T target) {
    // ... existing logic
    // Returns sync point with highest key <= target
  }

  List<SyncPoint<T>> getAllInOrder() {
    // ... existing logic
  }

  void clear() {
    _root = null;
    _size = 0;
  }
}

class SyncPoint<T> {
  final T key;  // Either Duration or int
  final String rectangleId;
  final int pageNumber;

  SyncPoint({
    required this.key,
    required this.rectangleId,
    required this.pageNumber,
  });
}

class _Node<T> {
  T key;
  String rectangleId;
  int pageNumber;
  _Node<T>? left;
  _Node<T>? right;
  _Node<T>? parent;
  bool isRed;

  _Node({
    required this.key,
    required this.rectangleId,
    required this.pageNumber,
    this.isRed = true,
  });
}
```

### 5.2 Update SyncProvider for Generic Tree
**File:** `lib/providers/sync_provider.dart`

```dart
class SyncProvider extends ChangeNotifier {
  final SyncTree<Duration> _timestampTree = SyncTree<Duration>();
  SyncPoint<Duration>? _activeSyncPoint;

  // ... rest of existing code

  void _rebuildSyncPoints() {
    _timestampTree.clear();

    final allRectangles = _rectangleProvider!.allRectangles;

    for (final rectangle in allRectangles) {
      for (final timestamp in rectangle.timestamps) {
        _timestampTree.insert(
          timestamp,
          rectangle.id,
          rectangle.pageNumber,
        );
      }
    }

    developer.log('Sync: Tree rebuilt with ${_timestampTree.size} sync points');
  }

  void _onVideoPositionChanged() {
    // Check mode
    if (_metronomeProvider?.settings.mode == MetronomeMode.beat) {
      return; // Don't process video position in beat mode
    }

    if (_appModeProvider?.isDesignMode ?? true) {
      return;
    }

    final currentPosition = _videoProvider!.currentPosition;
    final syncPoint = _timestampTree.findClosest(currentPosition);

    // ... rest of existing highlighting logic
  }
}
```

### 5.3 Create BeatSyncProvider with Beat Tree
**New File:** `lib/providers/beat_sync_provider.dart`

```dart
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../utils/timestamp_tree.dart';
import '../models/metronome_settings.dart';
import 'rectangle_provider.dart';
import 'metronome_provider.dart';
import 'score_provider.dart';
import 'app_mode_provider.dart';

class BeatSyncProvider extends ChangeNotifier {
  final SyncTree<int> _beatTree = SyncTree<int>();
  SyncPoint<int>? _activeSyncPoint;

  // Dependencies
  RectangleProvider? _rectangleProvider;
  MetronomeProvider? _metronomeProvider;
  ScoreProvider? _scoreProvider;
  AppModeProvider? _appModeProvider;

  String? get activeRectangleId => _activeSyncPoint?.rectangleId;

  void setDependencies(
    RectangleProvider rectangleProvider,
    MetronomeProvider metronomeProvider,
    ScoreProvider scoreProvider,
    AppModeProvider appModeProvider,
  ) {
    _rectangleProvider = rectangleProvider;
    _metronomeProvider = metronomeProvider;
    _scoreProvider = scoreProvider;
    _appModeProvider = appModeProvider;

    // Listen to metronome beats
    _metronomeProvider!.setOnBeatCallback(_onBeatChanged);

    // Rebuild tree when rectangles change
    _rectangleProvider!.addListener(_rebuildBeatTree);

    // Listen to app mode changes
    _appModeProvider!.addListener(_onAppModeChanged);

    _rebuildBeatTree();
  }

  @override
  void dispose() {
    _metronomeProvider?.setOnBeatCallback(null);
    _rectangleProvider?.removeListener(_rebuildBeatTree);
    _appModeProvider?.removeListener(_onAppModeChanged);
    super.dispose();
  }

  /// Rebuild beat tree from all rectangles with beat numbers
  void _rebuildBeatTree() {
    if (_rectangleProvider == null) return;

    final allRectangles = _rectangleProvider!.allRectangles;

    // Check if we need to rebuild
    final currentSyncCount = _beatTree.size;
    int expectedSyncCount = 0;
    for (final rectangle in allRectangles) {
      expectedSyncCount += rectangle.beatNumbers.length;
    }

    if (currentSyncCount == expectedSyncCount) {
      developer.log('BeatSync: Skipping rebuild - sync count unchanged ($currentSyncCount)');
      return;
    }

    _beatTree.clear();
    developer.log('BeatSync: Building tree from ${allRectangles.length} rectangles');

    for (final rectangle in allRectangles) {
      for (final beat in rectangle.beatNumbers) {
        _beatTree.insert(
          beat,
          rectangle.id,
          rectangle.pageNumber,
        );
      }
    }

    developer.log('BeatSync: Tree rebuilt with ${_beatTree.size} beat sync points');
  }

  /// Called on every metronome beat
  void _onBeatChanged(int totalBeat) {
    // Don't highlight in design mode
    if (_appModeProvider?.isDesignMode ?? true) {
      return;
    }

    // Only active in beat mode
    if (_metronomeProvider?.settings.mode != MetronomeMode.beat) {
      return;
    }

    // Find closest beat sync point with beat number <= currentBeat
    final syncPoint = _beatTree.findClosest(totalBeat);

    if (syncPoint != null) {
      // Check if we need to update (avoid redundant updates)
      if (_activeSyncPoint?.rectangleId != syncPoint.rectangleId ||
          _activeSyncPoint?.key != syncPoint.key) {
        _activeSyncPoint = syncPoint;

        developer.log(
          'BeatSync: Found sync point at beat ${syncPoint.key} '
          '(current beat: $totalBeat) -> rectangle ${syncPoint.rectangleId} '
          'on page ${syncPoint.pageNumber}'
        );

        // Navigate to page if different
        if (_scoreProvider?.currentPageNumber != syncPoint.pageNumber) {
          developer.log('BeatSync: Navigating to page ${syncPoint.pageNumber}');
          _scoreProvider?.setCurrentPage(syncPoint.pageNumber);
        }

        notifyListeners();
      }
    } else {
      // No sync point found, clear active
      if (_activeSyncPoint != null) {
        developer.log('BeatSync: No sync point at beat $totalBeat, clearing active');
        _activeSyncPoint = null;
        notifyListeners();
      }
    }
  }

  void _onAppModeChanged() {
    // Clear active sync point when switching to design mode
    if (_appModeProvider?.isDesignMode ?? false) {
      if (_activeSyncPoint != null) {
        _activeSyncPoint = null;
        notifyListeners();
      }
    }
  }

  void clearActiveSyncPoint() {
    if (_activeSyncPoint != null) {
      _activeSyncPoint = null;
      notifyListeners();
    }
  }
}
```

### 5.4 Update RectanglePainter for Beat Sync
**File:** `lib/widgets/score_viewer/rectangle_painter.dart`

Update constructor to accept both sync providers:

```dart
class RectanglePainter extends CustomPainter {
  final List<DrawnRectangle> rectangles;
  final DrawnRectangle? currentDrawing;
  final Size pdfPageSize;
  final Size widgetSize;
  final bool isDesignMode;
  final String? activeRectangleId;  // From video sync
  final String? activeBeatRectangleId;  // From beat sync

  RectanglePainter({
    required this.rectangles,
    this.currentDrawing,
    required this.pdfPageSize,
    required this.widgetSize,
    required this.isDesignMode,
    this.activeRectangleId,
    this.activeBeatRectangleId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate scaling
    final scaleX = widgetSize.width / pdfPageSize.width;
    final scaleY = widgetSize.height / pdfPageSize.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final offsetX = (widgetSize.width - pdfPageSize.width * scale) / 2;
    final offsetY = (widgetSize.height - pdfPageSize.height * scale) / 2;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);

    for (final rectangle in rectangles) {
      Color rectColor = rectangle.color;

      // In playback mode, check for active sync
      if (!isDesignMode) {
        // Video sync highlighting (yellow)
        if (activeRectangleId != null && rectangle.id == activeRectangleId) {
          rectColor = Colors.yellow;
        }
        // Beat sync highlighting (orange) - takes precedence
        else if (activeBeatRectangleId != null && rectangle.id == activeBeatRectangleId) {
          rectColor = Colors.orange;
        }
      }

      // Draw rectangle with determined color
      _drawRectangle(canvas, rectangle, rectColor);

      // ... rest of drawing logic (handles, badges, etc.)
    }

    canvas.restore();
  }

  // ... rest of class
}
```

### 5.5 Update InteractiveRectangleOverlay
**File:** `lib/widgets/score_viewer/rectangle_overlay.dart`

Update to pass both active rectangle IDs to painter:

```dart
@override
Widget build(BuildContext context) {
  return Consumer4<RectangleProvider, AppModeProvider, UiStateProvider, BeatSyncProvider>(
    builder: (context, rectangleProvider, appModeProvider, uiStateProvider, beatSyncProvider, _) {
      final isDesignMode = appModeProvider.isDesignMode;
      final isVideoDragging = uiStateProvider.isVideoDragging;
      final rectangles = rectangleProvider.getRectanglesForPage(widget.currentPageNumber);

      return LayoutBuilder(
        builder: (context, constraints) {
          _widgetSize = constraints.biggest;

          return MouseRegion(
            cursor: isDesignMode
                ? SystemMouseCursors.precise
                : SystemMouseCursors.basic,
            child: GestureDetector(
              // ... gesture handlers
              child: Stack(
                children: [
                  widget.child,
                  Positioned.fill(
                    child: CustomPaint(
                      painter: RectanglePainter(
                        rectangles: rectangles,
                        currentDrawing: rectangleProvider.currentDrawing,
                        pdfPageSize: widget.pdfPageSize,
                        widgetSize: _widgetSize!,
                        isDesignMode: isDesignMode,
                        activeRectangleId: rectangleProvider.activeRectangleId,
                        activeBeatRectangleId: beatSyncProvider.activeRectangleId,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
```

### 5.6 Update Main to Initialize BeatSyncProvider
**File:** `lib/main.dart`

Add to MultiProvider:
```dart
ChangeNotifierProvider(create: (_) => BeatSyncProvider()),
```

Initialize dependencies in `_MainScreenState`:
```dart
// After other provider dependencies are set
final beatSyncProvider = context.read<BeatSyncProvider>();
beatSyncProvider.setDependencies(
  rectangleProvider,
  metronomeProvider,
  scoreProvider,
  appModeProvider,
);
```

---

## Phase 6: Mode Switching & Persistence

### 6.1 Handle Mode Transitions
**File:** `lib/providers/metronome_provider.dart`

- Update `updateSettings()` to handle mode changes:
```dart
void updateSettings(MetronomeSettings newSettings) {
  final oldMode = _settings.mode;
  final newMode = newSettings.mode;

  // ... existing code

  _settings = newSettings;

  // If mode changed, clear active sync points
  if (oldMode != newMode) {
    developer.log('Metronome mode changed: $oldMode -> $newMode');
    // Notify mode change listeners
    notifyListeners();
  }

  // ... rest of existing code
}
```

### 6.2 Update Song Model for Mode Persistence
**File:** `lib/models/song.dart`

- No changes needed - mode is already stored in `MetronomeSettings` which is part of `Song`
- Beat numbers are stored in rectangles (already updated in Phase 1.2)

### 6.3 Ensure Data Integrity
- Rectangles retain BOTH video timestamps AND beat numbers
- Only the active mode determines which sync system is used
- Switching modes doesn't delete any sync point data
- When loading a song, mode preference is restored from `MetronomeSettings`

---

## Phase 7: Edge Cases & Polish

### 7.1 Handle Edge Cases

**Beat Mode with metronome disabled:**
- Show message in beat overlay: "Enable metronome to use Beat Mode"
- Disable sync point creation in sync bar

**Beat Mode in design mode:**
- Allow beat sync point creation even when metronome not playing
- Show current beat as 0 or last played beat
- Consider showing "Start metronome to see live beats" hint

**Rectangle with both video and beat sync points:**
- Show both badge types in sync points bar
- Green badges for video timestamps: "00:15"
- Blue badges for beat numbers: "B: 24"
- Allow deleting individual sync points of either type

**Total measures calculation:**
- Option 1: Add `int? totalMeasures` to Song model (user-defined)
- Option 2: Auto-calculate from highest beat sync point: `maxBeat / beatsPerMeasure`
- Recommend: Use highest beat sync point as default, allow manual override in song settings

### 7.2 Testing Considerations

**Beat Tracking Tests:**
- Start metronome and verify tick callback fires
- Verify `_totalBeats` increments correctly
- Verify `_currentBeat` cycles through 1 to timeSignature.numerator
- Verify `currentMeasure` calculates correctly
- Test with different time signatures (4/4, 3/4, 6/8, 9/8, 12/8)

**Beat Seeking Tests:**
- Test `seekToMeasure()` resets counters correctly
- Verify metronome continues playing from new position
- Test seeking while stopped vs playing

**Sync Point Tests:**
- Create beat sync points at various beats
- Verify beat sync points persist after stopping/starting
- Verify rectangles can have both video and beat sync points
- Test deleting individual beat sync points

**Mode Switching Tests:**
- Switch Video → Beat: Verify video sync points preserved
- Switch Beat → Video: Verify beat sync points preserved
- Test mode switching during playback
- Test mode switching with metronome running

**Highlighting Tests:**
- Verify beat sync highlighting works in playback mode
- Verify correct rectangle highlighted at each beat
- Verify page navigation when beat sync point on different page
- Test with overlapping beat sync points (multiple rectangles at same beat)

**Red-Black Tree Tests:**
- Verify `findClosest()` returns correct rectangle for any beat
- Test with multiple rectangles at different beats
- Test boundary conditions (beat 0, beat before first sync point)
- Verify O(log n) performance with many sync points

---

## Implementation Order

### Priority 1: Core Functionality (Start Here)
1. **Phase 2.1** - Enable tick callback and beat tracking
2. **Phase 1** - Data model changes (mode enum, beat numbers)
3. **Phase 3.2** - Create Beat Overlay widget (basic version without slider)
4. **Phase 3.1** - Add mode selector to settings panel
5. **Phase 3.3** - Conditional display in main layout

### Priority 2: Sync Points
6. **Phase 4.1** - Update sync points bar for beat mode
7. **Phase 4.2** - Badge display for beat numbers
8. **Phase 5.1** - Refactor TimestampTree to generic SyncTree
9. **Phase 5.3** - Create BeatSyncProvider with beat tree
10. **Phase 5.4-5.6** - Integrate beat sync highlighting

### Priority 3: Advanced Features
11. **Phase 2.2** - Add seek-by-measure functionality
12. **Phase 3.2** - Add measure slider to beat overlay (playback mode)
13. **Phase 5.2** - Update SyncProvider for mode awareness

### Priority 4: Polish
14. **Phase 6** - Persistence and mode switching
15. **Phase 7** - Edge cases and testing

---

## Key Design Decisions

1. **Dual-mode rectangles**: Each rectangle can have BOTH video timestamps AND beat numbers. The active mode determines which sync system is used for highlighting.

2. **Independent tracking**: Video position tracking (SyncProvider) and beat tracking (BeatSyncProvider) run independently. Only the active mode's highlighting is applied.

3. **Red-black tree for beat lookup**: Using the same efficient O(log n) data structure for beat mode as video mode. The tree finds the rectangle with the highest beat number ≤ current beat.

4. **Generic SyncTree**: Refactoring the existing TimestampTree to be generic `SyncTree<T>` allows both `Duration` (video) and `int` (beat) keys without code duplication.

5. **Beat counter persistence**: When metronome stops, beat counter resets to 0. When restarted, counting begins from 0 again. This is different from video which maintains its position.

6. **Measure seeking**: In playback mode, users can seek by measures. This resets the beat counter to the first beat of the target measure and continues from there.

7. **UI consistency**: Beat overlay matches video overlay in size, position, and draggability for a consistent user experience.

8. **Color coding**:
   - Video sync: Green badges, yellow highlight
   - Beat sync: Blue badges, orange highlight

9. **Total measures**: Auto-calculate from highest beat sync point, with option to manually override in future if needed.

## Example Behavior

If rectangles have beat sync points at beats: 8, 16, 24, 32

- Beat 1-7: No highlighting
- Beat 8-15: Rectangle at beat 8 highlighted (orange)
- Beat 16-23: Rectangle at beat 16 highlighted (orange)
- Beat 24-31: Rectangle at beat 24 highlighted (orange)
- Beat 32+: Rectangle at beat 32 highlighted (orange)

This matches exactly how video mode works with timestamps, using efficient red-black tree lookup!