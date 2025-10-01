enum MetronomeMode { video, beat }

class MetronomeModeHelper {
  static String toName(MetronomeMode mode) {
    switch (mode) {
      case MetronomeMode.video:
        return 'video';
      case MetronomeMode.beat:
        return 'beat';
    }
  }

  static MetronomeMode fromString(String value) {
    switch (value) {
      case 'video':
        return MetronomeMode.video;
      case 'beat':
        return MetronomeMode.beat;
      default:
        return MetronomeMode.video; // Default fallback
    }
  }
}

class MetronomeSettings {
  final bool isEnabled;
  final int bpm;
  final TimeSignature timeSignature;
  final bool countInEnabled;
  final double volume;
  final MetronomeMode mode;

  // Loop settings for Beat Mode
  final int? loopStartBeat;
  final int? loopEndBeat;
  final bool isLoopActive;
  final String? loopStartRectangleId;
  final String? loopEndRectangleId;

  MetronomeSettings({
    this.isEnabled = false,
    this.bpm = 120,
    this.timeSignature = const TimeSignature(4, 4),
    this.countInEnabled = true,
    this.volume = 0.7,
    this.mode = MetronomeMode.video,
    this.loopStartBeat,
    this.loopEndBeat,
    this.isLoopActive = false,
    this.loopStartRectangleId,
    this.loopEndRectangleId,
  });

  MetronomeSettings copyWith({
    bool? isEnabled,
    int? bpm,
    TimeSignature? timeSignature,
    bool? countInEnabled,
    double? volume,
    MetronomeMode? mode,
    int? loopStartBeat,
    int? loopEndBeat,
    bool? isLoopActive,
    String? loopStartRectangleId,
    String? loopEndRectangleId,
    bool clearLoopStart = false,
    bool clearLoopEnd = false,
    bool clearLoopRectangleIds = false,
  }) {
    return MetronomeSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      bpm: bpm ?? this.bpm,
      timeSignature: timeSignature ?? this.timeSignature,
      countInEnabled: countInEnabled ?? this.countInEnabled,
      volume: volume ?? this.volume,
      mode: mode ?? this.mode,
      loopStartBeat: clearLoopStart ? null : (loopStartBeat ?? this.loopStartBeat),
      loopEndBeat: clearLoopEnd ? null : (loopEndBeat ?? this.loopEndBeat),
      isLoopActive: isLoopActive ?? this.isLoopActive,
      loopStartRectangleId: clearLoopRectangleIds ? null : (loopStartRectangleId ?? this.loopStartRectangleId),
      loopEndRectangleId: clearLoopRectangleIds ? null : (loopEndRectangleId ?? this.loopEndRectangleId),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'bpm': bpm,
      'timeSignature': timeSignature.toJson(),
      'countInEnabled': countInEnabled,
      'volume': volume,
      'mode': MetronomeModeHelper.toName(mode),
      'loopStartBeat': loopStartBeat,
      'loopEndBeat': loopEndBeat,
      'isLoopActive': isLoopActive,
      'loopStartRectangleId': loopStartRectangleId,
      'loopEndRectangleId': loopEndRectangleId,
    };
  }

  factory MetronomeSettings.fromJson(Map<String, dynamic> json) {
    MetronomeMode mode = MetronomeMode.video;
    if (json['mode'] != null) {
      try {
        mode = MetronomeModeHelper.fromString(json['mode']);
      } catch (e) {
        mode = MetronomeMode.video;
      }
    }

    return MetronomeSettings(
      isEnabled: json['isEnabled'] ?? false,
      bpm: json['bpm'] ?? 120,
      timeSignature: json['timeSignature'] != null
          ? TimeSignature.fromJson(json['timeSignature'])
          : const TimeSignature(4, 4),
      countInEnabled: json['countInEnabled'] ?? true,
      volume: json['volume'] ?? 0.7,
      mode: mode,
      loopStartBeat: json['loopStartBeat'],
      loopEndBeat: json['loopEndBeat'],
      isLoopActive: json['isLoopActive'] ?? false,
      loopStartRectangleId: json['loopStartRectangleId'],
      loopEndRectangleId: json['loopEndRectangleId'],
    );
  }
}

class TimeSignature {
  final int numerator;   // beats per measure
  final int denominator; // note value (4 = quarter, 8 = eighth)
  
  const TimeSignature(this.numerator, this.denominator);

  String get displayString => '$numerator/$denominator';

  Map<String, dynamic> toJson() {
    return {
      'numerator': numerator,
      'denominator': denominator,
    };
  }

  factory TimeSignature.fromJson(Map<String, dynamic> json) {
    return TimeSignature(
      json['numerator'] ?? 4,
      json['denominator'] ?? 4,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimeSignature &&
        other.numerator == numerator &&
        other.denominator == denominator;
  }

  @override
  int get hashCode => numerator.hashCode ^ denominator.hashCode;
}

// Common time signatures
class TimeSignatures {
  static const twoFour = TimeSignature(2, 4);
  static const threeFour = TimeSignature(3, 4);
  static const fourFour = TimeSignature(4, 4);
  static const sixEight = TimeSignature(6, 8);
  static const nineEight = TimeSignature(9, 8);
  static const twelveEight = TimeSignature(12, 8);
  
  static const List<TimeSignature> common = [
    twoFour,
    threeFour,
    fourFour,
    sixEight,
    nineEight,
    twelveEight,
  ];
}