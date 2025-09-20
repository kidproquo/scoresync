import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:developer' as developer;

class ScoreProvider extends ChangeNotifier {
  File? _selectedPdfFile;
  int _currentPageNumber = 1;
  int _totalPages = 0;
  bool _isLoading = false;
  String? _errorMessage;

  File? get selectedPdfFile => _selectedPdfFile;
  int get currentPageNumber => _currentPageNumber;
  int get totalPages => _totalPages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasPdf => _selectedPdfFile != null;
  bool get hasError => _errorMessage != null;

  void setSelectedPdf(File? file) {
    _selectedPdfFile = file;
    if (file != null) {
      _currentPageNumber = 1;
      _totalPages = 0;
      _errorMessage = null;
      developer.log('PDF file selected: ${file.path}');
    } else {
      _currentPageNumber = 1;
      _totalPages = 0;
      developer.log('PDF file cleared');
    }
    notifyListeners();
  }

  void setCurrentPage(int pageNumber) {
    if (pageNumber >= 1 && pageNumber <= _totalPages && pageNumber != _currentPageNumber) {
      _currentPageNumber = pageNumber;
      developer.log('Page changed to: $pageNumber');
      notifyListeners();
    }
  }

  void setTotalPages(int totalPages) {
    if (_totalPages != totalPages) {
      _totalPages = totalPages;
      developer.log('Total pages set to: $totalPages');
      notifyListeners();
    }
  }

  void setLoading(bool isLoading) {
    if (_isLoading != isLoading) {
      _isLoading = isLoading;
      if (isLoading) {
        _errorMessage = null;
      }
      notifyListeners();
    }
  }

  void setError(String? errorMessage) {
    _errorMessage = errorMessage;
    _isLoading = false;
    if (errorMessage != null) {
      developer.log('PDF error: $errorMessage');
    }
    notifyListeners();
  }

  void clearError() {
    setError(null);
  }

  void goToFirstPage() {
    setCurrentPage(1);
  }

  void goToLastPage() {
    setCurrentPage(_totalPages);
  }

  void goToPreviousPage() {
    if (_currentPageNumber > 1) {
      setCurrentPage(_currentPageNumber - 1);
    }
  }

  void goToNextPage() {
    if (_currentPageNumber < _totalPages) {
      setCurrentPage(_currentPageNumber + 1);
    }
  }

  void goToPage(int pageNumber) {
    if (pageNumber >= 1 && pageNumber <= _totalPages) {
      setCurrentPage(pageNumber);
    }
  }

  bool canGoToPreviousPage() {
    return _currentPageNumber > 1;
  }

  bool canGoToNextPage() {
    return _currentPageNumber < _totalPages;
  }

  Future<void> loadPdf(File pdfFile) async {
    setSelectedPdf(pdfFile);
  }

  void clearPdf() {
    setSelectedPdf(null);
  }
}