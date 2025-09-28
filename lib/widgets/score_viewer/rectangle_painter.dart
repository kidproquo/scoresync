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

  RectanglePainter({
    required this.rectangles,
    this.currentDrawing,
    required this.pdfPageSize,
    required this.widgetSize,
    required this.isDesignMode,
    this.activeRectangleId,
    required this.isBeatMode,
    required this.beatsPerMeasure,
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

    // In playback mode, active rectangles have no border, just fill
    if (isActive && !isDesignMode) {
      final fillPaint = Paint()
        ..color = Colors.yellow.withAlpha(80)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rectangle.rect, fillPaint);
    } else {
      // Draw border for non-active rectangles or design mode
      final paint = Paint()
        ..color = rectangle.isSelected
            ? rectangle.color.withAlpha(255)
            : rectangle.color.withAlpha(180)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isDesignMode
            ? rectangle.strokeWidth
            : rectangle.strokeWidth * 0.5;  // Thinner border in playback mode

      canvas.drawRect(rectangle.rect, paint);

      // Draw fill for selected rectangles in design mode
      if (rectangle.isSelected) {
        final fillPaint = Paint()
          ..color = rectangle.color.withAlpha(30)
          ..style = PaintingStyle.fill;
        canvas.drawRect(rectangle.rect, fillPaint);
      }
    }

    // Draw handles for selected rectangles in design mode
    if (rectangle.isSelected && isDesignMode) {
      _drawHandles(canvas, rectangle);
    }

    if (isBeatMode) {
      if ((rectangle.isSelected && isDesignMode) || (!isDesignMode && rectangle.hasBeatNumbers)) {
        if (rectangle.hasBeatNumbers) {
          _drawBeatBadges(canvas, rectangle);
        }
      }

      if (!rectangle.isSelected && rectangle.hasBeatNumbers && isDesignMode) {
        _drawBeatIndicator(canvas, rectangle);
      }
    } else {
      if ((rectangle.isSelected && isDesignMode) || (!isDesignMode && rectangle.hasTimestamps)) {
        if (rectangle.hasTimestamps) {
          _drawTimestampBadges(canvas, rectangle);
        }
      }

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

  void _drawTimestampBadges(Canvas canvas, DrawnRectangle rectangle) {
    if (rectangle.timestamps.isEmpty) return;

    const badgeHeight = 16.0;
    const badgePadding = 3.0;
    const badgeSpacing = 4.0; // Space between badges in the row

    final badgePaint = Paint()
      ..color = Colors.green.withAlpha(70)
      ..style = PaintingStyle.fill;

    final badgeBorderPaint = Paint()
      ..color = Colors.green.withAlpha(120)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // First pass: calculate all badge widths and total width
    final List<double> badgeWidths = [];
    double totalWidth = 0;

    for (final timestamp in rectangle.timestamps) {
      final timeText = _formatDuration(timestamp);

      final textPainter = TextPainter(
        text: TextSpan(
          text: timeText,
          style: TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(
                offset: Offset(0.5, 0.5),
                blurRadius: 2.0,
                color: Colors.black87,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final badgeWidth = textPainter.width + badgePadding * 2;
      badgeWidths.add(badgeWidth);
      totalWidth += badgeWidth;
    }

    // Add spacing between badges to total width
    totalWidth += badgeSpacing * (rectangle.timestamps.length - 1);

    // Calculate starting X position to center the row
    final startX = rectangle.rect.center.dx - (totalWidth / 2);

    // Calculate Y position to center vertically in the rectangle
    final startY = rectangle.rect.center.dy - (badgeHeight / 2);

    // Second pass: draw badges in a horizontal row
    double currentX = startX;

    for (int i = 0; i < rectangle.timestamps.length; i++) {
      final timestamp = rectangle.timestamps[i];
      final timeText = _formatDuration(timestamp);
      final badgeWidth = badgeWidths[i];

      // Create text painter for drawing
      final textPainter = TextPainter(
        text: TextSpan(
          text: timeText,
          style: TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(
                offset: Offset(0.5, 0.5),
                blurRadius: 2.0,
                color: Colors.black87,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final badgeRect = Rect.fromLTWH(
        currentX,
        startY,
        badgeWidth,
        badgeHeight,
      );

      // Draw badge background
      canvas.drawRRect(
        RRect.fromRectAndRadius(badgeRect, const Radius.circular(10)),
        badgePaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(badgeRect, const Radius.circular(10)),
        badgeBorderPaint,
      );

      // Draw text
      textPainter.paint(
        canvas,
        Offset(
          badgeRect.left + badgePadding,
          badgeRect.top + (badgeHeight - textPainter.height) / 2,
        ),
      );

      currentX += badgeWidth + badgeSpacing;
    }
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

  void _drawBeatBadges(Canvas canvas, DrawnRectangle rectangle) {
    if (rectangle.beatNumbers.isEmpty) return;

    const badgeHeight = 16.0;
    const badgePadding = 3.0;
    const badgeSpacing = 4.0;

    final badgePaint = Paint()
      ..color = Colors.purple.withAlpha(70)
      ..style = PaintingStyle.fill;

    final badgeBorderPaint = Paint()
      ..color = Colors.purple.withAlpha(120)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final List<double> badgeWidths = [];
    double totalWidth = 0;

    for (final beatNumber in rectangle.beatNumbers) {
      final String beatText;
      if (beatNumber == 0) {
        beatText = 'M0:B0';
      } else {
        final measureNumber = ((beatNumber - 1) ~/ beatsPerMeasure) + 1;
        final beatInMeasure = ((beatNumber - 1) % beatsPerMeasure) + 1;
        beatText = 'M$measureNumber:B$beatInMeasure';
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: beatText,
          style: TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(
                offset: Offset(0.5, 0.5),
                blurRadius: 2.0,
                color: Colors.black87,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final badgeWidth = textPainter.width + badgePadding * 2;
      badgeWidths.add(badgeWidth);
      totalWidth += badgeWidth;
    }

    totalWidth += badgeSpacing * (rectangle.beatNumbers.length - 1);

    final startX = rectangle.rect.center.dx - (totalWidth / 2);
    final startY = rectangle.rect.center.dy - (badgeHeight / 2);

    double currentX = startX;

    for (int i = 0; i < rectangle.beatNumbers.length; i++) {
      final beatNumber = rectangle.beatNumbers[i];
      final String beatText;
      if (beatNumber == 0) {
        beatText = 'M0:B0';
      } else {
        final measureNumber = ((beatNumber - 1) ~/ beatsPerMeasure) + 1;
        final beatInMeasure = ((beatNumber - 1) % beatsPerMeasure) + 1;
        beatText = 'M$measureNumber:B$beatInMeasure';
      }
      final badgeWidth = badgeWidths[i];

      final textPainter = TextPainter(
        text: TextSpan(
          text: beatText,
          style: TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(
                offset: Offset(0.5, 0.5),
                blurRadius: 2.0,
                color: Colors.black87,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final badgeRect = Rect.fromLTWH(
        currentX,
        startY,
        badgeWidth,
        badgeHeight,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(badgeRect, const Radius.circular(10)),
        badgePaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(badgeRect, const Radius.circular(10)),
        badgeBorderPaint,
      );

      textPainter.paint(
        canvas,
        Offset(
          badgeRect.left + badgePadding,
          badgeRect.top + (badgeHeight - textPainter.height) / 2,
        ),
      );

      currentX += badgeWidth + badgeSpacing;
    }
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