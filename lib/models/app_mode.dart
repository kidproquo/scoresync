enum AppMode {
  design,
  playback,
}

extension AppModeExtension on AppMode {
  String get displayName {
    switch (this) {
      case AppMode.design:
        return 'Design Mode';
      case AppMode.playback:
        return 'Playback Mode';
    }
  }

  String get description {
    switch (this) {
      case AppMode.design:
        return 'Create sync points by drawing rectangles on the score';
      case AppMode.playback:
        return 'Watch synchronized score and video playback';
    }
  }

  bool get isDesignMode => this == AppMode.design;
  bool get isPlaybackMode => this == AppMode.playback;
}