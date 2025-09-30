import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rectangle_provider.dart';
import '../providers/video_provider.dart';
import '../providers/metronome_provider.dart';
import '../providers/app_mode_provider.dart';
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
      // When stopped (totalBeats = 0), use beat 1 (M1:B1)
      final currentBeat = metronomeProvider.totalBeats == 0 ? 1 : metronomeProvider.totalBeats;

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
    final videoProvider = context.read<VideoProvider>();

    // Clear loop markers only if deleting the specific timestamp used by the loop
    if (videoProvider.loopStartRectangleId == rectangle.id && videoProvider.loopStartTime == timestamp) {
      videoProvider.clearLoopStart();
    }
    if (videoProvider.loopEndRectangleId == rectangle.id && videoProvider.loopEndTime == timestamp) {
      videoProvider.clearLoopEnd();
    }

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
    final metronomeProvider = context.read<MetronomeProvider>();

    // Remove the beat first
    rectangle.removeBeatNumber(beatNumber);

    // Clear loop markers if this rectangle will have no more beats after deletion
    if (metronomeProvider.loopStartRectangleId == rectangle.id && rectangle.beatNumbers.isEmpty) {
      metronomeProvider.clearLoopStart();
    }
    if (metronomeProvider.loopEndRectangleId == rectangle.id && rectangle.beatNumbers.isEmpty) {
      metronomeProvider.clearLoopEnd();
    }

    rectangleProvider.updateRectangleTimestamps();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Beat sync point removed: beat $beatNumber'),
        backgroundColor: Colors.grey,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showBeatSyncMenu(BuildContext context, DrawnRectangle rectangle, int beatNumber, String displayText, Offset tapPosition) {
    final metronomeProvider = context.read<MetronomeProvider>();

    // Check if this rectangle is a loop marker
    final isLoopStart = metronomeProvider.loopStartRectangleId == rectangle.id;
    final isLoopEnd = metronomeProvider.loopEndRectangleId == rectangle.id;

    // Calculate position to show menu above the badge
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final menuPosition = RelativeRect.fromRect(
      Rect.fromPoints(
        tapPosition.translate(-50, -140), // Offset left and up from tap position
        tapPosition.translate(50, -40),    // Menu width and position above badge
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: menuPosition,
      items: [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit, size: 20),
              const SizedBox(width: 8),
              Text('Edit $displayText'),
            ],
          ),
        ),
        PopupMenuItem(
          value: isLoopStart ? 'clear_loop_start' : 'loop_start',
          child: Row(
            children: [
              Icon(Icons.flag_outlined, size: 20, color: Colors.green),
              const SizedBox(width: 8),
              Text(isLoopStart ? 'Clear Loop Start' : 'Set as Loop Start'),
            ],
          ),
        ),
        PopupMenuItem(
          value: isLoopEnd ? 'clear_loop_end' : 'loop_end',
          child: Row(
            children: [
              Icon(Icons.flag, size: 20, color: Colors.red),
              const SizedBox(width: 8),
              Text(isLoopEnd ? 'Clear Loop End' : 'Set as Loop End'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete, size: 20, color: Colors.red),
              const SizedBox(width: 8),
              const Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (!context.mounted) return;
      final provider = context.read<MetronomeProvider>();

      switch (value) {
        case 'edit':
          _editBeatSyncPoint(context, rectangle, beatNumber);
          break;
        case 'loop_start':
          provider.setLoopStart(beatNumber, rectangle.id);
          break;
        case 'clear_loop_start':
          provider.clearLoopStart();
          break;
        case 'loop_end':
          provider.setLoopEnd(beatNumber, rectangle.id);
          break;
        case 'clear_loop_end':
          provider.clearLoopEnd();
          break;
        case 'delete':
          _deleteBeatSyncPoint(context, rectangle, beatNumber);
          break;
      }
    });
  }

  void _showTimestampSyncMenu(BuildContext context, DrawnRectangle rectangle, Duration timestamp, Offset tapPosition) {
    final videoProvider = context.read<VideoProvider>();

    // Check if this rectangle is a loop marker
    final isLoopStart = videoProvider.loopStartRectangleId == rectangle.id;
    final isLoopEnd = videoProvider.loopEndRectangleId == rectangle.id;

    // Calculate position to show menu above the badge
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final menuPosition = RelativeRect.fromRect(
      Rect.fromPoints(
        tapPosition.translate(-50, -140), // Offset left and up from tap position
        tapPosition.translate(50, -40),    // Menu width and position above badge
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: menuPosition,
      items: [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit, size: 20),
              const SizedBox(width: 8),
              Text('Edit ${_formatDuration(timestamp)}'),
            ],
          ),
        ),
        PopupMenuItem(
          value: isLoopStart ? 'clear_loop_start' : 'loop_start',
          child: Row(
            children: [
              Icon(Icons.flag_outlined, size: 20, color: Colors.green),
              const SizedBox(width: 8),
              Text(isLoopStart ? 'Clear Loop Start' : 'Set as Loop Start'),
            ],
          ),
        ),
        PopupMenuItem(
          value: isLoopEnd ? 'clear_loop_end' : 'loop_end',
          child: Row(
            children: [
              Icon(Icons.flag, size: 20, color: Colors.red),
              const SizedBox(width: 8),
              Text(isLoopEnd ? 'Clear Loop End' : 'Set as Loop End'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete, size: 20, color: Colors.red),
              const SizedBox(width: 8),
              const Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (!context.mounted) return;
      final provider = context.read<VideoProvider>();

      switch (value) {
        case 'edit':
          _editTimestampSyncPoint(context, rectangle, timestamp);
          break;
        case 'loop_start':
          provider.setLoopStart(timestamp, rectangle.id);
          break;
        case 'clear_loop_start':
          provider.clearLoopStart();
          break;
        case 'loop_end':
          provider.setLoopEnd(timestamp, rectangle.id);
          break;
        case 'clear_loop_end':
          provider.clearLoopEnd();
          break;
        case 'delete':
          _deleteSyncPoint(context, rectangle, timestamp);
          break;
      }
    });
  }

  void _editBeatSyncPoint(BuildContext context, DrawnRectangle rectangle, int oldBeatNumber) {
    final metronomeProvider = context.read<MetronomeProvider>();
    final beatsPerMeasure = metronomeProvider.settings.timeSignature.numerator;

    // Calculate current measure and beat
    int currentMeasure;
    int currentBeat;
    if (oldBeatNumber == 0) {
      currentMeasure = 0;
      currentBeat = 0;
    } else {
      currentMeasure = ((oldBeatNumber - 1) ~/ beatsPerMeasure) + 1;
      currentBeat = ((oldBeatNumber - 1) % beatsPerMeasure) + 1;
    }

    final measureController = TextEditingController(text: currentMeasure.toString());
    final beatController = TextEditingController(text: currentBeat.toString());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Beat Sync Point'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: measureController,
                      decoration: const InputDecoration(
                        labelText: 'Measure',
                        hintText: 'e.g., 3',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: beatController,
                      decoration: InputDecoration(
                        labelText: 'Beat',
                        hintText: '1-$beatsPerMeasure',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Time signature: ${metronomeProvider.settings.timeSignature.displayString}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newMeasure = int.tryParse(measureController.text);
                final newBeat = int.tryParse(beatController.text);

                if (newMeasure == null || newBeat == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter valid numbers'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                if (newMeasure < 0 || newBeat < 0 || newBeat > beatsPerMeasure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Beat must be 0 or between 1 and $beatsPerMeasure'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                // Calculate new beat number
                final newBeatNumber = (newMeasure == 0 && newBeat == 0)
                    ? 0
                    : ((newMeasure - 1) * beatsPerMeasure) + newBeat;

                // Check for conflicts
                if (rectangle.beatNumbers.contains(newBeatNumber) && newBeatNumber != oldBeatNumber) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Beat sync point already exists at M$newMeasure:B$newBeat'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                // Update the sync point
                final rectangleProvider = context.read<RectangleProvider>();
                rectangle.removeBeatNumber(oldBeatNumber);
                rectangle.addBeatNumber(newBeatNumber);
                rectangleProvider.updateRectangleTimestamps();

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Beat sync point updated to M$newMeasure:B$newBeat'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _editTimestampSyncPoint(BuildContext context, DrawnRectangle rectangle, Duration oldTimestamp) {
    final totalMillis = oldTimestamp.inMilliseconds;
    final minutes = totalMillis ~/ 60000;
    final seconds = (totalMillis % 60000) ~/ 1000;
    final milliseconds = totalMillis % 1000;

    final minutesController = TextEditingController(text: minutes.toString());
    final secondsController = TextEditingController(text: seconds.toString());
    final millisController = TextEditingController(text: milliseconds.toString());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Timestamp Sync Point'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minutesController,
                      decoration: const InputDecoration(
                        labelText: 'Min',
                        hintText: '0-59',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: secondsController,
                      decoration: const InputDecoration(
                        labelText: 'Sec',
                        hintText: '0-59',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: millisController,
                      decoration: const InputDecoration(
                        labelText: 'Ms',
                        hintText: '0-999',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Current: ${_formatDuration(oldTimestamp)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const Text(
                '10ms accuracy',
                style: TextStyle(fontSize: 11, color: Colors.blue),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newMinutes = int.tryParse(minutesController.text);
                final newSeconds = int.tryParse(secondsController.text);
                final newMillis = int.tryParse(millisController.text);

                if (newMinutes == null || newSeconds == null || newMillis == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter valid numbers'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                if (newMinutes < 0 || newSeconds < 0 || newSeconds >= 60 || newMillis < 0 || newMillis >= 1000) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid time values'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                // Round to 10ms accuracy
                final roundedMillis = (newMillis ~/ 10) * 10;
                final newTimestamp = Duration(
                  minutes: newMinutes,
                  seconds: newSeconds,
                  milliseconds: roundedMillis,
                );

                // Check for conflicts
                const tolerance = Duration(milliseconds: 10);
                for (final existing in rectangle.timestamps) {
                  if (existing != oldTimestamp) {
                    final difference = (newTimestamp - existing).abs();
                    if (difference < tolerance) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Sync point already exists at ${_formatDuration(existing)}'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                  }
                }

                // Update the sync point
                final rectangleProvider = context.read<RectangleProvider>();
                rectangle.removeTimestamp(oldTimestamp);
                rectangle.addTimestamp(newTimestamp);
                rectangleProvider.updateRectangleTimestamps();

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Sync point updated to ${_formatDuration(newTimestamp)}'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<RectangleProvider, MetronomeProvider, AppModeProvider>(
      builder: (context, rectangleProvider, metronomeProvider, appModeProvider, _) {
        final selectedRectangle = rectangleProvider.selectedRectangle;

        if (selectedRectangle == null) {
          return const SizedBox.shrink();
        }

        final isBeatMode = metronomeProvider.settings.mode == MetronomeMode.beat;
        final isDesignMode = appModeProvider.isDesignMode;

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
              if (isDesignMode) ...[
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
              ],
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

                              final String displayText;
                              if (beatNumber == 0) {
                                displayText = 'M0:B0';
                              } else {
                                final measureNumber = ((beatNumber - 1) ~/ beatsPerMeasure) + 1;
                                final beatInMeasure = ((beatNumber - 1) % beatsPerMeasure) + 1;
                                displayText = 'M$measureNumber:B$beatInMeasure';
                              }

                              return GestureDetector(
                                onTap: () {
                                  // Seek to beat on tap
                                  metronomeProvider.seekToBeat(beatNumber);
                                },
                                onLongPressStart: isDesignMode ? (details) => _showBeatSyncMenu(
                                  context,
                                  selectedRectangle,
                                  beatNumber,
                                  displayText,
                                  details.globalPosition,
                                ) : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.purple.withValues(alpha: 0.6),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    displayText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
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
                              return GestureDetector(
                                onTap: () {
                                  // Seek to timestamp on tap
                                  final videoProvider = context.read<VideoProvider>();
                                  videoProvider.seekTo(timestamp);
                                },
                                onLongPressStart: isDesignMode ? (details) => _showTimestampSyncMenu(
                                  context,
                                  selectedRectangle,
                                  timestamp,
                                  details.globalPosition,
                                ) : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.green.withValues(alpha: 0.6),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    _formatDuration(timestamp),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
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