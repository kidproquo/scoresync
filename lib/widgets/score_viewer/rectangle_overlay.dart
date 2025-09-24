import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import '../../models/rectangle.dart';
import '../../providers/rectangle_provider.dart';
import '../../providers/app_mode_provider.dart';
import '../../providers/video_provider.dart';
import '../../providers/metronome_provider.dart';
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
      } else if (handle == RectangleHandle.sync && isDesignMode) {
        // Handle sync button click
        _handleSyncButtonTap(rectangle);
        return;
      } else if (rectangle.hasTimestamps) {
        // Check if clicking on a timestamp badge (in both design and playback mode)
        final tappedTimestamp = _getTimestampAtPoint(rectangle, localPoint);
        if (tappedTimestamp != null) {
          _handleTimestampBadgeTap(tappedTimestamp);
          return;
        }
      }
      
      if (isDesignMode) {
        rectangleProvider.selectRectangle(rectangle);
        
        if (handle != null && handle != RectangleHandle.delete && handle != RectangleHandle.sync) {
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

  void _handleSyncButtonTap(DrawnRectangle rectangle) {
    final videoProvider = context.read<VideoProvider>();

    if (!videoProvider.hasVideo) {
      developer.log('No video loaded - cannot create sync point');
      return;
    }

    // Get current video position
    final currentPosition = videoProvider.currentPosition;

    // Check for duplicate within 10ms tolerance
    const tolerance = Duration(milliseconds: 10);
    for (final existing in rectangle.timestamps) {
      final difference = (currentPosition - existing).abs();
      if (difference <= tolerance) {
        developer.log('Sync point at ${_formatDuration(currentPosition)} is too close to existing sync point at ${_formatDuration(existing)} (within 10ms)');

        // Show feedback to user via SnackBar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sync point already exists at ${_formatDuration(existing)}'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    // No duplicates found, add the timestamp
    final updatedRectangle = rectangle.copyWith(
      timestamps: [...rectangle.timestamps, currentPosition],
    );

    // Update rectangle in provider
    final rectangleProvider = context.read<RectangleProvider>();
    rectangleProvider.updateRectangle(updatedRectangle);

    developer.log('Added sync point at ${_formatDuration(currentPosition)} to rectangle ${rectangle.id}');
  }

  void _handleTimestampBadgeTap(Duration timestamp) {
    final videoProvider = context.read<VideoProvider>();
    final metronomeProvider = context.read<MetronomeProvider>();
    
    if (videoProvider.hasVideo) {
      developer.log('Timestamp badge tapped: seeking to ${_formatDuration(timestamp)}');
      
      // Stop everything, force pause first, then seek to timestamp
      metronomeProvider.stopMetronome();
      videoProvider.forcePause();
      videoProvider.seekTo(timestamp);
      // Force pause again after seek to ensure it stays paused
      Future.delayed(const Duration(milliseconds: 100), () {
        videoProvider.forcePause();
      });
      
      developer.log('Video paused at ${_formatDuration(timestamp)} - press play to start with metronome');
    }
  }

  Duration? _getTimestampAtPoint(DrawnRectangle rectangle, Offset point) {
    if (rectangle.timestamps.isEmpty) return null;
    
    const badgeHeight = 16.0; // Reduced from 20.0 to match smaller font
    const badgePadding = 3.0; // Reduced from 4.0 for more compact badges
    const badgeSpacing = 2.0;
    const buttonSize = 24.0; // Size of delete/sync buttons
    
    final startX = rectangle.rect.left + badgePadding;
    final startY = rectangle.rect.top + buttonSize + badgePadding * 2;
    
    double currentY = startY;
    
    for (int i = 0; i < rectangle.timestamps.length; i++) {
      final timestamp = rectangle.timestamps[i];
      final timeText = _formatDuration(timestamp);
      
      // Estimate badge width (simplified calculation - reduced for smaller font)
      final badgeWidth = timeText.length * 6.5 + badgePadding * 2;
      final badgeRect = Rect.fromLTWH(
        startX,
        currentY,
        badgeWidth,
        badgeHeight,
      );
      
      if (badgeRect.contains(point)) {
        return timestamp;
      }
      
      currentY += badgeHeight + badgeSpacing;
      
      // Don't check badges outside the rectangle
      if (currentY + badgeHeight > rectangle.rect.bottom - badgePadding) {
        break;
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

  @override
  Widget build(BuildContext context) {
    return Consumer2<RectangleProvider, AppModeProvider>(
      builder: (context, rectangleProvider, appModeProvider, _) {
        final isDesignMode = appModeProvider.isDesignMode;
        final rectangles = rectangleProvider.getRectanglesForPage(widget.currentPageNumber);
        

        return LayoutBuilder(
          builder: (context, constraints) {
            _widgetSize = constraints.biggest;

            return MouseRegion(
              cursor: isDesignMode 
                  ? SystemMouseCursors.precise
                  : SystemMouseCursors.basic,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (details) => _handleTapDown(details, rectangleProvider, isDesignMode),
                onPanUpdate: isDesignMode
                    ? (details) => _handlePanUpdate(details, rectangleProvider)
                    : null,
                onPanEnd: isDesignMode
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