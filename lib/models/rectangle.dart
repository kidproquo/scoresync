import 'package:flutter/material.dart';

class DrawnRectangle {
  final String id;
  final Rect rect;
  final int pageNumber;
  final DateTime createdAt;
  final Color color;
  final double strokeWidth;
  bool isSelected;
  List<Duration> timestamps;

  DrawnRectangle({
    required this.id,
    required this.rect,
    required this.pageNumber,
    required this.createdAt,
    this.color = Colors.blue,
    this.strokeWidth = 2.0,
    this.isSelected = false,
    List<Duration>? timestamps,
  }) : timestamps = timestamps ?? [];

  DrawnRectangle copyWith({
    String? id,
    Rect? rect,
    int? pageNumber,
    DateTime? createdAt,
    Color? color,
    double? strokeWidth,
    bool? isSelected,
    List<Duration>? timestamps,
  }) {
    return DrawnRectangle(
      id: id ?? this.id,
      rect: rect ?? this.rect,
      pageNumber: pageNumber ?? this.pageNumber,
      createdAt: createdAt ?? this.createdAt,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isSelected: isSelected ?? this.isSelected,
      timestamps: timestamps ?? List.from(this.timestamps),
    );
  }

  bool contains(Offset point) {
    return rect.contains(point);
  }

  bool isNear(Offset point, {double tolerance = 10.0}) {
    final expandedRect = rect.inflate(tolerance);
    return expandedRect.contains(point);
  }

  Rect getHandleRect(RectangleHandle handle, {double size = 8.0, double deleteSize = 36.0}) {
    switch (handle) {
      case RectangleHandle.topLeft:
        // This is now the delete button location
        return Rect.fromCenter(
          center: rect.topLeft,
          width: deleteSize,
          height: deleteSize,
        );
      case RectangleHandle.topRight:
        return Rect.fromCenter(
          center: rect.topRight,
          width: size,
          height: size,
        );
      case RectangleHandle.bottomLeft:
        return Rect.fromCenter(
          center: rect.bottomLeft,
          width: size,
          height: size,
        );
      case RectangleHandle.bottomRight:
        return Rect.fromCenter(
          center: rect.bottomRight,
          width: size,
          height: size,
        );
      case RectangleHandle.delete:
        // Delete button is at top-left
        return Rect.fromCenter(
          center: rect.topLeft,
          width: deleteSize,
          height: deleteSize,
        );
      case RectangleHandle.sync:
        // Sync button is at center of top edge
        return Rect.fromCenter(
          center: Offset(rect.center.dx, rect.top),
          width: deleteSize,
          height: deleteSize,
        );
    }
  }

  RectangleHandle? getHandleAt(Offset point, {double size = 12.0, double deleteSize = 36.0}) {
    // Check action buttons first (they're larger)
    if (getHandleRect(RectangleHandle.delete, size: size, deleteSize: deleteSize).contains(point)) {
      return RectangleHandle.delete;
    }
    if (getHandleRect(RectangleHandle.sync, size: size, deleteSize: deleteSize).contains(point)) {
      return RectangleHandle.sync;
    }
    
    // Check resize handles
    for (final handle in [RectangleHandle.topRight, RectangleHandle.bottomLeft, RectangleHandle.bottomRight]) {
      if (getHandleRect(handle, size: size, deleteSize: deleteSize).contains(point)) {
        return handle;
      }
    }
    return null;
  }

  bool get hasTimestamps => timestamps.isNotEmpty;
  
  void addTimestamp(Duration timestamp) {
    // Check for duplicates within 10ms tolerance
    const tolerance = Duration(milliseconds: 10);

    for (final existing in timestamps) {
      final difference = (timestamp - existing).abs();
      if (difference <= tolerance) {
        // Timestamp is too close to an existing one, don't add
        return;
      }
    }

    // No duplicates found, add the timestamp
    timestamps.add(timestamp);
    timestamps.sort();
  }

  void removeTimestamp(Duration timestamp) {
    timestamps.remove(timestamp);
  }

  void clearTimestamps() {
    timestamps.clear();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rect': {
        'left': rect.left,
        'top': rect.top,
        'right': rect.right,
        'bottom': rect.bottom,
      },
      'pageNumber': pageNumber,
      'createdAt': createdAt.toIso8601String(),
      'color': ((color.a * 255).round() << 24) | 
               ((color.r * 255).round() << 16) | 
               ((color.g * 255).round() << 8) | 
               (color.b * 255).round(),
      'strokeWidth': strokeWidth,
      'timestamps': timestamps.map((t) => t.inMilliseconds).toList(),
    };
  }

  factory DrawnRectangle.fromJson(Map<String, dynamic> json) {
    final rectJson = json['rect'] as Map<String, dynamic>;
    return DrawnRectangle(
      id: json['id'] as String,
      rect: Rect.fromLTRB(
        rectJson['left'] as double,
        rectJson['top'] as double,
        rectJson['right'] as double,
        rectJson['bottom'] as double,
      ),
      pageNumber: json['pageNumber'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      color: Color(json['color'] as int),
      strokeWidth: json['strokeWidth'] as double,
      timestamps: (json['timestamps'] as List<dynamic>)
          .map((ms) => Duration(milliseconds: ms as int))
          .toList(),
    );
  }
}

enum RectangleHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  delete, // Special handle for delete button
  sync,   // Special handle for sync button
}

enum DrawingMode {
  none,
  drawing,
  selecting,
  moving,
  resizing,
}