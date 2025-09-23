import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/metronome_provider.dart';

class MetronomeIndicator extends StatefulWidget {
  const MetronomeIndicator({super.key});

  @override
  State<MetronomeIndicator> createState() => _MetronomeIndicatorState();
}

class _MetronomeIndicatorState extends State<MetronomeIndicator> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  
  int _lastBeat = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MetronomeProvider>(
      builder: (context, metronomeProvider, _) {
        if (!metronomeProvider.settings.isEnabled || !metronomeProvider.isPlaying) {
          return const SizedBox.shrink();
        }

        // Trigger animation on beat change
        if (metronomeProvider.currentBeat != _lastBeat) {
          _lastBeat = metronomeProvider.currentBeat;
          _animationController.forward(from: 0);
        }

        final isDownbeat = metronomeProvider.currentBeat == 1;
        
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDownbeat ? Colors.blue : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: (isDownbeat ? Colors.blue : Colors.white)
                            .withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}