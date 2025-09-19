import 'package:flutter/material.dart';
import '../../models/rectangle.dart';

class RectanglePainter extends CustomPainter {
  final List<DrawnRectangle> rectangles;
  final DrawnRectangle? currentDrawing;
  final Size pdfPageSize;
  final Size widgetSize;
  final bool isDesignMode;

  RectanglePainter({
    required this.rectangles,
    this.currentDrawing,
    required this.pdfPageSize,
    required this.widgetSize,
    required this.isDesignMode,
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
    final paint = Paint()
      ..color = rectangle.isSelected 
          ? rectangle.color.withAlpha(255)
          : rectangle.color.withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = rectangle.strokeWidth;

    canvas.drawRect(rectangle.rect, paint);

    // Draw fill for selected rectangles
    if (rectangle.isSelected) {
      final fillPaint = Paint()
        ..color = rectangle.color.withAlpha(30)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rectangle.rect, fillPaint);
    }

    // Draw handles for selected rectangles in design mode
    if (rectangle.isSelected && isDesignMode) {
      _drawHandles(canvas, rectangle);
    }

    // Draw timestamp indicator if rectangle has timestamps
    if (rectangle.hasTimestamps) {
      _drawTimestampIndicator(canvas, rectangle);
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

    // Draw resize handles (topRight, bottomLeft, bottomRight)
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

  void _drawTimestampIndicator(Canvas canvas, DrawnRectangle rectangle) {
    final indicatorPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    final indicatorRadius = 4.0;
    final indicatorPosition = Offset(
      rectangle.rect.right - indicatorRadius - 4,
      rectangle.rect.top + indicatorRadius + 4,
    );

    canvas.drawCircle(indicatorPosition, indicatorRadius, indicatorPaint);

    // Draw timestamp count if multiple
    if (rectangle.timestamps.length > 1) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${rectangle.timestamps.length}',
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
        oldDelegate.isDesignMode != isDesignMode;
  }
}

class RectangleOverlay extends StatelessWidget {
  final List<DrawnRectangle> rectangles;
  final DrawnRectangle? currentDrawing;
  final Size pdfPageSize;
  final Size widgetSize;
  final bool isDesignMode;
  final Widget child;

  const RectangleOverlay({
    super.key,
    required this.rectangles,
    this.currentDrawing,
    required this.pdfPageSize,
    required this.widgetSize,
    required this.isDesignMode,
    required this.child,
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
              ),
            ),
          ),
      ],
    );
  }
}