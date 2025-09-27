import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import '../../models/rectangle.dart';
import '../../providers/rectangle_provider.dart';
import '../../providers/app_mode_provider.dart';
import '../../providers/video_provider.dart';
import '../../providers/metronome_provider.dart';
import '../../providers/beat_sync_provider.dart';
import '../../providers/ui_state_provider.dart';
import '../../models/metronome_settings.dart';
import 'rectangle_painter.dart';

class InteractiveRectangleOverlay extends StatefulWidget {
  final Widget child;
  final int currentPageNumber;
  final Size pdfPageSize;

  const InteractiveRectangleOverlay({
    super.key,
    required this.child,
    required this.currentPageNumber,
    required this.pdfPageSize,
  });

  @override
  State<InteractiveRectangleOverlay> createState() => _InteractiveRectangleOverlayState();
}

class _InteractiveRectangleOverlayState extends State<InteractiveRectangleOverlay> {
  Size? _widgetSize;

  Offset _transformPoint(Offset screenPoint) {
    if (_widgetSize == null) return screenPoint;

    final scaleX = _widgetSize!.width / widget.pdfPageSize.width;
    final scaleY = _widgetSize!.height / widget.pdfPageSize.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final offsetX = (_widgetSize!.width - widget.pdfPageSize.width * scale) / 2;
    final offsetY = (_widgetSize!.height - widget.pdfPageSize.height * scale) / 2;

    return Offset(
      (screenPoint.dx - offsetX) / scale,
      (screenPoint.dy - offsetY) / scale,
    );
  }

  void _handleTapDown(TapDownDetails details, RectangleProvider rectangleProvider, bool isDesignMode) {
    final localPoint = _transformPoint(details.localPosition);
    
    // Check if tapping on a rectangle first
    final rectangle = rectangleProvider.findRectangleAt(localPoint, widget.currentPageNumber);
    
    if (rectangle != null) {
      final handle = rectangle.getHandleAt(localPoint);
      
      if (handle == RectangleHandle.delete && isDesignMode) {
        rectangleProvider.selectRectangle(rectangle);
        rectangleProvider.deleteSelectedRectangle();
        return;
      } else if (rectangle.hasTimestamps || rectangle.hasBeatNumbers) {
        final metronomeProvider = context.read<MetronomeProvider>();
        final isBeatMode = metronomeProvider.settings.mode == MetronomeMode.beat;

        if (isBeatMode && rectangle.hasBeatNumbers) {
          final tappedBeat = _getBeatNumberAtPoint(rectangle, localPoint, metronomeProvider);
          if (tappedBeat != null) {
            _handleBeatBadgeTap(tappedBeat, metronomeProvider);
            return;
          }
        } else if (!isBeatMode && rectangle.hasTimestamps) {
          final tappedTimestamp = _getTimestampAtPoint(rectangle, localPoint);
          if (tappedTimestamp != null) {
            _handleTimestampBadgeTap(tappedTimestamp);
            return;
          }
        }
      }
      
      if (isDesignMode) {
        rectangleProvider.selectRectangle(rectangle);
        
        if (handle != null && handle != RectangleHandle.delete) {
          // Start resizing for resize handles
          rectangleProvider.startResizing(localPoint, handle);
        } else {
          // Start moving
          rectangleProvider.startMoving(localPoint);
        }
      }
    } else if (isDesignMode) {
      // Start drawing new rectangle
      rectangleProvider.selectRectangle(null);
      rectangleProvider.startDrawing(localPoint, widget.currentPageNumber);
    }
  }

  void _handlePanUpdate(DragUpdateDetails details, RectangleProvider rectangleProvider) {
    final localPoint = _transformPoint(details.localPosition);

    switch (rectangleProvider.drawingMode) {
      case DrawingMode.drawing:
        rectangleProvider.updateDrawing(localPoint);
        break;
      case DrawingMode.moving:
        rectangleProvider.moveRectangle(localPoint);
        break;
      case DrawingMode.resizing:
        rectangleProvider.resizeRectangle(localPoint);
        break;
      default:
        break;
    }
  }

  void _handlePanEnd(DragEndDetails details, RectangleProvider rectangleProvider) {
    switch (rectangleProvider.drawingMode) {
      case DrawingMode.drawing:
        rectangleProvider.finishDrawing();
        break;
      case DrawingMode.moving:
        rectangleProvider.finishMoving();
        break;
      case DrawingMode.resizing:
        rectangleProvider.finishResizing();
        break;
      default:
        break;
    }
  }

  void _handleTimestampBadgeTap(Duration timestamp) {
    final videoProvider = context.read<VideoProvider>();
    final metronomeProvider = context.read<MetronomeProvider>();

    if (videoProvider.hasVideo) {
      developer.log('Timestamp badge tapped: seeking to ${_formatDuration(timestamp)}');

      metronomeProvider.stopMetronome();
      videoProvider.forcePause();
      videoProvider.seekTo(timestamp);
      Future.delayed(const Duration(milliseconds: 100), () {
        videoProvider.forcePause();
      });

      developer.log('Video paused at ${_formatDuration(timestamp)} - press play to start with metronome');
    }
  }

  void _handleBeatBadgeTap(int beatNumber, MetronomeProvider metronomeProvider) {
    developer.log('Beat badge tapped: seeking to beat $beatNumber');

    final beatsPerMeasure = metronomeProvider.settings.timeSignature.numerator;
    final measureNumber = ((beatNumber - 1) ~/ beatsPerMeasure) + 1;

    metronomeProvider.seekToMeasure(measureNumber);

    if (metronomeProvider.isPlaying) {
      metronomeProvider.stopMetronome();
    }

    developer.log('Metronome reset to measure $measureNumber - press play to start');
  }

  int? _getBeatNumberAtPoint(DrawnRectangle rectangle, Offset point, MetronomeProvider metronomeProvider) {
    if (rectangle.beatNumbers.isEmpty) return null;

    const badgeHeight = 16.0;
    const badgePadding = 3.0;
    const badgeSpacing = 4.0;

    final beatsPerMeasure = metronomeProvider.settings.timeSignature.numerator;
    final List<double> badgeWidths = [];
    double totalWidth = 0;

    for (final beatNumber in rectangle.beatNumbers) {
      final measureNumber = ((beatNumber - 1) ~/ beatsPerMeasure) + 1;
      final beatInMeasure = ((beatNumber - 1) % beatsPerMeasure) + 1;
      final beatText = 'M$measureNumber:B$beatInMeasure';
      final badgeWidth = beatText.length * 6.5 + badgePadding * 2;
      badgeWidths.add(badgeWidth);
      totalWidth += badgeWidth;
    }

    totalWidth += badgeSpacing * (rectangle.beatNumbers.length - 1);

    final startX = rectangle.rect.center.dx - (totalWidth / 2);
    final startY = rectangle.rect.center.dy - (badgeHeight / 2);

    double currentX = startX;

    for (int i = 0; i < rectangle.beatNumbers.length; i++) {
      final beatNumber = rectangle.beatNumbers[i];
      final badgeWidth = badgeWidths[i];

      final badgeRect = Rect.fromLTWH(
        currentX,
        startY,
        badgeWidth,
        badgeHeight,
      );

      if (badgeRect.contains(point)) {
        return beatNumber;
      }

      currentX += badgeWidth + badgeSpacing;
    }

    return null;
  }

  Duration? _getTimestampAtPoint(DrawnRectangle rectangle, Offset point) {
    if (rectangle.timestamps.isEmpty) return null;

    const badgeHeight = 16.0;
    const badgePadding = 3.0;
    const badgeSpacing = 4.0;

    // First pass: calculate all badge widths and total width (same logic as painter)
    final List<double> badgeWidths = [];
    double totalWidth = 0;

    for (final timestamp in rectangle.timestamps) {
      final timeText = _formatDuration(timestamp);
      // Estimate badge width
      final badgeWidth = timeText.length * 6.5 + badgePadding * 2;
      badgeWidths.add(badgeWidth);
      totalWidth += badgeWidth;
    }

    // Add spacing between badges to total width
    totalWidth += badgeSpacing * (rectangle.timestamps.length - 1);

    // Calculate starting X position to center the row
    final startX = rectangle.rect.center.dx - (totalWidth / 2);

    // Calculate Y position to center vertically in the rectangle
    final startY = rectangle.rect.center.dy - (badgeHeight / 2);

    // Second pass: check which badge was tapped
    double currentX = startX;

    for (int i = 0; i < rectangle.timestamps.length; i++) {
      final timestamp = rectangle.timestamps[i];
      final badgeWidth = badgeWidths[i];

      final badgeRect = Rect.fromLTWH(
        currentX,
        startY,
        badgeWidth,
        badgeHeight,
      );

      if (badgeRect.contains(point)) {
        return timestamp;
      }

      currentX += badgeWidth + badgeSpacing;
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

  @override
  Widget build(BuildContext context) {
    return Consumer5<RectangleProvider, AppModeProvider, UiStateProvider, MetronomeProvider, BeatSyncProvider>(
      builder: (context, rectangleProvider, appModeProvider, uiStateProvider, metronomeProvider, beatSyncProvider, _) {
        final isDesignMode = appModeProvider.isDesignMode;
        final isVideoDragging = uiStateProvider.isVideoDragging;
        final rectangles = rectangleProvider.getRectanglesForPage(widget.currentPageNumber);
        final isBeatMode = metronomeProvider.settings.mode == MetronomeMode.beat;


        return LayoutBuilder(
          builder: (context, constraints) {
            _widgetSize = constraints.biggest;

            return MouseRegion(
              cursor: isDesignMode 
                  ? SystemMouseCursors.precise
                  : SystemMouseCursors.basic,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: isVideoDragging ? null : (details) => _handleTapDown(details, rectangleProvider, isDesignMode),
                onPanUpdate: (isDesignMode && !isVideoDragging)
                    ? (details) => _handlePanUpdate(details, rectangleProvider)
                    : null,
                onPanEnd: (isDesignMode && !isVideoDragging)
                    ? (details) => _handlePanEnd(details, rectangleProvider)
                    : null,
                child: Stack(
                children: [
                  widget.child,
                  Positioned.fill(
                    child: CustomPaint(
                      painter: RectanglePainter(
                        rectangles: rectangles,
                        currentDrawing: rectangleProvider.currentDrawing,
                        pdfPageSize: widget.pdfPageSize,
                        widgetSize: _widgetSize!,
                        isDesignMode: isDesignMode,
                        activeRectangleId: rectangleProvider.activeRectangleId,
                        isBeatMode: isBeatMode,
                        beatsPerMeasure: metronomeProvider.settings.timeSignature.numerator,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
}