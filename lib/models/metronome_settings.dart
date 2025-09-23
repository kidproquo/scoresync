class MetronomeSettings {
  final bool isEnabled;
  final int bpm;
  final TimeSignature timeSignature;
  final bool countInEnabled;
  final double volume;
  
  MetronomeSettings({
    this.isEnabled = false,
    this.bpm = 120,
    this.timeSignature = const TimeSignature(4, 4),
    this.countInEnabled = true,
    this.volume = 0.7,
  });

  MetronomeSettings copyWith({
    bool? isEnabled,
    int? bpm,
    TimeSignature? timeSignature,
    bool? countInEnabled,
    double? volume,
  }) {
    return MetronomeSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      bpm: bpm ?? this.bpm,
      timeSignature: timeSignature ?? this.timeSignature,
      countInEnabled: countInEnabled ?? this.countInEnabled,
      volume: volume ?? this.volume,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'bpm': bpm,
      'timeSignature': timeSignature.toJson(),
      'countInEnabled': countInEnabled,
      'volume': volume,
    };
  }

  factory MetronomeSettings.fromJson(Map<String, dynamic> json) {
    return MetronomeSettings(
      isEnabled: json['isEnabled'] ?? false,
      bpm: json['bpm'] ?? 120,
      timeSignature: json['timeSignature'] != null 
          ? TimeSignature.fromJson(json['timeSignature'])
          : const TimeSignature(4, 4),
      countInEnabled: json['countInEnabled'] ?? true,
      volume: json['volume'] ?? 0.7,
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
  
  static const List<TimeSignature> common = [
    twoFour,
    threeFour,
    fourFour,
    sixEight,
  ];
}