# Auto-Detect Measures Implementation Plan

## Overview
Implement automatic measure detection for PDF scores using an external AI service. This feature will save users time by automatically creating rectangles for all detected measures in their sheet music.

## API Specification
- **Endpoint**: `https://dabba.princesamuel.me/symph/upload_and_predict`
- **Method**: POST (multipart/form-data)
- **Request**: PDF file upload
- **Response**: JSON with measure coordinates for each page

## Implementation Approach: Manual Button (Option B)

Users will manually trigger measure detection through a dedicated button in design mode. This gives users control and prevents unexpected rectangle creation.

## Detailed Implementation Steps

### Phase 1: Core Infrastructure

#### 1.1 Create Data Models
**File**: `lib/models/measure_detection.dart`

```dart
class MeasureDetectionResult {
  final String originalFilename;
  final List<PageMeasures> pages;
  final int totalPages;
  final bool success;

  MeasureDetectionResult({
    required this.originalFilename,
    required this.pages,
    required this.totalPages,
    required this.success,
  });

  factory MeasureDetectionResult.fromJson(Map<String, dynamic> json) {
    return MeasureDetectionResult(
      originalFilename: json['original_filename'] ?? '',
      pages: (json['pages'] as List?)
          ?.map((p) => PageMeasures.fromJson(p))
          .toList() ?? [],
      totalPages: json['total_pages'] ?? 0,
      success: json['success'] ?? false,
    );
  }
}

class PageMeasures {
  final int pageNumber;
  final int width;
  final int height;
  final String imageFilename;
  final List<MeasureRect> systemMeasures;

  PageMeasures({
    required this.pageNumber,
    required this.width,
    required this.height,
    required this.imageFilename,
    required this.systemMeasures,
  });

  factory PageMeasures.fromJson(Map<String, dynamic> json) {
    return PageMeasures(
      pageNumber: json['page_number'] ?? 0,
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
      imageFilename: json['image_filename'] ?? '',
      systemMeasures: (json['system_measures'] as List?)
          ?.map((m) => MeasureRect.fromJson(m))
          .toList() ?? [],
    );
  }
}

class MeasureRect {
  final int left;
  final int top;
  final int right;
  final int bottom;

  MeasureRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  factory MeasureRect.fromJson(Map<String, dynamic> json) {
    return MeasureRect(
      left: json['left'] ?? 0,
      top: json['top'] ?? 0,
      right: json['right'] ?? 0,
      bottom: json['bottom'] ?? 0,
    );
  }

  // Convert to Flutter Rect with scaling
  Rect toRect(double scaleX, double scaleY) {
    return Rect.fromLTRB(
      left * scaleX,
      top * scaleY,
      right * scaleX,
      bottom * scaleY,
    );
  }
}
```

#### 1.2 Create API Service
**File**: `lib/services/measure_detection_service.dart`

```dart
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;
import '../models/measure_detection.dart';

class MeasureDetectionService {
  static const String apiUrl = 'https://dabba.princesamuel.me/symph/upload_and_predict';
  static const Duration timeout = Duration(seconds: 30);
  static const int maxFileSizeMB = 20;

  static Future<MeasureDetectionResult?> detectMeasures(File pdfFile) async {
    try {
      // Check file size
      final fileSizeInMB = await pdfFile.length() / (1024 * 1024);
      if (fileSizeInMB > maxFileSizeMB) {
        throw Exception('PDF file is too large (${fileSizeInMB.toStringAsFixed(1)}MB). Maximum size is ${maxFileSizeMB}MB.');
      }

      developer.log('Starting measure detection for file: ${pdfFile.path}');

      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          pdfFile.path,
          filename: pdfFile.path.split('/').last,
        ),
      );

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException('Measure detection timed out after ${timeout.inSeconds} seconds');
        },
      );

      // Read response
      final response = await http.Response.fromStream(streamedResponse);

      developer.log('Measure detection response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final result = MeasureDetectionResult.fromJson(json);

        developer.log('Successfully detected measures: ${result.pages.fold(0, (sum, page) => sum + page.systemMeasures.length)} total measures across ${result.totalPages} pages');

        return result;
      } else {
        developer.log('Measure detection failed with status ${response.statusCode}: ${response.body}');
        throw Exception('Server returned status ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error during measure detection: $e');
      rethrow;
    }
  }
}
```

### Phase 2: Integration with Rectangle System

#### 2.1 Update Rectangle Provider
**File**: `lib/providers/rectangle_provider.dart`
Add method to batch create rectangles from detection results:

```dart
void createRectanglesFromDetection(
  MeasureDetectionResult detection,
  Map<int, Size> pdfPageSizes, // Page number to PDF page size mapping
) {
  final newRectangles = <DrawnRectangle>[];

  for (final page in detection.pages) {
    final pdfPageSize = pdfPageSizes[page.pageNumber];
    if (pdfPageSize == null) continue;

    // Calculate scale factors
    final scaleX = pdfPageSize.width / page.width;
    final scaleY = pdfPageSize.height / page.height;

    // Create rectangle for each detected measure
    for (final measure in page.systemMeasures) {
      final rect = measure.toRect(scaleX, scaleY);

      final rectangle = DrawnRectangle(
        id: DateTime.now().millisecondsSinceEpoch.toString() + '_${Random().nextInt(10000)}',
        rect: rect,
        pageNumber: page.pageNumber,
        createdAt: DateTime.now(),
        timestamps: [], // No sync points initially
        beatNumbers: [], // No beat sync initially
      );

      newRectangles.add(rectangle);
    }
  }

  // Add all new rectangles
  for (final rectangle in newRectangles) {
    _rectangles[rectangle.id] = rectangle;
  }

  developer.log('Created ${newRectangles.length} rectangles from measure detection');
  notifyListeners();
}
```

### Phase 3: User Interface

#### 3.1 Add Auto-Detect Button
**File**: `lib/widgets/score_viewer/score_viewer.dart`
Add button in design mode toolbar:

```dart
Widget _buildDesignModeToolbar() {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        // Existing buttons...

        if (widget.isDesignMode && _pdfDocument != null)
          ElevatedButton.icon(
            icon: Icon(Icons.auto_awesome, size: 20),
            label: Text('Auto-Detect Measures'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            onPressed: _handleAutoDetect,
          ),
      ],
    ),
  );
}
```

#### 3.2 Implement Detection Handler
**File**: `lib/widgets/score_viewer/score_viewer.dart`

```dart
Future<void> _handleAutoDetect() async {
  // Show confirmation dialog
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.auto_awesome, color: Colors.purple),
          SizedBox(width: 12),
          Text('Auto-Detect Measures'),
        ],
      ),
      content: Text(
        'This will automatically detect and create rectangles for all measures in your score.\n\n'
        'Existing rectangles will be preserved.\n\n'
        'This may take a few moments depending on the size of your PDF.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
          ),
          child: Text('Detect Measures'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  // Show loading dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.purple),
          SizedBox(height: 24),
          Text(
            'Detecting measures...',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'This may take up to 30 seconds',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    ),
  );

  try {
    // Get PDF file
    final pdfFile = File(widget.pdfPath!);

    // Call detection API
    final result = await MeasureDetectionService.detectMeasures(pdfFile);

    if (!mounted) return;
    Navigator.of(context).pop(); // Close loading dialog

    if (result != null && result.success) {
      // Get page sizes from PDF document
      final pageSizes = <int, Size>{};
      for (int i = 1; i <= _pdfDocument!.pages.count; i++) {
        final page = await _pdfDocument!.getPage(i);
        pageSizes[i] = Size(page.width, page.height);
        page.close();
      }

      // Create rectangles
      final rectangleProvider = context.read<RectangleProvider>();
      rectangleProvider.createRectanglesFromDetection(result, pageSizes);

      // Show success message
      final measureCount = result.pages.fold(0, (sum, page) => sum + page.systemMeasures.length);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully detected $measureCount measures across ${result.totalPages} pages'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      throw Exception('Detection failed or returned no results');
    }
  } catch (e) {
    if (!mounted) return;
    Navigator.of(context).pop(); // Close loading dialog

    // Show error dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 12),
            Text('Detection Failed'),
          ],
        ),
        content: Text(_getErrorMessage(e)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}

String _getErrorMessage(dynamic error) {
  if (error is SocketException) {
    return 'Unable to connect to detection service. Please check your internet connection.';
  } else if (error is TimeoutException) {
    return 'Detection is taking longer than expected. Please try again.';
  } else if (error.toString().contains('too large')) {
    return error.toString();
  } else {
    return 'An error occurred during measure detection. Please try again or create rectangles manually.';
  }
}
```

### Phase 4: Testing & Refinement

#### 4.1 Testing Scenarios
1. **Success Cases**:
   - Small PDF (< 5 pages)
   - Medium PDF (5-15 pages)
   - Large PDF (15+ pages)
   - Different page orientations (portrait/landscape)

2. **Error Cases**:
   - No internet connection
   - API timeout
   - PDF too large (> 20MB)
   - API returns error
   - No measures detected

3. **Edge Cases**:
   - PDF with mixed page sizes
   - Existing rectangles present
   - User cancels during detection
   - App backgrounded during detection

#### 4.2 Performance Optimizations
1. Cache detection results using PDF hash as key
2. Show progress updates if API supports streaming
3. Compress large PDFs before upload
4. Implement retry logic for network failures

### Phase 5: UI Polish

#### 5.1 Visual Enhancements
1. Animate new rectangles appearing (fade in)
2. Highlight newly created rectangles briefly (purple glow)
3. Show measure count badge on button after detection
4. Add undo option in SnackBar

#### 5.2 User Guidance
1. Add tooltip to auto-detect button
2. Show onboarding hint on first PDF load
3. Add help text in confirmation dialog
4. Provide manual adjustment tips after detection

## Dependencies
Add to `pubspec.yaml`:
```yaml
dependencies:
  http: ^1.1.0
```

## Configuration
Consider adding to app settings:
- Toggle for auto-detect on PDF load (future)
- API endpoint configuration (for different environments)
- Timeout duration adjustment
- File size limit adjustment

## Security Considerations
1. PDF files are uploaded to external service - add privacy notice
2. Consider implementing client-side PDF preview/sampling
3. Add rate limiting to prevent abuse
4. Validate API responses before processing

## Future Enhancements
1. **Confidence Scores**: Show detection confidence for each measure
2. **Selective Detection**: Allow detecting specific pages only
3. **Manual Refinement**: UI for adjusting detected rectangles
4. **Batch Processing**: Detect multiple PDFs in queue
5. **Offline Support**: Integrate on-device ML model
6. **Smart Grouping**: Group measures by system/line
7. **Measure Numbering**: Automatically number detected measures
8. **Export/Import**: Save detection results for reuse