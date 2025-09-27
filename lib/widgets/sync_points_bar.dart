import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rectangle_provider.dart';
import '../providers/video_provider.dart';
import '../providers/metronome_provider.dart';
import '../models/rectangle.dart';
import '../models/metronome_settings.dart';

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
    final metronomeProvider = context.read<MetronomeProvider>();

    final isBeatMode = metronomeProvider.settings.mode == MetronomeMode.beat;

    if (isBeatMode) {
      if (!metronomeProvider.settings.isEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enable metronome first to create beat sync points'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (!metronomeProvider.isPlaying) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Start metronome first to create beat sync points'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final currentBeat = metronomeProvider.totalBeats;

      if (rectangle.beatNumbers.contains(currentBeat)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Beat sync point already exists at beat $currentBeat'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      rectangle.addBeatNumber(currentBeat);
      rectangleProvider.updateRectangleTimestamps();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Beat sync point added at beat $currentBeat (measure ${metronomeProvider.currentMeasure})'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      if (!videoProvider.isPlayerReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Load a video first to create sync points'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final currentPosition = videoProvider.currentPosition;

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

  void _deleteBeatSyncPoint(BuildContext context, DrawnRectangle rectangle, int beatNumber) {
    final rectangleProvider = context.read<RectangleProvider>();

    rectangle.removeBeatNumber(beatNumber);
    rectangleProvider.updateRectangleTimestamps();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Beat sync point removed: beat $beatNumber'),
        backgroundColor: Colors.grey,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<RectangleProvider, MetronomeProvider>(
      builder: (context, rectangleProvider, metronomeProvider, _) {
        final selectedRectangle = rectangleProvider.selectedRectangle;

        if (selectedRectangle == null) {
          return const SizedBox.shrink();
        }

        final isBeatMode = metronomeProvider.settings.mode == MetronomeMode.beat;

        final hasSyncPoints = isBeatMode
            ? selectedRectangle.beatNumbers.isNotEmpty
            : selectedRectangle.timestamps.isNotEmpty;

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
              Expanded(
                child: !hasSyncPoints
                    ? const Center(
                        child: Text(
                          'No sync points',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : isBeatMode
                        ? ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: selectedRectangle.beatNumbers.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final beatNumber = selectedRectangle.beatNumbers[index];
                              final beatsPerMeasure = metronomeProvider.settings.timeSignature.numerator;
                              final measureNumber = ((beatNumber - 1) ~/ beatsPerMeasure) + 1;
                              final beatInMeasure = ((beatNumber - 1) % beatsPerMeasure) + 1;

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.purple.withValues(alpha: 0.6),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'M$measureNumber:B$beatInMeasure',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => _deleteBeatSyncPoint(context, selectedRectangle, beatNumber),
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