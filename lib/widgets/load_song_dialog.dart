import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/song_provider.dart';

class LoadSongDialog extends StatefulWidget {
  const LoadSongDialog({super.key});

  @override
  State<LoadSongDialog> createState() => _LoadSongDialogState();
}

class _LoadSongDialogState extends State<LoadSongDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Song> _getFilteredAndSortedSongs(List<Song> songs) {
    // Create a copy of the list to avoid modifying the original unmodifiable list
    var filteredSongs = List<Song>.from(songs);
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filteredSongs = filteredSongs.where((song) => 
        song.name.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    // Sort by created date descending (newest first)
    filteredSongs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return filteredSongs;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SongProvider>(
      builder: (context, songProvider, _) {
        final songs = _getFilteredAndSortedSongs(songProvider.songs);
        
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Load Song',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search songs...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // Songs count
                Text(
                  '${songs.length} song${songs.length != 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                
                // Songs grid
                Expanded(
                  child: songs.isEmpty 
                    ? _buildEmptyState()
                    : GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: MediaQuery.of(context).size.width < 600 ? 2 : 3,  // 2 columns on smaller screens
                          childAspectRatio: 1.4,  // Wider tiles for better text display
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: songs.length,
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          final isCurrentSong = songProvider.currentSongName == song.name;
                          
                          return _SongCard(
                            song: song,
                            isCurrentSong: isCurrentSong,
                            onTap: () {
                              Navigator.of(context).pop();
                              if (!isCurrentSong) {
                                songProvider.loadSong(song.name);
                              }
                            },
                          );
                        },
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No songs found' : 'No songs match your search',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SongCard extends StatelessWidget {
  final Song song;
  final bool isCurrentSong;
  final VoidCallback onTap;

  const _SongCard({
    required this.song,
    required this.isCurrentSong,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isCurrentSong ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrentSong
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Music Icon
            Expanded(
              flex: 2,  // Reduced icon space
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: song.pdfPath != null ? Colors.blue[50] : Colors.grey[100],
                ),
                child: Icon(
                  Icons.music_note,
                  size: 32,  // Slightly smaller icon
                  color: song.pdfPath != null ? Colors.blue[600] : Colors.grey[400],
                ),
              ),
            ),

            // Song info
            Expanded(
              flex: 3,  // More space for text
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Song name with current indicator
                    Flexible(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              song.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,  // Slightly smaller to fit better
                                color: isCurrentSong
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.black87,
                              ),
                              maxLines: 2,  // Allow wrapping to 2 lines
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrentSong)
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),  // Reduced spacing

                    // Created date
                    Flexible(
                      child: Text(
                        _formatDate(song.createdAt),
                        style: TextStyle(
                          fontSize: 12,  // Improved readability
                          color: Colors.grey[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}