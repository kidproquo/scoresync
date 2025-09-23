import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:io';
import 'dart:async';
import 'dart:developer' as developer;
import 'widgets/score_viewer/score_viewer.dart';
import 'widgets/video_player/youtube_player.dart';
import 'widgets/mode_switcher.dart';
import 'providers/app_mode_provider.dart';
import 'providers/score_provider.dart';
import 'providers/video_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/rectangle_provider.dart';
import 'providers/song_provider.dart';
import 'providers/metronome_provider.dart';
import 'widgets/song_menu.dart';
import 'widgets/load_song_dialog.dart';
import 'widgets/metronome/metronome_settings_panel.dart';
import 'services/song_storage_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).then((_) {
    runApp(const ScoreSyncApp());
  });
}

class ScoreSyncApp extends StatelessWidget {
  const ScoreSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppModeProvider()),
        ChangeNotifierProvider(create: (_) => ScoreProvider()),
        ChangeNotifierProvider(create: (_) => VideoProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
        ChangeNotifierProvider(create: (_) => RectangleProvider()),
        ChangeNotifierProvider(create: (_) => SongProvider()),
        ChangeNotifierProvider(create: (_) => MetronomeProvider()),
      ],
      child: MaterialApp(
        title: 'Score Sync',
        theme: ThemeData(
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 2,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ),
        home: const ScoreSyncHome(),
      ),
    );
  }
}

class ScoreSyncHome extends StatefulWidget {
  const ScoreSyncHome({super.key});

  @override
  State<ScoreSyncHome> createState() => _ScoreSyncHomeState();
}

class _ScoreSyncHomeState extends State<ScoreSyncHome> {
  late Stream<List<SharedMediaFile>> _intentDataStreamFiles;
  
  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    
    // Initialize sharing intent stream
    _intentDataStreamFiles = ReceiveSharingIntent.instance.getMediaStream();
    _intentDataStreamFiles.listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedFiles(value);
      }
    });

    // Handle initial shared file when app is opened via sharing
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedFiles(value);
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final songProvider = context.read<SongProvider>();
      songProvider.setProviders(
        scoreProvider: context.read<ScoreProvider>(),
        videoProvider: context.read<VideoProvider>(),
        rectangleProvider: context.read<RectangleProvider>(),
        syncProvider: context.read<SyncProvider>(),
      );
      await songProvider.initialize();
      
      // Set up sync provider dependencies
      if (mounted) {
        final syncProvider = context.read<SyncProvider>();
        syncProvider.setDependencies(
          context.read<RectangleProvider>(),
          context.read<VideoProvider>(),
          context.read<ScoreProvider>(),
          context.read<AppModeProvider>(),
        );
      }
      
      // Check for welcome dialog after initialization is truly complete
      if (mounted && songProvider.songs.isEmpty) {
        developer.log('Post-initialization: No songs found, showing welcome dialog');
        _showNewSongDialog(context);
      } else if (mounted) {
        developer.log('Post-initialization: Songs exist (${songProvider.songs.length}), skipping welcome dialog');
      }
    });
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    // Filter for PDF files only
    final pdfFiles = files.where((file) => 
      file.path.toLowerCase().endsWith('.pdf')).toList();
    
    if (pdfFiles.isEmpty) {
      developer.log('No PDF files found in shared files');
      return;
    }
    
    // Handle the first PDF file
    final sharedPdf = pdfFiles.first;
    developer.log('Handling shared PDF: ${sharedPdf.path}');
    
    // Wait for app initialization to complete before showing dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showSharedPdfDialog(File(sharedPdf.path));
      }
    });
  }

  void _showSharedPdfDialog(File pdfFile) {
    final songProvider = context.read<SongProvider>();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Shared PDF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A PDF file has been shared with Score Sync:'),
              const SizedBox(height: 8),
              Text(
                pdfFile.path.split('/').last,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('What would you like to do?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Clear the shared intent
                ReceiveSharingIntent.instance.reset();
              },
              child: const Text('Cancel'),
            ),
            if (songProvider.hasSongs) ...[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showUpdateExistingSongDialog(pdfFile);
                },
                child: const Text('Update Existing Song'),
              ),
            ],
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _createNewSongFromSharedPdf(pdfFile);
              },
              child: const Text('Create New Song'),
            ),
          ],
        );
      },
    );
  }

  void _showUpdateExistingSongDialog(File pdfFile) {
    final songProvider = context.read<SongProvider>();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Song to Update'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: songProvider.songs.length,
              itemBuilder: (context, index) {
                final song = songProvider.songs[index];
                return ListTile(
                  title: Text(song.name),
                  subtitle: song.pdfPath != null 
                      ? Text('Current PDF: ${song.pdfPath!.split('/').last}')
                      : const Text('No PDF currently'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _updateExistingSongWithPdf(song.name, pdfFile);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Clear the shared intent
                ReceiveSharingIntent.instance.reset();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createNewSongFromSharedPdf(File pdfFile) async {
    try {
      final songProvider = context.read<SongProvider>();
      await songProvider.createSongFromPdf(pdfFile);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created new song from ${pdfFile.path.split('/').last}'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Clear the shared intent
      ReceiveSharingIntent.instance.reset();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating song: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateExistingSongWithPdf(String songName, File pdfFile) async {
    try {
      final songProvider = context.read<SongProvider>();
      await songProvider.loadSong(songName);
      await songProvider.updateSongPdf(pdfFile);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated $songName with new PDF'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Clear the shared intent
      ReceiveSharingIntent.instance.reset();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating song: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SongProvider>(
      builder: (context, songProvider, _) {
        // Show loading screen until initialization is complete AND we know if there's a current song
        if (songProvider.isLoading || !songProvider.isInitialized) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading Score Sync...'),
                ],
              ),
            ),
          );
        }

        return const MainScreen();
      },
    );
  }

  void _showNewSongDialog(BuildContext context) {
    // Check if a dialog is already showing
    if (ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Welcome to Score Sync'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Create your first song to get started.'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Song Name',
                  hintText: 'Enter song name',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                onSubmitted: (value) async {
                  if (value.trim().isNotEmpty) {
                    await _createFirstSong(context, value.trim());
                  }
                },
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  await _createFirstSong(context, name);
                }
              },
              child: const Text('Create Song'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createFirstSong(BuildContext context, String name) async {
    try {
      // Check if song already exists
      final exists = await SongStorageService.instance.songExists(name);
      if (exists) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Song "$name" already exists')),
          );
        }
        return;
      }

      if (context.mounted) {
        final songProvider = context.read<SongProvider>();
        await songProvider.createNewSong(name);
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating song: $e')),
        );
      }
    }
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _showGuiControls = true;
  Timer? _hideTimer;
  bool _hasInitialized = false;
  bool _showMetronomeSettings = false;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _toggleGuiControls() {
    setState(() {
      _showGuiControls = !_showGuiControls;
    });
    
    if (_showGuiControls) {
      _startHideTimer();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showGuiControls = false;
        });
      }
    });
  }

  void _onTap() {
    // Toggle GUI controls (only called from fullscreen playback mode)
    _toggleGuiControls();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SongProvider, AppModeProvider>(
      builder: (context, songProvider, appModeProvider, _) {
        final songName = songProvider.currentSongName ?? 'Score Sync';
        final hasSong = songProvider.currentSong != null;
        final isPlaybackMode = !appModeProvider.isDesignMode;
        
        // In playback mode, show GUI controls initially and start timer
        if (isPlaybackMode && !_hasInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Add a small delay to allow layout to stabilize before initializing
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                setState(() {
                  _hasInitialized = true;
                });
                _startHideTimer();
              }
            });
          });
        } else if (!isPlaybackMode) {
          // Reset state when switching to design mode
          _hasInitialized = false;
          _hideTimer?.cancel();
          _hideTimer = null;
          if (!_showGuiControls) {
            setState(() {
              _showGuiControls = true;
            });
          }
        }
        
        return Scaffold(
          appBar: (!isPlaybackMode) ? AppBar(
            leading: const SongMenu(),
            title: Text(songName),
            actions: hasSong ? const [
              ModeSwitcher(),
            ] : null,
          ) : null,
          body: hasSong ? (isPlaybackMode
              ? _buildFullscreenPlayback()
              : _buildSplitScreenLayout()) : const NoSongPlaceholder(),
        );
      },
    );
  }

  Widget _buildFullscreenPlayback() {
    final songProvider = context.read<SongProvider>();
    final songName = songProvider.currentSongName ?? 'Score Sync';
    
    return Stack(
      children: [
        // Fullscreen score viewer
        Positioned.fill(
          child: Container(
            key: const ValueKey('fullscreen_score_viewer'),
            child: ScoreViewer(showGuiControls: _showGuiControls),
          ),
        ),
        // Tap overlay (only when controls are hidden)
        if (!_showGuiControls)
          Positioned.fill(
            child: GestureDetector(
              onTap: _onTap,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
        // Video player overlay (always visible in fullscreen)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          bottom: _showGuiControls ? 80 : 20, // Adjust position when page controls are visible
          right: 20,
          width: 320,
          height: 240, // Fixed height since controls are now overlaid
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: _showGuiControls ? null : Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  // YouTube player
                  YouTubePlayerWidget(showGuiControls: _showGuiControls),
                  // Tap overlay for video area (only when controls are hidden)
                  if (!_showGuiControls)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _onTap,
                        behavior: HitTestBehavior.translucent,
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        // Floating app bar (shows/hides with tap)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          top: _showGuiControls ? 0 : -100,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _showGuiControls ? 1.0 : 0.0,
            child: Container(
              height: MediaQuery.of(context).padding.top + kToolbarHeight + 20,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      iconTheme: const IconThemeData(color: Colors.white),
                    ),
                    child: Row(
                      children: [
                        _buildFloatingMenu(context),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            songName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Metronome button (only in playback mode)
                            Consumer<MetronomeProvider>(
                              builder: (context, metronomeProvider, _) {
                                return IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _showMetronomeSettings = !_showMetronomeSettings;
                                    });
                                  },
                                  icon: Stack(
                                    children: [
                                      Icon(
                                        Icons.music_note,
                                        color: metronomeProvider.settings.isEnabled 
                                            ? Colors.white 
                                            : Colors.white54,
                                        size: 20,
                                      ),
                                      if (metronomeProvider.isPlaying)
                                        Positioned(
                                          right: 0,
                                          top: 0,
                                          child: Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  tooltip: 'Metronome Settings',
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            
                            // Mode switcher
                            Consumer<AppModeProvider>(
                              builder: (context, appModeProvider, _) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () => appModeProvider.setDesignMode(),
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: appModeProvider.isDesignMode 
                                                ? Colors.white 
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.edit,
                                                size: 16,
                                                color: appModeProvider.isDesignMode 
                                                    ? Colors.black87 
                                                    : Colors.white70,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Design',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: appModeProvider.isDesignMode 
                                                      ? Colors.black87 
                                                      : Colors.white70,
                                                  fontWeight: appModeProvider.isDesignMode 
                                                      ? FontWeight.w600 
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () => appModeProvider.setPlaybackMode(),
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: appModeProvider.isPlaybackMode 
                                                ? Colors.white 
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.play_arrow,
                                                size: 16,
                                                color: appModeProvider.isPlaybackMode 
                                                    ? Colors.black87 
                                                    : Colors.white70,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Playback',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: appModeProvider.isPlaybackMode 
                                                      ? Colors.black87 
                                                      : Colors.white70,
                                                  fontWeight: appModeProvider.isPlaybackMode 
                                                      ? FontWeight.w600 
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Metronome settings panel (slides up from bottom)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          bottom: _showMetronomeSettings ? 0 : -400,
          left: 0,
          right: 0,
          height: 400,
          child: MetronomeSettingsPanel(
            onClose: () {
              setState(() {
                _showMetronomeSettings = false;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu, color: Colors.white),
      onSelected: (String result) async {
        switch (result) {
          case 'new':
            _showNewSongDialog(context);
            break;
          case 'load':
            _showLoadSongDialog(context);
            break;
          case 'delete':
            _showDeleteSongDialog(context);
            break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'new',
          child: ListTile(
            leading: Icon(Icons.add),
            title: Text('New Song'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'load',
          child: ListTile(
            leading: Icon(Icons.folder_open),
            title: Text('Load Song'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('Delete Song', style: TextStyle(color: Colors.red)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildSplitScreenLayout() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: ScoreViewer(showGuiControls: _showGuiControls),
          ),
        ),
        Expanded(
          flex: 1,
          child: YouTubePlayerWidget(showGuiControls: _showGuiControls),
        ),
      ],
    );
  }

  void _showLoadSongDialog(BuildContext context) async {
    final songProvider = context.read<SongProvider>();

    if (songProvider.songs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No songs available to load')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => const LoadSongDialog(),
    );
  }

  void _showNewSongDialog(BuildContext context) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Song'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Song Name',
                hintText: 'Enter song name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              onSubmitted: (value) async {
                if (value.trim().isNotEmpty) {
                  Navigator.of(context).pop();
                  final songProvider = context.read<SongProvider>();
                  await songProvider.createNewSong(value.trim());
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop();
                final songProvider = context.read<SongProvider>();
                await songProvider.createNewSong(name);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showDeleteSongDialog(BuildContext context) {
    final songProvider = context.read<SongProvider>();
    final currentSong = songProvider.currentSong;

    if (currentSong == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No song selected to delete')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "${currentSong.name}"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await songProvider.deleteSong(currentSong.name);
              
              if (success && context.mounted) {
                if (songProvider.songs.isNotEmpty) {
                  _showLoadSongDialog(context);
                } else {
                  _showNewSongDialog(context);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class NoSongPlaceholder extends StatelessWidget {
  const NoSongPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Song Selected',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create or load a song to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // The SongMenu in the AppBar will handle song creation
            },
            icon: const Icon(Icons.add),
            label: const Text('Use the menu icon to create a song'),
          ),
        ],
      ),
    );
  }
}