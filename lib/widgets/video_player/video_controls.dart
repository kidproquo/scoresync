import 'package:flutter/material.dart';

class VideoControls extends StatefulWidget {
  final bool isPlaying;
  final bool isPlayerReady;
  final Duration currentPosition;
  final Duration totalDuration;
  final double playbackRate;
  final String currentUrl;
  final bool isDesignMode;
  final Function(String) onLoadVideo;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final Function(Duration) onSeek;
  final VoidCallback onSkipBackward;
  final VoidCallback onSkipForward;
  final Function(double) onPlaybackRateChanged;
  final String Function(Duration) formatDuration;

  const VideoControls({
    super.key,
    required this.isPlaying,
    required this.isPlayerReady,
    required this.currentPosition,
    required this.totalDuration,
    required this.playbackRate,
    required this.currentUrl,
    required this.isDesignMode,
    required this.onLoadVideo,
    required this.onPlayPause,
    required this.onStop,
    required this.onSeek,
    required this.onSkipBackward,
    required this.onSkipForward,
    required this.onPlaybackRateChanged,
    required this.formatDuration,
  });

  @override
  State<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<VideoControls> {
  final TextEditingController _urlController = TextEditingController();
  bool _isEditingUrl = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = widget.currentUrl;
  }

  @override
  void didUpdateWidget(VideoControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentUrl != oldWidget.currentUrl) {
      _urlController.text = widget.currentUrl;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _loadVideoFromUrl() {
    if (_urlController.text.trim().isNotEmpty) {
      widget.onLoadVideo(_urlController.text.trim());
      setState(() {
        _isEditingUrl = false;
      });
    }
  }

  Widget _buildUrlInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Change YouTube URL',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.link, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    hintText: 'Enter YouTube URL...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadVideoFromUrl(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _loadVideoFromUrl,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Load'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isEditingUrl = false;
                  });
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls() {
    final isPlaybackMode = !widget.isDesignMode;
    final iconColor = isPlaybackMode ? Colors.white : null;
    final textColor = isPlaybackMode ? Colors.white : null;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isPlaybackMode ? 12 : 16,
        vertical: isPlaybackMode ? 8 : 12,
      ),
      decoration: isPlaybackMode ? null : BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Control buttons with dynamic sizing
              if (!isPlaybackMode && widget.isDesignMode) ...[
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isEditingUrl = !_isEditingUrl;
                    });
                  },
                  icon: Icon(_isEditingUrl ? Icons.close : Icons.edit, color: iconColor),
                  tooltip: _isEditingUrl ? 'Cancel URL edit' : 'Change video URL',
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                onPressed: widget.isPlayerReady ? widget.onSkipBackward : null,
                icon: Icon(Icons.replay_10, color: iconColor, size: isPlaybackMode ? 20 : null),
                tooltip: '10 seconds backward',
                padding: isPlaybackMode ? const EdgeInsets.all(4) : null,
                constraints: isPlaybackMode ? const BoxConstraints(minWidth: 32, minHeight: 32) : null,
              ),
              IconButton(
                onPressed: widget.isPlayerReady ? widget.onPlayPause : null,
                icon: widget.isPlayerReady 
                    ? Icon(
                        widget.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: iconColor,
                        size: isPlaybackMode ? 24 : null,
                      )
                    : SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: iconColor ?? Theme.of(context).colorScheme.primary,
                        ),
                      ),
                tooltip: widget.isPlaying ? 'Pause' : 'Play',
                padding: isPlaybackMode ? const EdgeInsets.all(4) : null,
                constraints: isPlaybackMode ? const BoxConstraints(minWidth: 32, minHeight: 32) : null,
              ),
              if (!isPlaybackMode)
                IconButton(
                  onPressed: widget.isPlayerReady ? widget.onStop : null,
                  icon: Icon(Icons.stop, color: iconColor),
                  tooltip: 'Stop',
                ),
              IconButton(
                onPressed: widget.isPlayerReady ? widget.onSkipForward : null,
                icon: Icon(Icons.forward_10, color: iconColor, size: isPlaybackMode ? 20 : null),
                tooltip: '10 seconds forward',
                padding: isPlaybackMode ? const EdgeInsets.all(4) : null,
                constraints: isPlaybackMode ? const BoxConstraints(minWidth: 32, minHeight: 32) : null,
              ),
              const SizedBox(width: 8),
              if (!isPlaybackMode) const SizedBox(width: 16),
              isPlaybackMode
                  ? Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.formatDuration(widget.currentPosition),
                            style: TextStyle(color: textColor, fontSize: 12),
                          ),
                          Text(' / ', style: TextStyle(color: textColor?.withValues(alpha: 0.7), fontSize: 12)),
                          Text(
                            widget.formatDuration(widget.totalDuration),
                            style: TextStyle(color: textColor?.withValues(alpha: 0.7), fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : Row(
                      children: [
                        Text(
                          widget.formatDuration(widget.currentPosition),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                        ),
                        const SizedBox(width: 8),
                        const Text('/'),
                        const SizedBox(width: 8),
                        Text(
                          widget.formatDuration(widget.totalDuration),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor),
                        ),
                      ],
                    ),
              if (!isPlaybackMode) const Spacer(),
              if (isPlaybackMode && widget.isDesignMode)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isEditingUrl = !_isEditingUrl;
                    });
                  },
                  icon: Icon(
                    _isEditingUrl ? Icons.close : Icons.edit,
                    color: iconColor,
                    size: 18,
                  ),
                  tooltip: _isEditingUrl ? 'Cancel' : 'Change URL',
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              if (widget.isPlayerReady)
                isPlaybackMode
                    ? PopupMenuButton<double>(
                        icon: Icon(Icons.speed, color: iconColor, size: 18),
                        tooltip: 'Playback speed',
                        onSelected: widget.onPlaybackRateChanged,
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 0.5, child: Text('0.5x')),
                          const PopupMenuItem(value: 1.0, child: Text('1.0x')),
                          const PopupMenuItem(value: 1.25, child: Text('1.25x')),
                          const PopupMenuItem(value: 1.5, child: Text('1.5x')),
                          const PopupMenuItem(value: 2.0, child: Text('2.0x')),
                        ],
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      )
                    : DropdownButton<double>(
                        value: widget.playbackRate,
                        onChanged: (double? value) {
                          if (value != null) widget.onPlaybackRateChanged(value);
                        },
                        items: const [
                          DropdownMenuItem(value: 0.5, child: Text('0.5x')),
                          DropdownMenuItem(value: 1.0, child: Text('1.0x')),
                          DropdownMenuItem(value: 1.25, child: Text('1.25x')),
                          DropdownMenuItem(value: 1.5, child: Text('1.5x')),
                          DropdownMenuItem(value: 2.0, child: Text('2.0x')),
                        ],
                        underline: Container(),
                        isDense: true,
                      )
              else if (!isPlaybackMode)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: const Text(
                    'Loading...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: isPlaybackMode ? 3 : 4,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: isPlaybackMode ? 6 : 8),
              overlayShape: RoundSliderOverlayShape(overlayRadius: isPlaybackMode ? 12 : 16),
              activeTrackColor: isPlaybackMode ? Colors.white : Theme.of(context).colorScheme.primary,
              inactiveTrackColor: isPlaybackMode ? Colors.white30 : Theme.of(context).colorScheme.outline,
              thumbColor: isPlaybackMode ? Colors.white : Theme.of(context).colorScheme.primary,
              overlayColor: isPlaybackMode ? Colors.white24 : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: widget.totalDuration.inMilliseconds > 0
                  ? widget.currentPosition.inMilliseconds.toDouble()
                  : 0.0,
              max: widget.totalDuration.inMilliseconds.toDouble(),
              onChanged: widget.isPlayerReady
                  ? (value) {
                      widget.onSeek(Duration(milliseconds: value.round()));
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentUrlDisplay() {
    if (widget.currentUrl.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            const Text(
              'No video loaded. Click edit to add a YouTube URL.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.video_library, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.currentUrl,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isEditingUrl && widget.isDesignMode) 
          _buildUrlInput()
        else if (widget.isDesignMode)
          _buildCurrentUrlDisplay(),
        _buildPlaybackControls(),
      ],
    );
  }
}