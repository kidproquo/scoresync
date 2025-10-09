import 'dart:ui';

class MeasureDetectionResult {
  final String originalFilename;
  final List<PageMeasures> pages;
  final int totalPages;
  final bool success;

  MeasureDetectionResult({
    required this.originalFilename,
    required this.pages,
    required this.totalPages,
    required this.success,
  });

  factory MeasureDetectionResult.fromJson(Map<String, dynamic> json) {
    return MeasureDetectionResult(
      originalFilename: json['original_filename'] ?? '',
      pages: (json['pages'] as List?)
          ?.map((p) => PageMeasures.fromJson(p))
          .toList() ?? [],
      totalPages: json['total_pages'] ?? 0,
      success: json['success'] ?? false,
    );
  }
}

class PageMeasures {
  final int pageNumber;
  final int width;
  final int height;
  final String imageFilename;
  final List<MeasureRect> systemMeasures;

  PageMeasures({
    required this.pageNumber,
    required this.width,
    required this.height,
    required this.imageFilename,
    required this.systemMeasures,
  });

  factory PageMeasures.fromJson(Map<String, dynamic> json) {
    return PageMeasures(
      pageNumber: json['page_number'] ?? 0,
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
      imageFilename: json['image_filename'] ?? '',
      systemMeasures: (json['system_measures'] as List?)
          ?.map((m) => MeasureRect.fromJson(m))
          .toList() ?? [],
    );
  }
}

class MeasureRect {
  final int left;
  final int top;
  final int right;
  final int bottom;

  MeasureRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  factory MeasureRect.fromJson(Map<String, dynamic> json) {
    return MeasureRect(
      left: json['left'] ?? 0,
      top: json['top'] ?? 0,
      right: json['right'] ?? 0,
      bottom: json['bottom'] ?? 0,
    );
  }

  // Convert to Flutter Rect with scaling
  Rect toRect(double scaleX, double scaleY) {
    return Rect.fromLTRB(
      left * scaleX,
      top * scaleY,
      right * scaleX,
      bottom * scaleY,
    );
  }
}