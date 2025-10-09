import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:developer' as developer;

import '../models/song.dart';
import '../models/song_archive.dart';

class SongArchiveService {
  /// Creates a timestamped ZIP archive containing the song data and PDF
  /// Returns the File object of the created archive
  Future<File> createSongArchive(Song song) async {
    try {
      // Generate timestamp for unique archive name
      final timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
      // Sanitize song name for filename (replace spaces with underscores, remove special characters)
      final sanitizedSongName = _sanitizeFilename(song.name);
      final archiveName = '${sanitizedSongName}_symph_$timestamp.zip';

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final archiveFile = File('${tempDir.path}/$archiveName');

      // Create archive object
      final archive = Archive();

      // Create song archive data
      final songArchive = SongArchive.fromSong(song);
      final metadataJson = songArchive.toJsonString();

      // Add metadata.json to archive
      final metadataBytes = Uint8List.fromList(metadataJson.codeUnits);
      final metadataFile = ArchiveFile('metadata.json', metadataBytes.length, metadataBytes);
      archive.addFile(metadataFile);

      // Add PDF file if it exists
      if (song.pdfPath != null) {
        // Resolve path based on whether it's relative or absolute
        String absolutePdfPath;
        if (_isRelativePath(song.pdfPath!)) {
          absolutePdfPath = await _resolveRelativePath(song.pdfPath!);
          developer.log('Resolved relative path: ${song.pdfPath!} -> $absolutePdfPath');
        } else {
          absolutePdfPath = song.pdfPath!;
          developer.log('Using absolute path: $absolutePdfPath');
        }

        final pdfFile = File(absolutePdfPath);
        if (await pdfFile.exists()) {
          final pdfBytes = await pdfFile.readAsBytes();
          // Preserve the original filename from the path
          final pdfFileName = path.basename(absolutePdfPath);
          final pdfArchiveFile = ArchiveFile(pdfFileName, pdfBytes.length, pdfBytes);
          archive.addFile(pdfArchiveFile);
          developer.log('Added PDF to archive with filename: $pdfFileName');
        } else {
          developer.log('Warning: PDF file not found at $absolutePdfPath');
          throw Exception('PDF file not found. Cannot create archive without score.');
        }
      } else {
        throw Exception('No PDF associated with this song. Cannot create archive.');
      }

      // Create manifest
      final manifest = ArchiveManifest(
        version: '1.0',
        createdAt: DateTime.now(),
        songName: song.name,
      );
      final manifestJson = manifest.toJsonString();
      final manifestBytes = Uint8List.fromList(manifestJson.codeUnits);
      final manifestFile = ArchiveFile('manifest.json', manifestBytes.length, manifestBytes);
      archive.addFile(manifestFile);

      // Encode archive to ZIP
      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);

      if (zipBytes == null) {
        throw Exception('Failed to create ZIP archive');
      }

      // Write ZIP to file
      await archiveFile.writeAsBytes(zipBytes);

      developer.log('Created song archive: $archiveName (${zipBytes.length} bytes)');
      return archiveFile;

    } catch (e) {
      developer.log('Error creating song archive: $e');
      rethrow;
    }
  }

  /// Imports a song archive from a ZIP file
  /// Handles conflict resolution by appending timestamp if song already exists
  Future<Song> importSongArchive(File zipFile) async {
    try {
      developer.log('Importing song archive: ${zipFile.path}');

      // Validate file exists
      if (!await zipFile.exists()) {
        throw Exception('Archive file does not exist');
      }

      // Read and decode ZIP file
      final zipBytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      // Extract files and validate structure
      ArchiveFile? metadataFile;
      ArchiveFile? scoreFile;
      String? scoreFileName;
      ArchiveFile? manifestFile;

      for (final file in archive) {
        if (file.isFile) {
          if (file.name == 'metadata.json') {
            metadataFile = file;
          } else if (file.name == 'manifest.json') {
            manifestFile = file;
          } else if (file.name.toLowerCase().endsWith('.pdf')) {
            // Accept any PDF file in the archive
            scoreFile = file;
            scoreFileName = file.name;
          }
        }
      }

      // Validate required files
      if (metadataFile == null || scoreFile == null) {
        throw Exception('Invalid archive: missing required files (metadata.json or PDF file)');
      }

      // Log manifest info if present
      if (manifestFile != null) {
        developer.log('Archive manifest found');
      }

      // Parse metadata
      final metadataContent = String.fromCharCodes(metadataFile.content as List<int>);
      final metadataJson = Map<String, dynamic>.from(
        jsonDecode(metadataContent)
      );
      final songArchive = SongArchive.fromJson(metadataJson);

      // Check for existing song and handle conflicts
      String finalSongName = songArchive.name;
      final songsDir = await _getSongsDirectory();
      final songDir = Directory('${songsDir.path}/$finalSongName');

      if (await songDir.exists()) {
        // Append timestamp to avoid conflict
        final timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
        finalSongName = '${songArchive.name}_$timestamp';
        developer.log('Song name conflict resolved: $finalSongName');
      }

      // Create song directory
      final finalSongDir = Directory('${songsDir.path}/$finalSongName');
      await finalSongDir.create(recursive: true);

      // Save PDF file with original or default name
      final pdfFileName = scoreFileName ?? 'score.pdf';
      final pdfPath = '${finalSongDir.path}/$pdfFileName';
      final pdfFile = File(pdfPath);
      await pdfFile.writeAsBytes(scoreFile.content as List<int>);

      // Create Song object with imported data using toSong method (includes loop settings)
      final song = songArchive.toSong(pdfPath: pdfPath).copyWith(name: finalSongName);

      developer.log('Successfully imported song: $finalSongName');
      return song;

    } catch (e) {
      developer.log('Error importing song archive: $e');
      rethrow;
    }
  }


  /// Get the songs directory for storing imported songs
  Future<Directory> _getSongsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final songsDir = Directory('${appDir.path}/songs');
    if (!await songsDir.exists()) {
      await songsDir.create(recursive: true);
    }
    return songsDir;
  }

  /// Clean up temporary archive files
  Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = await tempDir.list().toList();

      for (final file in files) {
        if (file is File && file.path.endsWith('.zip') && file.path.contains('_symph_')) {
          // Check if it matches our archive naming pattern (contains _symph_ and timestamp)
          final filename = path.basename(file.path);
          if (RegExp(r'.*_symph_\d{14}\.zip$').hasMatch(filename)) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      developer.log('Error cleaning up temp files: $e');
    }
  }

  /// Resolve relative path to absolute path
  Future<String> _resolveRelativePath(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    return path.join(appDir.path, relativePath);
  }

  /// Check if path is relative (doesn't start with /)
  bool _isRelativePath(String filePath) {
    return !filePath.startsWith('/');
  }

  /// Sanitize filename by replacing spaces with underscores and removing special characters
  String _sanitizeFilename(String filename) {
    return filename
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^\w\-_.]'), '') // Keep only word characters, hyphens, underscores, and dots
        .toLowerCase();
  }
}