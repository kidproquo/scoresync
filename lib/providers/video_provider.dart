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

  void clearVideo() {
    setCurrentUrl('');
  }
}