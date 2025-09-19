import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'video_controls.dart';
import '../../providers/song_provider.dart';
import '../../providers/video_provider.dart';

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
  Timer? _loadingTimeout;

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    if (_controller != null) {
      try {
        _controller!.removeListener(_onPlayerStateChanged);
        _controller!.dispose();
      } catch (e) {
        developer.log('Error disposing controller: $e');
      }
      _controller = null;
    }
    super.dispose();
  }

  void _loadVideo(String url) {
    // Don't reload if it's the same URL and controller exists
    if (_currentUrl == url && _controller != null) {
      developer.log('Video already loaded: $url');
      return;
    }
    
    // Prevent loading if already loading the same URL
    if (_isLoading && _currentUrl == url) {
      developer.log('Already loading video: $url');
      return;
    }

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

      // Properly dispose of existing controller before creating new one
      if (_controller != null) {
        try {
          _controller!.removeListener(_onPlayerStateChanged);
          _controller!.dispose();
        } catch (e) {
          developer.log('Error disposing previous controller: $e');
        }
        _controller = null;
        
        // Small delay to ensure cleanup is complete
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            _createController(videoId, url);
          }
        });
      } else {
        _createController(videoId, url);
      }

      developer.log('Loading YouTube video: $url');
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading video: $e';
        _isLoading = false;
      });
      developer.log('Error loading YouTube video: $e');
    }
  }

  void _createController(String videoId, String url) {
    developer.log('Creating new controller for video: $url');
    
    // Cancel any existing timeout
    _loadingTimeout?.cancel();
    
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

    // Set up VideoProvider callback for seeking
    final videoProvider = context.read<VideoProvider>();
    videoProvider.setSeekToCallback(_onSeek);

    // Set a timeout to handle cases where player never becomes ready
    _loadingTimeout = Timer(const Duration(seconds: 10), () {
      if (mounted && !_isPlayerReady && _currentUrl == url) {
        developer.log('YouTube player loading timeout for: $url');
        setState(() {
          _errorMessage = 'Video failed to load. Please check the URL or try again.';
          _isLoading = false;
        });
      }
    });

    // Save video URL to current song
    final songProvider = context.read<SongProvider>();
    if (songProvider.currentSong != null) {
      songProvider.updateSongVideoUrl(url);
    }
  }

  void _clearVideo() {
    _loadingTimeout?.cancel();
    if (_controller != null) {
      try {
        _controller!.removeListener(_onPlayerStateChanged);
        _controller!.dispose();
      } catch (e) {
        developer.log('Error disposing controller in clear: $e');
      }
      _controller = null;
    }

    setState(() {
      _currentUrl = '';
      _isPlayerReady = false;
      _isPlaying = false;
      _currentPosition = Duration.zero;
      _totalDuration = Duration.zero;
      _playbackRate = 1.0;
      _errorMessage = null;
      _isLoading = false;
    });

    developer.log('Video player cleared');
  }

  void _onPlayerStateChanged() {
    if (_controller == null || !mounted) return;

    try {
      final wasReady = _isPlayerReady;
      final isNowReady = _controller!.value.isReady;
      
      setState(() {
        _isPlayerReady = isNowReady;
        _isPlaying = _controller!.value.isPlaying;
        _currentPosition = _controller!.value.position;
        _totalDuration = _controller!.metadata.duration;
      });

      // Update VideoProvider with current state
      final videoProvider = context.read<VideoProvider>();
      videoProvider.setPlayerReady(isNowReady);
      videoProvider.setPlaying(_isPlaying);
      videoProvider.setCurrentPosition(_currentPosition);
      videoProvider.setTotalDuration(_totalDuration);
      
      if (!wasReady && isNowReady) {
        developer.log('YouTube player ready - controls enabled');
      }
    } catch (e) {
      developer.log('Error in player state change: $e');
    }
  }

  void _onPlayPause() {
    if (_controller == null || !_isPlayerReady || !mounted) return;
    
    try {
      if (_isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    } catch (e) {
      developer.log('Error in play/pause: $e');
    }
  }

  void _onStop() {
    if (_controller == null || !_isPlayerReady || !mounted) return;
    
    try {
      _controller!.seekTo(Duration.zero);
      _controller!.pause();
    } catch (e) {
      developer.log('Error in stop: $e');
    }
  }

  void _onSeek(Duration position) {
    if (_controller == null || !_isPlayerReady || !mounted) return;
    
    try {
      _controller!.seekTo(position);
    } catch (e) {
      developer.log('Error in seek: $e');
    }
  }

  void _onSkipBackward() {
    if (_controller == null || !_isPlayerReady || !mounted) return;
    
    try {
      final newPosition = _currentPosition - const Duration(seconds: 10);
      _controller!.seekTo(newPosition.isNegative ? Duration.zero : newPosition);
    } catch (e) {
      developer.log('Error in skip backward: $e');
    }
  }

  void _onSkipForward() {
    if (_controller == null || !_isPlayerReady || !mounted) return;
    
    try {
      final newPosition = _currentPosition + const Duration(seconds: 10);
      _controller!.seekTo(newPosition > _totalDuration ? _totalDuration : newPosition);
    } catch (e) {
      developer.log('Error in skip forward: $e');
    }
  }

  void _onPlaybackRateChanged(double rate) {
    if (_controller == null || !_isPlayerReady || !mounted) return;
    
    try {
      _controller!.setPlaybackRate(rate);
      if (mounted) {
        setState(() {
          _playbackRate = rate;
        });
      }
      developer.log('Playback rate changed to: ${rate}x');
    } catch (e) {
      developer.log('Error changing playback rate: $e');
    }
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
      key: ValueKey(_currentUrl), // Use URL as key to help with view management
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
        if (mounted) {
          _loadingTimeout?.cancel();
          setState(() {
            _isPlayerReady = true;
            _isLoading = false;
            _errorMessage = null;
          });
          developer.log('YouTube player onReady callback');
        }
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
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              if (_currentUrl.isNotEmpty) {
                setState(() {
                  _errorMessage = null;
                });
                _loadVideo(_currentUrl);
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SongProvider, VideoProvider>(
      builder: (context, songProvider, videoProvider, _) {
        final hasSong = songProvider.currentSong != null;
        
        // Check if we need to load a video URL from VideoProvider
        if (hasSong && videoProvider.hasVideo && videoProvider.currentUrl != _currentUrl && !_isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && videoProvider.currentUrl != _currentUrl) {
              developer.log('VideoProvider URL changed, loading: ${videoProvider.currentUrl}');
              _loadVideo(videoProvider.currentUrl);
            }
          });
        } else if (hasSong && !videoProvider.hasVideo && _currentUrl.isNotEmpty) {
          // Clear video if song has no video URL
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              developer.log('Song has no video URL, clearing player');
              _clearVideo();
            }
          });
        }
        
        if (!hasSong) {
          return _buildNoSongPlaceholder();
        }
        
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
      },
    );
  }

  Widget _buildNoSongPlaceholder() {
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
            'No Video Player',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create or load a song to access video features',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}