# PDF Sharing Implementation Plan

## Recent Updates (Latest Session)

### UI Improvements Completed:

1. **Load Song Dialog Enhancement** ✅
   - Replaced simple list with grid view (6 columns)
   - Added music note icons instead of PDF thumbnails for performance
   - Icons colored blue for songs with PDFs, gray without
   - Added search functionality by song name
   - Songs automatically sorted by creation date (newest first)
   - Enhanced visual design with current song indicator

2. **Video Player Loading State Fix** ✅
   - Removed loading spinner when no video URL is present
   - Fixed loading animations in video controls
   - Only shows loading state when actually loading a video URL

### Files Modified:
- Created: `lib/widgets/load_song_dialog.dart`
- Updated: `lib/main.dart` (to use new LoadSongDialog)
- Updated: `lib/widgets/song_menu.dart` (to use new LoadSongDialog)
- Updated: `lib/widgets/video_player/youtube_player.dart`
- Updated: `lib/widgets/video_player/video_controls.dart`

---

# PDF Sharing Implementation Plan

## Current State Analysis

The app already has solid foundation for PDF sharing:
- ✅ `receive_sharing_intent: ^1.8.0` package is installed
- ✅ Android intent filters configured for PDF sharing in `AndroidManifest.xml:33-37`
- ✅ iOS document types configured for PDF support in `Info.plist:47-71`
- ✅ Existing PDF sharing logic in `main.dart` with `_handleSharedFiles()` and `_showSharedPdfDialog()`
- ✅ SongProvider has methods: `createNewSong()`, `createSongFromPdf()`, `updateSongPdf()`

## Missing Configuration Updates (from receive_sharing_intent docs)

### 1. Android Permissions
**Location**: `android/app/src/main/AndroidManifest.xml`
- **Missing**: `READ_EXTERNAL_STORAGE` permission required for accessing shared files
- **Current**: Only has `INTERNET` permission

### 2. iOS Share Extension Setup
**Status**: Currently missing entirely
- **Required**: Create iOS Share Extension target in Xcode
- **Required**: Configure App Groups for data sharing between main app and extension
- **Required**: Add ShareViewController that inherits from RSIShareViewController

### 3. Enhanced Android Intent Filters
**Current**: Basic PDF sharing intent filter
**Missing**: Additional intent filters for better file handling

### 4. App Groups Configuration (iOS)
**Missing**: App Groups capability configuration needed for data sharing

## Implementation Plan

### Phase 1: Configuration Updates
1. **Android Permissions**:
   ```xml
   <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
   ```

2. **iOS Share Extension Setup**:
   - Create Share Extension target in Xcode
   - Configure App Groups capability
   - Implement ShareViewController

### Phase 2: Enhanced Sharing Dialog
**Location**: `lib/main.dart:_showSharedPdfDialog()`

**Current**: Basic dialog with create new/update existing options

**Enhancement**: Replace with comprehensive dialog including:
- Radio buttons for "Create New Song" vs "Update Existing Song"
- Text input field for song name (enabled only when "Create New Song" selected)
- Dropdown/list for existing songs (enabled only when "Update Existing Song" selected)
- Real-time name conflict validation with visual feedback
- OK/Cancel buttons with proper validation

### Phase 3: SongProvider Method Enhancements
**Location**: `lib/providers/song_provider.dart`

1. **Add name conflict checking**:
   ```dart
   Future<bool> checkSongNameConflict(String name) async {
     return await SongStorageService.instance.songExists(name);
   }
   ```

2. **Create specialized method**:
   ```dart
   Future<void> createNewSongWithPdf(String name, File pdfFile) async {
     // Check for name conflicts first
     // Copy PDF to song directory
     // Create song with PDF path
     // Set as current song and load into providers
   }
   ```

3. **Modify existing `createNewSong()` method**:
   - Add `hasChosenPdf` flag parameter
   - When flag is true, skip PDF selection workflow
   - Load provided PDF immediately after song creation

### Phase 4: Main App Sharing Handler Updates
**Location**: `lib/main.dart`

1. **Enhance `_handleSharedFiles()` method**:
   - Store shared PDF file reference globally
   - Show enhanced dialog
   - Handle user choice with proper validation
   - Route to appropriate workflow based on choice

2. **Add state management for shared PDF**:
   - Add `File? _pendingSharedPdf` field
   - Add `bool _hasPendingSharedPdf` getter
   - Clear pending PDF after processing

### Phase 5: New Song Workflow Integration
**Location**: Existing new song creation screens/widgets

1. **Add shared PDF awareness**:
   - Check for `_hasPendingSharedPdf` flag in new song workflow
   - Skip PDF selection step if flag is true
   - Automatically load pending PDF when song is created
   - Clear flag after successful creation

### Phase 6: Error Handling and User Feedback

1. **Enhanced error handling**:
   - Handle file access permissions
   - Validate PDF file integrity
   - Show loading states during file operations
   - Display appropriate error messages for conflicts, file errors, etc.
   - Provide success confirmation messages

2. **User experience improvements**:
   - Real-time validation feedback
   - Clear progress indicators
   - Intuitive error messages

## Testing Scenarios

**Key test cases to validate**:
- Share PDF → Create new song with custom name → Success
- Share PDF → Create new song with conflicting name → Error handling
- Share PDF → Update existing song → Success
- Share PDF → Cancel dialog → Cleanup
- Share invalid/corrupted PDF → Error handling
- Share PDF while app is closed → Launch and handle
- Share PDF while app is running → Handle in foreground

## Implementation Priority

1. **High Priority**: 
   - Android permission update (blocking on some devices)
   - Enhanced dialog with name input and conflict checking

2. **Medium Priority**: 
   - SongProvider method enhancements for PDF workflow
   - New song workflow integration with shared PDF flag

3. **Lower Priority**: 
   - iOS Share Extension (nice-to-have, current sharing works)
   - Additional testing and edge case handling

## Files to Modify

- `android/app/src/main/AndroidManifest.xml` - Add storage permission
- `lib/main.dart` - Enhanced sharing dialog and handler
- `lib/providers/song_provider.dart` - New methods and PDF workflow integration
- Any new song creation UI components - Add shared PDF awareness
- iOS project (Xcode) - Share Extension setup

## User Requirements Addressed

- ✅ When shared a PDF, app allows creating new song or updating existing song
- ✅ If new song is chosen, ask for name and check for conflicts
- ✅ Follow new song workflow with flag to indicate chosen PDF
- ✅ Load PDF automatically if flag is true

This plan leverages the existing infrastructure while adding the specific requirements for name input, conflict checking, and seamless integration with the new song workflow.