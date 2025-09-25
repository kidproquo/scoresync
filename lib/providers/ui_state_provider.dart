import 'package:flutter/foundation.dart';

class UiStateProvider extends ChangeNotifier {
  bool _isVideoDragging = false;

  bool get isVideoDragging => _isVideoDragging;

  void setVideoDragging(bool dragging) {
    if (_isVideoDragging != dragging) {
      _isVideoDragging = dragging;
      notifyListeners();
    }
  }
}