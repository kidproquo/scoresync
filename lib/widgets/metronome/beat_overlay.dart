import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/metronome_provider.dart';
import '../../providers/app_mode_provider.dart';
import 'count_in_overlay.dart';

class BeatOverlay extends StatelessWidget {
  const BeatOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<MetronomeProvider, AppModeProvider>(
      builder: (context, metronomeProvider, appModeProvider, _) {
        final isDesignMode = appModeProvider.isDesignMode;

        return Stack(
          children: [
            // Background
            Container(color: Colors.black),
            // Main content area with tap gesture
            Positioned.fill(
              bottom: 60, // Exclude controls area
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (metronomeProvider.isPlaying) {
                    metronomeProvider.pauseMetronome();
                  } else {
                    metronomeProvider.startMetronome(isPlaybackMode: !isDesignMode);
                  }
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildMeasureDisplay(metronomeProvider),
                    const SizedBox(height: 1),
                    _buildBeatVisualization(metronomeProvider),
                    const SizedBox(height: 1),
                    _buildBPMDisplay(metronomeProvider),
                  ],
                ),
              ),
            ),
            // Count-in overlay
            if (metronomeProvider.isCountingIn)
              IgnorePointer(
                child: CountInOverlay(
                  currentBeat: metronomeProvider.currentBeat,
                  totalBeats: metronomeProvider.settings.timeSignature.numerator,
                ),
              ),
            // Controls overlay at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildControls(metronomeProvider, isDesignMode),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMeasureDisplay(MetronomeProvider provider) {
    return Text(
      'Measure ${provider.currentMeasure}',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildBeatVisualization(MetronomeProvider provider) {
    final beatsPerMeasure = provider.settings.timeSignature.numerator;
    final currentBeat = provider.currentBeat;

    // Adjust size and spacing based on number of beats
    final circleSize = beatsPerMeasure > 8 ? 16.0 : 20.0;
    final horizontalMargin = beatsPerMeasure > 8 ? 4.0 : 8.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(beatsPerMeasure, (index) {
        final beatNumber = index + 1;
        final isCurrentBeat = beatNumber == currentBeat;
        final isAccented = beatNumber == 1;

        return Container(
          margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCurrentBeat
              ? (isAccented ? Colors.red : Colors.blue)
              : Colors.grey[700],
            border: Border.all(
              color: Colors.white,
              width: isCurrentBeat ? 2 : 1,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBPMDisplay(MetronomeProvider provider) {
    final showEffective = provider.playbackRate != 1.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              showEffective
                  ? '${provider.effectiveBPM} BPM'
                  : '${provider.settings.bpm} BPM',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
            if (showEffective) ...[
              const SizedBox(height: 2),
              Text(
                '${provider.settings.bpm} × ${provider.playbackRate}x',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(width: 12),
        PopupMenuButton<double>(
          icon: Icon(Icons.speed, color: Colors.grey[400], size: 18),
          tooltip: 'Playback speed',
          onSelected: (double rate) {
            provider.setPlaybackRate(rate);
          },
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 0.5, child: Text('0.5x')),
            const PopupMenuItem(value: 0.6, child: Text('0.6x')),
            const PopupMenuItem(value: 0.7, child: Text('0.7x')),
            const PopupMenuItem(value: 0.8, child: Text('0.8x')),
            const PopupMenuItem(value: 0.9, child: Text('0.9x')),
            const PopupMenuItem(value: 1.0, child: Text('1.0x')),
            const PopupMenuItem(value: 1.2, child: Text('1.2x')),
          ],
        ),
        const SizedBox(width: 8),
        // Enhanced loop button with details
        _buildLoopButton(provider),
      ],
    );
  }

  Widget _buildControls(MetronomeProvider provider, bool isDesignMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Rewind 4 measures
          IconButton(
            icon: const Icon(Icons.fast_rewind, color: Colors.white, size: 20),
            onPressed: provider.totalBeats > 0
                ? () => _skipMeasures(provider, -4)
                : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
          ),
          // Rewind 1 measure
          IconButton(
            icon: const Icon(Icons.skip_previous, color: Colors.white, size: 20),
            onPressed: provider.totalBeats > 0
                ? () => _skipMeasures(provider, -1)
                : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
          ),
          // Stop button (resets counter)
          IconButton(
            icon: const Icon(Icons.stop, color: Colors.white, size: 20),
            onPressed: (provider.isPlaying || provider.totalBeats > 0)
                ? () => provider.resetMetronome()
                : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
          ),
          // Play/Pause button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (provider.isPlaying) {
                  provider.pauseMetronome();
                } else {
                  provider.startMetronome(isPlaybackMode: !isDesignMode);
                }
              },
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: Icon(
                  provider.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
          // Forward 1 measure
          IconButton(
            icon: const Icon(Icons.skip_next, color: Colors.white, size: 20),
            onPressed: () => _skipMeasures(provider, 1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
          ),
          // Forward 4 measures
          IconButton(
            icon: const Icon(Icons.fast_forward, color: Colors.white, size: 20),
            onPressed: () => _skipMeasures(provider, 4),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoopButton(MetronomeProvider provider) {
    // Determine button state and appearance
    final hasLoop = provider.loopStartBeat != null && provider.loopEndBeat != null;
    final isActive = provider.isLoopActive;
    final canLoop = provider.canLoop;

    // Calculate loop details if available
    String loopText = '';
    if (hasLoop) {
      final beatsPerMeasure = provider.settings.timeSignature.numerator;
      final startMeasure = ((provider.loopStartBeat! - 1) ~/ beatsPerMeasure) + 1;
      final endMeasure = ((provider.loopEndBeat! - 1) ~/ beatsPerMeasure) + 1;
      loopText = 'M$startMeasure-M$endMeasure';
    }

    // Determine colors based on state
    Color iconColor;
    Color textColor;
    Color backgroundColor;

    if (!hasLoop) {
      // No loop set - disabled state
      iconColor = Colors.grey[600]!;
      textColor = Colors.grey[600]!;
      backgroundColor = Colors.transparent;
    } else if (isActive) {
      // Loop active - enabled and on
      iconColor = Colors.blue;
      textColor = Colors.blue;
      backgroundColor = Colors.blue.withValues(alpha: 0.1);
    } else {
      // Loop set but not active - enabled but off
      iconColor = Colors.grey[400]!;
      textColor = Colors.grey[400]!;
      backgroundColor = Colors.transparent;
    }

    return GestureDetector(
      onTap: canLoop ? () => provider.toggleLoop() : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: isActive ? Border.all(color: Colors.blue.withValues(alpha: 0.4)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? Icons.repeat_on : Icons.repeat,
              color: iconColor,
              size: 16,
            ),
            if (hasLoop) ...[
              const SizedBox(width: 4),
              Text(
                loopText,
                style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _skipMeasures(MetronomeProvider provider, int measures) {
    final targetMeasure = (provider.currentMeasure + measures).clamp(1, 9999);
    provider.seekToMeasure(targetMeasure);
  }
}