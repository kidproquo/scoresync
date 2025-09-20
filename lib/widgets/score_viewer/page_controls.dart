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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
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
                'Page $currentPage of $totalPages',
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
              label: const Text('Select PDF'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}