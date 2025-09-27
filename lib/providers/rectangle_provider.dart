import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../models/rectangle.dart';

class RectangleProvider extends ChangeNotifier {
  final Map<int, List<DrawnRectangle>> _rectanglesByPage = {};
  DrawnRectangle? _selectedRectangle;
  DrawnRectangle? _currentDrawing;
  DrawingMode _drawingMode = DrawingMode.none;
  Offset? _startPoint;
  RectangleHandle? _activeHandle;
  String? _activeRectangleId; // Rectangle currently active during playback
  
  // Callback for when rectangles are modified
  VoidCallback? _onRectanglesChanged;

  Map<int, List<DrawnRectangle>> get rectanglesByPage => _rectanglesByPage;
  DrawnRectangle? get selectedRectangle => _selectedRectangle;
  DrawnRectangle? get currentDrawing => _currentDrawing;
  DrawingMode get drawingMode => _drawingMode;
  String? get activeRectangleId => _activeRectangleId;

  List<DrawnRectangle> getRectanglesForPage(int pageNumber) {
    return _rectanglesByPage[pageNumber] ?? [];
  }

  // Get all rectangles across all pages
  List<DrawnRectangle> get allRectangles {
    final allRects = <DrawnRectangle>[];
    for (final rects in _rectanglesByPage.values) {
      allRects.addAll(rects);
    }
    return allRects;
  }

  // Set the active rectangle for playback highlighting
  void setActiveRectangle(String? rectangleId) {
    if (_activeRectangleId != rectangleId) {
      _activeRectangleId = rectangleId;
      notifyListeners();
    }
  }

  // Check if a rectangle is active
  bool isRectangleActive(String rectangleId) {
    return _activeRectangleId == rectangleId;
  }

  // Set callback for when rectangles change
  void setOnRectanglesChanged(VoidCallback? callback) {
    _onRectanglesChanged = callback;
  }

  // Notify that rectangles have changed
  void _notifyRectanglesChanged() {
    _onRectanglesChanged?.call();
  }

  // Public method to trigger updates when rectangle timestamps are modified
  void updateRectangleTimestamps() {
    notifyListeners();
    _notifyRectanglesChanged();
  }

  void startDrawing(Offset point, int pageNumber) {
    _startPoint = point;
    _drawingMode = DrawingMode.drawing;
    
    _currentDrawing = DrawnRectangle(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      rect: Rect.fromPoints(point, point),
      pageNumber: pageNumber,
      createdAt: DateTime.now(),
    );
    
    developer.log('Started drawing rectangle on page $pageNumber');
    notifyListeners();
  }

  void updateDrawing(Offset point) {
    if (_drawingMode != DrawingMode.drawing || _startPoint == null || _currentDrawing == null) {
      return;
    }

    _currentDrawing = _currentDrawing!.copyWith(
      rect: Rect.fromPoints(_startPoint!, point),
    );
    
    notifyListeners();
  }

  void finishDrawing() {
    if (_currentDrawing == null || _drawingMode != DrawingMode.drawing) {
      return;
    }

    // Only add rectangle if it has a minimum size
    if (_currentDrawing!.rect.width > 10 && _currentDrawing!.rect.height > 10) {
      final pageNumber = _currentDrawing!.pageNumber;
      
      if (!_rectanglesByPage.containsKey(pageNumber)) {
        _rectanglesByPage[pageNumber] = [];
      }
      
      _rectanglesByPage[pageNumber]!.add(_currentDrawing!);
      developer.log('Added rectangle to page $pageNumber');
      _notifyRectanglesChanged();
    }

    _currentDrawing = null;
    _startPoint = null;
    _drawingMode = DrawingMode.none;
    notifyListeners();
  }

  void selectRectangle(DrawnRectangle? rectangle) {
    if (_selectedRectangle != null) {
      _selectedRectangle!.isSelected = false;
    }

    _selectedRectangle = rectangle;
    
    if (rectangle != null) {
      rectangle.isSelected = true;
      _drawingMode = DrawingMode.selecting;
      developer.log('Selected rectangle: ${rectangle.id}');
    } else {
      _drawingMode = DrawingMode.none;
      developer.log('Deselected rectangle');
    }
    
    notifyListeners();
  }

  DrawnRectangle? findRectangleAt(Offset point, int pageNumber) {
    final rectangles = getRectanglesForPage(pageNumber);
    
    // Check in reverse order (top-most rectangle first)
    for (var i = rectangles.length - 1; i >= 0; i--) {
      if (rectangles[i].contains(point)) {
        return rectangles[i];
      }
    }
    
    // Check with tolerance for edges
    for (var i = rectangles.length - 1; i >= 0; i--) {
      if (rectangles[i].isNear(point)) {
        return rectangles[i];
      }
    }
    
    return null;
  }

  void startMoving(Offset startPoint) {
    if (_selectedRectangle == null) return;
    
    _startPoint = startPoint;
    _drawingMode = DrawingMode.moving;
    developer.log('Started moving rectangle: ${_selectedRectangle!.id}');
    notifyListeners();
  }

  void moveRectangle(Offset currentPoint) {
    if (_selectedRectangle == null || _startPoint == null || _drawingMode != DrawingMode.moving) {
      return;
    }

    final delta = currentPoint - _startPoint!;
    final newRect = _selectedRectangle!.rect.shift(delta);
    
    _selectedRectangle = _selectedRectangle!.copyWith(rect: newRect);
    
    // Update in the page map
    final pageRectangles = _rectanglesByPage[_selectedRectangle!.pageNumber];
    if (pageRectangles != null) {
      final index = pageRectangles.indexWhere((r) => r.id == _selectedRectangle!.id);
      if (index != -1) {
        pageRectangles[index] = _selectedRectangle!;
      }
    }
    
    _startPoint = currentPoint;
    notifyListeners();
  }

  void finishMoving() {
    _drawingMode = DrawingMode.selecting;
    _startPoint = null;
    _notifyRectanglesChanged();
    developer.log('Finished moving rectangle');
    notifyListeners();
  }

  void deleteSelectedRectangle() {
    if (_selectedRectangle == null) return;

    final pageNumber = _selectedRectangle!.pageNumber;
    final rectangles = _rectanglesByPage[pageNumber];
    
    if (rectangles != null) {
      rectangles.removeWhere((r) => r.id == _selectedRectangle!.id);
      developer.log('Deleted rectangle: ${_selectedRectangle!.id}');
      _notifyRectanglesChanged();
    }
    
    _selectedRectangle = null;
    _drawingMode = DrawingMode.none;
    notifyListeners();
  }

  void clearRectanglesForPage(int pageNumber) {
    _rectanglesByPage[pageNumber]?.clear();
    
    if (_selectedRectangle?.pageNumber == pageNumber) {
      _selectedRectangle = null;
      _drawingMode = DrawingMode.none;
    }
    
    developer.log('Cleared all rectangles for page $pageNumber');
    notifyListeners();
  }

  void clearAllRectangles() {
    _rectanglesByPage.clear();
    _selectedRectangle = null;
    _currentDrawing = null;
    _drawingMode = DrawingMode.none;
    developer.log('Cleared all rectangles');
    notifyListeners();
  }

  void loadRectangles(List<DrawnRectangle> rectangles) {
    clearAllRectangles();
    
    for (final rectangle in rectangles) {
      final pageNumber = rectangle.pageNumber;
      if (!_rectanglesByPage.containsKey(pageNumber)) {
        _rectanglesByPage[pageNumber] = [];
      }
      _rectanglesByPage[pageNumber]!.add(rectangle);
    }
    
    developer.log('Loaded ${rectangles.length} rectangles');
    notifyListeners();
  }

  // Get all rectangles across all pages
  List<DrawnRectangle> getAllRectangles() {
    final allRectangles = <DrawnRectangle>[];
    for (final rectangles in _rectanglesByPage.values) {
      allRectangles.addAll(rectangles);
    }
    return allRectangles;
  }

  RectangleHandle? getHandleAt(Offset point) {
    if (_selectedRectangle == null) return null;
    return _selectedRectangle!.getHandleAt(point);
  }

  void startResizing(Offset point, RectangleHandle handle) {
    if (_selectedRectangle == null) return;
    
    _startPoint = point;
    _activeHandle = handle;
    _drawingMode = DrawingMode.resizing;
    developer.log('Started resizing rectangle with handle: $handle');
    notifyListeners();
  }

  void resizeRectangle(Offset currentPoint) {
    if (_selectedRectangle == null || _activeHandle == null || _drawingMode != DrawingMode.resizing) {
      return;
    }

    // Don't resize if trying to use delete handle
    if (_activeHandle == RectangleHandle.delete) {
      return;
    }

    final rect = _selectedRectangle!.rect;
    Rect newRect;

    switch (_activeHandle!) {
      case RectangleHandle.topLeft:
        // TopLeft is now delete button, shouldn't resize
        return;
      case RectangleHandle.topRight:
        newRect = Rect.fromLTRB(rect.left, currentPoint.dy, currentPoint.dx, rect.bottom);
        break;
      case RectangleHandle.bottomLeft:
        newRect = Rect.fromLTRB(currentPoint.dx, rect.top, rect.right, currentPoint.dy);
        break;
      case RectangleHandle.bottomRight:
        newRect = Rect.fromLTRB(rect.left, rect.top, currentPoint.dx, currentPoint.dy);
        break;
      case RectangleHandle.delete:
        // Delete handle shouldn't resize
        return;
    }

    // Ensure minimum size
    if (newRect.width > 10 && newRect.height > 10) {
      _selectedRectangle = _selectedRectangle!.copyWith(rect: newRect);
      
      // Update in the page map
      final pageRectangles = _rectanglesByPage[_selectedRectangle!.pageNumber];
      if (pageRectangles != null) {
        final index = pageRectangles.indexWhere((r) => r.id == _selectedRectangle!.id);
        if (index != -1) {
          pageRectangles[index] = _selectedRectangle!;
        }
      }
      
      notifyListeners();
    }
  }

  void finishResizing() {
    _drawingMode = DrawingMode.selecting;
    _activeHandle = null;
    _notifyRectanglesChanged();
    developer.log('Finished resizing rectangle');
    notifyListeners();
  }

  void updateRectangle(DrawnRectangle updatedRectangle) {
    final pageNumber = updatedRectangle.pageNumber;
    final pageRectangles = _rectanglesByPage[pageNumber];
    
    if (pageRectangles != null) {
      final index = pageRectangles.indexWhere((r) => r.id == updatedRectangle.id);
      if (index != -1) {
        pageRectangles[index] = updatedRectangle;
        
        // Update selected rectangle if it's the same one
        if (_selectedRectangle?.id == updatedRectangle.id) {
          _selectedRectangle = updatedRectangle;
        }
        
        _notifyRectanglesChanged();
        developer.log('Updated rectangle: ${updatedRectangle.id}');
        notifyListeners();
      }
    }
  }
}