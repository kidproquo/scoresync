import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import 'dart:async';
import '../../providers/song_provider.dart';
import '../../providers/video_provider.dart';
import '../../providers/app_mode_provider.dart';
import '../../providers/metronome_provider.dart';
import '../metronome/count_in_overlay.dart';

class YouTubePlayerWidget extends StatefulWidget {
  final bool showGuiControls;
  
  const YouTubePlayerWidget({
    super.key,
    this.showGuiControls = true,
  });

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
  Timer? _positionTimer;
  VideoProvider? _videoProvider;
  SongProvider? _songProvider;
  MetronomeProvider? _metronomeProvider;
  bool _showCountIn = false;
  Timer? _countInTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Safely get provider references
    _videoProvider ??= context.read<VideoProvider>();
    _songProvider ??= context.read<SongProvider>();
    _metronomeProvider ??= context.read<MetronomeProvider>();
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    _positionTimer?.cancel();
    _countInTimer?.cancel();
    
    // Clear all callbacks first to prevent future calls using stored reference
    _videoProvider?.setSeekToCallback(null);
    _videoProvider?.setPlayCallback(null);
    _videoProvider?.setPauseCallback(null);
    _videoProvider?.setForcePauseCallback(null);

    
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
    if (_currentUrl == url && _controller != null && !_isLoading) {
      developer.log('Video already loaded: $url');
      return;
    }
    
    // Prevent multiple simultaneous loads
    if (_isLoading) {
      developer.log('Already loading video, ignoring new request: $url');
      return;
    }

    developer.log('Loading YouTube video: $url');

    try {
      final videoId = YoutubePlayer.convertUrlToId(url);
      if (videoId == null) {
        setState(() {
          _errorMessage = 'Invalid YouTube URL';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Stop any existing timers first
      _loadingTimeout?.cancel();
      _positionTimer?.cancel();

      // If controller exists, dispose it safely
      if (_controller != null) {
        _disposeCurrentController();
        
        // Wait for disposal to complete before creating new controller
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && context.mounted) {
            _createController(videoId, url);
          }
        });
      } else {
        _createController(videoId, url);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading video: $e';
        _isLoading = false;
      });
      developer.log('Error loading YouTube video: $e');
    }
  }

  void _disposeCurrentController() {
    if (_controller == null) return;
    
    developer.log('Disposing current controller');
    
    // Clear all callbacks immediately to prevent future calls
    _videoProvider?.setSeekToCallback(null);
    _videoProvider?.setPlayCallback(null);
    _videoProvider?.setPauseCallback(null);
    _videoProvider?.setForcePauseCallback(null);

    
    try {
      // Remove listener before disposing
      _controller!.removeListener(_onPlayerStateChanged);
      _controller!.dispose();
    } catch (e) {
      developer.log('Error disposing controller: $e');
    } finally {
      _controller = null;
      _isPlayerReady = false;
      _isPlaying = false;
      _currentPosition = Duration.zero;
      _totalDuration = Duration.zero;
      _playbackRate = 1.0;
    }
  }

  void _createController(String videoId, String url) {
    // Ensure we're not already creating a controller
    if (_controller != null) {
      developer.log('Controller already exists, not creating new one');
      return;
    }
    
    developer.log('Creating new controller for video: $url');
    
    try {
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
          hideControls: true,  // Hide YouTube's default controls
          disableDragSeek: true,  // Disable seeking by dragging
        ),
      );

      // Add listener only if controller was created successfully
      _controller!.addListener(_onPlayerStateChanged);

      // Update state only if mounted
      if (mounted) {
        setState(() {
          _currentUrl = url;
          _isPlayerReady = false;
          _isPlaying = false;
          _currentPosition = Duration.zero;
          _totalDuration = Duration.zero;
          _playbackRate = 1.0;
          _isLoading = false;
        });

        // Set up VideoProvider callbacks using stored reference - but only if still mounted
        _videoProvider?.setSeekToCallback(_onSeek);
        _videoProvider?.setPlayCallback(() {
          if (mounted && _controller != null && !_isPlaying) _onPlayPause();
        });
        _videoProvider?.setPauseCallback(() {
          if (mounted && _controller != null && _isPlaying) _onPlayPause();
        });
        _videoProvider?.setForcePauseCallback(() {
          // Always pause regardless of current state
          if (mounted && _controller != null && _isPlayerReady) {
            try {
              _controller!.pause();
              _metronomeProvider?.stopMetronome();
              developer.log('Force pause executed - video should be paused');
            } catch (e) {
              developer.log('Error in force pause: $e');
            }
          }
        });


        // Set a timeout to handle cases where player never becomes ready
        _loadingTimeout = Timer(const Duration(seconds: 30), () {
          if (mounted && context.mounted && !_isPlayerReady && _currentUrl == url) {
            setState(() {
              _errorMessage = 'Video failed to load. Please check the URL or try again.';
              _isLoading = false;
            });
            developer.log('YouTube player loading timeout after 30s: $url');
          }
        });

        // Save video URL to current song
        if (_songProvider?.currentSong != null) {
          _songProvider?.updateSongVideoUrl(url);
        }
      }
      
      developer.log('Controller created successfully for: $url');
    } catch (e) {
      developer.log('Error creating controller: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error creating video player: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _clearVideo() {
    _loadingTimeout?.cancel();
    _stopPositionTracking();
    
    // Use the new disposal method
    _disposeCurrentController();

    setState(() {
      _currentUrl = '';
      _errorMessage = null;
      _isLoading = false;
    });

    developer.log('Video player cleared');
  }
  
  void _startPositionTracking() {
    // High-resolution position tracking for precise synchronization
    // The YouTube player listener should handle most updates
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      if (_controller != null && mounted && context.mounted) {
        try {
          // Additional safety checks before accessing controller
          if (_controller!.value.isPlaying) {
            final newPosition = _controller!.value.position;
            if (newPosition != _currentPosition) {
              setState(() {
                _currentPosition = newPosition;
              });

              // Update video provider
              _videoProvider?.setCurrentPosition(newPosition);
            }
          }
        } catch (e) {
          developer.log('Error in position tracking timer: $e');
        }
      }
    });
    developer.log('Started supplemental position tracking (10ms)');
  }
  
  void _stopPositionTracking() {
    _positionTimer?.cancel();
    _positionTimer = null;
    developer.log('Stopped position tracking');
  }

  void _onPlayerStateChanged() {
    // Extra safety checks to prevent using disposed controller
    if (_controller == null || !mounted) return;
    
    try {
      final wasReady = _isPlayerReady;
      final wasPlaying = _isPlaying;
      final isNowReady = _controller!.value.isReady;
      final isNowPlaying = _controller!.value.isPlaying;
      
      // Only update state if we're still mounted and controller is valid
      if (mounted && _controller != null) {
        setState(() {
          _isPlayerReady = isNowReady;
          _isPlaying = isNowPlaying;
          _currentPosition = _controller!.value.position;
          _totalDuration = _controller!.metadata.duration;
        });

        // Update VideoProvider with current state only if still mounted
        if (mounted) {
          _videoProvider?.setPlayerReady(isNowReady);
          _videoProvider?.setPlaying(_isPlaying);
          _videoProvider?.setCurrentPosition(_currentPosition);
          _videoProvider?.setTotalDuration(_totalDuration);
        }
        
        if (!wasReady && isNowReady) {
          developer.log('YouTube player ready - controls enabled');
        }


        // Handle metronome integration when play state changes
        if (wasPlaying != isNowPlaying) {
          developer.log('Play state changed: wasPlaying=$wasPlaying, isNowPlaying=$isNowPlaying');
          _handleMetronomeStateChange(isNowPlaying);
        }
        
        // Start or stop position tracking based on playing state
        if (_isPlaying && _positionTimer == null) {
          _startPositionTracking();
        } else if (!_isPlaying && _positionTimer != null) {
          _stopPositionTracking();
        }
      }
    } catch (e) {
      developer.log('Error in player state change: $e');
      // If we get an error, the controller might be disposed
      if (e.toString().contains('disposed')) {
        developer.log('Controller was disposed, clearing reference');
        _controller = null;
      }
    }
  }

  void _handleMetronomeStateChange(bool isPlaying) {
    try {
      if (!isPlaying && (_metronomeProvider?.isPlaying ?? false)) {
        // Video was paused by some other means (e.g., clicking YouTube player)
        // Stop the metronome
        developer.log('Video paused externally, stopping metronome');
        _metronomeProvider?.stopMetronome();
      }
      // Note: We don't start metronome here when video plays - that's handled by _onPlayPause
    } catch (e) {
      developer.log('Error handling metronome state change: $e');
    }
  }

  void _onPlayPause() {
    if (_controller == null || !_isPlayerReady || !mounted) return;

    try {
      developer.log('_onPlayPause called: isPlaying=$_isPlaying');
      if (_isPlaying) {
        // Pause video and stop metronome
        developer.log('Pausing video and stopping metronome');
        _controller!.pause();
        _metronomeProvider?.stopMetronome();

        // Cancel any pending count-in timer
        _countInTimer?.cancel();
        _countInTimer = null;

        if (_showCountIn) {
          setState(() {
            _showCountIn = false;
          });
        }
      } else {
        // Start playing with metronome
        developer.log('Starting playback');
        _startPlayback();
      }
    } catch (e) {
      developer.log('Error in play/pause: $e');
    }
  }

  void _startPlayback() {
    try {
      // Cancel any existing count-in timer first
      _countInTimer?.cancel();
      _countInTimer = null;

      if (_metronomeProvider?.settings.isEnabled ?? false) {
        // Set playback rate before starting metronome
        _metronomeProvider?.setPlaybackRate(_playbackRate);

        // Start metronome without count-in (count-in only used in Beat Mode)
        developer.log('Starting metronome with playback rate: $_playbackRate');
        _metronomeProvider?.startMetronome();
        // Start video immediately
        _controller!.play();
      } else {
        // No metronome, just play video
        _controller!.play();
      }
    } catch (e) {
      developer.log('Error in start playback: $e');
    }
  }

  void _onStop() {
    if (_controller == null || !_isPlayerReady || !mounted) return;
    
    try {
      _controller!.seekTo(Duration.zero);
      _controller!.pause();
      
      // Stop metronome when stopping video
      _metronomeProvider?.stopMetronome();
    } catch (e) {
      developer.log('Error in stop: $e');
    }
  }

  void _onSeek(Duration position) {
    if (_controller == null || !_isPlayerReady || !mounted) return;

    try {
      // Additional check to ensure controller is not disposed
      if (_controller!.value.isReady) {
        _controller!.seekTo(position);
      }
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

  void _onSeekBackward1s() {
    if (_controller == null || !_isPlayerReady || !mounted) return;

    try {
      final newPosition = _currentPosition - const Duration(seconds: 1);
      _controller!.seekTo(newPosition.isNegative ? Duration.zero : newPosition);
    } catch (e) {
      developer.log('Error in 1s backward seek: $e');
    }
  }

  void _onSeekForward1s() {
    if (_controller == null || !_isPlayerReady || !mounted) return;

    try {
      final newPosition = _currentPosition + const Duration(seconds: 1);
      _controller!.seekTo(newPosition > _totalDuration ? _totalDuration : newPosition);
    } catch (e) {
      developer.log('Error in 1s forward seek: $e');
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

        // Update metronome playback rate
        _metronomeProvider?.setPlaybackRate(rate);
        developer.log('Updated metronome playback rate to: ${rate}x');
      }
      developer.log('Playback rate changed to: ${rate}x');
    } catch (e) {
      developer.log('Error changing playback rate: $e');
    }
  }

  void _showEditUrlDialog() {
    final TextEditingController urlController = TextEditingController(text: _currentUrl);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit YouTube URL'),
          content: TextField(
            controller: urlController,
            decoration: const InputDecoration(
              labelText: 'YouTube URL',
              hintText: 'Enter YouTube URL...',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                Navigator.of(dialogContext).pop();
                _loadVideo(value.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final url = urlController.text.trim();
                if (url.isNotEmpty) {
                  Navigator.of(dialogContext).pop();
                  _loadVideo(url);
                }
              },
              child: const Text('Load'),
            ),
          ],
        );
      },
    );
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

    return GestureDetector(
      onTap: () {
        // Toggle play/pause on tap
        if (_isPlayerReady && _controller != null) {
          _onPlayPause();
        }
      },
      child: YoutubePlayer(
        key: ValueKey(_currentUrl), // Use URL as key to help with view management
        controller: _controller!,
        showVideoProgressIndicator: false,
        progressIndicatorColor: Theme.of(context).colorScheme.primary,
        // No topActions - we're using our own controls
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
      ),
    );
  }

  Widget _buildNoVideoSelected() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'No Video Selected',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _showEditUrlDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Video URL'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Check if we have limited space (like in playback mode overlay)
        final isCompact = constraints.maxHeight < 200;

        if (isCompact) {
          // Compact error display for small containers
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 24,
                  color: Colors.red[400],
                ),
                const SizedBox(height: 4),
                Text(
                  'Error Loading Video',
                  style: TextStyle(
                    color: Colors.red[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () {
                    if (_currentUrl.isNotEmpty) {
                      setState(() {
                        _errorMessage = null;
                      });
                      _loadVideo(_currentUrl);
                    }
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(60, 30),
                  ),
                ),
              ],
            ),
          );
        } else {
          // Full error display for larger containers
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<SongProvider, VideoProvider, AppModeProvider>(
      builder: (context, songProvider, videoProvider, appModeProvider, _) {
        final hasSong = songProvider.currentSong != null;
        
        // Check if we need to load a video URL from VideoProvider
        if (hasSong && videoProvider.hasVideo && videoProvider.currentUrl != _currentUrl && !_isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && context.mounted && videoProvider.currentUrl != _currentUrl && !_isLoading) {
              developer.log('VideoProvider URL changed, loading: ${videoProvider.currentUrl}');
              _loadVideo(videoProvider.currentUrl);
            }
          });
        } else if (hasSong && !videoProvider.hasVideo && _currentUrl.isNotEmpty && 
                   songProvider.currentSong?.videoUrl?.isEmpty == true) {
          // Only clear video if BOTH VideoProvider has no video AND the song has no video URL
          // This prevents race condition where user loads video but song hasn't been updated yet
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && context.mounted && !_isLoading && !videoProvider.hasVideo) {
              developer.log('Song and VideoProvider have no video URL, clearing player');
              _clearVideo();
            }
          });
        }
        
        if (!hasSong) {
          return _buildNoSongPlaceholder();
        }

        // Use overlay layout for both modes now
        return Stack(
            children: [
              // Video player fills the entire container
              Container(
                color: Colors.black,
                child: (_isLoading && _currentUrl.isNotEmpty) || (videoProvider.hasVideo && _controller == null)
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      )
                    : _buildPlayer(),
              ),
                // Count-in overlay (only show during count-in)
                if (_showCountIn)
                  Positioned.fill(
                    child: Consumer<MetronomeProvider>(
                      builder: (context, metronomeProvider, _) {
                        return CountInOverlay(
                          currentBeat: metronomeProvider.currentBeat,
                          totalBeats: metronomeProvider.settings.timeSignature.numerator,
                        );
                      },
                    ),
                  ),
                // Minimal controls overlay (always visible in overlay mode)
              if (widget.showGuiControls && _isPlayerReady)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: appModeProvider.isDesignMode ? 10 : 6,
                      vertical: appModeProvider.isDesignMode ? 8 : 2,
                    ),
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
                    child: appModeProvider.isDesignMode ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top row - main controls
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final controls = _buildDesignControls();
                            // Use SingleChildScrollView for narrow containers
                            final isVeryNarrow = constraints.maxWidth <= 320;
                            if (isVeryNarrow) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(children: controls),
                              );
                            } else {
                              return Row(children: controls);
                            }
                          },
                        ),
                        // Bottom row - progress bar and time
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              // Current time
                              Text(
                                _formatDuration(_currentPosition),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              // Progress bar
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: SizedBox(
                                  height: 16,
                                  child: SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 1.5,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 4,
                                      ),
                                      overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 8,
                                      ),
                                      activeTrackColor: Theme.of(context).colorScheme.primary,
                                      inactiveTrackColor: Colors.grey[600],
                                      thumbColor: Theme.of(context).colorScheme.primary,
                                      overlayColor: Theme.of(context).colorScheme.primary.withAlpha(50),
                                    ),
                                    child: Slider(
                                      value: _totalDuration.inSeconds > 0
                                          ? _currentPosition.inSeconds.toDouble()
                                          : 0.0,
                                      min: 0.0,
                                      max: _totalDuration.inSeconds.toDouble(),
                                      onChanged: (value) {
                                        _onSeek(Duration(seconds: value.toInt()));
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Total time
                            Text(
                              _formatDuration(_totalDuration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            ],
                          ),
                        ),
                      ],
                    ) : Column(
                      // Playback mode - same layout as design mode but without edit button
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top row - main controls
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final controls = _buildPlaybackControls();
                            // Use SingleChildScrollView for narrow containers
                            final isVeryNarrow = constraints.maxWidth <= 320;
                            if (isVeryNarrow) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(children: controls),
                              );
                            } else {
                              return Row(children: controls);
                            }
                          },
                        ),
                        // Bottom row - progress bar and time
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              // Current time
                              Text(
                                _formatDuration(_currentPosition),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              // Progress bar
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: SizedBox(
                                  height: 16,
                                  child: SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 1.5,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 4,
                                      ),
                                      overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 8,
                                      ),
                                      activeTrackColor: Theme.of(context).colorScheme.primary,
                                      inactiveTrackColor: Colors.grey[600],
                                      thumbColor: Theme.of(context).colorScheme.primary,
                                      overlayColor: Theme.of(context).colorScheme.primary.withAlpha(50),
                                    ),
                                    child: Slider(
                                      value: _totalDuration.inSeconds > 0
                                          ? _currentPosition.inSeconds.toDouble()
                                          : 0.0,
                                      min: 0.0,
                                      max: _totalDuration.inSeconds.toDouble(),
                                      onChanged: (value) {
                                        _onSeek(Duration(seconds: value.toInt()));
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Total time
                            Text(
                              _formatDuration(_totalDuration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
      },
    );
  }

  Widget _buildNoSongPlaceholder() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Check if we have limited space (like in playback mode overlay)
        final isCompact = constraints.maxHeight < 200;

        if (isCompact) {
          // Compact display for small containers
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.video_library,
                  size: 24,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 4),
                Text(
                  'No Video',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        } else {
          // Full display for larger containers
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
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
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Create or load a song to access video features',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  List<Widget> _buildPlaybackControls() {
    // Same as design controls but without edit button
    return _buildControlButtons(includeEditButton: false);
  }

  List<Widget> _buildDesignControls() {
    // Design controls with edit button
    return _buildControlButtons(includeEditButton: true);
  }

  List<Widget> _buildControlButtons({required bool includeEditButton}) {
    return [
      // Edit button (only in design mode)
      if (includeEditButton)
        IconButton(
          icon: const Icon(
            Icons.edit,
            color: Colors.white,
            size: 20,
          ),
          onPressed: _showEditUrlDialog,
          padding: const EdgeInsets.all(1),
          constraints: const BoxConstraints(
            minWidth: 30,
            minHeight: 30,
          ),
          tooltip: 'Edit YouTube URL',
        ),
      // 10s backward button
      IconButton(
        icon: const Icon(
          Icons.replay_10,
          color: Colors.white,
          size: 20,
        ),
        onPressed: _isPlayerReady ? _onSkipBackward : null,
        padding: const EdgeInsets.all(1),
        constraints: const BoxConstraints(
          minWidth: 30,
          minHeight: 30,
        ),
        tooltip: '10 seconds backward',
      ),
      // 1s backward button
      IconButton(
        icon: const Icon(
          Icons.keyboard_arrow_left,
          color: Colors.white,
          size: 20,
        ),
        onPressed: _isPlayerReady ? _onSeekBackward1s : null,
        padding: const EdgeInsets.all(1),
        constraints: const BoxConstraints(
          minWidth: 30,
          minHeight: 30,
        ),
        tooltip: '1 second backward',
      ),
      // Play/pause button
      IconButton(
        icon: Icon(
          _isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
          size: 24,
        ),
        onPressed: _onPlayPause,
        padding: const EdgeInsets.all(1),
        constraints: const BoxConstraints(
          minWidth: 34,
          minHeight: 34,
        ),
      ),
      // 1s forward button
      IconButton(
        icon: const Icon(
          Icons.keyboard_arrow_right,
          color: Colors.white,
          size: 20,
        ),
        onPressed: _isPlayerReady ? _onSeekForward1s : null,
        padding: const EdgeInsets.all(1),
        constraints: const BoxConstraints(
          minWidth: 30,
          minHeight: 30,
        ),
        tooltip: '1 second forward',
      ),
      // Stop button
      IconButton(
        icon: const Icon(
          Icons.stop,
          color: Colors.white,
          size: 20,
        ),
        onPressed: _isPlayerReady ? _onStop : null,
        padding: const EdgeInsets.all(1),
        constraints: const BoxConstraints(
          minWidth: 30,
          minHeight: 30,
        ),
        tooltip: 'Stop',
      ),
      // 10s forward button
      IconButton(
        icon: const Icon(
          Icons.forward_10,
          color: Colors.white,
          size: 20,
        ),
        onPressed: _isPlayerReady ? _onSkipForward : null,
        padding: const EdgeInsets.all(1),
        constraints: const BoxConstraints(
          minWidth: 30,
          minHeight: 30,
        ),
        tooltip: '10 seconds forward',
      ),
      // Speed control in top row
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
        ),
        child: DropdownButton<double>(
          value: _playbackRate,
          onChanged: (double? value) {
            if (value != null) _onPlaybackRateChanged(value);
          },
          items: const [
            DropdownMenuItem(value: 0.5, child: Text('0.5x', style: TextStyle(fontSize: 11))),
            DropdownMenuItem(value: 0.6, child: Text('0.6x', style: TextStyle(fontSize: 11))),
            DropdownMenuItem(value: 0.7, child: Text('0.7x', style: TextStyle(fontSize: 11))),
            DropdownMenuItem(value: 0.8, child: Text('0.8x', style: TextStyle(fontSize: 11))),
            DropdownMenuItem(value: 0.9, child: Text('0.9x', style: TextStyle(fontSize: 11))),
            DropdownMenuItem(value: 1.0, child: Text('1.0x', style: TextStyle(fontSize: 11))),
            DropdownMenuItem(value: 1.2, child: Text('1.2x', style: TextStyle(fontSize: 11))),
          ],
          underline: Container(),
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
          dropdownColor: Colors.black87,
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    ];
  }
}