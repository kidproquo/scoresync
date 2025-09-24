import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/metronome_provider.dart';
import '../../models/metronome_settings.dart';

class MetronomeSettingsPanel extends StatelessWidget {
  final VoidCallback onClose;
  
  const MetronomeSettingsPanel({
    super.key,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MetronomeProvider>(
      builder: (context, metronomeProvider, _) {
        final settings = metronomeProvider.settings;
        
        return Container(
          height: 420,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.9),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Metronome Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Enable/Disable Toggle
                      _buildToggleRow(
                        'Metronome',
                        settings.isEnabled,
                        (value) => metronomeProvider.toggleEnabled(),
                      ),
                      const SizedBox(height: 16),
                      
                      // BPM Slider
                      _buildBPMSlider(context, settings, metronomeProvider),
                      const SizedBox(height: 16),
                      
                      // Time Signature Selector
                      _buildTimeSignatureSelector(context, settings, metronomeProvider),
                      const SizedBox(height: 16),
                      
                      // Count-in Toggle
                      _buildToggleRow(
                        'Count-in',
                        settings.countInEnabled,
                        (value) => metronomeProvider.setCountInEnabled(value),
                      ),
                      const SizedBox(height: 16),
                      
                      // Volume Slider
                      _buildVolumeSlider(context, settings, metronomeProvider),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToggleRow(String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildBPMSlider(BuildContext context, MetronomeSettings settings, MetronomeProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'BPM',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            Text(
              '${settings.bpm}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.blue,
            inactiveTrackColor: Colors.white30,
            thumbColor: Colors.blue,
            overlayColor: Colors.blue.withValues(alpha: 0.3),
          ),
          child: Slider(
            value: settings.bpm.toDouble(),
            min: 40,
            max: 240,
            divisions: 200,
            onChanged: settings.isEnabled 
                ? (value) => provider.setBPM(value.round())
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSignatureSelector(BuildContext context, MetronomeSettings settings, MetronomeProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Time Signature',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: TimeSignatures.common.map((ts) {
            final isSelected = settings.timeSignature == ts;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: settings.isEnabled 
                    ? () => provider.setTimeSignature(ts)
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Colors.blue 
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected 
                          ? Colors.blue 
                          : Colors.white30,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    ts.displayString,
                    style: TextStyle(
                      color: isSelected || !settings.isEnabled
                          ? Colors.white 
                          : Colors.white70,
                      fontWeight: isSelected 
                          ? FontWeight.bold 
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildVolumeSlider(BuildContext context, MetronomeSettings settings, MetronomeProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Volume',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            Text(
              '${(settings.volume * 100).round()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Volume slider and preview buttons on same row
        Row(
          children: [
            // Volume slider (takes up less space)
            Expanded(
              flex: 3,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.blue,
                  inactiveTrackColor: Colors.white30,
                  thumbColor: Colors.blue,
                  overlayColor: Colors.blue.withValues(alpha: 0.3),
                ),
                child: Slider(
                  value: settings.volume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  onChanged: settings.isEnabled 
                      ? (value) => provider.setVolume(value)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Preview metronome button
            _buildCompactPreviewButton(
              'Preview',
              Icons.play_arrow,
              () => provider.previewMetronome(),
              enabled: settings.isEnabled,
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildCompactPreviewButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
    {required bool enabled}
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: enabled 
                ? Colors.white.withValues(alpha: 0.1) 
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: enabled ? Colors.white30 : Colors.white10,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: enabled ? Colors.white : Colors.white30,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? Colors.white70 : Colors.white30,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}