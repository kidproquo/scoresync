import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../utils/timestamp_tree.dart';
import 'rectangle_provider.dart';
import 'metronome_provider.dart';
import 'score_provider.dart';
import 'app_mode_provider.dart';

class BeatSyncProvider extends ChangeNotifier {
  final BeatTree _beatTree = BeatTree();
  SyncPoint<int>? _activeSyncPoint;

  RectangleProvider? _rectangleProvider;
  MetronomeProvider? _metronomeProvider;
  ScoreProvider? _scoreProvider;
  AppModeProvider? _appModeProvider;

  SyncPoint<int>? get activeSyncPoint => _activeSyncPoint;
  List<SyncPoint<int>> get allSyncPoints => _beatTree.getAllInOrder();
  bool get hasSyncPoints => !_beatTree.isEmpty;

  void setDependencies(
    RectangleProvider rectangleProvider,
    MetronomeProvider metronomeProvider,
    ScoreProvider scoreProvider,
    AppModeProvider appModeProvider,
  ) {
    _rectangleProvider = rectangleProvider;
    _metronomeProvider = metronomeProvider;
    _scoreProvider = scoreProvider;
    _appModeProvider = appModeProvider;

    _metronomeProvider!.setOnBeatCallback(_onBeatChanged);

    _rectangleProvider!.addListener(_rebuildSyncPoints);

    _appModeProvider!.addListener(_onAppModeChanged);

    _rebuildSyncPoints();
  }

  @override
  void dispose() {
    _metronomeProvider?.setOnBeatCallback(null);
    _rectangleProvider?.removeListener(_rebuildSyncPoints);
    _appModeProvider?.removeListener(_onAppModeChanged);
    super.dispose();
  }

  void _rebuildSyncPoints() {
    if (_rectangleProvider == null) {
      developer.log('BeatSync: Cannot rebuild - RectangleProvider is null');
      return;
    }

    final allRectangles = _rectangleProvider!.allRectangles;

    final currentSyncCount = _beatTree.size;
    int expectedSyncCount = 0;
    for (final rectangle in allRectangles) {
      expectedSyncCount += rectangle.beatNumbers.length;
    }

    if (currentSyncCount == expectedSyncCount) {
      developer.log('BeatSync: Skipping rebuild - sync count unchanged ($currentSyncCount)');
      return;
    }

    _beatTree.clear();
    developer.log('BeatSync: Found ${allRectangles.length} total rectangles');

    int syncPointCount = 0;
    for (final rectangle in allRectangles) {
      developer.log('BeatSync: Rectangle ${rectangle.id} has ${rectangle.beatNumbers.length} beat numbers');
      for (final beatNumber in rectangle.beatNumbers) {
        final syncPoint = SyncPoint<int>(
          key: beatNumber,
          rectangle: rectangle,
          pageNumber: rectangle.pageNumber,
        );
        _beatTree.insert(syncPoint);
        syncPointCount++;
      }
    }

    developer.log('Rebuilt beat tree with $syncPointCount sync points from ${allRectangles.length} rectangles');
    notifyListeners();
  }

  void _onBeatChanged(int totalBeats) {
    if (_appModeProvider == null || _appModeProvider!.isDesignMode) {
      return;
    }
    if (_metronomeProvider == null) {
      return;
    }

    final newActivePoint = _beatTree.findActiveAt(totalBeats);

    if (_activeSyncPoint != newActivePoint) {
      _activeSyncPoint = newActivePoint;

      if (newActivePoint != null) {
        developer.log('🎵 Active beat sync: page ${newActivePoint.pageNumber} at beat ${newActivePoint.key} (current beat $totalBeats)');

        _rectangleProvider!.setActiveRectangle(newActivePoint.rectangle.id);

        if (_scoreProvider != null && _scoreProvider!.currentPageNumber != newActivePoint.pageNumber) {
          developer.log('📄 Auto-turning to page ${newActivePoint.pageNumber}');
          _scoreProvider!.goToPage(newActivePoint.pageNumber);
        }
      } else {
        developer.log('❌ No active beat sync at beat $totalBeats');
        _rectangleProvider!.setActiveRectangle(null);
      }

      notifyListeners();
    }
  }

  void _onAppModeChanged() {
    if (_appModeProvider!.isDesignMode && _activeSyncPoint != null) {
      _activeSyncPoint = null;
      _rectangleProvider?.setActiveRectangle(null);
      notifyListeners();
    }
  }

  List<SyncPoint<int>> getSyncPointsForPage(int pageNumber) {
    return allSyncPoints.where((point) => point.pageNumber == pageNumber).toList();
  }

  List<SyncPoint<int>> getSyncPointsInRange(int start, int end) {
    return _beatTree.findInRange(start, end);
  }

  SyncPoint<int>? getNextSyncPoint() {
    if (_metronomeProvider == null) return null;

    final currentBeat = _metronomeProvider!.totalBeats;
    final allPoints = allSyncPoints;

    for (final point in allPoints) {
      if (point.key > currentBeat) {
        return point;
      }
    }

    return null;
  }

  SyncPoint<int>? getPreviousSyncPoint() {
    if (_metronomeProvider == null) return null;

    final currentBeat = _metronomeProvider!.totalBeats;
    final allPoints = allSyncPoints.reversed;

    for (final point in allPoints) {
      if (point.key < currentBeat) {
        return point;
      }
    }

    return null;
  }
}