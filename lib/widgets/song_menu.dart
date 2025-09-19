import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/song_provider.dart';
import '../services/song_storage_service.dart';

class SongMenu extends StatelessWidget {
  const SongMenu({super.key});

  Future<void> _showNewSongDialog(BuildContext context) async {
    final controller = TextEditingController();
    final songProvider = context.read<SongProvider>();

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Song'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Song Name',
              hintText: 'Enter song name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (value) async {
              final name = value.trim();
              if (name.isNotEmpty) {
                final exists = await SongStorageService.instance.songExists(name);
                if (context.mounted) {
                  if (exists) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Song "$name" already exists')),
                    );
                  } else {
                    Navigator.of(context).pop();
                    songProvider.createNewSong(name);
                  }
                }
              }
            },
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
                  final exists = await SongStorageService.instance.songExists(name);
                  if (context.mounted) {
                    if (exists) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Song "$name" already exists')),
                      );
                    } else {
                      Navigator.of(context).pop();
                      songProvider.createNewSong(name);
                    }
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLoadSongDialog(BuildContext context) async {
    final songProvider = context.read<SongProvider>();
    final songNames = songProvider.songNames;

    if (songNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No songs available to load')),
      );
      return;
    }

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Load Song'),
        content: SizedBox(
          width: double.maxFinite,
          height: 200, // Fixed height to prevent intrinsic dimension issues
          child: ListView.builder(
            itemCount: songNames.length,
            itemBuilder: (context, index) {
              final songName = songNames[index];
              final isCurrentSong = songProvider.currentSongName == songName;
              
              return ListTile(
                title: Text(songName),
                trailing: isCurrentSong 
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  if (!isCurrentSong) {
                    songProvider.loadSong(songName);
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteSongDialog(BuildContext context) async {
    final songProvider = context.read<SongProvider>();
    final currentSong = songProvider.currentSong;

    if (currentSong == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No song selected to delete')),
      );
      return;
    }

    _confirmDeleteSong(context, currentSong.name);
  }

  Future<void> _confirmDeleteSong(BuildContext context, String songName) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "$songName"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final songProvider = context.read<SongProvider>();
              final success = await songProvider.deleteSong(songName);
              
              if (success && context.mounted) {
                // After successful deletion, show appropriate dialog
                if (songProvider.songs.isNotEmpty) {
                  // Show load song dialog if there are still songs available
                  _showLoadSongDialog(context);
                } else {
                  // Show new song dialog if no songs left
                  _showNewSongDialog(context);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SongProvider>(
      builder: (context, songProvider, _) {
        final hasCurrentSong = songProvider.currentSong != null;
        
        return PopupMenuButton<String>(
          icon: const Icon(Icons.music_note),
          tooltip: 'Song Menu',
          onSelected: (value) {
            switch (value) {
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
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'new',
              child: ListTile(
                leading: Icon(Icons.add),
                title: Text('New Song'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'load',
              child: ListTile(
                leading: Icon(Icons.folder_open),
                title: Text('Load Song'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              enabled: hasCurrentSong,
              child: ListTile(
                leading: Icon(Icons.delete, color: hasCurrentSong ? Colors.red : Colors.grey),
                title: Text('Delete Current Song', style: TextStyle(color: hasCurrentSong ? null : Colors.grey)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        );
      },
    );
  }
}