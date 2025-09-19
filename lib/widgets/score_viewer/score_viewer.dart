import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:developer' as developer;
import 'dart:io';
import 'page_controls.dart';

class ScoreViewer extends StatefulWidget {
  const ScoreViewer({super.key});

  @override
  State<ScoreViewer> createState() => _ScoreViewerState();
}

class _ScoreViewerState extends State<ScoreViewer> {
  PdfViewerController? _pdfViewerController;
  File? _selectedPdfFile;
  int _currentPageNumber = 1;
  int _totalPages = 0;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
  }

  @override
  void dispose() {
    _pdfViewerController?.dispose();
    super.dispose();
  }

  Future<void> _pickPdfFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        setState(() {
          _selectedPdfFile = file;
          _currentPageNumber = 1;
          _totalPages = 0;
        });
        developer.log('PDF file selected: ${file.path}');
      } else {
        developer.log('PDF file selection cancelled');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error selecting PDF file: $e';
      });
      developer.log('Error picking PDF file: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) {
    setState(() {
      _totalPages = details.document.pages.count;
      _currentPageNumber = 1;
    });
    developer.log('PDF loaded with $_totalPages pages');
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    setState(() {
      _currentPageNumber = details.newPageNumber;
    });
    developer.log('Page changed to: $_currentPageNumber');
  }

  void _onDocumentLoadFailed(PdfDocumentLoadFailedDetails details) {
    setState(() {
      _errorMessage = 'Failed to load PDF: ${details.error}';
    });
    developer.log('PDF load failed: ${details.error}');
  }

  void _goToFirstPage() {
    if (_pdfViewerController != null && _totalPages > 0) {
      _pdfViewerController!.jumpToPage(1);
    }
  }

  void _goToLastPage() {
    if (_pdfViewerController != null && _totalPages > 0) {
      _pdfViewerController!.jumpToPage(_totalPages);
    }
  }

  void _goToPreviousPage() {
    if (_pdfViewerController != null && _currentPageNumber > 1) {
      _pdfViewerController!.previousPage();
    }
  }

  void _goToNextPage() {
    if (_pdfViewerController != null && _currentPageNumber < _totalPages) {
      _pdfViewerController!.nextPage();
    }
  }

  Widget _buildPdfViewer() {
    if (_selectedPdfFile == null) {
      return _buildNoPdfSelected();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return SfPdfViewer.file(
      _selectedPdfFile!,
      controller: _pdfViewerController,
      onDocumentLoaded: _onDocumentLoaded,
      onPageChanged: _onPageChanged,
      onDocumentLoadFailed: _onDocumentLoadFailed,
      enableDoubleTapZooming: true,
      canShowScrollHead: false,
      canShowScrollStatus: false,
      canShowPaginationDialog: false,
    );
  }

  Widget _buildNoPdfSelected() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No PDF Selected',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to select a PDF score',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _pickPdfFile,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_open),
            label: Text(_isLoading ? 'Loading...' : 'Select PDF'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading PDF',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.red[600],
                ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _pickPdfFile,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _buildPdfViewer(),
        ),
        if (_selectedPdfFile != null && _totalPages > 0)
          PageControls(
            currentPage: _currentPageNumber,
            totalPages: _totalPages,
            onFirstPage: _goToFirstPage,
            onPreviousPage: _goToPreviousPage,
            onNextPage: _goToNextPage,
            onLastPage: _goToLastPage,
            onSelectPdf: _pickPdfFile,
          ),
      ],
    );
  }
}