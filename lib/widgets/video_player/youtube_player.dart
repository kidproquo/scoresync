import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'dart:developer' as developer;
import 'video_controls.dart';

class YouTubePlayerWidget extends StatefulWidget {
  const YouTubePlayerWidget({super.key});

  @override
  State<YouTubePlayerWidget> createState() => _YouTubePlayerWidgetState();
}

class _YouTubePlayerWidgetState extends State<YouTubePlayerWidget> {
  YoutubePlayerController? _controller;
  String _currentUrl = '';
  bool _isPlayerReady = false;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _playbackRate = 1.0;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _loadVideo(String url) {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final videoId = YoutubePlayer.convertUrlToId(url);
      if (videoId == null) {
        setState(() {
          _errorMessage = 'Invalid YouTube URL';
          _isLoading = false;
        });
        return;
      }

      _controller?.dispose();

      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          enableCaption: false,
          hideThumbnail: true,
          showLiveFullscreenButton: false,
        ),
      );

      _controller!.addListener(_onPlayerStateChanged);

      setState(() {
        _currentUrl = url;
        _isPlayerReady = false;
        _isPlaying = false;
        _currentPosition = Duration.zero;
        _totalDuration = Duration.zero;
        _playbackRate = 1.0;
        _isLoading = false;
      });

      developer.log('Loading YouTube video: $url');
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading video: $e';
        _isLoading = false;
      });
      developer.log('Error loading YouTube video: $e');
    }
  }

  void _onPlayerStateChanged() {
    if (_controller == null) return;

    setState(() {
      _isPlayerReady = _controller!.value.isReady;
      _isPlaying = _controller!.value.isPlaying;
      _currentPosition = _controller!.value.position;
      _totalDuration = _controller!.metadata.duration;
    });
  }

  void _onPlayPause() {
    if (_controller == null || !_isPlayerReady) return;

    if (_isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  void _onStop() {
    if (_controller == null || !_isPlayerReady) return;
    _controller!.seekTo(Duration.zero);
    _controller!.pause();
  }

  void _onSeek(Duration position) {
    if (_controller == null || !_isPlayerReady) return;
    _controller!.seekTo(position);
  }

  void _onSkipBackward() {
    if (_controller == null || !_isPlayerReady) return;
    final newPosition = _currentPosition - const Duration(seconds: 10);
    _controller!.seekTo(newPosition.isNegative ? Duration.zero : newPosition);
  }

  void _onSkipForward() {
    if (_controller == null || !_isPlayerReady) return;
    final newPosition = _currentPosition + const Duration(seconds: 10);
    _controller!.seekTo(newPosition > _totalDuration ? _totalDuration : newPosition);
  }

  void _onPlaybackRateChanged(double rate) {
    if (_controller == null || !_isPlayerReady) return;
    _controller!.setPlaybackRate(rate);
    setState(() {
      _playbackRate = rate;
    });
    developer.log('Playback rate changed to: ${rate}x');
  }

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

  Widget _buildPlayer() {
    if (_controller == null) {
      return _buildNoVideoSelected();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return YoutubePlayer(
      controller: _controller!,
      showVideoProgressIndicator: false,
      progressIndicatorColor: Theme.of(context).colorScheme.primary,
      topActions: <Widget>[
        const SizedBox(width: 8.0),
        Expanded(
          child: Text(
            _controller!.metadata.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18.0,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
      onReady: () {
        setState(() {
          _isPlayerReady = true;
          _isLoading = false;
        });
        developer.log('YouTube player ready');
      },
      onEnded: (data) {
        developer.log('Video ended');
      },
    );
  }

  Widget _buildNoVideoSelected() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Video Selected',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a YouTube URL below to load a video',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading Video',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.red[600],
                ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
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
        Expanded(
          child: Container(
            color: Colors.black,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  )
                : _buildPlayer(),
          ),
        ),
        VideoControls(
          isPlaying: _isPlaying,
          isPlayerReady: _isPlayerReady,
          currentPosition: _currentPosition,
          totalDuration: _totalDuration,
          playbackRate: _playbackRate,
          currentUrl: _currentUrl,
          onLoadVideo: _loadVideo,
          onPlayPause: _onPlayPause,
          onStop: _onStop,
          onSeek: _onSeek,
          onSkipBackward: _onSkipBackward,
          onSkipForward: _onSkipForward,
          onPlaybackRateChanged: _onPlaybackRateChanged,
          formatDuration: _formatDuration,
        ),
      ],
    );
  }
}