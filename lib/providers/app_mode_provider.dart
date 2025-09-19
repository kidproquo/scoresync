import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../models/app_mode.dart';

class AppModeProvider extends ChangeNotifier {
  AppMode _currentMode = AppMode.design;

  AppMode get currentMode => _currentMode;
  bool get isDesignMode => _currentMode.isDesignMode;
  bool get isPlaybackMode => _currentMode.isPlaybackMode;
  String get currentModeDisplayName => _currentMode.displayName;
  String get currentModeDescription => _currentMode.description;

  void toggleMode() {
    setMode(_currentMode == AppMode.design ? AppMode.playback : AppMode.design);
  }

  void setMode(AppMode mode) {
    if (_currentMode != mode) {
      final previousMode = _currentMode;
      _currentMode = mode;
      
      developer.log('Mode changed from ${previousMode.displayName} to ${mode.displayName}');
      
      notifyListeners();
    }
  }

  void setDesignMode() {
    setMode(AppMode.design);
  }

  void setPlaybackMode() {
    setMode(AppMode.playback);
  }
}