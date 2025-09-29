import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'rectangle.dart';
import 'metronome_settings.dart';

class Song {
  final String name;
  final String? pdfPath;
  final List<DrawnRectangle> rectangles;
  final String? videoUrl;
  final MetronomeSettings metronomeSettings;
  final DateTime createdAt;
  final DateTime lastModified;

  // Video loop settings
  final Duration? videoLoopStart;
  final Duration? videoLoopEnd;
  final bool videoLoopActive;
  final String? videoLoopStartRectangleId;
  final String? videoLoopEndRectangleId;

  Song({
    required this.name,
    this.pdfPath,
    List<DrawnRectangle>? rectangles,
    this.videoUrl,
    MetronomeSettings? metronomeSettings,
    DateTime? createdAt,
    DateTime? lastModified,
    this.videoLoopStart,
    this.videoLoopEnd,
    this.videoLoopActive = false,
    this.videoLoopStartRectangleId,
    this.videoLoopEndRectangleId,
  })  : rectangles = rectangles ?? [],
        metronomeSettings = metronomeSettings ?? MetronomeSettings(),
        createdAt = createdAt ?? DateTime.now(),
        lastModified = lastModified ?? DateTime.now();

  Song copyWith({
    String? name,
    String? pdfPath,
    List<DrawnRectangle>? rectangles,
    String? videoUrl,
    MetronomeSettings? metronomeSettings,
    DateTime? createdAt,
    DateTime? lastModified,
    Duration? videoLoopStart,
    Duration? videoLoopEnd,
    bool? videoLoopActive,
    String? videoLoopStartRectangleId,
    String? videoLoopEndRectangleId,
    bool clearVideoLoopStart = false,
    bool clearVideoLoopEnd = false,
  }) {
    return Song(
      name: name ?? this.name,
      pdfPath: pdfPath ?? this.pdfPath,
      rectangles: rectangles ?? List.from(this.rectangles),
      videoUrl: videoUrl ?? this.videoUrl,
      metronomeSettings: metronomeSettings ?? this.metronomeSettings,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? DateTime.now(),
      videoLoopStart: clearVideoLoopStart ? null : (videoLoopStart ?? this.videoLoopStart),
      videoLoopEnd: clearVideoLoopEnd ? null : (videoLoopEnd ?? this.videoLoopEnd),
      videoLoopActive: videoLoopActive ?? this.videoLoopActive,
      videoLoopStartRectangleId: clearVideoLoopStart ? null : (videoLoopStartRectangleId ?? this.videoLoopStartRectangleId),
      videoLoopEndRectangleId: clearVideoLoopEnd ? null : (videoLoopEndRectangleId ?? this.videoLoopEndRectangleId),
    );
  }

  // Get song name from PDF filename (without extension)
  static String nameFromPdfPath(String pdfPath) {
    final filename = path.basename(pdfPath);
    final nameWithoutExtension = path.basenameWithoutExtension(filename);
    return nameWithoutExtension;
  }

  // Check if PDF file still exists
  bool get pdfExists {
    if (pdfPath == null) return false;
    return File(pdfPath!).existsSync();
  }

  // Get File object for PDF
  File? get pdfFile {
    if (pdfPath == null) return null;
    return File(pdfPath!);
  }

  // Get rectangles for a specific page
  List<DrawnRectangle> getRectanglesForPage(int pageNumber) {
    return rectangles.where((rect) => rect.pageNumber == pageNumber).toList();
  }

  // Get all rectangles with sync points (timestamps)
  List<DrawnRectangle> get syncedRectangles {
    return rectangles.where((rect) => rect.hasTimestamps).toList();
  }

  // Check if song has any content
  bool get hasContent {
    return pdfPath != null || 
           rectangles.isNotEmpty || 
           videoUrl != null;
  }

  // Serialize to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'pdfPath': pdfPath,
      'rectangles': rectangles.map((r) => r.toJson()).toList(),
      'videoUrl': videoUrl,
      'metronomeSettings': metronomeSettings.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
      'videoLoopStart': videoLoopStart?.inMilliseconds,
      'videoLoopEnd': videoLoopEnd?.inMilliseconds,
      'videoLoopActive': videoLoopActive,
      'videoLoopStartRectangleId': videoLoopStartRectangleId,
      'videoLoopEndRectangleId': videoLoopEndRectangleId,
    };
  }

  // Deserialize from JSON
  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      name: json['name'] as String,
      pdfPath: json['pdfPath'] as String?,
      rectangles: (json['rectangles'] as List<dynamic>?)
          ?.map((r) => DrawnRectangle.fromJson(r as Map<String, dynamic>))
          .toList() ?? [],
      videoUrl: json['videoUrl'] as String?,
      metronomeSettings: json['metronomeSettings'] != null
          ? MetronomeSettings.fromJson(json['metronomeSettings'] as Map<String, dynamic>)
          : MetronomeSettings(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastModified: DateTime.parse(json['lastModified'] as String),
      videoLoopStart: json['videoLoopStart'] != null
          ? Duration(milliseconds: json['videoLoopStart'] as int)
          : null,
      videoLoopEnd: json['videoLoopEnd'] != null
          ? Duration(milliseconds: json['videoLoopEnd'] as int)
          : null,
      videoLoopActive: json['videoLoopActive'] ?? false,
      videoLoopStartRectangleId: json['videoLoopStartRectangleId'] as String?,
      videoLoopEndRectangleId: json['videoLoopEndRectangleId'] as String?,
    );
  }

  // Convert to JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }

  // Create from JSON string
  factory Song.fromJsonString(String jsonString) {
    return Song.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  @override
  String toString() {
    return 'Song(name: $name, pdfPath: $pdfPath, rectangles: ${rectangles.length}, '
           'videoUrl: $videoUrl, syncedRects: ${syncedRectangles.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Song && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;
}