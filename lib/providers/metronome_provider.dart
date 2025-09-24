import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../models/metronome_settings.dart';

class MetronomeProvider extends ChangeNotifier {
  MetronomeSettings _settings = MetronomeSettings();
  Timer? _metronomeTimer;
  int _currentBeat = 0;
  bool _isCountingIn = false;
  double _playbackRate = 1.0; // Add playback rate
  
  // Audio players for metronome sounds
  AudioPlayer? _accentPlayer;
  AudioPlayer? _normalPlayer;
  bool _audioInitialized = false;
  
  // Callbacks
  Function(int beat)? _onBeat;
  Function(int beat)? _onCountInBeat;
  
  MetronomeSettings get settings => _settings;
  bool get isPlaying => _metronomeTimer != null && _metronomeTimer!.isActive;
  bool get isCountingIn => _isCountingIn;
  int get currentBeat => _currentBeat;
  
  MetronomeProvider() {
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    try {
      // Initialize audio players for accent and normal beats
      _accentPlayer = AudioPlayer();
      _normalPlayer = AudioPlayer();
      
      // Load metronome sound files
      await _accentPlayer!.setAsset('assets/Synth_Tick_D_hi.wav'); // Higher pitch for accent
      await _normalPlayer!.setAsset('assets/Synth_Tick_C_hi.wav'); // Normal pitch for regular beats
      
      // Set volume based on settings
      await _accentPlayer!.setVolume(_settings.volume);
      await _normalPlayer!.setVolume(_settings.volume);
      
      _audioInitialized = true;
      developer.log('Metronome audio initialized with custom WAV files');
    } catch (e) {
      developer.log('Error initializing metronome audio: $e');
      developer.log('Falling back to system sounds');
      _audioInitialized = false;
    }
  }

  void updateSettings(MetronomeSettings newSettings) {
    final wasPlaying = isPlaying;
    developer.log('updateSettings called: wasPlaying=$wasPlaying, newEnabled=${newSettings.isEnabled}');
    
    if (wasPlaying) {
      stopMetronome();
    }
    
    _settings = newSettings;
    notifyListeners();
    
    if (wasPlaying && _settings.isEnabled) {
      developer.log('Restarting metronome after settings update');
      startMetronome();
    }
    
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
    
    // Don't auto-start metronome when enabled - it should only start with video
    if (!_settings.isEnabled) {
      stopMetronome();
    }
  }

  void setBPM(int bpm) {
    // Clamp BPM between reasonable values
    final clampedBPM = bpm.clamp(40, 240);
    updateSettings(_settings.copyWith(bpm: clampedBPM));
  }

  void setTimeSignature(TimeSignature timeSignature) {
    updateSettings(_settings.copyWith(timeSignature: timeSignature));
  }

  void setVolume(double volume) {
    final clampedVolume = volume.clamp(0.0, 1.0);
    updateSettings(_settings.copyWith(volume: clampedVolume));
    
    // Update audio player volumes if initialized
    if (_audioInitialized) {
      _accentPlayer?.setVolume(clampedVolume);
      _normalPlayer?.setVolume(clampedVolume);
    }
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
    final beatDuration = Duration(
      milliseconds: (60000 / effectiveBPM).round(),
    );
    
    developer.log('Starting metronome: BPM=${_settings.bpm}, playbackRate=$_playbackRate, effectiveBPM=$effectiveBPM, beatDuration=${beatDuration.inMilliseconds}ms, timeSignature=${_settings.timeSignature.displayString}');
    
    _currentBeat = 1; // Start with beat 1
    _playClick(true); // Play first beat (accent) immediately
    
    _metronomeTimer = Timer.periodic(beatDuration, (timer) {
      // Increment to next beat
      _currentBeat++;
      
      // Reset to 1 after last beat of measure
      if (_currentBeat > _settings.timeSignature.numerator) {
        _currentBeat = 1;
      }
      
      
      // Play accent on beat 1, normal click on other beats
      _playClick(_currentBeat == 1);
      
      _onBeat?.call(_currentBeat);
      notifyListeners();
    });
    
    developer.log('Metronome started at $effectiveBPM effective BPM (base: ${_settings.bpm} BPM × $_playbackRate rate)');
  }

  void stopMetronome() {
    _metronomeTimer?.cancel();
    _metronomeTimer = null;
    _currentBeat = 0;
    _isCountingIn = false;
    notifyListeners();
    
    developer.log('Metronome stopped');
  }

  Future<void> startCountIn() async {
    if (!_settings.countInEnabled) {
      return;
    }

    _isCountingIn = true;
    _currentBeat = 0;
    notifyListeners();

    // Apply playback rate to count-in as well
    final effectiveBPM = (_settings.bpm * _playbackRate).round();
    final beatDuration = Duration(
      milliseconds: (60000 / effectiveBPM).round(),
    );

    for (int beat = 1; beat <= _settings.timeSignature.numerator; beat++) {
      _currentBeat = beat;
      _playClick(beat == 1);
      _onCountInBeat?.call(beat);
      notifyListeners();
      
      if (beat < _settings.timeSignature.numerator) {
        await Future.delayed(beatDuration);
      }
    }

    _isCountingIn = false;
    _currentBeat = 0;
    notifyListeners();
    
    developer.log('Count-in completed at $effectiveBPM effective BPM');
  }

  void _playClick(bool isAccent) async {
    try {
      if (_audioInitialized && _accentPlayer != null && _normalPlayer != null) {
        // Use custom WAV files for better sound quality
        final player = isAccent ? _accentPlayer! : _normalPlayer!;
        
        // Reset to beginning and play
        await player.seek(Duration.zero);
        await player.play();
      } else {
        // Fallback to system sounds if custom audio failed to load
        SystemSound.play(SystemSoundType.click);
      }
    } catch (e) {
      developer.log('Error playing metronome sound: $e');
      // Final fallback to system sound
      SystemSound.play(SystemSoundType.click);
    }
  }

  void setOnBeatCallback(Function(int)? callback) {
    _onBeat = callback;
  }

  void setOnCountInBeatCallback(Function(int)? callback) {
    _onCountInBeat = callback;
  }

  // Preview methods for testing sounds
  Future<void> previewAccentSound() async {
    _playClick(true);
  }

  Future<void> previewNormalSound() async {
    _playClick(false);
  }

  // Preview metronome for a few beats
  Timer? _previewTimer;
  int _previewBeatCount = 0;
  bool _isPreviewRunning = false;

  void previewMetronome() {
    if (!_settings.isEnabled || _isPreviewRunning) return;
    
    // Stop main metronome if running
    final wasPlaying = isPlaying;
    if (wasPlaying) {
      stopMetronome();
    }
    
    _isPreviewRunning = true;
    _previewBeatCount = 0;
    
    // Play 4 beats (one measure) as preview
    final beatDuration = Duration(
      milliseconds: (60000 / _settings.bpm).round(),
    );
    
    developer.log('Starting metronome preview: ${_settings.bpm} BPM, ${_settings.timeSignature.displayString}');
    
    // Play first beat immediately
    _previewBeatCount = 1;
    _playClick(true); // Accent on first beat
    
    // Schedule remaining beats
    _previewTimer = Timer.periodic(beatDuration, (timer) {
      _previewBeatCount++;
      
      if (_previewBeatCount > _settings.timeSignature.numerator) {
        // Finished one measure, stop preview
        _previewTimer?.cancel();
        _previewTimer = null;
        _isPreviewRunning = false;
        developer.log('Metronome preview completed');
        
        // Restart main metronome if it was playing before
        if (wasPlaying) {
          startMetronome();
        }
        return;
      }
      
      // Play accent on beat 1, normal click on other beats
      _playClick(_previewBeatCount == 1);
    });
  }

  @override
  void dispose() {
    stopMetronome();
    
    // Cancel preview timer
    _previewTimer?.cancel();
    _previewTimer = null;
    
    // Dispose audio players
    _accentPlayer?.dispose();
    _normalPlayer?.dispose();
    
    super.dispose();
  }
}