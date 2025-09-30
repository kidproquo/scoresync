import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:async';
import 'dart:developer' as developer;
import 'services/song_archive_service.dart';
import 'widgets/score_viewer/score_viewer.dart';
import 'widgets/video_player/youtube_player.dart';
import 'providers/app_mode_provider.dart';
import 'providers/score_provider.dart';
import 'providers/video_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/beat_sync_provider.dart';
import 'providers/rectangle_provider.dart';
import 'providers/song_provider.dart';
import 'providers/metronome_provider.dart';
import 'providers/ui_state_provider.dart';
import 'widgets/load_song_dialog.dart';
import 'widgets/metronome/metronome_settings_panel.dart';
import 'widgets/metronome/beat_overlay.dart';
import 'widgets/score_viewer/page_controls.dart';
import 'widgets/sync_points_bar.dart';
import 'services/song_storage_service.dart';
import 'models/metronome_settings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
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
        ChangeNotifierProvider(create: (_) => BeatSyncProvider()),
        ChangeNotifierProvider(create: (_) => RectangleProvider()),
        ChangeNotifierProvider(create: (_) => SongProvider()),
        ChangeNotifierProvider(create: (_) => MetronomeProvider()),
        ChangeNotifierProvider(create: (_) => UiStateProvider()),
      ],
      child: MaterialApp(
        title: 'Symph',
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
      developer.log('Received media stream files: ${value.length}');
      for (final file in value) {
        developer.log('Media file: ${file.path}, type: ${file.type}');
      }
      if (value.isNotEmpty) {
        _handleSharedFiles(value);
      }
    });

    // Handle initial shared file when app is opened via sharing
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      developer.log('Initial media files: ${value.length}');
      for (final file in value) {
        developer.log('Initial media file: ${file.path}, type: ${file.type}');
      }
      if (value.isNotEmpty) {
        _handleSharedFiles(value);
      }
    });

    // Handle text sharing (for URLs from Share Extension)
    // Note: Text sharing support may require additional configuration
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final songProvider = context.read<SongProvider>();
      songProvider.setProviders(
        scoreProvider: context.read<ScoreProvider>(),
        videoProvider: context.read<VideoProvider>(),
        rectangleProvider: context.read<RectangleProvider>(),
        syncProvider: context.read<SyncProvider>(),
        metronomeProvider: context.read<MetronomeProvider>(),
      );
      await songProvider.initialize();

      if (mounted) {
        final syncProvider = context.read<SyncProvider>();
        syncProvider.setDependencies(
          context.read<RectangleProvider>(),
          context.read<VideoProvider>(),
          context.read<ScoreProvider>(),
          context.read<AppModeProvider>(),
        );

        final beatSyncProvider = context.read<BeatSyncProvider>();
        beatSyncProvider.setDependencies(
          context.read<RectangleProvider>(),
          context.read<MetronomeProvider>(),
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
    // Filter for PDF and ZIP files
    final pdfFiles = files.where((file) =>
      file.path.toLowerCase().endsWith('.pdf')).toList();

    final zipFiles = files.where((file) =>
      file.path.toLowerCase().endsWith('.zip') ||
      file.path.toLowerCase().endsWith('.symph')).toList();

    // Prioritize Symph archives over PDF files
    if (zipFiles.isNotEmpty) {
      final sharedZip = zipFiles.first;
      developer.log('Handling shared Symph archive: ${sharedZip.path}');

      // Wait for app initialization to complete before showing dialog
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showSharedArchiveDialog(File(sharedZip.path));
        }
      });
    } else if (pdfFiles.isNotEmpty) {
      // Handle the first PDF file
      final sharedPdf = pdfFiles.first;
      developer.log('Handling shared PDF: ${sharedPdf.path}');

      // Wait for app initialization to complete before showing dialog
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showSharedPdfDialog(File(sharedPdf.path));
        }
      });
    } else {
      developer.log('No PDF or ZIP files found in shared files');
    }
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
              Text('A PDF file has been shared with Symph:'),
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

  void _showSharedArchiveDialog(File archiveFile) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Symph Song Archive'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A Symph song archive has been shared with you:'),
              const SizedBox(height: 8),
              Text(
                archiveFile.path.split('/').last,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('Would you like to import this song?'),
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
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _importSongFromArchive(archiveFile);
              },
              child: const Text('Import Song'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importSongFromArchive(File archiveFile) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Importing song archive...'),
            duration: Duration(seconds: 3),
          ),
        );
      }

      final archiveService = SongArchiveService();
      final importedSong = await archiveService.importSongArchive(archiveFile);

      // Save the imported song directly
      if (mounted) {
        final songProvider = context.read<SongProvider>();

        // Save the imported song with all its data (PDF path, rectangles, etc.)
        await SongStorageService.instance.saveSong(importedSong);

        // Load the saved song into providers
        await songProvider.loadSong(importedSong.name);

        developer.log('Successfully imported song: ${importedSong.name}');

        // Check mounted again after async operations
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully imported: ${importedSong.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // Clear the shared intent
      ReceiveSharingIntent.instance.reset();

    } catch (e) {
      developer.log('Error importing song archive: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing archive: $e'),
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
                  Text('Loading Symph...'),
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
          title: const Text('Welcome to Symph'),
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
  bool _hasInitialized = false;
  bool _showMetronomeSettings = false;

  // Video overlay position tracking
  double? _videoOverlayX;
  double? _videoOverlayY;
  bool _isDragging = false;

  @override
  void dispose() {
    super.dispose();
  }


  void _goToFirstPage(BuildContext context) {
    final scoreProvider = context.read<ScoreProvider>();
    scoreProvider.setCurrentPage(1);
  }

  void _goToPreviousPage(BuildContext context) {
    final scoreProvider = context.read<ScoreProvider>();
    if (scoreProvider.canGoToPreviousPage()) {
      scoreProvider.setCurrentPage(scoreProvider.currentPageNumber - 1);
    }
  }

  void _goToNextPage(BuildContext context) {
    final scoreProvider = context.read<ScoreProvider>();
    if (scoreProvider.canGoToNextPage()) {
      scoreProvider.setCurrentPage(scoreProvider.currentPageNumber + 1);
    }
  }

  void _goToLastPage(BuildContext context) {
    final scoreProvider = context.read<ScoreProvider>();
    scoreProvider.setCurrentPage(scoreProvider.totalPages);
  }

  Future<void> _pickPdfFile(BuildContext context) async {
    final scoreProvider = context.read<ScoreProvider>();
    final songProvider = context.read<SongProvider>();
    scoreProvider.setLoading(true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        scoreProvider.setSelectedPdf(file);
        
        // Update the current song with the new PDF
        await songProvider.updateSongPdf(file);
        
        developer.log('PDF file selected and saved to song: ${file.path}');
      } else {
        developer.log('PDF file selection cancelled');
      }
    } catch (e) {
      scoreProvider.setError('Error selecting PDF file: $e');
      developer.log('Error picking PDF file: $e');
    } finally {
      scoreProvider.setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SongProvider, AppModeProvider>(
      builder: (context, songProvider, appModeProvider, _) {
        final songName = songProvider.currentSongName ?? 'Symph';
        final hasSong = songProvider.currentSong != null;
        final isPlaybackMode = !appModeProvider.isDesignMode;

        // Initialize controls and timer
        if (!_hasInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Add a small delay to allow layout to stabilize before initializing
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                setState(() {
                  _hasInitialized = true;
                });
              }
            });
          });
        }


        return Scaffold(
          // No fixed AppBar - it's part of the fullscreen layout now
          body: hasSong ? _buildFullscreenLayout(isPlaybackMode, songName) : const NoSongPlaceholder(),
        );
      },
    );
  }

  Widget _buildFullscreenLayout(bool isPlaybackMode, String songName) {
    return Builder(
      builder: (context) {
        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

        return Stack(
          children: [
            // Fullscreen score viewer
            Positioned.fill(
              child: Container(
                key: const ValueKey('fullscreen_score_viewer'),
                child: const ScoreViewer(),
              ),
            ),
            // Video player overlay OR Beat overlay (depending on mode)
            Builder(
              builder: (context) {
                final metronomeProvider = context.watch<MetronomeProvider>();
                final videoProvider = context.watch<VideoProvider>();
                final isBeatMode = metronomeProvider.settings.mode == MetronomeMode.beat;

                final screenSize = MediaQuery.of(context).size;
                // Same size for both design and playback modes
                final overlayWidth = isLandscape ? 420.0 : 320.0;
                final overlayHeight = isLandscape ? 280.0 : 180.0;

                // Calculate default position if not set
                final defaultX = screenSize.width - overlayWidth - 20;
                final defaultY = screenSize.height - overlayHeight - (isLandscape ? 80 : 160);

                final currentX = _videoOverlayX ?? defaultX;
                final currentY = _videoOverlayY ?? defaultY;

                // Hide controls overlay if video has error
                final showControlsOverlay = isBeatMode || !videoProvider.hasError;

                return Positioned(
                  left: currentX,
                  top: currentY,
                  width: overlayWidth,
                  height: overlayHeight,
                  child: GestureDetector(
                    onPanStart: (details) {
                      final uiStateProvider = context.read<UiStateProvider>();
                      setState(() {
                        _isDragging = true;
                      });
                      uiStateProvider.setVideoDragging(true);
                    },
                    onPanUpdate: (details) {
                      final screenSize = MediaQuery.of(context).size;
                      final newX = (currentX + details.delta.dx).clamp(0.0, screenSize.width - overlayWidth);
                      final newY = (currentY + details.delta.dy).clamp(0.0, screenSize.height - overlayHeight);

                      setState(() {
                        _videoOverlayX = newX;
                        _videoOverlayY = newY;
                      });
                    },
                    onPanEnd: (details) {
                      final uiStateProvider = context.read<UiStateProvider>();
                      setState(() {
                        _isDragging = false;
                      });
                      uiStateProvider.setVideoDragging(false);
                    },
                    onDoubleTap: () {
                      // Reset to default position on double tap
                      setState(() {
                        _videoOverlayX = null;
                        _videoOverlayY = null;
                      });
                    },
                    child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                          border: _isDragging
                              ? Border.all(color: Colors.blue.withValues(alpha: 0.8), width: 2)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: _isDragging ? 0.8 : 0.5),
                              blurRadius: _isDragging ? 15 : 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              // Show Beat Overlay or Video Player based on mode
                              if (isBeatMode)
                                const BeatOverlay()
                              else
                                YouTubePlayerWidget(
                                  key: const ValueKey('youtube_player_draggable'),
                                  showGuiControls: showControlsOverlay,
                                ),
                              // Drag indicator
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    Icons.drag_indicator,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),  // Stack
                        ),      // ClipRRect
                      ),        // Container
                    ),          // GestureDetector
                );              // Positioned
              },
            ),
        // Floating app bar (always visible)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
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
                            // Share button
                            IconButton(
                              onPressed: _shareCurrentSong,
                              icon: const Icon(
                                Icons.share,
                                color: Colors.white,
                                size: 20,
                              ),
                              tooltip: 'Share Song',
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
        // Page controls overlay at bottom (always visible)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Consumer2<ScoreProvider, SongProvider>(
            builder: (context, scoreProvider, songProvider, _) {
              if (scoreProvider.selectedPdfFile != null && scoreProvider.totalPages > 0) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sync points bar (shown in both design and playback modes when rectangle selected)
                    const SyncPointsBar(),
                    // Page controls
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: PageControls(
                        currentPage: scoreProvider.currentPageNumber,
                        totalPages: scoreProvider.totalPages,
                        onFirstPage: () => _goToFirstPage(context),
                        onPreviousPage: () => _goToPreviousPage(context),
                        onNextPage: () => _goToNextPage(context),
                        onLastPage: () => _goToLastPage(context),
                        onSelectPdf: () => _pickPdfFile(context),
                        canSelectPdf: songProvider.currentSong != null,
                        isDesignMode: !isPlaybackMode,
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        // Metronome settings panel (slides up from bottom)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          bottom: _showMetronomeSettings ? 0 : -500,
          left: 0,
          right: 0,
          height: 500,
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
      },
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
          case 'metronome':
            setState(() {
              _showMetronomeSettings = !_showMetronomeSettings;
            });
            break;
          case 'share':
            _shareCurrentSong();
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
          value: 'metronome',
          child: ListTile(
            leading: Icon(Icons.music_note),
            title: Text('Metronome Settings'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'share',
          child: ListTile(
            leading: Icon(Icons.share),
            title: Text('Share Song'),
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

  // Removed _buildSplitScreenLayout - now using fullscreen for both modes

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

  // Share current song as archive
  Future<void> _shareCurrentSong() async {
    final songProvider = Provider.of<SongProvider>(context, listen: false);

    if (songProvider.currentSong == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No song to share. Please load a song first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Creating song archive...'),
          duration: Duration(seconds: 2),
        ),
      );

      final archiveService = SongArchiveService();
      final archiveFile = await archiveService.createSongArchive(songProvider.currentSong!);

      // Share the archive file
      await Share.shareXFiles(
        [XFile(archiveFile.path)],
        text: 'Check out this Symph song: ${songProvider.currentSong!.name}',
        sharePositionOrigin: const Rect.fromLTWH(0, 0, 100, 100),
      );

      developer.log('Successfully shared song archive: ${archiveFile.path}');

      // Optional: Clean up temp file after a delay
      Future.delayed(const Duration(minutes: 1), () {
        archiveService.cleanupTempFiles();
      });

    } catch (e) {
      developer.log('Error sharing song: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing song: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class NoSongPlaceholder extends StatelessWidget {
  const NoSongPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final songProvider = context.read<SongProvider>();
    
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showNewSongDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('New Song'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: songProvider.songs.isNotEmpty 
                    ? () => _showLoadSongDialog(context)
                    : null,
                icon: const Icon(Icons.folder_open),
                label: const Text('Load Song'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
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
            const Text('Enter a name for your new song:'),
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
                  await _createNewSong(context, value.trim());
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
                await _createNewSong(context, name);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showLoadSongDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const LoadSongDialog(),
    );
  }

  Future<void> _createNewSong(BuildContext context, String name) async {
    try {
      final songProvider = context.read<SongProvider>();

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