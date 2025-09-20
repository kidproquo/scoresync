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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
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
              // Add Change URL button (only in design mode)
              if (widget.isDesignMode) ...[
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isEditingUrl = !_isEditingUrl;
                    });
                  },
                  icon: Icon(_isEditingUrl ? Icons.close : Icons.edit),
                  tooltip: _isEditingUrl ? 'Cancel URL edit' : 'Change video URL',
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                onPressed: widget.isPlayerReady ? widget.onSkipBackward : null,
                icon: const Icon(Icons.replay_10),
                tooltip: widget.isPlayerReady ? '10 seconds backward' : 'Loading video...',
              ),
              IconButton(
                onPressed: widget.isPlayerReady ? widget.onPlayPause : null,
                icon: widget.isPlayerReady 
                    ? Icon(widget.isPlaying ? Icons.pause : Icons.play_arrow)
                    : const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                tooltip: widget.isPlayerReady 
                    ? (widget.isPlaying ? 'Pause' : 'Play')
                    : 'Loading video...',
              ),
              IconButton(
                onPressed: widget.isPlayerReady ? widget.onStop : null,
                icon: const Icon(Icons.stop),
                tooltip: widget.isPlayerReady ? 'Stop' : 'Loading video...',
              ),
              IconButton(
                onPressed: widget.isPlayerReady ? widget.onSkipForward : null,
                icon: const Icon(Icons.forward_10),
                tooltip: widget.isPlayerReady ? '10 seconds forward' : 'Loading video...',
              ),
              const SizedBox(width: 16),
              Text(
                widget.formatDuration(widget.currentPosition),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(width: 8),
              const Text('/'),
              const SizedBox(width: 8),
              Text(
                widget.formatDuration(widget.totalDuration),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              widget.isPlayerReady
                  ? DropdownButton<double>(
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
                  : Container(
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
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
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
              activeColor: Theme.of(context).colorScheme.primary,
              inactiveColor: Theme.of(context).colorScheme.outline,
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