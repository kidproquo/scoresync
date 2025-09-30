import 'package:flutter/material.dart';
import '../../models/rectangle.dart';

class RectanglePainter extends CustomPainter {
  final List<DrawnRectangle> rectangles;
  final DrawnRectangle? currentDrawing;
  final Size pdfPageSize;
  final Size widgetSize;
  final bool isDesignMode;
  final String? activeRectangleId;
  final bool isBeatMode;
  final int beatsPerMeasure;
  final String? loopStartRectangleId;
  final String? loopEndRectangleId;

  RectanglePainter({
    required this.rectangles,
    this.currentDrawing,
    required this.pdfPageSize,
    required this.widgetSize,
    required this.isDesignMode,
    this.activeRectangleId,
    required this.isBeatMode,
    required this.beatsPerMeasure,
    this.loopStartRectangleId,
    this.loopEndRectangleId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = widgetSize.width / pdfPageSize.width;
    final scaleY = widgetSize.height / pdfPageSize.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final offsetX = (widgetSize.width - pdfPageSize.width * scale) / 2;
    final offsetY = (widgetSize.height - pdfPageSize.height * scale) / 2;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale, scale);

    // Draw existing rectangles
    for (final rectangle in rectangles) {
      _drawRectangle(canvas, rectangle);
    }

    // Draw current drawing rectangle
    if (currentDrawing != null) {
      _drawRectangle(canvas, currentDrawing!);
    }

    canvas.restore();
  }

  void _drawRectangle(Canvas canvas, DrawnRectangle rectangle) {
    final isActive = activeRectangleId == rectangle.id;
    final isLoopStart = loopStartRectangleId == rectangle.id;
    final isLoopEnd = loopEndRectangleId == rectangle.id;

    // In playback mode, active rectangles have no border, just fill
    if (isActive && !isDesignMode) {
      Color fillColor = Colors.yellow.withAlpha(80);

      // Override color for loop markers
      if (isLoopStart) {
        fillColor = Colors.green.withAlpha(100);
      } else if (isLoopEnd) {
        fillColor = Colors.red.withAlpha(100);
      }

      final fillPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill;
      canvas.drawRect(rectangle.rect, fillPaint);
    } else {
      // Draw border for non-active rectangles or design mode
      Color borderColor = rectangle.isSelected
          ? rectangle.color.withAlpha(255)
          : rectangle.color.withAlpha(180);

      // Override color for loop markers
      if (isLoopStart) {
        borderColor = Colors.green;
      } else if (isLoopEnd) {
        borderColor = Colors.red;
      }

      final paint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isDesignMode
            ? rectangle.strokeWidth
            : rectangle.strokeWidth * 0.5;  // Thinner border in playback mode

      canvas.drawRect(rectangle.rect, paint);

      // Draw fill for selected rectangles in design mode or loop markers
      if (rectangle.isSelected || isLoopStart || isLoopEnd) {
        Color fillColor = rectangle.color.withAlpha(30);

        if (isLoopStart) {
          fillColor = Colors.green.withAlpha(50);
        } else if (isLoopEnd) {
          fillColor = Colors.red.withAlpha(50);
        }

        final fillPaint = Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill;
        canvas.drawRect(rectangle.rect, fillPaint);
      }
    }

    // Draw handles for selected rectangles in design mode
    if (rectangle.isSelected && isDesignMode) {
      _drawHandles(canvas, rectangle);
    }

    if (isBeatMode) {
      // Badge drawing removed - badges now shown in sync bar only

      if (!rectangle.isSelected && rectangle.hasBeatNumbers && isDesignMode) {
        _drawBeatIndicator(canvas, rectangle);
      }
    } else {
      // Badge drawing removed - badges now shown in sync bar only

      if (!rectangle.isSelected && rectangle.hasTimestamps && isDesignMode) {
        _drawIndicator(canvas, rectangle, Colors.green, rectangle.timestamps.length);
      }
    }
  }

  void _drawIndicator(Canvas canvas, DrawnRectangle rectangle, Color color, int count) {
    final indicatorPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final indicatorRadius = 4.0;
    final indicatorPosition = Offset(
      rectangle.rect.right - indicatorRadius - 4,
      rectangle.rect.top + indicatorRadius + 4,
    );

    canvas.drawCircle(indicatorPosition, indicatorRadius, indicatorPaint);

    if (count > 1) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        indicatorPosition - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  void _drawHandles(Canvas canvas, DrawnRectangle rectangle) {
    const handleSize = 12.0; // Increased from 8.0
    const deleteSize = 24.0;

    // Draw resize handles (skip topLeft as it's for delete button)
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final handleBorderPaint = Paint()
      ..color = rectangle.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw resize handles (skip topLeft as it's for delete button)
    for (final handle in [RectangleHandle.topRight, RectangleHandle.bottomLeft, RectangleHandle.bottomRight]) {
      final handleRect = rectangle.getHandleRect(handle, size: handleSize);
      
      canvas.drawRect(handleRect, handlePaint);
      canvas.drawRect(handleRect, handleBorderPaint);
    }

    // Draw delete button at top-left
    _drawDeleteButton(canvas, rectangle, deleteSize);
  }

  void _drawDeleteButton(Canvas canvas, DrawnRectangle rectangle, double size) {
    final deleteRect = rectangle.getHandleRect(RectangleHandle.delete, deleteSize: size);
    
    // Draw red circular background
    final deletePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    
    final deleteBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(deleteRect.center, size / 2, deletePaint);
    canvas.drawCircle(deleteRect.center, size / 2, deleteBorderPaint);

    // Draw X icon
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final iconSize = size * 0.4;
    final center = deleteRect.center;
    
    // Draw X lines
    canvas.drawLine(
      Offset(center.dx - iconSize / 2, center.dy - iconSize / 2),
      Offset(center.dx + iconSize / 2, center.dy + iconSize / 2),
      iconPaint,
    );
    canvas.drawLine(
      Offset(center.dx + iconSize / 2, center.dy - iconSize / 2),
      Offset(center.dx - iconSize / 2, center.dy + iconSize / 2),
      iconPaint,
    );
  }

  void _drawBeatIndicator(Canvas canvas, DrawnRectangle rectangle) {
    final indicatorPaint = Paint()
      ..color = Colors.purple
      ..style = PaintingStyle.fill;

    final indicatorRadius = 4.0;
    final indicatorPosition = Offset(
      rectangle.rect.right - indicatorRadius - 4,
      rectangle.rect.top + indicatorRadius + 4,
    );

    canvas.drawCircle(indicatorPosition, indicatorRadius, indicatorPaint);

    if (rectangle.beatNumbers.length > 1) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${rectangle.beatNumbers.length}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        indicatorPosition - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(RectanglePainter oldDelegate) {
    return oldDelegate.rectangles != rectangles ||
        oldDelegate.currentDrawing != currentDrawing ||
        oldDelegate.pdfPageSize != pdfPageSize ||
        oldDelegate.widgetSize != widgetSize ||
        oldDelegate.isDesignMode != isDesignMode ||
        oldDelegate.isBeatMode != isBeatMode ||
        oldDelegate.beatsPerMeasure != beatsPerMeasure ||
        oldDelegate.activeRectangleId != activeRectangleId;
  }
}

class RectangleOverlay extends StatelessWidget {
  final List<DrawnRectangle> rectangles;
  final DrawnRectangle? currentDrawing;
  final Size pdfPageSize;
  final Size widgetSize;
  final bool isDesignMode;
  final Widget child;
  final bool isBeatMode;
  final int beatsPerMeasure;

  const RectangleOverlay({
    super.key,
    required this.rectangles,
    this.currentDrawing,
    required this.pdfPageSize,
    required this.widgetSize,
    required this.isDesignMode,
    required this.child,
    required this.isBeatMode,
    required this.beatsPerMeasure,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (rectangles.isNotEmpty || currentDrawing != null)
          Positioned.fill(
            child: CustomPaint(
              painter: RectanglePainter(
                rectangles: rectangles,
                currentDrawing: currentDrawing,
                pdfPageSize: pdfPageSize,
                widgetSize: widgetSize,
                isDesignMode: isDesignMode,
                isBeatMode: isBeatMode,
                beatsPerMeasure: beatsPerMeasure,
              ),
            ),
          ),
      ],
    );
  }
}