import 'package:flutter/material.dart';
import 'dart:developer' as developer;

class SyncPoint {
  final String id;
  final int pageNumber;
  final Rect rectangle;
  final Duration timestamp;
  final DateTime createdAt;

  SyncPoint({
    required this.id,
    required this.pageNumber,
    required this.rectangle,
    required this.timestamp,
    required this.createdAt,
  });

  SyncPoint copyWith({
    String? id,
    int? pageNumber,
    Rect? rectangle,
    Duration? timestamp,
    DateTime? createdAt,
  }) {
    return SyncPoint(
      id: id ?? this.id,
      pageNumber: pageNumber ?? this.pageNumber,
      rectangle: rectangle ?? this.rectangle,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pageNumber': pageNumber,
      'rectangle': {
        'left': rectangle.left,
        'top': rectangle.top,
        'right': rectangle.right,
        'bottom': rectangle.bottom,
      },
      'timestamp': timestamp.inMilliseconds,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SyncPoint.fromJson(Map<String, dynamic> json) {
    final rectJson = json['rectangle'] as Map<String, dynamic>;
    return SyncPoint(
      id: json['id'] as String,
      pageNumber: json['pageNumber'] as int,
      rectangle: Rect.fromLTRB(
        rectJson['left'] as double,
        rectJson['top'] as double,
        rectJson['right'] as double,
        rectJson['bottom'] as double,
      ),
      timestamp: Duration(milliseconds: json['timestamp'] as int),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class SyncProvider extends ChangeNotifier {
  final List<SyncPoint> _syncPoints = [];
  SyncPoint? _selectedSyncPoint;
  SyncPoint? _activeSyncPoint;

  List<SyncPoint> get syncPoints => List.unmodifiable(_syncPoints);
  SyncPoint? get selectedSyncPoint => _selectedSyncPoint;
  SyncPoint? get activeSyncPoint => _activeSyncPoint;
  int get syncPointCount => _syncPoints.length;
  bool get hasSyncPoints => _syncPoints.isNotEmpty;

  List<SyncPoint> getSyncPointsForPage(int pageNumber) {
    return _syncPoints.where((point) => point.pageNumber == pageNumber).toList();
  }

  void addSyncPoint(SyncPoint syncPoint) {
    _syncPoints.add(syncPoint);
    _syncPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    developer.log('Added sync point at ${_formatDuration(syncPoint.timestamp)} on page ${syncPoint.pageNumber}');
    notifyListeners();
  }

  void removeSyncPoint(String id) {
    final index = _syncPoints.indexWhere((point) => point.id == id);
    if (index != -1) {
      final removedPoint = _syncPoints.removeAt(index);
      
      if (_selectedSyncPoint?.id == id) {
        _selectedSyncPoint = null;
      }
      if (_activeSyncPoint?.id == id) {
        _activeSyncPoint = null;
      }
      
      developer.log('Removed sync point at ${_formatDuration(removedPoint.timestamp)}');
      notifyListeners();
    }
  }

  void updateSyncPoint(String id, {
    int? pageNumber,
    Rect? rectangle,
    Duration? timestamp,
  }) {
    final index = _syncPoints.indexWhere((point) => point.id == id);
    if (index != -1) {
      final oldPoint = _syncPoints[index];
      final updatedPoint = oldPoint.copyWith(
        pageNumber: pageNumber,
        rectangle: rectangle,
        timestamp: timestamp,
      );
      
      _syncPoints[index] = updatedPoint;
      _syncPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      if (_selectedSyncPoint?.id == id) {
        _selectedSyncPoint = updatedPoint;
      }
      if (_activeSyncPoint?.id == id) {
        _activeSyncPoint = updatedPoint;
      }
      
      developer.log('Updated sync point $id');
      notifyListeners();
    }
  }

  void selectSyncPoint(String? id) {
    if (id == null) {
      _selectedSyncPoint = null;
    } else {
      _selectedSyncPoint = _syncPoints.firstWhere(
        (point) => point.id == id,
        orElse: () => _selectedSyncPoint!,
      );
    }
    developer.log('Selected sync point: ${_selectedSyncPoint?.id ?? 'none'}');
    notifyListeners();
  }

  void setActiveSyncPoint(Duration currentPosition) {
    SyncPoint? newActivePoint;
    
    for (final point in _syncPoints) {
      if (point.timestamp <= currentPosition) {
        newActivePoint = point;
      } else {
        break;
      }
    }
    
    if (_activeSyncPoint != newActivePoint) {
      _activeSyncPoint = newActivePoint;
      if (newActivePoint != null) {
        developer.log('Active sync point: page ${newActivePoint.pageNumber} at ${_formatDuration(newActivePoint.timestamp)}');
      }
      notifyListeners();
    }
  }

  void clearActiveSyncPoint() {
    if (_activeSyncPoint != null) {
      _activeSyncPoint = null;
      notifyListeners();
    }
  }

  void clearAllSyncPoints() {
    _syncPoints.clear();
    _selectedSyncPoint = null;
    _activeSyncPoint = null;
    developer.log('Cleared all sync points');
    notifyListeners();
  }

  void loadSyncPoints(List<SyncPoint> syncPoints) {
    clearAllSyncPoints();
    _syncPoints.addAll(syncPoints);
    _syncPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    developer.log('Loaded ${syncPoints.length} sync points');
    notifyListeners();
  }

  SyncPoint? findSyncPointAt(int pageNumber, Offset position, {double tolerance = 10.0}) {
    final pagePoints = getSyncPointsForPage(pageNumber);
    
    for (final point in pagePoints) {
      if (point.rectangle.contains(position)) {
        return point;
      }
      
      final expandedRect = point.rectangle.inflate(tolerance);
      if (expandedRect.contains(position)) {
        return point;
      }
    }
    
    return null;
  }

  List<SyncPoint> getSyncPointsInTimeRange(Duration start, Duration end) {
    return _syncPoints.where((point) {
      return point.timestamp >= start && point.timestamp <= end;
    }).toList();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      String hours = twoDigits(duration.inHours);
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}