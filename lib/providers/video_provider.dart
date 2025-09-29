import 'package:flutter/material.dart';
import 'dart:developer' as developer;

class VideoProvider extends ChangeNotifier {
  String _currentUrl = '';
  bool _isPlayerReady = false;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _playbackRate = 1.0;
  String? _errorMessage;
  bool _isLoading = false;

  // Loop state for Video Mode
  Duration? _loopStartTime;
  Duration? _loopEndTime;
  bool _isLoopActive = false;
  String? _loopStartRectangleId;
  String? _loopEndRectangleId;

  String get currentUrl => _currentUrl;
  bool get isPlayerReady => _isPlayerReady;
  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  double get playbackRate => _playbackRate;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get hasVideo => _currentUrl.isNotEmpty;
  bool get hasError => _errorMessage != null;

  // Loop state getters
  Duration? get loopStartTime => _loopStartTime;
  Duration? get loopEndTime => _loopEndTime;
  bool get isLoopActive => _isLoopActive;
  String? get loopStartRectangleId => _loopStartRectangleId;
  String? get loopEndRectangleId => _loopEndRectangleId;
  bool get canLoop => _loopStartTime != null &&
                     _loopEndTime != null &&
                     _loopEndTime! > _loopStartTime! &&
                     (_loopEndTime! - _loopStartTime!) >= const Duration(seconds: 1);

  void setCurrentUrl(String url) {
    if (_currentUrl != url) {
      _currentUrl = url;
      _isPlayerReady = false;
      _isPlaying = false;
      _currentPosition = Duration.zero;
      _totalDuration = Duration.zero;
      _playbackRate = 1.0;
      _errorMessage = null;
      developer.log('Video URL set: $url');
      notifyListeners();
    }
  }

  void setPlayerReady(bool isReady) {
    if (_isPlayerReady != isReady) {
      _isPlayerReady = isReady;
      _isLoading = false;
      if (isReady) {
        _errorMessage = null;
        developer.log('Video player ready');
      }
      notifyListeners();
    }
  }

  void setPlaying(bool isPlaying) {
    if (_isPlaying != isPlaying) {
      _isPlaying = isPlaying;
      developer.log('Video ${isPlaying ? 'playing' : 'paused'}');
      notifyListeners();
    }
  }

  void setCurrentPosition(Duration position) {
    if (_currentPosition != position) {
      _currentPosition = position;

      // Check for loop end in Video Mode
      if (_isLoopActive && _loopEndTime != null && position >= _loopEndTime!) {
        developer.log('Loop end reached at ${_formatDuration(position)}, jumping to start time ${_formatDuration(_loopStartTime!)}');

        if (_loopStartTime != null) {
          // Use Future.delayed to avoid issues with simultaneous position updates
          Future.delayed(const Duration(milliseconds: 10), () {
            seekTo(_loopStartTime!);
            play();
          });
        }
      }

      notifyListeners();
    }
  }

  void setTotalDuration(Duration duration) {
    if (_totalDuration != duration) {
      _totalDuration = duration;
      developer.log('Video duration: ${_formatDuration(duration)}');
      notifyListeners();
    }
  }

  void setPlaybackRate(double rate) {
    if (_playbackRate != rate) {
      _playbackRate = rate;
      developer.log('Playback rate changed to: ${rate}x');
      notifyListeners();
    }
  }

  void setLoading(bool isLoading) {
    if (_isLoading != isLoading) {
      _isLoading = isLoading;
      if (isLoading) {
        _errorMessage = null;
      }
      notifyListeners();
    }
  }

  void setError(String? errorMessage) {
    _errorMessage = errorMessage;
    _isLoading = false;
    _isPlayerReady = false;
    if (errorMessage != null) {
      developer.log('Video error: $errorMessage');
    }
    notifyListeners();
  }

  void clearError() {
    setError(null);
  }

  String formatDuration(Duration duration) {
    return _formatDuration(duration);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      String hours = twoDigits(duration.inHours);
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  double get progressPercentage {
    if (_totalDuration.inMilliseconds == 0) return 0.0;
    return _currentPosition.inMilliseconds / _totalDuration.inMilliseconds;
  }

  String get positionText => formatDuration(_currentPosition);
  String get durationText => formatDuration(_totalDuration);

  void setVideoUrl(String url) {
    setCurrentUrl(url);
  }

  // Loop management methods
  void setLoopStart(Duration timestamp, String rectangleId) {
    _loopStartTime = timestamp;
    _loopStartRectangleId = rectangleId;

    if (_loopEndTime != null && _loopEndTime! <= _loopStartTime!) {
      clearLoopEnd();
    }

    _updateLoopStatus();
    notifyListeners();
  }

  void setLoopEnd(Duration timestamp, String rectangleId) {
    _loopEndTime = timestamp;
    _loopEndRectangleId = rectangleId;

    if (_loopStartTime != null && _loopEndTime! <= _loopStartTime!) {
      clearLoopStart();
    }

    _updateLoopStatus();
    notifyListeners();
  }

  void clearLoopStart() {
    _loopStartTime = null;
    _loopStartRectangleId = null;
    _updateLoopStatus();
    notifyListeners();
  }

  void clearLoopEnd() {
    _loopEndTime = null;
    _loopEndRectangleId = null;
    _updateLoopStatus();
    notifyListeners();
  }

  void toggleLoop() {
    if (canLoop) {
      _isLoopActive = !_isLoopActive;
      notifyListeners();
    }
  }

  void _updateLoopStatus() {
    final wasActive = _isLoopActive;
    _isLoopActive = canLoop && _isLoopActive;

    if (wasActive && !_isLoopActive) {
      developer.log('Loop deactivated due to invalid start/end points');
    }
  }

  void clearAllLoopState() {
    _loopStartTime = null;
    _loopEndTime = null;
    _isLoopActive = false;
    _loopStartRectangleId = null;
    _loopEndRectangleId = null;
    notifyListeners();
    developer.log('Video loop state cleared');
  }

  void clearVideo() {
    setCurrentUrl('');
  }

  // Callbacks for controlling video - will be set by YouTube player
  Function(Duration)? _seekToCallback;
  Function()? _playCallback;
  Function()? _pauseCallback;
  Function()? _forcePauseCallback;

  void setSeekToCallback(Function(Duration)? callback) {
    _seekToCallback = callback;
  }

  void setPlayCallback(Function()? callback) {
    _playCallback = callback;
  }

  void setPauseCallback(Function()? callback) {
    _pauseCallback = callback;
  }

  void setForcePauseCallback(Function()? callback) {
    _forcePauseCallback = callback;
  }

  void seekTo(Duration position) {
    if (_seekToCallback != null && _isPlayerReady) {
      _seekToCallback!(position);
      developer.log('Seeking to: ${_formatDuration(position)}');
    } else {
      developer.log('Cannot seek - no callback set or player not ready');
    }
  }

  void play() {
    if (_playCallback != null && _isPlayerReady) {
      _playCallback!();
      developer.log('Video play requested');
    } else {
      developer.log('Cannot play - no callback set or player not ready');
    }
  }

  void pause() {
    if (_pauseCallback != null && _isPlayerReady) {
      _pauseCallback!();

      // When loop is active, pause seeks to loop start
      if (_isLoopActive && _loopStartTime != null) {
        developer.log('Loop active - seeking to loop start time ${_formatDuration(_loopStartTime!)} on pause');
        seekTo(_loopStartTime!);
      }

      developer.log('Video pause requested');
    } else {
      developer.log('Cannot pause - no callback set or player not ready');
    }
  }

  void forcePause() {
    if (_forcePauseCallback != null && _isPlayerReady) {
      _forcePauseCallback!();
      developer.log('Video force pause requested');
    } else {
      developer.log('Cannot force pause - no callback set or player not ready');
    }
  }
}