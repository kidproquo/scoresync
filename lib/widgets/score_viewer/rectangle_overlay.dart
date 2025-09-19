import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/rectangle.dart';
import '../../providers/rectangle_provider.dart';
import '../../providers/app_mode_provider.dart';
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
    if (!isDesignMode) return;

    final localPoint = _transformPoint(details.localPosition);
    
    // Check if tapping on a handle
    if (rectangleProvider.selectedRectangle != null) {
      final handle = rectangleProvider.getHandleAt(localPoint);
      if (handle != null) {
        if (handle == RectangleHandle.delete) {
          // Delete the rectangle
          rectangleProvider.deleteSelectedRectangle();
          return;
        } else {
          // Start resizing (only for non-delete handles)
          rectangleProvider.startResizing(localPoint, handle);
          return;
        }
      }
    }

    // Check if tapping on a rectangle
    final rectangle = rectangleProvider.findRectangleAt(localPoint, widget.currentPageNumber);
    
    if (rectangle != null) {
      // Check if clicking on delete button of any rectangle
      final deleteHandle = rectangle.getHandleAt(localPoint);
      if (deleteHandle == RectangleHandle.delete) {
        rectangleProvider.selectRectangle(rectangle);
        rectangleProvider.deleteSelectedRectangle();
        return;
      }
      
      rectangleProvider.selectRectangle(rectangle);
      rectangleProvider.startMoving(localPoint);
    } else {
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
                onTapDown: isDesignMode
                    ? (details) => _handleTapDown(details, rectangleProvider, isDesignMode)
                    : null,
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