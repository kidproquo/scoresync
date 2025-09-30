import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      
      if (handle == RectangleHandle.delete && isDesignMode && rectangle.isSelected) {
        rectangleProvider.deleteSelectedRectangle();
        return;
      }
      // Badge tap detection removed - badges now in sync bar only

      // Always allow rectangle selection in both modes for sync bar display
      rectangleProvider.selectRectangle(rectangle);

      if (isDesignMode) {
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






  @override
  Widget build(BuildContext context) {
    return Consumer6<RectangleProvider, AppModeProvider, UiStateProvider, MetronomeProvider, BeatSyncProvider, VideoProvider>(
      builder: (context, rectangleProvider, appModeProvider, uiStateProvider, metronomeProvider, beatSyncProvider, videoProvider, _) {
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
                        loopStartRectangleId: isBeatMode
                            ? metronomeProvider.loopStartRectangleId
                            : videoProvider.loopStartRectangleId,
                        loopEndRectangleId: isBeatMode
                            ? metronomeProvider.loopEndRectangleId
                            : videoProvider.loopEndRectangleId,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }
}