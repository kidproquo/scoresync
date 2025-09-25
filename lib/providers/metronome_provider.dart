import 'package:flutter/material.dart';
import 'package:metronome/metronome.dart';
import 'dart:async';
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

  // Callbacks (only used during count-in)
  Function(int beat)? _onCountInBeat;

  MetronomeSettings get settings => _settings;
  bool get isPlaying => _isPlaying;
  bool get isCountingIn => _isCountingIn;
  bool get isPreviewing => _isPreviewing;
  int get currentBeat => _currentBeat;

  MetronomeProvider() {
    _initializeMetronome();
    _initializeCountInMetronome();
  }

  Future<void> _initializeMetronome() async {
    try {
      _metronome = Metronome();

      // Initialize with distinct click and accent sounds
      await _metronome.init(
        'assets/woodblock_high44_wav.wav', // Regular click sound (beats 2, 3, 4)
        accentedPath: 'assets/claves44_wav.wav', // Accent sound (beat 1)
        bpm: _settings.bpm,
        volume: (_settings.volume * 100).round(), // Convert 0-1 to 0-100
        timeSignature: _settings.timeSignature.numerator,
        enableTickCallback: false,  // No callback needed for regular metronome
      );

      developer.log('Main metronome initialized');
    } catch (e) {
      developer.log('Error initializing metronome: $e');
    }
  }

  Future<void> _initializeCountInMetronome() async {
    try {
      _countInMetronome = Metronome();

      // Initialize count-in metronome with same sounds as main metronome
      await _countInMetronome.init(
        'assets/woodblock_high44_wav.wav', // Regular click sound (beats 2, 3, 4)
        accentedPath: 'assets/claves44_wav.wav', // Accent sound (beat 1)
        bpm: _settings.bpm,
        volume: (_settings.volume * 100).round(),
        timeSignature: _settings.timeSignature.numerator,
        enableTickCallback: false,  // No callback needed - using manual timing
      );

      developer.log('Count-in metronome initialized with same config as main');
    } catch (e) {
      developer.log('Error initializing count-in metronome: $e');
    }
  }

  void updateSettings(MetronomeSettings newSettings) {
    final wasPlaying = isPlaying;
    developer.log('updateSettings called: wasPlaying=$wasPlaying, newEnabled=${newSettings.isEnabled}');

    // Pause preview if running
    _pausePreviewForUpdate();

    if (wasPlaying) {
      stopMetronome();
    }

    _settings = newSettings;

    // Update both metronome settings
    final effectiveBPM = (_settings.bpm * _playbackRate).round();
    _metronome.setBPM(effectiveBPM);
    _metronome.setVolume((_settings.volume * 100).round());
    _metronome.setTimeSignature(_settings.timeSignature.numerator);

    // Update count-in metronome as well
    _countInMetronome.setBPM(effectiveBPM);
    _countInMetronome.setVolume((_settings.volume * 100).round());
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
    updateSettings(_settings.copyWith(volume: clampedVolume));
  }

  void setCountInEnabled(bool enabled) {
    updateSettings(_settings.copyWith(countInEnabled: enabled));
  }

  void setPlaybackRate(double rate) {
    if (_playbackRate != rate) {
      _playbackRate = rate;
      // If metronome is playing, restart with new rate
      if (isPlaying) {
        developer.log('Playback rate changed to $rate, restarting metronome');
        startMetronome();
      }
    }
  }

  void startMetronome() {
    if (!_settings.isEnabled) return;

    stopMetronome(); // Ensure clean start

    // Apply playback rate to BPM
    final effectiveBPM = (_settings.bpm * _playbackRate).round();

    developer.log('Starting metronome: BPM=${_settings.bpm}, playbackRate=$_playbackRate, effectiveBPM=$effectiveBPM, timeSignature=${_settings.timeSignature.displayString}');

    // Update metronome with all settings
    _metronome.setBPM(effectiveBPM);
    _metronome.setTimeSignature(_settings.timeSignature.numerator);
    _metronome.setVolume((_settings.volume * 100).round());

    developer.log('Main metronome configured: BPM=$effectiveBPM, timeSignature=${_settings.timeSignature.numerator}, volume=${(_settings.volume * 100).round()}');

    // Start the metronome
    _metronome.play();
    _isPlaying = true;
    notifyListeners();

    developer.log('Metronome started at $effectiveBPM effective BPM (base: ${_settings.bpm} BPM × $_playbackRate rate)');
  }

  void stopMetronome() {
    _metronome.stop();
    _countInMetronome.stop();
    _isPlaying = false;
    _isPreviewing = false;  // Also stop preview if running
    _currentBeat = 0;
    _isCountingIn = false;
    notifyListeners();

    developer.log('Metronome stopped');
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
    _countInMetronome.setVolume((_settings.volume * 100).round());

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

  // Toggle preview metronome - continuous play/stop
  void togglePreview() {
    if (_isPreviewing) {
      stopPreview();
    } else {
      startPreview();
    }
  }

  void startPreview() {
    if (!_settings.isEnabled) return;

    // Stop main metronome if playing
    if (_isPlaying) {
      stopMetronome();
    }

    developer.log('Starting metronome preview: ${_settings.bpm} BPM, ${_settings.timeSignature.displayString}');

    // Configure and start metronome for preview (use main metronome)
    _metronome.setBPM(_settings.bpm);
    _metronome.setTimeSignature(_settings.timeSignature.numerator);
    _metronome.setVolume((_settings.volume * 100).round());

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
      _metronome.setVolume((_settings.volume * 100).round());
      _metronome.play();
    }
  }

  @override
  void dispose() {
    stopMetronome();
    stopPreview();
    super.dispose();
  }
}