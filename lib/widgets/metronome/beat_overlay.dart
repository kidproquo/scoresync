import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/metronome_provider.dart';
import '../../providers/app_mode_provider.dart';

class BeatOverlay extends StatelessWidget {
  const BeatOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<MetronomeProvider, AppModeProvider>(
      builder: (context, metronomeProvider, appModeProvider, _) {
        final isDesignMode = appModeProvider.isDesignMode;

        return Stack(
          children: [
            // Main content area with tap gesture
            GestureDetector(
              onTap: () {
                if (metronomeProvider.isPlaying) {
                  metronomeProvider.stopMetronome();
                } else {
                  metronomeProvider.startMetronome();
                }
              },
              child: Container(
                color: Colors.black,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildMeasureDisplay(metronomeProvider),
                    const SizedBox(height: 8),
                    _buildBeatVisualization(metronomeProvider),
                    const SizedBox(height: 8),
                    _buildBPMDisplay(metronomeProvider),
                    const SizedBox(height: 50),
                  ],
                ),
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(beatsPerMeasure, (index) {
        final beatNumber = index + 1;
        final isCurrentBeat = beatNumber == currentBeat;
        final isAccented = beatNumber == 1;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCurrentBeat
              ? (isAccented ? Colors.red : Colors.blue)
              : Colors.grey[700],
            border: Border.all(
              color: Colors.white,
              width: isCurrentBeat ? 3 : 1,
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
            icon: const Icon(Icons.fast_rewind, color: Colors.white, size: 18),
            onPressed: provider.totalBeats > 0
                ? () => _skipMeasures(provider, -4)
                : null,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(
              minWidth: 28,
              minHeight: 28,
            ),
          ),
          // Rewind 1 measure
          IconButton(
            icon: const Icon(Icons.skip_previous, color: Colors.white, size: 18),
            onPressed: provider.totalBeats > 0
                ? () => _skipMeasures(provider, -1)
                : null,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(
              minWidth: 28,
              minHeight: 28,
            ),
          ),
          // Stop button (resets counter)
          IconButton(
            icon: const Icon(Icons.stop, color: Colors.white, size: 18),
            onPressed: (provider.isPlaying || provider.totalBeats > 0)
                ? () => provider.resetMetronome()
                : null,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(
              minWidth: 28,
              minHeight: 28,
            ),
          ),
          // Play/Pause button
          IconButton(
            icon: Icon(
              provider.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () {
              if (provider.isPlaying) {
                provider.stopMetronome();
              } else {
                provider.startMetronome();
              }
            },
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
          // Forward 1 measure
          IconButton(
            icon: const Icon(Icons.skip_next, color: Colors.white, size: 18),
            onPressed: () => _skipMeasures(provider, 1),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(
              minWidth: 28,
              minHeight: 28,
            ),
          ),
          // Forward 4 measures
          IconButton(
            icon: const Icon(Icons.fast_forward, color: Colors.white, size: 18),
            onPressed: () => _skipMeasures(provider, 4),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(
              minWidth: 28,
              minHeight: 28,
            ),
          ),
        ],
      ),
    );
  }

  void _skipMeasures(MetronomeProvider provider, int measures) {
    final targetMeasure = (provider.currentMeasure + measures).clamp(1, 9999);
    provider.seekToMeasure(targetMeasure);
  }
}