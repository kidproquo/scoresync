import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:provider/provider.dart';
import '../../providers/score_provider.dart';
import '../../providers/app_mode_provider.dart';
import '../../providers/song_provider.dart';
import 'page_controls.dart';
import 'rectangle_overlay.dart';

class ScoreViewer extends StatefulWidget {
  const ScoreViewer({super.key});

  @override
  State<ScoreViewer> createState() => _ScoreViewerState();
}

class _ScoreViewerState extends State<ScoreViewer> {
  PdfViewerController? _pdfViewerController;
  Size _pdfPageSize = const Size(612, 792); // Default US Letter size

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    
    // Listen to score provider for page changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scoreProvider = context.read<ScoreProvider>();
      scoreProvider.addListener(_onScoreProviderChanged);
    });
  }
  
  void _onScoreProviderChanged() {
    final scoreProvider = context.read<ScoreProvider>();
    if (_pdfViewerController != null && 
        scoreProvider.currentPageNumber != _pdfViewerController!.pageNumber) {
      _pdfViewerController!.jumpToPage(scoreProvider.currentPageNumber);
    }
  }

  @override
  void dispose() {
    final scoreProvider = context.read<ScoreProvider>();
    scoreProvider.removeListener(_onScoreProviderChanged);
    _pdfViewerController?.dispose();
    super.dispose();
  }

  Future<void> _pickPdfFile() async {
    final scoreProvider = context.read<ScoreProvider>();
    final songProvider = context.read<SongProvider>();
    scoreProvider.setLoading(true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        scoreProvider.setSelectedPdf(file);
        
        // Update the current song with the new PDF
        await songProvider.updateSongPdf(file);
        
        developer.log('PDF file selected and saved to song: ${file.path}');
      } else {
        developer.log('PDF file selection cancelled');
      }
    } catch (e) {
      scoreProvider.setError('Error selecting PDF file: $e');
      developer.log('Error picking PDF file: $e');
    } finally {
      scoreProvider.setLoading(false);
    }
  }

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) {
    final scoreProvider = context.read<ScoreProvider>();
    scoreProvider.setTotalPages(details.document.pages.count);
    scoreProvider.setCurrentPage(1);
    
    // Get page size from first page
    if (details.document.pages.count > 0) {
      final page = details.document.pages[0];
      _pdfPageSize = Size(page.size.width, page.size.height);
    }
    
    developer.log('PDF loaded with ${scoreProvider.totalPages} pages');
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    final scoreProvider = context.read<ScoreProvider>();
    scoreProvider.setCurrentPage(details.newPageNumber);
    
    // Update page size for the current page
    // Note: We'll use the same size from document load for consistency
    
    developer.log('Page changed to: ${details.newPageNumber}');
  }

  void _onDocumentLoadFailed(PdfDocumentLoadFailedDetails details) {
    final scoreProvider = context.read<ScoreProvider>();
    scoreProvider.setError('Failed to load PDF: ${details.error}');
    developer.log('PDF load failed: ${details.error}');
  }

  void _goToFirstPage() {
    final scoreProvider = context.read<ScoreProvider>();
    if (_pdfViewerController != null && scoreProvider.totalPages > 0) {
      _pdfViewerController!.jumpToPage(1);
    }
  }

  void _goToLastPage() {
    final scoreProvider = context.read<ScoreProvider>();
    if (_pdfViewerController != null && scoreProvider.totalPages > 0) {
      _pdfViewerController!.jumpToPage(scoreProvider.totalPages);
    }
  }

  void _goToPreviousPage() {
    final scoreProvider = context.read<ScoreProvider>();
    if (_pdfViewerController != null && scoreProvider.canGoToPreviousPage()) {
      _pdfViewerController!.previousPage();
    }
  }

  void _goToNextPage() {
    final scoreProvider = context.read<ScoreProvider>();
    if (_pdfViewerController != null && scoreProvider.canGoToNextPage()) {
      _pdfViewerController!.nextPage();
    }
  }

  Widget _buildPdfViewer(ScoreProvider scoreProvider, bool isDesignMode) {
    if (scoreProvider.selectedPdfFile == null) {
      return _buildNoPdfSelected(isDesignMode);
    }

    if (scoreProvider.errorMessage != null) {
      return _buildErrorState(scoreProvider.errorMessage!);
    }

    final pdfViewer = SfPdfViewer.file(
      scoreProvider.selectedPdfFile!,
      controller: _pdfViewerController,
      onDocumentLoaded: _onDocumentLoaded,
      onPageChanged: _onPageChanged,
      onDocumentLoadFailed: _onDocumentLoadFailed,
      enableDoubleTapZooming: !isDesignMode, // Disable zoom in design mode
      interactionMode: isDesignMode 
          ? PdfInteractionMode.selection // This prevents scrolling
          : PdfInteractionMode.pan, // Normal interaction in playback mode
      canShowScrollHead: false,
      canShowScrollStatus: false,
      canShowPaginationDialog: false,
      pageLayoutMode: PdfPageLayoutMode.single, // Show one page at a time
    );

    // Always wrap with rectangle overlay to show rectangles in both modes
    return InteractiveRectangleOverlay(
      currentPageNumber: scoreProvider.currentPageNumber,
      pdfPageSize: _pdfPageSize,
      child: isDesignMode 
          ? IgnorePointer(
              child: pdfViewer, // Ignore PDF gestures in design mode
            )
          : pdfViewer, // Allow PDF gestures in playback mode
    );
  }

  Widget _buildNoPdfSelected(bool isDesignMode) {
    final songProvider = context.read<SongProvider>();
    final hasSong = songProvider.currentSong != null;
    
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
            hasSong 
                ? (isDesignMode 
                    ? 'Tap the button below to select a PDF score'
                    : 'Switch to Design Mode to select a PDF score')
                : 'Create or load a song first to select a PDF',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (isDesignMode)
            ElevatedButton.icon(
              onPressed: hasSong ? _pickPdfFile : null,
              icon: const Icon(Icons.folder_open),
              label: const Text('Select PDF'),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String errorMessage) {
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
              errorMessage,
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
    return Consumer2<ScoreProvider, AppModeProvider>(
      builder: (context, scoreProvider, appModeProvider, _) {
        return Column(
          children: [
            if (scoreProvider.isLoading)
              const LinearProgressIndicator(),
            Expanded(
              child: _buildPdfViewer(scoreProvider, appModeProvider.isDesignMode),
            ),
            if (scoreProvider.selectedPdfFile != null && scoreProvider.totalPages > 0)
              Consumer<SongProvider>(
                builder: (context, songProvider, _) => PageControls(
                  currentPage: scoreProvider.currentPageNumber,
                  totalPages: scoreProvider.totalPages,
                  onFirstPage: _goToFirstPage,
                  onPreviousPage: _goToPreviousPage,
                  onNextPage: _goToNextPage,
                  onLastPage: _goToLastPage,
                  onSelectPdf: _pickPdfFile,
                  canSelectPdf: songProvider.currentSong != null,
                  isDesignMode: appModeProvider.isDesignMode,
                ),
              ),
          ],
        );
      },
    );
  }
}