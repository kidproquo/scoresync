# Loop Feature Implementation Plan

## Overview
Implement a looping feature that allows users to mark sync points as loop start/end points and continuously play between them.

## 1. Data Model Updates

### MetronomeProvider (Beat Mode)
```dart
class MetronomeProvider {
  int? loopStartBeat;
  int? loopEndBeat;
  bool isLoopActive = false;
  String? loopStartRectangleId;
  String? loopEndRectangleId;
}
```

### VideoProvider (Video Mode)
```dart
class VideoProvider {
  Duration? loopStartTime;
  Duration? loopEndTime;
  bool isLoopActive = false;
  String? loopStartRectangleId;
  String? loopEndRectangleId;
}
```

## 2. Sync Point Menu Enhancement

### Menu Items to Add
- **"Set as Loop Start"** - Mark this sync point as loop beginning
- **"Set as Loop End"** - Mark this sync point as loop ending
- **"Clear Loop Start"** - Remove loop start marker (if this is current start)
- **"Clear Loop End"** - Remove loop end marker (if this is current end)
- Show indicator if sync point is already a loop marker

### Menu Logic
```dart
// In _showBeatSyncMenu and _showTimestampSyncMenu
PopupMenuItem(
  value: 'loop_start',
  child: Row(
    children: [
      Icon(Icons.flag_outlined, size: 20, color: Colors.green),
      SizedBox(width: 8),
      Text(isLoopStart ? 'Clear Loop Start' : 'Set as Loop Start'),
    ],
  ),
),
PopupMenuItem(
  value: 'loop_end',
  child: Row(
    children: [
      Icon(Icons.flag, size: 20, color: Colors.red),
      SizedBox(width: 8),
      Text(isLoopEnd ? 'Clear Loop End' : 'Set as Loop End'),
    ],
  ),
),
```

## 3. Loop Validation Logic

### Beat Mode Rules
- Loop end beat must be > loop start beat
- Automatically expand to full measures:
  ```dart
  // When setting loop start
  int measureStart = ((beatNumber - 1) ~/ beatsPerMeasure);
  loopStartBeat = measureStart * beatsPerMeasure + 1;

  // When setting loop end
  int measureEnd = ((beatNumber - 1) ~/ beatsPerMeasure) + 1;
  loopEndBeat = measureEnd * beatsPerMeasure;
  ```

### Video Mode Rules
- Loop end time must be > loop start time
- Minimum loop duration: 1 second
- Maximum precision: 10ms

### Validation Function
```dart
bool validateLoop() {
  if (loopStart == null || loopEnd == null) return false;

  if (isBeatMode) {
    return loopEndBeat! > loopStartBeat!;
  } else {
    return loopEndTime! > loopStartTime! &&
           (loopEndTime! - loopStartTime!) >= Duration(seconds: 1);
  }
}
```

## 4. Playback Behavior

### Loop Monitoring
```dart
// In MetronomeProvider._onBeat() for Beat Mode
if (isLoopActive && loopEndBeat != null && totalBeats >= loopEndBeat!) {
  // Include count-in if enabled
  if (settings.countInEnabled) {
    startCountIn().then((_) => seekToBeat(loopStartBeat!));
  } else {
    seekToBeat(loopStartBeat!);
  }
}

// In VideoProvider position update for Video Mode
if (isLoopActive && loopEndTime != null && currentPosition >= loopEndTime!) {
  seekTo(loopStartTime!);
  play();
}
```

### Stop Button Behavior
```dart
// When loop is active, stop seeks to loop start
void stopMetronome() {
  if (isLoopActive && loopStartBeat != null) {
    seekToBeat(loopStartBeat!);
  } else {
    // Normal stop behavior
  }
}
```

## 5. Visual Indicators

### Rectangle Highlighting
```dart
// In RectanglePainter
Color getRectangleColor(DrawnRectangle rectangle) {
  if (rectangle.id == loopStartRectangleId) {
    return Colors.green.withAlpha(100);  // Green tint for start
  } else if (rectangle.id == loopEndRectangleId) {
    return Colors.red.withAlpha(100);    // Red tint for end
  } else if (isActive) {
    return Colors.yellow.withAlpha(80);  // Normal active color
  }
  return rectangle.color;
}
```

### Overlay Indicators
```dart
// In BeatOverlay or video overlay
if (provider.isLoopActive) {
  Container(
    padding: EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.blue.withAlpha(50),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.repeat, color: Colors.blue, size: 16),
        SizedBox(width: 4),
        Text(
          isBeatMode
            ? 'Loop: M${startMeasure}-M${endMeasure}'
            : 'Loop: ${formatTime(start)}-${formatTime(end)}',
          style: TextStyle(color: Colors.blue, fontSize: 12),
        ),
      ],
    ),
  )
}
```

## 6. UI/UX Enhancements

### Sync Points Bar Badge Styling
```dart
// Different styling for loop markers
BoxDecoration getDecoration(bool isLoopStart, bool isLoopEnd) {
  Color bgColor;
  Color borderColor;

  if (isLoopStart) {
    bgColor = Colors.green.withAlpha(50);
    borderColor = Colors.green;
  } else if (isLoopEnd) {
    bgColor = Colors.red.withAlpha(50);
    borderColor = Colors.red;
  } else {
    // Normal badge colors
  }

  return BoxDecoration(
    color: bgColor,
    border: Border.all(color: borderColor),
    borderRadius: BorderRadius.circular(16),
  );
}
```

### Loop Toggle Button
```dart
// Add to transport controls
IconButton(
  icon: Icon(
    provider.isLoopActive ? Icons.repeat_on : Icons.repeat,
    color: provider.isLoopActive ? Colors.blue : Colors.white,
  ),
  onPressed: provider.canLoop ? () => provider.toggleLoop() : null,
  tooltip: 'Toggle Loop',
)
```

## 7. Edge Cases

### Sync Point Deletion
- If deleting loop start/end point, clear the loop
- Show warning dialog before deletion

### Sync Point Editing
- If editing changes order (end becomes < start), clear loop
- Validate after edit and show appropriate message

### Mode Switching
- Clear loop when switching between Beat/Video modes
- Each mode maintains its own loop state

### Page Turns
- Continue loop even if it spans multiple pages
- Auto-turn pages as needed during loop playback

## 8. Implementation Order

1. **Phase 1: Core Loop State**
   - Add loop properties to providers
   - Add loop validation functions
   - Update menu with loop options

2. **Phase 2: Loop Playback**
   - Implement loop monitoring in beat/position callbacks
   - Update stop behavior for loop mode
   - Handle count-in with loops

3. **Phase 3: Visual Feedback**
   - Update rectangle colors for loop markers
   - Add overlay indicators
   - Style sync point badges

4. **Phase 4: Controls & Polish**
   - Add loop toggle button
   - Handle edge cases
   - Add animations for loop transitions

## 9. Testing Scenarios

- Set loop across measures in Beat Mode
- Set loop with count-in enabled
- Delete/edit loop markers
- Loop with very short duration in Video Mode
- Loop spanning multiple pages
- Switch modes with active loop
- Save/load songs with loop markers

## 10. Future Enhancements

- Loop count (repeat X times then continue)
- Speed ramping within loop
- A/B comparison loops
- Loop presets/bookmarks
- Export loop as separate file