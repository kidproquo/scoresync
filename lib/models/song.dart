import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'rectangle.dart';
import '../providers/sync_provider.dart';

class Song {
  final String name;
  final String? pdfPath;
  final List<DrawnRectangle> rectangles;
  final String? videoUrl;
  final List<SyncPoint> syncPoints;
  final DateTime createdAt;
  final DateTime lastModified;

  Song({
    required this.name,
    this.pdfPath,
    List<DrawnRectangle>? rectangles,
    this.videoUrl,
    List<SyncPoint>? syncPoints,
    DateTime? createdAt,
    DateTime? lastModified,
  })  : rectangles = rectangles ?? [],
        syncPoints = syncPoints ?? [],
        createdAt = createdAt ?? DateTime.now(),
        lastModified = lastModified ?? DateTime.now();

  Song copyWith({
    String? name,
    String? pdfPath,
    List<DrawnRectangle>? rectangles,
    String? videoUrl,
    List<SyncPoint>? syncPoints,
    DateTime? createdAt,
    DateTime? lastModified,
  }) {
    return Song(
      name: name ?? this.name,
      pdfPath: pdfPath ?? this.pdfPath,
      rectangles: rectangles ?? List.from(this.rectangles),
      videoUrl: videoUrl ?? this.videoUrl,
      syncPoints: syncPoints ?? List.from(this.syncPoints),
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? DateTime.now(),
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

  // Get all sync points sorted by timestamp
  List<SyncPoint> get sortedSyncPoints {
    final sorted = List<SyncPoint>.from(syncPoints);
    sorted.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return sorted;
  }

  // Check if song has any content
  bool get hasContent {
    return pdfPath != null || 
           rectangles.isNotEmpty || 
           videoUrl != null || 
           syncPoints.isNotEmpty;
  }

  // Serialize to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'pdfPath': pdfPath,
      'rectangles': rectangles.map((r) => r.toJson()).toList(),
      'videoUrl': videoUrl,
      'syncPoints': syncPoints.map((s) => s.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
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
      syncPoints: (json['syncPoints'] as List<dynamic>?)
          ?.map((s) => SyncPoint.fromJson(s as Map<String, dynamic>))
          .toList() ?? [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastModified: DateTime.parse(json['lastModified'] as String),
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
           'videoUrl: $videoUrl, syncPoints: ${syncPoints.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Song && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;
}