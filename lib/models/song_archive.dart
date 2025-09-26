import 'dart:convert';
import 'package:flutter/material.dart';
import 'song.dart';

class SongArchive {
  final String version;
  final String name;
  final DateTime createdAt;
  final String? youtubeUrl;
  final MetronomeSettingsData metronomeSettings;
  final List<RectangleData> rectangles;

  const SongArchive({
    required this.version,
    required this.name,
    required this.createdAt,
    this.youtubeUrl,
    required this.metronomeSettings,
    required this.rectangles,
  });

  factory SongArchive.fromSong(Song song) {
    // Extract rectangles data
    final List<RectangleData> rectanglesList = [];

    for (final rectangle in song.rectangles) {
      final rectangleData = RectangleData(
        pageNumber: rectangle.pageNumber,
        id: rectangle.id,
        rect: RectData.fromRect(rectangle.rect),
        timestamps: rectangle.timestamps.map((d) => d.inMilliseconds).toList(),
      );
      rectanglesList.add(rectangleData);
    }

    return SongArchive(
      version: '1.0',
      name: song.name,
      createdAt: song.createdAt,
      youtubeUrl: song.videoUrl,
      metronomeSettings: MetronomeSettingsData.fromMetronomeSettings(song.metronomeSettings),
      rectangles: rectanglesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'youtubeUrl': youtubeUrl,
      'metronomeSettings': metronomeSettings.toJson(),
      'rectangles': rectangles.map((r) => r.toJson()).toList(),
    };
  }

  factory SongArchive.fromJson(Map<String, dynamic> json) {
    return SongArchive(
      version: json['version'] ?? '1.0',
      name: json['name'],
      createdAt: DateTime.parse(json['createdAt']),
      youtubeUrl: json['youtubeUrl'],
      metronomeSettings: MetronomeSettingsData.fromJson(json['metronomeSettings']),
      rectangles: (json['rectangles'] as List)
          .map((r) => RectangleData.fromJson(r))
          .toList(),
    );
  }

  String toJsonString() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}

class RectangleData {
  final int pageNumber;
  final String id;
  final RectData rect;
  final List<int> timestamps;

  const RectangleData({
    required this.pageNumber,
    required this.id,
    required this.rect,
    required this.timestamps,
  });

  Map<String, dynamic> toJson() {
    return {
      'pageNumber': pageNumber,
      'id': id,
      'rect': rect.toJson(),
      'timestamps': timestamps,
    };
  }

  factory RectangleData.fromJson(Map<String, dynamic> json) {
    return RectangleData(
      pageNumber: json['pageNumber'],
      id: json['id'],
      rect: RectData.fromJson(json['rect']),
      timestamps: List<int>.from(json['timestamps']),
    );
  }
}

class RectData {
  final double left;
  final double top;
  final double width;
  final double height;

  const RectData({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  factory RectData.fromRect(Rect rect) {
    return RectData(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
    );
  }

  Rect toRect() {
    return Rect.fromLTWH(left, top, width, height);
  }

  Map<String, dynamic> toJson() {
    return {
      'left': left,
      'top': top,
      'width': width,
      'height': height,
    };
  }

  factory RectData.fromJson(Map<String, dynamic> json) {
    return RectData(
      left: json['left'].toDouble(),
      top: json['top'].toDouble(),
      width: json['width'].toDouble(),
      height: json['height'].toDouble(),
    );
  }
}

class MetronomeSettingsData {
  final int bpm;
  final TimeSignatureData timeSignature;
  final bool countInEnabled;
  final double volume;
  final bool enabled;

  const MetronomeSettingsData({
    required this.bpm,
    required this.timeSignature,
    required this.countInEnabled,
    required this.volume,
    required this.enabled,
  });

  factory MetronomeSettingsData.fromMetronomeSettings(dynamic metronomeSettings) {
    // Handle the metronome settings from the actual MetronomeSettings object
    return MetronomeSettingsData(
      bpm: metronomeSettings.bpm,
      timeSignature: TimeSignatureData.fromTimeSignature(metronomeSettings.timeSignature),
      countInEnabled: metronomeSettings.countInEnabled,
      volume: metronomeSettings.volume,
      enabled: metronomeSettings.isEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bpm': bpm,
      'timeSignature': timeSignature.toJson(),
      'countInEnabled': countInEnabled,
      'volume': volume,
      'enabled': enabled,
    };
  }

  factory MetronomeSettingsData.fromJson(Map<String, dynamic> json) {
    return MetronomeSettingsData(
      bpm: json['bpm'],
      timeSignature: TimeSignatureData.fromJson(json['timeSignature']),
      countInEnabled: json['countInEnabled'],
      volume: json['volume'].toDouble(),
      enabled: json['enabled'],
    );
  }
}

class TimeSignatureData {
  final int beats;
  final int noteValue;

  const TimeSignatureData({
    required this.beats,
    required this.noteValue,
  });

  factory TimeSignatureData.fromTimeSignature(dynamic timeSignature) {
    return TimeSignatureData(
      beats: timeSignature.numerator,
      noteValue: timeSignature.denominator,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'beats': beats,
      'noteValue': noteValue,
    };
  }

  factory TimeSignatureData.fromJson(Map<String, dynamic> json) {
    return TimeSignatureData(
      beats: json['beats'],
      noteValue: json['noteValue'],
    );
  }
}

class ArchiveManifest {
  final String version;
  final DateTime createdAt;
  final String songName;
  final int archiveFormatVersion;

  const ArchiveManifest({
    required this.version,
    required this.createdAt,
    required this.songName,
    this.archiveFormatVersion = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'createdAt': createdAt.toIso8601String(),
      'songName': songName,
      'archiveFormatVersion': archiveFormatVersion,
    };
  }

  factory ArchiveManifest.fromJson(Map<String, dynamic> json) {
    return ArchiveManifest(
      version: json['version'] ?? '1.0',
      createdAt: DateTime.parse(json['createdAt']),
      songName: json['songName'],
      archiveFormatVersion: json['archiveFormatVersion'] ?? 1,
    );
  }

  String toJsonString() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}