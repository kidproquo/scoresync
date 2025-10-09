import 'package:flutter/material.dart';

class PageControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback onFirstPage;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final VoidCallback onLastPage;
  final VoidCallback? onSelectPdf;
  final bool canSelectPdf;
  final bool isDesignMode;
  final VoidCallback? onAutoDetectMeasures;
  final bool hasPdf;

  const PageControls({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onFirstPage,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onLastPage,
    this.onSelectPdf,
    this.canSelectPdf = true,
    required this.isDesignMode,
    this.onAutoDetectMeasures,
    this.hasPdf = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: currentPage > 1 ? onFirstPage : null,
            icon: const Icon(Icons.first_page),
            tooltip: 'First page',
          ),
          IconButton(
            onPressed: currentPage > 1 ? onPreviousPage : null,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous page',
          ),
          Expanded(
            child: Center(
              child: Text(
                '$currentPage/$totalPages',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ),
          IconButton(
            onPressed: currentPage < totalPages ? onNextPage : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next page',
          ),
          IconButton(
            onPressed: currentPage < totalPages ? onLastPage : null,
            icon: const Icon(Icons.last_page),
            tooltip: 'Last page',
          ),
          if (isDesignMode) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: canSelectPdf ? onSelectPdf : null,
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('PDF'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
            if (hasPdf && onAutoDetectMeasures != null) ...[
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onAutoDetectMeasures,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Auto-Detect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}