import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/metronome_provider.dart';

class MetronomeButton extends StatelessWidget {
  final VoidCallback onPressed;
  
  const MetronomeButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MetronomeProvider>(
      builder: (context, metronomeProvider, _) {
        final isEnabled = metronomeProvider.settings.isEnabled;
        final isPlaying = metronomeProvider.isPlaying;
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(12),
                child: Stack(
                  children: [
                    // Metronome icon
                    Center(
                      child: Icon(
                        Icons.music_note,
                        color: isEnabled ? Colors.white : Colors.white54,
                        size: 28,
                      ),
                    ),
                    // Playing indicator
                    if (isPlaying)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    // BPM label
                    if (isEnabled)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${metronomeProvider.settings.bpm}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}