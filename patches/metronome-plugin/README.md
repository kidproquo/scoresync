# Metronome Plugin Patch

This directory contains a patched version of the `metronome` plugin (v2.0.6) that fixes the Android-specific timing issue.

## Issue

The original Android implementation has a timing discrepancy compared to iOS:
- **Android**: Metronome plays audio immediately when `play()` is called, but the first tick callback comes later
- **iOS**: Metronome waits for the first tick before playing, so audio and tick events are synchronized

This causes a 1-beat offset on Android where the visual beat display doesn't match the audio timing.

## Fix

**File**: `android/src/main/java/com/sumsg/metronome/Metronome.java`

**Change**: Added immediate tick callback in the `play()` method (lines 71-74):

```java
public void play() {
    if (!isPlaying()) {
        updated = true;
        onTick();
        // Send immediate tick event to match iOS behavior
        if (eventTickSink != null) {
            eventTickSink.success(0);  // Send tick 0 immediately
        }
        audioTrack.play();
        startMetronome();
    }
}
```

## Result

- ✅ Android now sends tick 0 immediately when audio starts playing
- ✅ Both platforms have synchronized audio and tick events
- ✅ Beat display aligns with audio timing from the first beat
- ✅ Eliminates weird UI patterns like (1,2,3,1,2,3,4)

## Usage

To apply this patch:

1. Replace the original file in your pub cache:
   ```bash
   cp patches/metronome-plugin/android/src/main/java/com/sumsg/metronome/Metronome.java \
      ~/.pub-cache/hosted/pub.dev/metronome-2.0.6/android/src/main/java/com/sumsg/metronome/
   ```

2. Clean and rebuild your Flutter project:
   ```bash
   flutter clean && flutter pub get
   ```

## Potential PR

This fix could be submitted as a pull request to the original metronome plugin repository to benefit all users experiencing this Android timing issue.

## Original Plugin

- **Plugin**: metronome
- **Version**: 2.0.6
- **Repository**: https://pub.dev/packages/metronome