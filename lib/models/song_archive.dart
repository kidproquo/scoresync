import 'dart:convert';
import 'package:flutter/material.dart';
import 'song.dart';
import 'rectangle.dart';
import 'metronome_settings.dart';

class SongArchive {
  final String version;
  final String name;
  final DateTime createdAt;
  final String? youtubeUrl;
  final MetronomeSettingsData metronomeSettings;
  final List<RectangleData> rectangles;

  // Video loop settings
  final int? videoLoopStart;
  final int? videoLoopEnd;
  final bool videoLoopActive;
  final String? videoLoopStartRectangleId;
  final String? videoLoopEndRectangleId;

  const SongArchive({
    required this.version,
    required this.name,
    required this.createdAt,
    this.youtubeUrl,
    required this.metronomeSettings,
    required this.rectangles,
    this.videoLoopStart,
    this.videoLoopEnd,
    this.videoLoopActive = false,
    this.videoLoopStartRectangleId,
    this.videoLoopEndRectangleId,
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
        beatNumbers: rectangle.beatNumbers,
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
      videoLoopStart: song.videoLoopStart?.inMilliseconds,
      videoLoopEnd: song.videoLoopEnd?.inMilliseconds,
      videoLoopActive: song.videoLoopActive,
      videoLoopStartRectangleId: song.videoLoopStartRectangleId,
      videoLoopEndRectangleId: song.videoLoopEndRectangleId,
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
      'videoLoopStart': videoLoopStart,
      'videoLoopEnd': videoLoopEnd,
      'videoLoopActive': videoLoopActive,
      'videoLoopStartRectangleId': videoLoopStartRectangleId,
      'videoLoopEndRectangleId': videoLoopEndRectangleId,
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
      videoLoopStart: json['videoLoopStart'],
      videoLoopEnd: json['videoLoopEnd'],
      videoLoopActive: json['videoLoopActive'] ?? false,
      videoLoopStartRectangleId: json['videoLoopStartRectangleId'],
      videoLoopEndRectangleId: json['videoLoopEndRectangleId'],
    );
  }

  String toJsonString() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  // Convert back to Song object (without PDF path - that needs to be set separately)
  Song toSong({String? pdfPath}) {
    // Convert rectangles back to DrawnRectangle objects
    final drawnRectangles = rectangles.map((rectData) {
      return DrawnRectangle(
        id: rectData.id,
        rect: rectData.rect.toRect(),
        pageNumber: rectData.pageNumber,
        createdAt: DateTime.now(), // Use current time since we don't store this in archive
        timestamps: rectData.timestamps.map((ms) => Duration(milliseconds: ms)).toList(),
        beatNumbers: rectData.beatNumbers,
      );
    }).toList();

    // Convert metronome settings back
    final metronomeSettings = MetronomeSettings(
      isEnabled: this.metronomeSettings.enabled,
      bpm: this.metronomeSettings.bpm,
      timeSignature: TimeSignature(
        this.metronomeSettings.timeSignature.beats,
        this.metronomeSettings.timeSignature.noteValue,
      ),
      countInEnabled: this.metronomeSettings.countInEnabled,
      volume: this.metronomeSettings.volume,
      mode: this.metronomeSettings.mode == 'beat' ? MetronomeMode.beat : MetronomeMode.video,
      loopStartBeat: this.metronomeSettings.loopStartBeat,
      loopEndBeat: this.metronomeSettings.loopEndBeat,
      isLoopActive: this.metronomeSettings.isLoopActive,
      loopStartRectangleId: this.metronomeSettings.loopStartRectangleId,
      loopEndRectangleId: this.metronomeSettings.loopEndRectangleId,
    );

    return Song(
      name: name,
      pdfPath: pdfPath,
      rectangles: drawnRectangles,
      videoUrl: youtubeUrl,
      metronomeSettings: metronomeSettings,
      createdAt: createdAt,
      videoLoopStart: videoLoopStart != null ? Duration(milliseconds: videoLoopStart!) : null,
      videoLoopEnd: videoLoopEnd != null ? Duration(milliseconds: videoLoopEnd!) : null,
      videoLoopActive: videoLoopActive,
      videoLoopStartRectangleId: videoLoopStartRectangleId,
      videoLoopEndRectangleId: videoLoopEndRectangleId,
    );
  }
}

class RectangleData {
  final int pageNumber;
  final String id;
  final RectData rect;
  final List<int> timestamps;
  final List<int> beatNumbers;

  const RectangleData({
    required this.pageNumber,
    required this.id,
    required this.rect,
    required this.timestamps,
    required this.beatNumbers,
  });

  Map<String, dynamic> toJson() {
    return {
      'pageNumber': pageNumber,
      'id': id,
      'rect': rect.toJson(),
      'timestamps': timestamps,
      'beatNumbers': beatNumbers,
    };
  }

  factory RectangleData.fromJson(Map<String, dynamic> json) {
    return RectangleData(
      pageNumber: json['pageNumber'],
      id: json['id'],
      rect: RectData.fromJson(json['rect']),
      timestamps: List<int>.from(json['timestamps']),
      beatNumbers: List<int>.from(json['beatNumbers'] ?? []),
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
  final String mode;

  // Loop settings for Beat Mode
  final int? loopStartBeat;
  final int? loopEndBeat;
  final bool isLoopActive;
  final String? loopStartRectangleId;
  final String? loopEndRectangleId;

  const MetronomeSettingsData({
    required this.bpm,
    required this.timeSignature,
    required this.countInEnabled,
    required this.volume,
    required this.enabled,
    required this.mode,
    this.loopStartBeat,
    this.loopEndBeat,
    this.isLoopActive = false,
    this.loopStartRectangleId,
    this.loopEndRectangleId,
  });

  factory MetronomeSettingsData.fromMetronomeSettings(dynamic metronomeSettings) {
    // Handle the metronome settings from the actual MetronomeSettings object
    return MetronomeSettingsData(
      bpm: metronomeSettings.bpm,
      timeSignature: TimeSignatureData.fromTimeSignature(metronomeSettings.timeSignature),
      countInEnabled: metronomeSettings.countInEnabled,
      volume: metronomeSettings.volume,
      enabled: metronomeSettings.isEnabled,
      mode: metronomeSettings.mode.name,
      loopStartBeat: metronomeSettings.loopStartBeat,
      loopEndBeat: metronomeSettings.loopEndBeat,
      isLoopActive: metronomeSettings.isLoopActive,
      loopStartRectangleId: metronomeSettings.loopStartRectangleId,
      loopEndRectangleId: metronomeSettings.loopEndRectangleId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bpm': bpm,
      'timeSignature': timeSignature.toJson(),
      'countInEnabled': countInEnabled,
      'volume': volume,
      'enabled': enabled,
      'mode': mode,
      'loopStartBeat': loopStartBeat,
      'loopEndBeat': loopEndBeat,
      'isLoopActive': isLoopActive,
      'loopStartRectangleId': loopStartRectangleId,
      'loopEndRectangleId': loopEndRectangleId,
    };
  }

  factory MetronomeSettingsData.fromJson(Map<String, dynamic> json) {
    return MetronomeSettingsData(
      bpm: json['bpm'],
      timeSignature: TimeSignatureData.fromJson(json['timeSignature']),
      countInEnabled: json['countInEnabled'],
      volume: json['volume'].toDouble(),
      enabled: json['enabled'],
      mode: json['mode'] ?? 'video',
      loopStartBeat: json['loopStartBeat'],
      loopEndBeat: json['loopEndBeat'],
      isLoopActive: json['isLoopActive'] ?? false,
      loopStartRectangleId: json['loopStartRectangleId'],
      loopEndRectangleId: json['loopEndRectangleId'],
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