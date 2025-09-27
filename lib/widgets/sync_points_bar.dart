import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rectangle_provider.dart';
import '../providers/video_provider.dart';
import '../models/rectangle.dart';

class SyncPointsBar extends StatelessWidget {
  const SyncPointsBar({super.key});

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

  void _createSyncPoint(BuildContext context, DrawnRectangle rectangle) {
    final videoProvider = context.read<VideoProvider>();
    final rectangleProvider = context.read<RectangleProvider>();

    if (!videoProvider.hasVideo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Load a video first to create sync points'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final currentPosition = videoProvider.currentPosition;

    // Check for duplicate within 10ms tolerance
    const tolerance = Duration(milliseconds: 10);
    for (final existing in rectangle.timestamps) {
      final difference = (currentPosition - existing).abs();
      if (difference <= tolerance) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync point already exists at ${_formatDuration(existing)}'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    // Add timestamp to rectangle
    rectangle.addTimestamp(currentPosition);
    rectangleProvider.updateRectangleTimestamps();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sync point added at ${_formatDuration(currentPosition)}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _deleteSyncPoint(BuildContext context, DrawnRectangle rectangle, Duration timestamp) {
    final rectangleProvider = context.read<RectangleProvider>();

    rectangle.removeTimestamp(timestamp);
    rectangleProvider.updateRectangleTimestamps();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sync point removed: ${_formatDuration(timestamp)}'),
        backgroundColor: Colors.grey,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RectangleProvider>(
      builder: (context, rectangleProvider, _) {
        final selectedRectangle = rectangleProvider.selectedRectangle;

        // Only show in design mode when a rectangle is selected
        if (selectedRectangle == null) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.7),
                Colors.black.withValues(alpha: 0.5),
              ],
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Create sync point button
              ElevatedButton.icon(
                onPressed: () => _createSyncPoint(context, selectedRectangle),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Sync'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 40),
                ),
              ),
              const SizedBox(width: 12),
              // Scrollable list of sync point badges
              Expanded(
                child: selectedRectangle.timestamps.isEmpty
                    ? const Center(
                        child: Text(
                          'No sync points',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedRectangle.timestamps.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final timestamp = selectedRectangle.timestamps[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatDuration(timestamp),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => _deleteSyncPoint(context, selectedRectangle, timestamp),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}