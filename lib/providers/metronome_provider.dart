import 'package:flutter/material.dart';
import 'package:metronome/metronome.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:developer' as developer;
import '../models/metronome_settings.dart';

class MetronomeProvider extends ChangeNotifier {
  MetronomeSettings _settings = MetronomeSettings();
  late Metronome _metronome;
  late Metronome _countInMetronome;  // Separate instance for count-in
  int _currentBeat = 0;
  bool _isCountingIn = false;
  bool _isPlaying = false;
  bool _isPreviewing = false;
  double _playbackRate = 1.0;
  bool _isInPlaybackMode = false;
  int? _resumeFromBeat; // Track where to resume after count-in

  // Beat tracking for Beat Mode
  StreamSubscription<int>? _tickSubscription;
  int _totalBeats = 0;
  int _absoluteBeatCount = 0; // Track absolute beats across measures
  Function(int beat)? _onBeat;
  Function(int beat)? _onLoopPageCheck;

  // Metronome plugin sends tick events per measure (0,1,2,3 repeating)
  // We need to track absolute beat count ourselves

  // Callbacks (only used during count-in)
  Function(int beat)? _onCountInBeat;


  MetronomeSettings get settings => _settings;
  bool get isPlaying => _isPlaying;
  bool get isCountingIn => _isCountingIn;
  bool get isPreviewing => _isPreviewing;
  int get currentBeat => _currentBeat;
  int get totalBeats => _absoluteBeatCount;
  double get playbackRate => _playbackRate;
  int get effectiveBPM => (_settings.bpm * _playbackRate).round();
  int get currentMeasure {
    final effectiveBeats = totalBeats;
    final measure = effectiveBeats > 0
        ? ((effectiveBeats - 1) ~/ _settings.timeSignature.numerator) + 1
        : 1;

    // Debug logging for measure calculation
    if (effectiveBeats <= 20) {
      developer.log('[MEASURE] effectiveBeats=$effectiveBeats, timeSignature=${_settings.timeSignature.numerator}, calculated measure=$measure');
    }

    return measure;
  }

  // Loop state getters (read from settings)
  int? get loopStartBeat => _settings.loopStartBeat;
  int? get loopEndBeat => _settings.loopEndBeat;
  bool get isLoopActive => _settings.isLoopActive;
  String? get loopStartRectangleId => _settings.loopStartRectangleId;
  String? get loopEndRectangleId => _settings.loopEndRectangleId;
  bool get canLoop => _settings.loopStartBeat != null && _settings.loopEndBeat != null && _settings.loopEndBeat! > _settings.loopStartBeat!;

  MetronomeProvider() {
    _metronome = Metronome();
    _countInMetronome = _metronome;
    _initializeMetronome();
  }

  Future<void> _initializeMetronome() async {
    try {
      await _metronome.init(
        'assets/woodblock_high44_wav.wav',
        accentedPath: 'assets/claves44_wav.wav',
        bpm: _settings.bpm,
        volume: (_settings.volume * 100).round(),
        timeSignature: _settings.timeSignature.numerator,
        enableTickCallback: true,
      );

      developer.log('[${Platform.operatingSystem.toUpperCase()}] Metronome initialized with enableTickCallback=true');
    } catch (e) {
      developer.log('[${Platform.operatingSystem.toUpperCase()}] Error initializing metronome: $e');
    }
  }

  // Helper method to ensure metronome is properly synchronized
  void _synchronizeMetronome() {
    final effectiveBPM = (_settings.bpm * _playbackRate).round();
    _metronome.setBPM(effectiveBPM);
    _metronome.setTimeSignature(_settings.timeSignature.numerator);
    // Volume is set only at initialization and when slider changes, not on every playback
    developer.log('Metronome synchronized: BPM=$effectiveBPM, timeSignature=${_settings.timeSignature.numerator}');
  }

  void updateSettings(MetronomeSettings newSettings) {
    final wasPlaying = isPlaying;
    developer.log('updateSettings called: wasPlaying=$wasPlaying, newEnabled=${newSettings.isEnabled}');

    // Pause preview if running
    _pausePreviewForUpdate();

    if (wasPlaying) {
      stopMetronome();
    }

    // Clear loop when switching modes (already handled in newSettings if needed)

    _settings = newSettings;

    // Update both metronome settings
    final effectiveBPM = (_settings.bpm * _playbackRate).round();
    _metronome.setBPM(effectiveBPM);
    _metronome.setTimeSignature(_settings.timeSignature.numerator);

    // Update count-in metronome as well
    _countInMetronome.setBPM(effectiveBPM);
    _countInMetronome.setTimeSignature(_settings.timeSignature.numerator);

    notifyListeners();

    if (wasPlaying && _settings.isEnabled) {
      developer.log('Restarting metronome after settings update');
      startMetronome();
    }

    // Resume preview if it was running
    _resumePreviewAfterUpdate();

    // Trigger save to song when settings change
    _onSettingsChanged?.call();
  }

  // Callback for when settings change (to save to song)
  Function()? _onSettingsChanged;

  void setOnSettingsChangedCallback(Function()? callback) {
    _onSettingsChanged = callback;
  }

  void toggleEnabled() {
    updateSettings(_settings.copyWith(isEnabled: !_settings.isEnabled));

    // Stop everything when disabled
    if (!_settings.isEnabled) {
      stopMetronome();
      stopPreview();
    }
  }

  void setBPM(int bpm) {
    final clampedBPM = bpm.clamp(40, 240);
    updateSettings(_settings.copyWith(bpm: clampedBPM));
  }

  void setTimeSignature(TimeSignature timeSignature) {
    updateSettings(_settings.copyWith(timeSignature: timeSignature));
  }

  void setVolume(double volume) {
    final clampedVolume = volume.clamp(0.0, 1.0);

    // Immediately update the metronome volume
    _metronome.setVolume((clampedVolume * 100).round());
    _countInMetronome.setVolume((clampedVolume * 100).round());

    updateSettings(_settings.copyWith(volume: clampedVolume));
  }

  void setCountInEnabled(bool enabled) {
    updateSettings(_settings.copyWith(countInEnabled: enabled));
  }

  void setPlaybackRate(double rate) {
    if (_playbackRate != rate) {
      _playbackRate = rate;
      notifyListeners();
      // If metronome is playing, restart with new rate
      if (isPlaying) {
        developer.log('Playback rate changed to $rate, restarting metronome');
        startMetronome();
      }
    }
  }

  void startMetronome({bool isSeeking = false, bool isPlaybackMode = false}) {
    final isBeatMode = _settings.mode == MetronomeMode.beat;
    _isInPlaybackMode = isPlaybackMode;

    // Only check isEnabled in Video mode; Beat mode can always start
    if (!_settings.isEnabled && !isBeatMode) return;

    final isResuming = _absoluteBeatCount > 0 && !isSeeking;

    // Save the current measure BEFORE modifying counters for resume logic
    final resumeMeasure = isResuming ? currentMeasure : 1;

    if (isResuming) {
      final beatsPerMeasure = _settings.timeSignature.numerator;
      final currentMeasureStartBeat = ((resumeMeasure - 1) * beatsPerMeasure) + 1;
      _totalBeats = currentMeasureStartBeat - 1;
      _absoluteBeatCount = currentMeasureStartBeat - 1; // Keep absolute count in sync
      _currentBeat = 0;
      developer.log('Resuming from start of measure $resumeMeasure (totalBeats reset to $_totalBeats, absoluteBeatCount reset to $_absoluteBeatCount)');
    }

    // If Beat Mode, playback mode, and count-in enabled, start with count-in
    if (isBeatMode && _isInPlaybackMode && _settings.countInEnabled) {
      // If resuming, save the position to resume from after count-in
      if (isResuming) {
        // Calculate the start of the measure where we paused
        final beatsPerMeasure = _settings.timeSignature.numerator;
        final currentMeasureStartBeat = ((resumeMeasure - 1) * beatsPerMeasure) + 1;
        // We want to resume at beat 1 of this measure, so back up by 1 since tick will increment
        _resumeFromBeat = currentMeasureStartBeat - 1;
        developer.log('Count-in resume: paused at measure $resumeMeasure, will resume from beat $currentMeasureStartBeat (backed up to $_resumeFromBeat)');
      } else {
        _resumeFromBeat = null; // Start fresh
      }
      _startWithCountIn();
      return;
    }

    _cleanStopForRestart();

    final effectiveBPM = (_settings.bpm * _playbackRate).round();

    developer.log('[${Platform.operatingSystem.toUpperCase()}] ${isResuming ? "Resuming" : "Starting"} metronome: BPM=${_settings.bpm}, playbackRate=$_playbackRate, effectiveBPM=$effectiveBPM, timeSignature=${_settings.timeSignature.displayString}, totalBeats=$_totalBeats');

    // Synchronize metronome settings and ensure clean start
    _synchronizeMetronome();

    // Don't set _currentBeat here - let the first tick handle it
    developer.log('[${Platform.operatingSystem.toUpperCase()}] About to start tick subscription with totalBeats=$_totalBeats, currentBeat=$_currentBeat');

    _tickSubscription?.cancel();
    _tickSubscription = _metronome.tickStream.listen(
      (int tick) {
        developer.log('[${Platform.operatingSystem.toUpperCase()}] Raw tick received: $tick, _isCountingIn: $_isCountingIn');
        if (!_isCountingIn) {
          // Increment absolute beat count on every tick
          _absoluteBeatCount++;

          // Calculate current beat within measure from tick (0-based from plugin)
          _currentBeat = (tick % _settings.timeSignature.numerator) + 1;

          _onBeat?.call(_absoluteBeatCount);

          // Only log every beat or first few beats to avoid spam
          if (_absoluteBeatCount <= 10 || _currentBeat == 1) {
            developer.log('[${Platform.operatingSystem.toUpperCase()}] Tick: absoluteBeats=$_absoluteBeatCount, currentBeat=$_currentBeat, measure=$currentMeasure (raw tick: $tick)');
          }

          notifyListeners();

          // Check for loop end in Beat Mode - stop after first beat of next measure, wait 3s, then restart
          if (_settings.isLoopActive && _settings.loopEndBeat != null && _absoluteBeatCount > _settings.loopEndBeat!) {
            developer.log('[${Platform.operatingSystem.toUpperCase()}] Loop end reached at beat $_absoluteBeatCount, stopping for 3-second pause before restart');

            // Stop the metronome
            pauseMetronome();

            // Check if we need to change pages for loop start
            if (_settings.loopStartBeat != null) {
              _onLoopPageCheck?.call(_settings.loopStartBeat!);
            }

            // Wait 3 seconds, then restart from loop start
            Future.delayed(const Duration(seconds: 3), () {
              if (_settings.isLoopActive && _settings.loopStartBeat != null) {
                developer.log('[${Platform.operatingSystem.toUpperCase()}] 3-second pause complete, restarting loop from beat ${_settings.loopStartBeat}');

                // Set beat position to one before loop start so first tick lands on loop start
                final targetBeat = _settings.loopStartBeat!;
                _totalBeats = targetBeat > 0 ? targetBeat - 1 : 0;
                _absoluteBeatCount = targetBeat > 0 ? targetBeat - 1 : 0; // Keep absolute count in sync
                _currentBeat = 0;
                notifyListeners();

                // Include count-in if enabled and in playback mode
                if (_settings.countInEnabled && _isInPlaybackMode) {
                  _startWithCountIn();
                } else {
                  startMetronome(isSeeking: true, isPlaybackMode: _isInPlaybackMode);
                }
              }
            });
          }
        }
        notifyListeners();
      },
    );

    _metronome.play();
    _isPlaying = true;
    notifyListeners();

    developer.log('[${Platform.operatingSystem.toUpperCase()}] Metronome ${isResuming ? "resumed" : "started"} at $effectiveBPM effective BPM (beat $_currentBeat of measure $currentMeasure)');
  }

  void _startWithCountIn() {
    _cleanStopForRestart();

    _isCountingIn = true;
    _isPlaying = true;
    _currentBeat = 0;
    notifyListeners();

    final effectiveBPM = (_settings.bpm * _playbackRate).round();
    final beatsPerMeasure = _settings.timeSignature.numerator;

    developer.log('Starting count-in for $beatsPerMeasure beats at $effectiveBPM BPM');

    // Synchronize metronome settings for count-in
    _synchronizeMetronome();

    int countInBeatsPlayed = 0;
    bool countInComplete = false;

    _tickSubscription?.cancel();
    _tickSubscription = _metronome.tickStream.listen(
      (int tick) {
        developer.log('[${Platform.operatingSystem.toUpperCase()}] Count-in raw tick: $tick, _isCountingIn: $_isCountingIn, countInComplete: $countInComplete');
        if (_isCountingIn && !countInComplete) {
          // Count-in beats from plugin tick (0-based)
          countInBeatsPlayed = tick + 1;
          _currentBeat = countInBeatsPlayed;
          notifyListeners();
          developer.log('[${Platform.operatingSystem.toUpperCase()}] Count-in beat: $countInBeatsPlayed/$beatsPerMeasure (raw tick: $tick)');

          if (countInBeatsPlayed >= beatsPerMeasure) {
            // Mark count-in as complete, but don't exit yet
            countInComplete = true;
            developer.log('Count-in measure complete, will exit on next tick');
          }
        } else if (_isCountingIn && countInComplete) {
          // Exit count-in mode now - this tick IS the first beat of main playback
          _isCountingIn = false;

          // Resume from saved position or start from beat 1
          // The first tick after count-in should increment from the saved position
          _absoluteBeatCount = (_resumeFromBeat ?? 0) + 1;
          _currentBeat = (tick % _settings.timeSignature.numerator) + 1;
          _onBeat?.call(_absoluteBeatCount);
          developer.log('[${Platform.operatingSystem.toUpperCase()}] Exited count-in, starting normal playback on beat $_currentBeat (absolute beats: $_absoluteBeatCount, resumeFromBeat: $_resumeFromBeat, raw tick: $tick)');
          _resumeFromBeat = null; // Clear after use
          notifyListeners();
        } else {
          // Normal playback within count-in method
          _absoluteBeatCount++;
          _currentBeat = (tick % _settings.timeSignature.numerator) + 1;
          _onBeat?.call(_absoluteBeatCount);
          // Only log every beat or first few beats to avoid spam
          if (_absoluteBeatCount <= 10 || _currentBeat == 1) {
            developer.log('[${Platform.operatingSystem.toUpperCase()}] Normal tick: absoluteBeats=$_absoluteBeatCount, currentBeat=$_currentBeat, measure=$currentMeasure (raw tick: $tick)');
          }

          notifyListeners();

          // Check for loop end in Beat Mode (also needed in count-in method) - stop after first beat of next measure, wait 3s, then restart
          if (_settings.isLoopActive && _settings.loopEndBeat != null && _totalBeats > _settings.loopEndBeat!) {
            developer.log('Loop end reached at beat $_totalBeats, stopping for 3-second pause before restart');

            // Stop the metronome
            pauseMetronome();

            // Check if we need to change pages for loop start
            if (_settings.loopStartBeat != null) {
              _onLoopPageCheck?.call(_settings.loopStartBeat!);
            }

            // Wait 3 seconds, then restart from loop start
            Future.delayed(const Duration(seconds: 3), () {
              if (_settings.isLoopActive && _settings.loopStartBeat != null) {
                developer.log('3-second pause complete, restarting loop from beat ${_settings.loopStartBeat}');

                // Set beat position to one before loop start so first tick lands on loop start
                final targetBeat = _settings.loopStartBeat!;
                _totalBeats = targetBeat > 0 ? targetBeat - 1 : 0;
                _absoluteBeatCount = targetBeat > 0 ? targetBeat - 1 : 0; // Keep absolute count in sync
                _currentBeat = 0;
                notifyListeners();

                // Include count-in if enabled and in playback mode
                if (_settings.countInEnabled && _isInPlaybackMode) {
                  _startWithCountIn();
                } else {
                  startMetronome(isSeeking: true, isPlaybackMode: _isInPlaybackMode);
                }
              }
            });
          }

          notifyListeners();
        }
      },
    );

    _metronome.play();
    notifyListeners();

    developer.log('Count-in started');
  }

  void pauseMetronome() {
    _metronome.pause();
    _countInMetronome.pause();
    _isPlaying = false;
    _isPreviewing = false;
    _isCountingIn = false;

    // Pause preserves position - no seeking to loop start

    notifyListeners();

    developer.log('Metronome paused (beat counter preserved: $_totalBeats)');
  }

  void _cleanStopForRestart() {
    // Stop metronome cleanly for restart without seeking to loop start
    _metronome.pause();
    _countInMetronome.pause();
    _isPlaying = false;
    _isPreviewing = false;
    _isCountingIn = false;

    // Important: Also stop the metronome internally to reset timing
    _metronome.stop();

    notifyListeners();

    developer.log('Metronome cleanly stopped for restart (beat counter preserved: $_totalBeats)');
  }

  void stopMetronome() {
    _metronome.pause();
    _countInMetronome.pause();
    _isPlaying = false;
    _isPreviewing = false;
    _isCountingIn = false;

    // When loop is active, stop seeks to loop start
    if (_settings.isLoopActive && _settings.loopStartBeat != null) {
      developer.log('Loop active - seeking to loop start beat ${_settings.loopStartBeat} on stop');
      seekToBeat(_settings.loopStartBeat!);
    }

    notifyListeners();

    developer.log('Metronome stopped (beat counter preserved: $_totalBeats)');
  }

  void resetMetronome() {
    _tickSubscription?.cancel();
    _tickSubscription = null;
    _metronome.stop();
    _countInMetronome.stop();
    _isPlaying = false;
    _isPreviewing = false;
    _currentBeat = 0;
    _totalBeats = 0;
    _absoluteBeatCount = 0;
    _isCountingIn = false;

    // Synchronize metronome to ensure clean state for next start
    _synchronizeMetronome();

    notifyListeners();

    developer.log('[${Platform.operatingSystem.toUpperCase()}] Metronome stopped, beat counter reset to $_totalBeats, metronome synchronized');
  }

  Future<void> startCountIn() async {
    if (!_settings.countInEnabled) {
      return;
    }

    developer.log('Starting count-in sequence...');

    _isCountingIn = true;
    _currentBeat = 0;
    notifyListeners();

    // Apply playback rate to count-in as well
    final effectiveBPM = (_settings.bpm * _playbackRate).round();
    final totalBeats = _settings.timeSignature.numerator;
    final beatDuration = Duration(milliseconds: (60000 / effectiveBPM).round());

    developer.log('Setting up count-in for $totalBeats beats at $effectiveBPM BPM (${beatDuration.inMilliseconds}ms per beat)');

    // Configure count-in metronome with same settings
    _countInMetronome.setBPM(effectiveBPM);
    _countInMetronome.setTimeSignature(_settings.timeSignature.numerator);
    // Volume already set at initialization and when slider changes

    try {
      // Manual count-in with precise timing
      for (int beat = 1; beat <= totalBeats; beat++) {
        if (!_isCountingIn) break; // Allow cancellation

        _currentBeat = beat;
        _onCountInBeat?.call(beat);
        notifyListeners();

        developer.log('Count-in beat: $beat/$totalBeats');

        // Play count-in metronome for this beat
        _countInMetronome.play();
        await Future.delayed(const Duration(milliseconds: 100)); // Brief play
        _countInMetronome.pause();

        // Wait for the rest of the beat
        await Future.delayed(beatDuration - const Duration(milliseconds: 100));
      }

      // Count-in completed, but we're now AT the first beat of the next measure
      _isCountingIn = false;
      _currentBeat = 0;
      notifyListeners();

      developer.log('Count-in completed, starting main metronome and video on first beat of next measure');

      // Start the main metronome - this is now the first beat of the next measure
      if (_settings.isEnabled) {
        developer.log('Starting main metronome after count-in...');
        startMetronome();
      }

      // Also trigger the video start callback at this precise moment
      _onCountInBeat?.call(0); // Special signal for "start now"

      developer.log('Count-in completed, main metronome and video started on beat 1');
    } catch (e) {
      developer.log('Error during count-in: $e');
      _isCountingIn = false;
      _currentBeat = 0;
      notifyListeners();
    }
  }

  void setOnCountInBeatCallback(Function(int)? callback) {
    _onCountInBeat = callback;
  }

  void setOnBeatCallback(Function(int)? callback) {
    _onBeat = callback;
  }

  void setOnLoopPageCheckCallback(Function(int)? callback) {
    _onLoopPageCheck = callback;
  }

  void seekToMeasure(int measureNumber) {
    final wasPlaying = _isPlaying;

    if (wasPlaying) {
      _metronome.stop();
      _isPlaying = false;
    }

    final beatsPerMeasure = _settings.timeSignature.numerator;
    final targetBeat = (measureNumber - 1) * beatsPerMeasure;

    _totalBeats = targetBeat;
    _absoluteBeatCount = targetBeat; // Keep absolute count in sync
    _currentBeat = 0;
    developer.log('Seeked to measure $measureNumber (total beat $_totalBeats, absoluteBeatCount=$_absoluteBeatCount)');
    notifyListeners();

    if (wasPlaying) {
      startMetronome(isSeeking: true);
    }
  }

  void seekToBeat(int beatNumber) {
    final wasPlaying = _isPlaying;

    if (wasPlaying) {
      _metronome.stop();
      _isPlaying = false;
    }

    // Set to actual beat number for display
    _totalBeats = beatNumber; // Keep legacy counter in sync
    _absoluteBeatCount = beatNumber;
    _currentBeat = beatNumber == 0 ? 0 : ((beatNumber - 1) % _settings.timeSignature.numerator) + 1;
    developer.log('[${Platform.operatingSystem.toUpperCase()}] Seeked to beat $beatNumber (totalBeats=$_totalBeats, absoluteBeatCount=$_absoluteBeatCount, currentBeat=$_currentBeat)');
    notifyListeners();

    if (wasPlaying) {
      // When resuming, we need to back up one beat so it starts on the target beat
      _totalBeats = beatNumber > 0 ? beatNumber - 1 : 0; // Keep legacy counter in sync
      _absoluteBeatCount = beatNumber > 0 ? beatNumber - 1 : 0;
      _currentBeat = 0;
      developer.log('[${Platform.operatingSystem.toUpperCase()}] Resuming after seek: totalBeats=$_totalBeats, absoluteBeatCount=$_absoluteBeatCount, currentBeat=$_currentBeat');
      startMetronome(isSeeking: true);
    }
  }

  // Toggle preview metronome - continuous play/stop
  void togglePreview() {
    if (_isPreviewing) {
      stopPreview();
    } else {
      startPreview();
    }
  }

  void startPreview() {
    // Preview should work regardless of enabled state - it's just for testing

    // Stop main metronome if playing
    if (_isPlaying) {
      stopMetronome();
    }

    developer.log('Starting metronome preview: ${_settings.bpm} BPM, ${_settings.timeSignature.displayString}');

    // Configure and start metronome for preview (use main metronome)
    _metronome.setBPM(_settings.bpm);
    _metronome.setTimeSignature(_settings.timeSignature.numerator);
    _metronome.setVolume((_settings.volume * 100).round()); // Ensure volume is set for preview

    _metronome.play();
    _isPreviewing = true;
    notifyListeners();

    developer.log('Preview metronome started');
  }

  void stopPreview() {
    if (!_isPreviewing) return;

    _metronome.stop();
    _countInMetronome.stop();  // Also stop count-in if running
    _isPreviewing = false;
    notifyListeners();

    developer.log('Preview metronome stopped');
  }

  // Pause preview temporarily (when settings change)
  void _pausePreviewForUpdate() {
    if (_isPreviewing) {
      _metronome.pause();
    }
  }

  // Resume preview after settings update
  void _resumePreviewAfterUpdate() {
    if (_isPreviewing) {
      // Apply new settings
      _metronome.setBPM(_settings.bpm);
      _metronome.setTimeSignature(_settings.timeSignature.numerator);
      _metronome.setVolume((_settings.volume * 100).round()); // Ensure volume for preview resume
      _metronome.play();
    }
  }

  // Loop management methods
  void setLoopStart(int beatNumber, String rectangleId) {
    final beatsPerMeasure = _settings.timeSignature.numerator;
    final measureStart = ((beatNumber - 1) ~/ beatsPerMeasure);
    final loopStartBeat = measureStart * beatsPerMeasure + 1;

    // Check if end needs to be cleared
    bool shouldClearEnd = _settings.loopEndBeat != null && _settings.loopEndBeat! <= loopStartBeat;

    _settings = _settings.copyWith(
      loopStartBeat: loopStartBeat,
      loopStartRectangleId: rectangleId,
      loopEndBeat: shouldClearEnd ? null : _settings.loopEndBeat,
      loopEndRectangleId: shouldClearEnd ? null : _settings.loopEndRectangleId,
      clearLoopEnd: shouldClearEnd,
    );

    _updateLoopStatus();
    notifyListeners();
    _onSettingsChanged?.call();
  }

  void setLoopEnd(int beatNumber, String rectangleId) {
    final beatsPerMeasure = _settings.timeSignature.numerator;
    final measureEnd = ((beatNumber - 1) ~/ beatsPerMeasure) + 1;
    final loopEndBeat = measureEnd * beatsPerMeasure;

    // Check if start needs to be cleared
    bool shouldClearStart = _settings.loopStartBeat != null && loopEndBeat <= _settings.loopStartBeat!;

    _settings = _settings.copyWith(
      loopEndBeat: loopEndBeat,
      loopEndRectangleId: rectangleId,
      loopStartBeat: shouldClearStart ? null : _settings.loopStartBeat,
      loopStartRectangleId: shouldClearStart ? null : _settings.loopStartRectangleId,
      clearLoopStart: shouldClearStart,
    );

    _updateLoopStatus();
    notifyListeners();
    _onSettingsChanged?.call();
  }

  void clearLoopStart() {
    _settings = _settings.copyWith(
      clearLoopStart: true,
      clearLoopRectangleIds: true,
    );
    _updateLoopStatus();
    notifyListeners();
    _onSettingsChanged?.call();
  }

  void clearLoopEnd() {
    _settings = _settings.copyWith(
      clearLoopEnd: true,
      clearLoopRectangleIds: true,
    );
    _updateLoopStatus();
    notifyListeners();
    _onSettingsChanged?.call();
  }

  void toggleLoop() {
    if (canLoop) {
      _settings = _settings.copyWith(isLoopActive: !_settings.isLoopActive);
      notifyListeners();
      _onSettingsChanged?.call();
    }
  }

  void _updateLoopStatus() {
    final wasActive = _settings.isLoopActive;
    final shouldBeActive = canLoop && _settings.isLoopActive;

    if (wasActive != shouldBeActive) {
      _settings = _settings.copyWith(isLoopActive: shouldBeActive);
      if (wasActive && !shouldBeActive) {
        developer.log('Loop deactivated due to invalid start/end points');
      }
    }
  }

  @override
  void dispose() {
    _tickSubscription?.cancel();
    stopMetronome();
    stopPreview();
    super.dispose();
  }
}