import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/song.dart';
import '../models/rectangle.dart';
import '../services/song_storage_service.dart';
import 'sync_provider.dart';
import 'score_provider.dart';
import 'video_provider.dart';
import 'rectangle_provider.dart';

class SongProvider extends ChangeNotifier {
  Song? _currentSong;
  List<Song> _songs = [];
  bool _isLoading = false;
  bool _isInitialized = false; // Track if initialization is completely done
  String? _errorMessage;
  
  // Provider references for updating other providers
  ScoreProvider? _scoreProvider;
  VideoProvider? _videoProvider;
  RectangleProvider? _rectangleProvider;
  
  // Debouncing timer for rectangle updates
  Timer? _rectangleUpdateTimer;

  Song? get currentSong => _currentSong;
  List<Song> get songs => List.unmodifiable(_songs);
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  bool get hasSongs => _songs.isNotEmpty;
  String? get currentSongName => _currentSong?.name;

  // Set provider references
  void setProviders({
    required ScoreProvider scoreProvider,
    required VideoProvider videoProvider,
    required RectangleProvider rectangleProvider,
    required SyncProvider syncProvider,
  }) {
    developer.log('Setting provider references...');
    _scoreProvider = scoreProvider;
    _videoProvider = videoProvider;
    _rectangleProvider = rectangleProvider;
    
    // Set up auto-save callbacks
    _rectangleProvider?.setOnRectanglesChanged(_onRectanglesChanged);
    developer.log('Provider references set successfully');
  }

  // Handle rectangle changes with debouncing
  void _onRectanglesChanged() {
    if (_currentSong != null && _rectangleProvider != null) {
      // Cancel previous timer
      _rectangleUpdateTimer?.cancel();
      
      // Start new timer to debounce saves
      _rectangleUpdateTimer = Timer(const Duration(milliseconds: 500), () {
        final rectangles = _rectangleProvider!.getAllRectangles();
        _updateSongRectanglesDebounced(rectangles);
      });
    }
  }

  // Update rectangles without debouncing (for immediate saves)
  Future<void> _updateSongRectanglesDebounced(List<DrawnRectangle> rectangles) async {
    if (_currentSong == null) return;

    try {
      final updatedSong = _currentSong!.copyWith(rectangles: rectangles);
      await _saveSongDirect(updatedSong);
      _currentSong = updatedSong;
      
      // Update local songs list without reloading
      _songs.removeWhere((s) => s.name == updatedSong.name);
      _songs.add(updatedSong);
      _songs.sort((a, b) => a.name.compareTo(b.name));
      
      notifyListeners();
    } catch (e) {
      developer.log('Error updating rectangles: $e');
    }
  }

  // Initialize and load data
  Future<void> initialize() async {
    developer.log('SongProvider initialization starting...');
    _isLoading = true;
    notifyListeners();

    try {
      developer.log('Initializing SongStorageService...');
      await SongStorageService.instance.initialize();
      
      developer.log('Loading songs...');
      await _loadSongsInternal(); // Use internal method to avoid extra notifyListeners
      
      developer.log('Loading current song...');
      await _loadCurrentSongInternal(); // Use internal method to avoid extra notifyListeners
      
      developer.log('SongProvider initialization complete - currentSong: ${_currentSong?.name}, songsCount: ${_songs.length}');
    } catch (e) {
      _errorMessage = 'Failed to initialize song storage: $e';
      developer.log('SongProvider initialization error: $e');
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners(); // Single notification at the end
    }
  }

  // Load all songs from storage
  Future<void> loadSongs() async {
    await _loadSongsInternal();
    notifyListeners();
  }

  // Internal method without notifyListeners
  Future<void> _loadSongsInternal() async {
    try {
      _songs = await SongStorageService.instance.loadSongs();
      developer.log('Loaded ${_songs.length} songs');
    } catch (e) {
      _errorMessage = 'Failed to load songs: $e';
      developer.log('Error loading songs: $e');
    }
  }

  // Load current song from storage
  Future<void> loadCurrentSong() async {
    await _loadCurrentSongInternal();
    notifyListeners();
  }

  // Internal method without notifyListeners
  Future<void> _loadCurrentSongInternal() async {
    try {
      final currentSongName = SongStorageService.instance.getCurrentSongName();
      developer.log('Current song name from storage: $currentSongName');
      
      if (currentSongName != null) {
        _currentSong = await SongStorageService.instance.getSong(currentSongName);
        if (_currentSong != null) {
          await _loadSongDataIntoProviders(_currentSong!);
          developer.log('Loaded current song: ${_currentSong!.name}');
        } else {
          developer.log('Current song not found in storage: $currentSongName');
        }
      } else {
        developer.log('No current song name in storage');
      }
    } catch (e) {
      developer.log('Error loading current song: $e');
    }
  }

  // Create new song
  Future<void> createNewSong(String name, {String? pdfPath}) async {
    try {
      // Check if song already exists
      if (await SongStorageService.instance.songExists(name)) {
        _errorMessage = 'Song "$name" already exists';
        notifyListeners();
        return;
      }

      final song = Song(
        name: name,
        pdfPath: pdfPath,
      );

      await _saveSong(song);
      await _setCurrentSong(song);
      await _loadSongDataIntoProviders(song);

      developer.log('Created new song: $name');
    } catch (e) {
      _errorMessage = 'Failed to create song: $e';
      developer.log('Error creating song: $e');
      notifyListeners();
    }
  }

  // Create song from PDF
  Future<void> createSongFromPdf(File pdfFile) async {
    try {
      final name = Song.nameFromPdfPath(pdfFile.path);
      
      // Copy PDF to song directory
      final appPdfPath = await _copyPdfToSongDirectory(pdfFile, name);
      
      await createNewSong(name, pdfPath: appPdfPath);
    } catch (e) {
      _errorMessage = 'Failed to create song from PDF: $e';
      developer.log('Error creating song from PDF: $e');
      notifyListeners();
    }
  }

  // Load song
  Future<void> loadSong(String songName) async {
    try {
      developer.log('Starting to load song: $songName');
      final song = await SongStorageService.instance.getSong(songName);
      if (song == null) {
        _errorMessage = 'Song "$songName" not found';
        developer.log('Song not found: $songName');
        notifyListeners();
        return;
      }

      developer.log('Found song: ${song.name}, PDF: ${song.pdfPath}, Rectangles: ${song.rectangles.length}, VideoURL: ${song.videoUrl}');
      
      // Clear all providers first to ensure clean state
      await _setCurrentSong(song);
      await _loadSongDataIntoProviders(song);
      developer.log('Loaded song: $songName');
    } catch (e) {
      _errorMessage = 'Failed to load song: $e';
      developer.log('Error loading song: $e');
      notifyListeners();
    }
  }

  // Delete song
  Future<bool> deleteSong(String songName) async {
    try {
      final success = await SongStorageService.instance.deleteSong(songName);
      if (success) {
        _songs.removeWhere((s) => s.name == songName);
        
        // If deleted song was current, clear current song
        if (_currentSong?.name == songName) {
          _currentSong = null;
          await SongStorageService.instance.setCurrentSong(null);
        }
        
        // Clean up song directory
        await _deleteSongDirectory(songName);
        
        developer.log('Deleted song: $songName');
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to delete song "$songName"';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to delete song: $e';
      developer.log('Error deleting song: $e');
      notifyListeners();
      return false;
    }
  }

  // Update current song's PDF
  Future<void> updateSongPdf(File pdfFile) async {
    if (_currentSong == null) return;

    try {
      // Copy PDF to song directory
      final appPdfPath = await _copyPdfToSongDirectory(pdfFile, _currentSong!.name);
      
      final updatedSong = _currentSong!.copyWith(
        pdfPath: appPdfPath,
      );

      await _saveSong(updatedSong);
      await _setCurrentSong(updatedSong);
      
      developer.log('Updated song PDF: ${_currentSong!.name} -> $appPdfPath');
    } catch (e) {
      _errorMessage = 'Failed to update PDF: $e';
      developer.log('Error updating PDF: $e');
      notifyListeners();
    }
  }


  // Update current song's rectangles
  Future<void> updateSongRectangles(List<DrawnRectangle> rectangles) async {
    if (_currentSong == null) return;

    try {
      final updatedSong = _currentSong!.copyWith(rectangles: rectangles);
      await _saveSong(updatedSong);
      _currentSong = updatedSong;
      
      notifyListeners();
    } catch (e) {
      developer.log('Error updating rectangles: $e');
    }
  }

  // Private helper to save song (reloads all songs)
  Future<void> _saveSong(Song song) async {
    await SongStorageService.instance.saveSong(song);
    
    // Update songs list
    _songs.removeWhere((s) => s.name == song.name);
    _songs.add(song);
    _songs.sort((a, b) => a.name.compareTo(b.name));
  }

  // Direct save without reloading all songs (for frequent updates like rectangles)
  Future<void> _saveSongDirect(Song song) async {
    await SongStorageService.instance.saveSongDirect(song);
  }

  // Private helper to set current song
  Future<void> _setCurrentSong(Song song) async {
    _currentSong = song;
    await SongStorageService.instance.setCurrentSong(song.name);
    _errorMessage = null;
    notifyListeners();
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Update video URL for current song
  Future<void> updateSongVideoUrl(String videoUrl) async {
    if (_currentSong == null) return;

    try {
      final updatedSong = _currentSong!.copyWith(videoUrl: videoUrl);
      await _saveSongDirect(updatedSong);
      _currentSong = updatedSong;
      
      // Update local songs list
      _songs.removeWhere((s) => s.name == updatedSong.name);
      _songs.add(updatedSong);
      _songs.sort((a, b) => a.name.compareTo(b.name));
      
      developer.log('Saved video URL for song: ${_currentSong!.name}');
      notifyListeners();
    } catch (e) {
      developer.log('Error updating video URL: $e');
    }
  }

  // Load song data into other providers
  Future<void> _loadSongDataIntoProviders(Song song) async {
    try {
      developer.log('Loading song data into providers: ${song.name}');
      
      // Clear all providers first to avoid intermediate states
      _clearAllProviders();
      
      // Load PDF into ScoreProvider
      if (song.pdfPath != null && _scoreProvider != null) {
        String absolutePdfPath;
        
        // Resolve path based on whether it's relative or absolute
        if (_isRelativePath(song.pdfPath!)) {
          absolutePdfPath = await _resolveRelativePath(song.pdfPath!);
          developer.log('Resolved relative path: ${song.pdfPath!} -> $absolutePdfPath');
        } else {
          absolutePdfPath = song.pdfPath!;
          developer.log('Using absolute path: $absolutePdfPath');
        }
        
        final pdfFile = File(absolutePdfPath);
        developer.log('Loading PDF: $absolutePdfPath, exists: ${pdfFile.existsSync()}');
        
        if (pdfFile.existsSync()) {
          developer.log('ScoreProvider before loading PDF: ${_scoreProvider.hashCode}');
          await _scoreProvider!.loadPdf(pdfFile);
          developer.log('PDF successfully loaded into ScoreProvider');
          
          // If this was an absolute path, convert to relative for future persistence
          if (!_isRelativePath(song.pdfPath!)) {
            final appDir = await getApplicationDocumentsDirectory();
            if (absolutePdfPath.startsWith(appDir.path)) {
              final relativePath = path.relative(absolutePdfPath, from: appDir.path);
              developer.log('Converting absolute to relative path: $relativePath');
              final updatedSong = song.copyWith(pdfPath: relativePath);
              await _saveSongDirect(updatedSong);
              _currentSong = updatedSong;
            }
          }
        } else {
          developer.log('PDF file does not exist: $absolutePdfPath');
          // Try to find PDF in the song directory
          await _tryRecoverPdfFromSongDirectory(song);
        }
      } else {
        developer.log('Skipping PDF load - pdfPath: ${song.pdfPath}, scoreProvider: ${_scoreProvider != null}');
      }

      // Load rectangles into RectangleProvider
      if (_rectangleProvider != null) {
        developer.log('RectangleProvider before loading: ${_rectangleProvider.hashCode}');
        developer.log('Loading ${song.rectangles.length} rectangles');
        _rectangleProvider!.loadRectangles(song.rectangles);
        developer.log('Rectangles successfully loaded into RectangleProvider');
      } else {
        developer.log('RectangleProvider is null');
      }

      // Load video URL into VideoProvider
      if (song.videoUrl != null && _videoProvider != null) {
        developer.log('VideoProvider before loading: ${_videoProvider.hashCode}');
        developer.log('Loading video URL: ${song.videoUrl!}');
        _videoProvider!.setVideoUrl(song.videoUrl!);
        developer.log('Video URL successfully loaded into VideoProvider');
      } else {
        developer.log('Skipping video load - videoUrl: ${song.videoUrl}, videoProvider: ${_videoProvider != null}');
      }

      // Load sync points into SyncProvider
      // Sync points are now handled automatically through rectangles with timestamps
      // The SyncProvider rebuilds its tree when rectangles are loaded
    } catch (e) {
      developer.log('Error loading song data into providers: $e');
    }
  }

  // Clear all providers
  Future<void> _clearAllProviders() async {
    try {
      developer.log('Clearing all providers before loading new song');
      
      if (_scoreProvider != null) {
        _scoreProvider!.clearPdf();
        developer.log('ScoreProvider cleared');
      }
      
      if (_rectangleProvider != null) {
        _rectangleProvider!.clearAllRectangles();
        developer.log('RectangleProvider cleared');
      }
      
      if (_videoProvider != null) {
        _videoProvider!.clearVideo();
        developer.log('VideoProvider cleared');
      }
      
      // SyncProvider will automatically rebuild when rectangles are cleared
      
      developer.log('All providers cleared successfully');
    } catch (e) {
      developer.log('Error clearing providers: $e');
    }
  }

  // Copy PDF to song's directory in app folder and return relative path
  Future<String> _copyPdfToSongDirectory(File sourceFile, String songName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final sanitizedSongName = songName.replaceAll(RegExp(r'[^\w\-_\s]'), '_');
      final songDir = Directory(path.join(appDir.path, 'songs', sanitizedSongName));
      
      // Create song directory if it doesn't exist
      if (!await songDir.exists()) {
        await songDir.create(recursive: true);
      }
      
      // Use original filename or create a simple name
      final extension = path.extension(sourceFile.path);
      final fileName = 'score$extension';
      final destinationPath = path.join(songDir.path, fileName);
      
      // Copy the file
      await sourceFile.copy(destinationPath);
      
      // Return relative path from app documents directory
      final relativePath = path.join('songs', sanitizedSongName, fileName);
      developer.log('PDF copied to song directory, relative path: $relativePath');
      
      return relativePath;
    } catch (e) {
      developer.log('Error copying PDF to song directory: $e');
      rethrow;
    }
  }

  // Get song directory path
  Future<String> _getSongDirectoryPath(String songName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final sanitizedSongName = songName.replaceAll(RegExp(r'[^\w\-_\s]'), '_');
    return path.join(appDir.path, 'songs', sanitizedSongName);
  }

  // Resolve relative path to absolute path
  Future<String> _resolveRelativePath(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    return path.join(appDir.path, relativePath);
  }

  // Check if path is relative (doesn't start with /)
  bool _isRelativePath(String filePath) {
    return !path.isAbsolute(filePath);
  }

  // Try to recover PDF from song directory when stored path is invalid
  Future<void> _tryRecoverPdfFromSongDirectory(Song song) async {
    try {
      final songDirPath = await _getSongDirectoryPath(song.name);
      final songDir = Directory(songDirPath);
      if (await songDir.exists()) {
        final files = await songDir.list().toList();
        final pdfFiles = files.where((file) => file.path.toLowerCase().endsWith('.pdf')).toList();
        if (pdfFiles.isNotEmpty) {
          final correctPdfPath = pdfFiles.first.path;
          developer.log('Found PDF in song directory: $correctPdfPath');
          await _scoreProvider!.loadPdf(File(correctPdfPath));
          
          // Update song with correct relative path
          final appDir = await getApplicationDocumentsDirectory();
          final relativePath = path.relative(correctPdfPath, from: appDir.path);
          final updatedSong = song.copyWith(pdfPath: relativePath);
          await _saveSongDirect(updatedSong);
          _currentSong = updatedSong;
          developer.log('Updated song with recovered relative PDF path: $relativePath');
        }
      }
    } catch (e) {
      developer.log('Error finding PDF in song directory: $e');
    }
  }

  // Delete song directory and all its contents
  Future<void> _deleteSongDirectory(String songName) async {
    try {
      final songDirPath = await _getSongDirectoryPath(songName);
      final songDir = Directory(songDirPath);
      
      if (await songDir.exists()) {
        await songDir.delete(recursive: true);
        developer.log('Deleted song directory: $songDirPath');
      }
    } catch (e) {
      developer.log('Error deleting song directory: $e');
      // Don't rethrow as this is cleanup and shouldn't fail the main operation
    }
  }

  // Get song names for UI
  List<String> get songNames {
    return _songs.map((s) => s.name).toList()..sort();
  }

  @override
  void dispose() {
    _rectangleUpdateTimer?.cancel();
    super.dispose();
  }
}