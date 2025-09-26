# Song Archive/Share Feature - Implementation Plan

## Overview
Enable users to export and import songs as portable archive files (.zip) containing all song data, allowing sharing between devices and users.

## Phase 1: Data Model Updates

### 1.1 Song Export Data Structure
Create a JSON schema for song metadata export:
```json
{
  "version": "1.0",
  "name": "Song Name",
  "createdAt": "2024-01-01T12:00:00Z",
  "youtubeUrl": "https://youtube.com/watch?v=...",
  "metronomeSettings": {
    "bpm": 120,
    "timeSignature": {"beats": 4, "noteValue": 4},
    "countInEnabled": true,
    "volume": 0.7,
    "enabled": true
  },
  "rectangles": [
    {
      "pageNumber": 1,
      "id": "rect_123",
      "rect": {"left": 100, "top": 200, "width": 50, "height": 30},
      "timestamps": [1500, 3000, 4500]  // milliseconds
    }
  ],
  "syncPoints": {
    "rect_123": [1500, 3000, 4500]
  }
}
```

### 1.2 Archive Structure
```
song_archive_20241225143000.zip/
├── metadata.json     # Song data and sync points
├── score.pdf        # The PDF score file
└── manifest.json    # Archive metadata (version, created date)
```

**Naming Convention**:
- Format: `song_archive_YYYYMMDDHHMMSS.zip`
- Example: `song_archive_20241225143000.zip`
- Timestamp ensures unique filenames for each export

## Phase 2: UI Reorganization

### 2.1 Move Metronome Settings to Menu
**Current Location**: Floating button in playback mode
**New Location**: Song menu (hamburger menu)
- Add menu item: "Metronome Settings" with music note icon
- Opens existing metronome settings panel
- Available in both design and playback modes

### 2.2 Replace Metronome Button with Share Button
**Location**: Where metronome button currently is (floating position in playback mode)
**Design Mode**: Show share button in top bar next to mode switcher
**Playback Mode**: Show share button in floating position (where metronome was)
**Icon**: Icons.share
**Behavior**:
- Only visible when a song is loaded
- Generates timestamped archive
- Triggers native share sheet

### 2.3 Updated Menu Structure
```
☰ Menu
├── New Song
├── Load Song
├── Delete Song
├── Metronome Settings  // NEW - moved from floating button
└── Share Song         // Alternative access point
```

## Phase 3: Export Functionality

### 3.1 Create Archive Service (`lib/services/song_archive_service.dart`)
- **Method: `Future<File> createSongArchive(Song song)`**
  ```dart
  String timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
  String archiveName = 'song_archive_$timestamp.zip';
  ```
  - Serialize song data to JSON
  - Copy PDF file from app storage
  - Create zip archive with timestamped name
  - Save to temp directory
  - Return zip file handle

### 3.2 Share Button Implementation
- **Widget**: `ShareSongButton`
- **Locations**:
  - Top bar in design mode
  - Floating position in playback mode (replacing metronome)
  - Menu as secondary access point
- **Action Flow**:
  1. Generate timestamped archive
  2. Show loading indicator
  3. Trigger native share sheet
  4. Clean up temp files after sharing

### 3.3 Integration Points
- Add to `SongProvider`:
  - `exportCurrentSong()` method
  - Handle archive creation errors
- Use `share_plus` package for native share sheet
- Use `archive` package for zip creation
- Use `intl` package for timestamp formatting

## Phase 4: Import Functionality (Complete Native Implementation)

### 4.1 Configure receive_sharing_intent Package

#### 4.1.1 Add Package Dependency
```yaml
dependencies:
  receive_sharing_intent: ^1.5.0  # Or latest version
```

### 4.2 iOS Native Configuration

#### 4.2.1 Create Share Extension Target
1. **Open ios/Runner.xcworkspace in Xcode**
2. **Add New Target**:
   - File → New → Target
   - Select "Share Extension"
   - Name: "ShareExtension"
   - Language: Swift
   - Project: Runner
   - Embed in Application: Runner

#### 4.2.2 Configure Share Extension Info.plist
**Location**: `ios/ShareExtension/Info.plist`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionAttributes</key>
        <dict>
            <key>NSExtensionActivationRule</key>
            <dict>
                <key>NSExtensionActivationSupportsFileWithMaxCount</key>
                <integer>1</integer>
                <key>NSExtensionActivationSupportsText</key>
                <false/>
                <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
                <integer>0</integer>
            </dict>
            <key>NSExtensionActivationDictionaryVersion</key>
            <integer>2</integer>
            <key>NSExtensionActivationSupportsFileWithMaxCount</key>
            <integer>1</integer>
            <key>NSExtensionActivationUsesStrictMatching</key>
            <integer>1</integer>
            <key>NSExtensionActivationFileTypeIdentifiers</key>
            <array>
                <string>com.pkware.zip-archive</string>
                <string>public.zip-archive</string>
                <string>com.adobe.pdf</string>
            </array>
        </dict>
        <key>NSExtensionMainStoryboard</key>
        <string>MainInterface</string>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.share-services</string>
    </dict>
</dict>
</plist>
```

#### 4.2.3 Update Share Extension Swift Code
**File**: `ios/ShareExtension/ShareViewController.swift`
```swift
import UIKit
import Social
import MobileCoreServices

class ShareViewController: SLComposeServiceViewController {

    override func isContentValid() -> Bool {
        return true
    }

    override func didSelectPost() {
        if let item = extensionContext?.inputItems.first as? NSExtensionItem {
            if let attachments = item.attachments {
                for attachment in attachments {
                    if attachment.hasItemConformingToTypeIdentifier("com.pkware.zip-archive") ||
                       attachment.hasItemConformingToTypeIdentifier("public.zip-archive") ||
                       attachment.hasItemConformingToTypeIdentifier("com.adobe.pdf") {

                        attachment.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (data, error) in
                            if let url = data as? URL {
                                self.handleFile(url: url)
                            }
                        }
                    }
                }
            }
        }

        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func handleFile(url: URL) {
        let sharedDefaults = UserDefaults(suiteName: "group.me.princesamuel.scoresync")

        // Copy file to shared container
        let fileManager = FileManager.default
        if let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.me.princesamuel.scoresync") {
            let fileName = url.lastPathComponent
            let destURL = containerURL.appendingPathComponent(fileName)

            try? fileManager.removeItem(at: destURL)
            try? fileManager.copyItem(at: url, to: destURL)

            // Save file path for main app
            var sharedFiles = sharedDefaults?.array(forKey: "shared_files") as? [String] ?? []
            sharedFiles.append(destURL.path)
            sharedDefaults?.set(sharedFiles, forKey: "shared_files")
            sharedDefaults?.synchronize()
        }
    }

    override func configurationItems() -> [Any]! {
        return []
    }
}
```

#### 4.2.4 Configure App Groups
1. **In Xcode Project Navigator**:
   - Select Runner target → Signing & Capabilities
   - Add Capability: "App Groups"
   - Add group: `group.me.princesamuel.scoresync`

2. **For Share Extension**:
   - Select ShareExtension target → Signing & Capabilities
   - Add Capability: "App Groups"
   - Add same group: `group.me.princesamuel.scoresync`

#### 4.2.5 Update Main App Info.plist
**Add to** `ios/Runner/Info.plist`:
```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeExtensions</key>
        <array>
            <string>zip</string>
            <string>pdf</string>
        </array>
        <key>CFBundleTypeName</key>
        <string>Song Archive</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>com.pkware.zip-archive</string>
            <string>public.zip-archive</string>
            <string>com.adobe.pdf</string>
        </array>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
    </dict>
</array>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
<key>UISupportsDocumentBrowser</key>
<true/>
```

### 4.3 Android Native Configuration

#### 4.3.1 Update AndroidManifest.xml
**File**: `android/app/src/main/AndroidManifest.xml`
```xml
<manifest>
    <application>
        <activity
            android:name=".MainActivity">

            <!-- Existing intent filters... -->

            <!-- Intent filter for receiving ZIP files -->
            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="application/zip" />
                <data android:mimeType="application/x-zip-compressed" />
                <data android:mimeType="application/octet-stream" />
            </intent-filter>

            <!-- Intent filter for viewing ZIP files -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="file" />
                <data android:scheme="content" />
                <data android:mimeType="application/zip" />
                <data android:mimeType="application/x-zip-compressed" />
                <data android:pathPattern=".*\\.zip" />
                <data android:host="*" />
            </intent-filter>

            <!-- Existing PDF intent filters remain... -->
        </activity>
    </application>
</manifest>
```

#### 4.3.2 No Additional Native Code Required
Android handles file sharing through intent filters defined in the manifest. The `receive_sharing_intent` package handles the native bridge automatically.

### 4.4 Flutter Implementation

#### 4.4.1 Initialize Package in main.dart
```dart
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class _MainScreenState extends State<MainScreen> {
  StreamSubscription? _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    _initSharingIntent();
  }

  void _initSharingIntent() {
    // For sharing files coming from outside the app while the app is in memory
    _intentDataStreamSubscription = ReceiveSharingIntent.getMediaStream()
        .listen((List<SharedMediaFile> files) {
      _handleSharedFiles(files);
    }, onError: (err) {
      developer.log("Error receiving shared files: $err");
    });

    // For sharing files coming from outside the app while the app is closed
    ReceiveSharingIntent.getInitialMedia().then((List<SharedMediaFile> files) {
      _handleSharedFiles(files);
    });
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    if (files.isEmpty) return;

    for (var file in files) {
      if (file.path.endsWith('.zip')) {
        _importSongArchive(File(file.path));
      } else if (file.path.endsWith('.pdf')) {
        _handleSharedPdf(File(file.path));
      }
    }
  }

  Future<void> _importSongArchive(File zipFile) async {
    // Show import dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ImportSongDialog(),
    );

    try {
      final songProvider = context.read<SongProvider>();
      final archiveService = SongArchiveService();
      final song = await archiveService.importSongArchive(zipFile);

      await songProvider.loadSong(song.name);

      Navigator.of(context).pop(); // Close dialog

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Song "${song.name}" imported successfully')),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close dialog

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to import song: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }
}
```

#### 4.4.2 Import Service Implementation
```dart
class SongArchiveService {
  Future<Song> importSongArchive(File zipFile) async {
    // Validate file name pattern (optional)
    final fileName = path.basename(zipFile.path);
    if (!fileName.startsWith('song_archive_') && !fileName.endsWith('.zip')) {
      // Still accept it, might be renamed
      developer.log('Warning: Archive name doesn\'t match expected pattern');
    }

    // Extract to temp directory
    final tempDir = await getTemporaryDirectory();
    final extractDir = Directory('${tempDir.path}/import_${DateTime.now().millisecondsSinceEpoch}');
    await extractDir.create();

    // Extract archive
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Extract files and validate structure
    File? metadataFile;
    File? scoreFile;

    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        final extractedFile = File('${extractDir.path}/$filename')
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);

        if (filename == 'metadata.json') {
          metadataFile = extractedFile;
        } else if (filename == 'score.pdf') {
          scoreFile = extractedFile;
        }
      }
    }

    if (metadataFile == null || scoreFile == null) {
      throw Exception('Invalid archive: missing required files');
    }

    // Parse metadata
    final metadataJson = await metadataFile.readAsString();
    final metadata = json.decode(metadataJson);

    // Check for existing song and handle conflicts
    final songName = metadata['name'];
    final songProvider = SongProvider();
    String finalSongName = songName;

    if (await songProvider.songExists(songName)) {
      final timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
      finalSongName = '${songName}_$timestamp';
    }

    // Create song with imported data
    // ... rest of import logic

    return song;
  }
}
```

### 4.5 Platform-Specific Considerations

#### iOS Specific:
- **Provisioning Profile**: Must include App Groups capability
- **Share Extension Bundle ID**: Must be `me.princesamuel.scoresync.ShareExtension`
- **Deployment Target**: Share Extension must match main app's deployment target

#### Android Specific:
- **File Permissions**: Already handled by existing permissions
- **Content URIs**: Handle both file:// and content:// schemes
- **MIME Type Variations**: Support multiple ZIP MIME types

### 4.6 Testing Checklist

1. **iOS Testing**:
   - [ ] Share Extension appears in share sheet
   - [ ] ZIP files can be shared from Files app
   - [ ] ZIP files can be shared from other apps (Mail, Safari downloads)
   - [ ] App launches when receiving shared file
   - [ ] App handles file when already running

2. **Android Testing**:
   - [ ] App appears as share target for ZIP files
   - [ ] Can receive files from file managers
   - [ ] Can receive files from messaging apps
   - [ ] Handles both file:// and content:// URIs
   - [ ] Works with different ZIP MIME types

## Phase 5: UI/UX Enhancements

### 5.1 Export Flow
1. User taps Share button (from floating position or menu)
2. Show loading indicator "Preparing song archive..."
3. Generate zip with timestamp: `song_archive_20241225143000.zip`
4. Open native share sheet with timestamped file
5. Handle success/error states

### 5.2 Import Flow
1. Receive shared zip file (any `song_archive_*.zip`)
2. Show import dialog: "Importing song..."
3. Validate and extract archive
4. Handle conflicts if necessary (append timestamp)
5. Load imported song automatically
6. Show success message with song name

### 5.3 Updated Main Screen Layout
```dart
// Design Mode:
AppBar [☰ Menu] [Song Name] [Share 🔗] [Design/Playback Switch]

// Playback Mode:
Floating Share Button (where metronome was)
Bottom Controls remain unchanged
```

## Phase 6: Technical Implementation Details

### 6.1 Dependencies to Add
```yaml
dependencies:
  archive: ^3.4.0        # For zip file creation/extraction
  share_plus: ^7.2.0     # For native share sheet
  path: ^1.9.0          # For path manipulation
  intl: ^0.19.0         # For date formatting (already in project)
  receive_sharing_intent: ^1.5.0  # For receiving shared files
```

### 6.2 File Structure Changes
```
lib/
├── models/
│   └── song_archive.dart      # Archive data models
├── services/
│   └── song_archive_service.dart  # Import/export logic
└── widgets/
    ├── share_song_button.dart  # Share UI component
    ├── import_song_dialog.dart # Import progress dialog
    └── song_menu.dart         # Updated with metronome settings
```

### 6.3 Storage Considerations
- Archives created in temp directory with timestamp
- Clean up temp files after sharing
- Validate file sizes before processing
- Handle storage permission requests

## Phase 7: Testing Strategy

### 7.1 Unit Tests
- Timestamp generation for archive names
- Archive creation with various song configurations
- JSON serialization/deserialization
- Conflict resolution with timestamp appending
- Path generation for duplicates

### 7.2 Integration Tests
- Full export/import cycle with timestamped files
- Share button positioning in both modes
- Menu reorganization with metronome settings
- File system operations
- Error recovery scenarios

### 7.3 Manual Testing
- Cross-device sharing with timestamped archives
- UI flow with repositioned buttons
- Menu access to metronome settings
- Large PDF handling
- Various archive sizes

## Implementation Order

1. **Move metronome settings** to menu
2. **Replace metronome button** with share button
3. **Create data models** for archive structure
4. **Implement timestamp generation** for archive names
5. **Implement archive service** with export functionality
6. **Add share button** in both locations (floating and top bar)
7. **Configure app** as share target (iOS Share Extension + Android intents)
8. **Implement import** functionality with timestamp conflict resolution
9. **Create UI dialogs** for import progress
10. **Test end-to-end** flow with timestamped archives
11. **Add error handling** and edge cases
12. **Write comprehensive tests**

## Key Features

1. **Archive Naming**: All archives include timestamp `song_archive_YYYYMMDDHHMMSS.zip`
2. **UI Reorganization**:
   - Metronome settings moved from floating button to menu
   - Share button takes metronome's floating position in playback mode
   - Share button also available in design mode top bar
3. **No FAB**: Removed floating action button approach
4. **Menu Enhancement**: Added metronome settings as menu item
5. **Timestamp Usage**: Both in archive names and conflict resolution
6. **Native Share Extensions**: Complete iOS and Android implementation

## Potential Challenges & Solutions

**Challenge**: Users expecting metronome in old location
- **Solution**: Clear visual cue in menu, perhaps first-time tooltip

**Challenge**: Share button visibility in both modes
- **Solution**: Consistent positioning logic, clear visual hierarchy

**Challenge**: Timestamped filenames getting long
- **Solution**: Use compact format YYYYMMDDHHMMSS, clear naming in share sheet

**Challenge**: Multiple archives from same session
- **Solution**: Timestamp ensures uniqueness even for rapid exports

**Challenge**: iOS Share Extension setup complexity
- **Solution**: Detailed step-by-step instructions, testing checklist

**Challenge**: Android content URI handling
- **Solution**: Support multiple URI schemes and MIME types