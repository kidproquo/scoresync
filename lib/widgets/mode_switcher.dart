import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_mode_provider.dart';
import '../models/app_mode.dart';

class ModeSwitcher extends StatelessWidget {
  const ModeSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppModeProvider>(
      builder: (context, appModeProvider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeButton(
                  context,
                  AppMode.design,
                  Icons.edit,
                  appModeProvider.isDesignMode,
                  () => appModeProvider.setDesignMode(),
                ),
                _buildModeButton(
                  context,
                  AppMode.playback,
                  Icons.play_arrow,
                  appModeProvider.isPlaybackMode,
                  () => appModeProvider.setPlaybackMode(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeButton(
    BuildContext context,
    AppMode mode,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              mode == AppMode.design ? 'Design' : 'Playback',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}