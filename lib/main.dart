import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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
import 'widgets/song_menu.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final songProvider = context.read<SongProvider>();
      songProvider.setProviders(
        scoreProvider: context.read<ScoreProvider>(),
        videoProvider: context.read<VideoProvider>(),
        rectangleProvider: context.read<RectangleProvider>(),
        syncProvider: context.read<SyncProvider>(),
      );
      await songProvider.initialize();
      
      // Check for welcome dialog after initialization is truly complete
      if (mounted && songProvider.songs.isEmpty) {
        developer.log('Post-initialization: No songs found, showing welcome dialog');
        _showNewSongDialog(context);
      } else if (mounted) {
        developer.log('Post-initialization: Songs exist (${songProvider.songs.length}), skipping welcome dialog');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SongProvider>(
      builder: (context, songProvider, _) {
        if (songProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Dialog logic moved to initState after proper initialization

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

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SongProvider>(
      builder: (context, songProvider, _) {
        final songName = songProvider.currentSongName ?? 'Score Sync';
        final hasSong = songProvider.currentSong != null;
        
        return Scaffold(
          appBar: AppBar(
            leading: const SongMenu(),
            title: Text(songName),
            actions: hasSong ? const [
              ModeSwitcher(),
            ] : null,
          ),
          body: hasSong ? Row(
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
                  child: const ScoreViewer(),
                ),
              ),
              Expanded(
                flex: 1,
                child: const YouTubePlayerWidget(),
              ),
            ],
          ) : const NoSongPlaceholder(),
        );
      },
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

