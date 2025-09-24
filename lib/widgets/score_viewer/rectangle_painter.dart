import 'package:flutter/material.dart';
import '../../models/rectangle.dart';

class RectanglePainter extends CustomPainter {
  final List<DrawnRectangle> rectangles;
  final DrawnRectangle? currentDrawing;
  final Size pdfPageSize;
  final Size widgetSize;
  final bool isDesignMode;
  final String? activeRectangleId;

  RectanglePainter({
    required this.rectangles,
    this.currentDrawing,
    required this.pdfPageSize,
    required this.widgetSize,
    required this.isDesignMode,
    this.activeRectangleId,
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
    
    final paint = Paint()
      ..color = rectangle.isSelected 
          ? rectangle.color.withAlpha(255)
          : isActive
              ? Colors.yellow.withAlpha(255)  // Highlight active rectangles in yellow
              : rectangle.color.withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isActive 
          ? rectangle.strokeWidth * 2  // Thicker border for active
          : rectangle.strokeWidth;

    canvas.drawRect(rectangle.rect, paint);

    // Draw fill for selected or active rectangles
    if (rectangle.isSelected) {
      final fillPaint = Paint()
        ..color = rectangle.color.withAlpha(30)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rectangle.rect, fillPaint);
    } else if (isActive && !isDesignMode) {
      // Highlight active rectangle during playback
      final fillPaint = Paint()
        ..color = Colors.yellow.withAlpha(50)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rectangle.rect, fillPaint);
    }

    // Draw handles for selected rectangles in design mode
    if (rectangle.isSelected && isDesignMode) {
      _drawHandles(canvas, rectangle);
    }

    // Draw timestamp badges inside selected rectangles OR in playback mode for rectangles with timestamps
    if ((rectangle.isSelected && isDesignMode) || (!isDesignMode && rectangle.hasTimestamps)) {
      if (rectangle.hasTimestamps) {
        _drawTimestampBadges(canvas, rectangle);
      }
    }

    // Draw timestamp indicator if rectangle has timestamps (when not selected in design mode)
    if (!rectangle.isSelected && rectangle.hasTimestamps && isDesignMode) {
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

    // Draw resize handles (skip topLeft as it's for delete button)
    for (final handle in [RectangleHandle.topRight, RectangleHandle.bottomLeft, RectangleHandle.bottomRight]) {
      final handleRect = rectangle.getHandleRect(handle, size: handleSize);
      
      canvas.drawRect(handleRect, handlePaint);
      canvas.drawRect(handleRect, handleBorderPaint);
    }

    // Draw delete button at top-left
    _drawDeleteButton(canvas, rectangle, deleteSize);
    
    // Draw sync button at center of top edge
    _drawSyncButton(canvas, rectangle, deleteSize);
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

  void _drawSyncButton(Canvas canvas, DrawnRectangle rectangle, double size) {
    final syncRect = rectangle.getHandleRect(RectangleHandle.sync, deleteSize: size);
    
    // Draw blue circular background
    final syncPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    
    final syncBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(syncRect.center, size / 2, syncPaint);
    canvas.drawCircle(syncRect.center, size / 2, syncBorderPaint);

    // Draw sync icon (link/chain icon)
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final iconSize = size * 0.4;
    final center = syncRect.center;
    
    // Draw chain link icon
    final linkSize = iconSize * 0.7;
    
    // Left oval
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - linkSize * 0.3, center.dy),
        width: linkSize * 0.6,
        height: linkSize,
      ),
      iconPaint,
    );
    
    // Right oval
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + linkSize * 0.3, center.dy),
        width: linkSize * 0.6,
        height: linkSize,
      ),
      iconPaint,
    );
  }

  void _drawTimestampBadges(Canvas canvas, DrawnRectangle rectangle) {
    if (rectangle.timestamps.isEmpty) return;
    
    const badgeHeight = 16.0; // Reduced from 20.0 to match smaller font
    const badgePadding = 3.0; // Reduced from 4.0 for more compact badges
    const badgeSpacing = 2.0;
    
    final badgePaint = Paint()
      ..color = Colors.green.withAlpha(70) // Very transparent - about 27% opacity
      ..style = PaintingStyle.fill;

    final badgeBorderPaint = Paint()
      ..color = Colors.green.withAlpha(120) // More transparent border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    // Calculate starting position (below the action buttons area)
    const buttonSize = 24.0; // Size of delete/sync buttons
    final startX = rectangle.rect.left + badgePadding;
    final startY = rectangle.rect.top + buttonSize + badgePadding * 2;
    
    double currentY = startY;
    
    for (int i = 0; i < rectangle.timestamps.length; i++) {
      final timestamp = rectangle.timestamps[i];
      final timeText = _formatDuration(timestamp);
      
      // Create text painter for measuring
      final textPainter = TextPainter(
        text: TextSpan(
          text: timeText,
          style: TextStyle(
            color: Colors.white,
            fontSize: 9, // Reduced from 11 for smaller badges
            fontWeight: FontWeight.bold, // Slightly bolder for better readability
            shadows: const [
              Shadow(
                offset: Offset(0.5, 0.5),
                blurRadius: 2.0,
                color: Colors.black87, // Stronger shadow for better contrast
              ),
            ], // Add shadow for better contrast
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      final badgeWidth = textPainter.width + badgePadding * 2;
      final badgeRect = Rect.fromLTWH(
        startX,
        currentY,
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
      
      currentY += badgeHeight + badgeSpacing;
      
      // Don't draw badges outside the rectangle
      if (currentY + badgeHeight > rectangle.rect.bottom - badgePadding) {
        break;
      }
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