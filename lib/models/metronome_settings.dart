enum MetronomeMode { video, beat }

class MetronomeSettings {
  final bool isEnabled;
  final int bpm;
  final TimeSignature timeSignature;
  final bool countInEnabled;
  final double volume;
  final MetronomeMode mode;

  MetronomeSettings({
    this.isEnabled = false,
    this.bpm = 120,
    this.timeSignature = const TimeSignature(4, 4),
    this.countInEnabled = true,
    this.volume = 0.7,
    this.mode = MetronomeMode.video,
  });

  MetronomeSettings copyWith({
    bool? isEnabled,
    int? bpm,
    TimeSignature? timeSignature,
    bool? countInEnabled,
    double? volume,
    MetronomeMode? mode,
  }) {
    return MetronomeSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      bpm: bpm ?? this.bpm,
      timeSignature: timeSignature ?? this.timeSignature,
      countInEnabled: countInEnabled ?? this.countInEnabled,
      volume: volume ?? this.volume,
      mode: mode ?? this.mode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'bpm': bpm,
      'timeSignature': timeSignature.toJson(),
      'countInEnabled': countInEnabled,
      'volume': volume,
      'mode': mode.name,
    };
  }

  factory MetronomeSettings.fromJson(Map<String, dynamic> json) {
    MetronomeMode mode = MetronomeMode.video;
    if (json['mode'] != null) {
      try {
        mode = MetronomeMode.values.byName(json['mode']);
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