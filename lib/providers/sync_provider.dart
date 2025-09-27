import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../utils/timestamp_tree.dart';
import 'rectangle_provider.dart';
import 'video_provider.dart';
import 'score_provider.dart';
import 'app_mode_provider.dart';

/// Provider for managing sync points and playback synchronization
class SyncProvider extends ChangeNotifier {
  final TimestampTree _timestampTree = TimestampTree();
  SyncPoint<Duration>? _activeSyncPoint;
  
  // Dependencies
  RectangleProvider? _rectangleProvider;
  VideoProvider? _videoProvider;
  ScoreProvider? _scoreProvider;
  AppModeProvider? _appModeProvider;

  SyncPoint<Duration>? get activeSyncPoint => _activeSyncPoint;
  List<SyncPoint<Duration>> get allSyncPoints => _timestampTree.getAllInOrder();
  bool get hasSyncPoints => !_timestampTree.isEmpty;

  void setDependencies(
    RectangleProvider rectangleProvider,
    VideoProvider videoProvider,
    ScoreProvider scoreProvider,
    AppModeProvider appModeProvider,
  ) {
    _rectangleProvider = rectangleProvider;
    _videoProvider = videoProvider;
    _scoreProvider = scoreProvider;
    _appModeProvider = appModeProvider;
    
    // Listen to video position changes
    _videoProvider!.addListener(_onVideoPositionChanged);
    
    // Rebuild sync points when rectangles change
    _rectangleProvider!.addListener(_rebuildSyncPoints);
    
    // Listen to app mode changes
    _appModeProvider!.addListener(_onAppModeChanged);
    
    _rebuildSyncPoints();
  }

  @override
  void dispose() {
    _videoProvider?.removeListener(_onVideoPositionChanged);
    _rectangleProvider?.removeListener(_rebuildSyncPoints);
    _appModeProvider?.removeListener(_onAppModeChanged);
    super.dispose();
  }

  /// Rebuild sync points from all rectangles with timestamps
  void _rebuildSyncPoints() {
    // Only rebuild if rectangles actually changed, not just active rectangle
    if (_rectangleProvider == null) {
      developer.log('Sync: Cannot rebuild - RectangleProvider is null');
      return;
    }
    
    final allRectangles = _rectangleProvider!.allRectangles;
    
    // Check if we need to rebuild (compare rectangle count and timestamps)
    final currentSyncCount = _timestampTree.size;
    int expectedSyncCount = 0;
    for (final rectangle in allRectangles) {
      expectedSyncCount += rectangle.timestamps.length;
    }
    
    // Only rebuild if the number of sync points has changed
    if (currentSyncCount == expectedSyncCount) {
      developer.log('Sync: Skipping rebuild - sync count unchanged ($currentSyncCount)');
      return;
    }
    
    _timestampTree.clear();
    developer.log('Sync: Found ${allRectangles.length} total rectangles');
    
    int syncPointCount = 0;
    for (final rectangle in allRectangles) {
      developer.log('Sync: Rectangle ${rectangle.id} has ${rectangle.timestamps.length} timestamps');
      for (final timestamp in rectangle.timestamps) {
        final syncPoint = SyncPoint<Duration>(
          key: timestamp,
          rectangle: rectangle,
          pageNumber: rectangle.pageNumber,
        );
        _timestampTree.insert(syncPoint);
        syncPointCount++;
      }
    }
    
    developer.log('Rebuilt sync tree with $syncPointCount sync points from ${allRectangles.length} rectangles');
    notifyListeners();
  }

  /// Called when video position changes
  void _onVideoPositionChanged() {
    // Only track in playback mode
    if (_appModeProvider == null || _appModeProvider!.isDesignMode) {
      return;
    }
    if (_videoProvider == null) {
      return;
    }
    
    final currentPosition = _videoProvider!.currentPosition;
    
    // Don't require video to be playing - track position changes even when paused
    
    final newActivePoint = _timestampTree.findActiveAt(currentPosition);
    
    if (_activeSyncPoint != newActivePoint) {
      _activeSyncPoint = newActivePoint;
      
      if (newActivePoint != null) {
        developer.log('🎯 Active sync: page ${newActivePoint.pageNumber} at ${_formatDuration(newActivePoint.key)} (video at ${_formatDuration(currentPosition)})');

        _rectangleProvider!.setActiveRectangle(newActivePoint.rectangle.id);
        
        // Check if we need to change pages
        if (_scoreProvider != null && _scoreProvider!.currentPageNumber != newActivePoint.pageNumber) {
          developer.log('📄 Auto-turning to page ${newActivePoint.pageNumber}');
          _scoreProvider!.goToPage(newActivePoint.pageNumber);
        }
      } else {
        developer.log('❌ No active sync point at position ${_formatDuration(currentPosition)}');
        // Clear active rectangle
        _rectangleProvider!.setActiveRectangle(null);
      }
      
      notifyListeners();
    }
  }
  
  /// Called when app mode changes
  void _onAppModeChanged() {
    // Clear active sync point when switching to design mode
    if (_appModeProvider!.isDesignMode && _activeSyncPoint != null) {
      _activeSyncPoint = null;
      _rectangleProvider?.setActiveRectangle(null);
      notifyListeners();
    }
  }

  List<SyncPoint<Duration>> getSyncPointsForPage(int pageNumber) {
    return allSyncPoints.where((point) => point.pageNumber == pageNumber).toList();
  }

  List<SyncPoint<Duration>> getSyncPointsInRange(Duration start, Duration end) {
    return _timestampTree.findInRange(start, end);
  }

  SyncPoint<Duration>? getNextSyncPoint() {
    if (_videoProvider == null) return null;

    final currentPosition = _videoProvider!.currentPosition;
    final allPoints = allSyncPoints;

    for (final point in allPoints) {
      if (point.key > currentPosition) {
        return point;
      }
    }

    return null;
  }

  SyncPoint<Duration>? getPreviousSyncPoint() {
    if (_videoProvider == null) return null;

    final currentPosition = _videoProvider!.currentPosition;
    final allPoints = allSyncPoints.reversed;

    for (final point in allPoints) {
      if (point.key < currentPosition) {
        return point;
      }
    }

    return null;
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