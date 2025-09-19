import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import '../models/song.dart';

class SongStorageService {
  static const String _songsKey = 'score_sync_songs';
  static const String _currentSongKey = 'score_sync_current_song';
  
  static SongStorageService? _instance;
  SharedPreferences? _prefs;

  SongStorageService._();

  static SongStorageService get instance {
    return _instance ??= SongStorageService._();
  }

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    developer.log('SongStorageService initialized');
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('SongStorageService not initialized. Call initialize() first.');
    }
    return _prefs!;
  }

  // Save all songs
  Future<bool> saveSongs(List<Song> songs) async {
    try {
      final songMap = <String, String>{};
      for (final song in songs) {
        songMap[song.name] = song.toJsonString();
      }
      
      final success = await prefs.setString(_songsKey, jsonEncode(songMap));
      if (success) {
        developer.log('Saved ${songs.length} songs to storage');
      }
      return success;
    } catch (e) {
      developer.log('Error saving songs: $e');
      return false;
    }
  }

  // Load all songs
  Future<List<Song>> loadSongs() async {
    try {
      final songsJson = prefs.getString(_songsKey);
      if (songsJson == null) {
        developer.log('No songs found in storage');
        return [];
      }

      final songMap = jsonDecode(songsJson) as Map<String, dynamic>;
      final songs = <Song>[];
      
      for (final entry in songMap.entries) {
        try {
          final song = Song.fromJsonString(entry.value as String);
          songs.add(song);
        } catch (e) {
          developer.log('Error loading song ${entry.key}: $e');
        }
      }

      developer.log('Loaded ${songs.length} songs from storage');
      return songs;
    } catch (e) {
      developer.log('Error loading songs: $e');
      return [];
    }
  }

  // Save a single song
  Future<bool> saveSong(Song song) async {
    try {
      final songs = await loadSongs();
      
      // Remove existing song with same name
      songs.removeWhere((s) => s.name == song.name);
      
      // Add updated song
      songs.add(song);
      
      return await saveSongs(songs);
    } catch (e) {
      developer.log('Error saving song ${song.name}: $e');
      return false;
    }
  }

  // Save a single song directly without reloading all songs (more efficient for frequent updates)
  Future<bool> saveSongDirect(Song song) async {
    try {
      // Get existing songs data
      final songsJson = prefs.getString(_songsKey);
      Map<String, dynamic> songMap;
      
      if (songsJson != null) {
        songMap = jsonDecode(songsJson) as Map<String, dynamic>;
      } else {
        songMap = <String, dynamic>{};
      }
      
      // Update just this song
      songMap[song.name] = song.toJsonString();
      
      // Save back
      final success = await prefs.setString(_songsKey, jsonEncode(songMap));
      if (success) {
        developer.log('Saved song ${song.name} directly');
      }
      return success;
    } catch (e) {
      developer.log('Error saving song ${song.name} directly: $e');
      return false;
    }
  }

  // Delete a song
  Future<bool> deleteSong(String songName) async {
    try {
      final songs = await loadSongs();
      final initialCount = songs.length;
      
      songs.removeWhere((s) => s.name == songName);
      
      if (songs.length < initialCount) {
        developer.log('Deleted song: $songName');
        return await saveSongs(songs);
      } else {
        developer.log('Song not found for deletion: $songName');
        return false;
      }
    } catch (e) {
      developer.log('Error deleting song $songName: $e');
      return false;
    }
  }

  // Get a specific song
  Future<Song?> getSong(String songName) async {
    try {
      final songs = await loadSongs();
      return songs.where((s) => s.name == songName).firstOrNull;
    } catch (e) {
      developer.log('Error getting song $songName: $e');
      return null;
    }
  }

  // Get song names
  Future<List<String>> getSongNames() async {
    try {
      final songs = await loadSongs();
      return songs.map((s) => s.name).toList()..sort();
    } catch (e) {
      developer.log('Error getting song names: $e');
      return [];
    }
  }

  // Set current song
  Future<bool> setCurrentSong(String? songName) async {
    try {
      if (songName == null) {
        return await prefs.remove(_currentSongKey);
      } else {
        return await prefs.setString(_currentSongKey, songName);
      }
    } catch (e) {
      developer.log('Error setting current song: $e');
      return false;
    }
  }

  // Get current song name
  String? getCurrentSongName() {
    try {
      return prefs.getString(_currentSongKey);
    } catch (e) {
      developer.log('Error getting current song: $e');
      return null;
    }
  }

  // Get current song
  Future<Song?> getCurrentSong() async {
    final currentSongName = getCurrentSongName();
    if (currentSongName == null) return null;
    return await getSong(currentSongName);
  }

  // Check if song exists
  Future<bool> songExists(String songName) async {
    try {
      final songs = await loadSongs();
      return songs.any((s) => s.name == songName);
    } catch (e) {
      developer.log('Error checking song existence: $e');
      return false;
    }
  }

  // Clear all data
  Future<bool> clearAllData() async {
    try {
      await prefs.remove(_songsKey);
      await prefs.remove(_currentSongKey);
      developer.log('Cleared all song data');
      return true;
    } catch (e) {
      developer.log('Error clearing all data: $e');
      return false;
    }
  }
}