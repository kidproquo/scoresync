# Score Sync Implementation Plan

## Phase 1: Project Setup & Basic UI Structure ✅ **COMPLETED**
**Goal**: Create Flutter project with basic split-screen layout

- [x] Initialize Flutter project with app ID `me.princesamuel.scoresync`
- [x] Configure landscape-only orientation for iOS and Android
- [x] Set up basic Material theme with light mode
- [x] Create main split-screen layout (50/50 split)
- [x] Add placeholder containers for score viewer and video player
- [x] Set up basic project folder structure

**Progress**: All Phase 1 tasks completed. Main app structure with landscape mode, split-screen layout, and basic mode switching is implemented in `/lib/main.dart`.

## Phase 2: PDF Score Viewer
**Goal**: Implement fully functional PDF score viewer

- [ ] Add PDF viewer dependency (`syncfusion_flutter_pdfviewer` or `flutter_pdfview`)
- [ ] Implement file picker for PDF selection
- [ ] Create score viewer widget with PDF rendering
- [ ] Add page navigation controls (next, previous, first, last)
- [ ] Display current page number and total pages
- [ ] Handle PDF loading states and errors

**Status**: Not started - placeholder widget exists in main.dart

## Phase 3: YouTube Video Player
**Goal**: Integrate YouTube player with custom controls

- [ ] Add `youtube_player_flutter` dependency
- [ ] Create YouTube player widget
- [ ] Implement URL input field for video loading
- [ ] Add playback controls:
  - [ ] Play/pause/stop buttons
  - [ ] Seek bar with current position
  - [ ] 10-second forward/backward buttons
  - [ ] Speed control (0.5x, 1x, 1.5x, 2x)
- [ ] Display current playback position (timestamp)
- [ ] Handle video loading states and errors

**Status**: Not started - placeholder widget exists in main.dart

## Phase 4: Mode Management & State Architecture
**Goal**: Implement Design/Playback mode switching with proper state management

- [ ] Set up state management (Provider or Riverpod)
- [x] Create mode enum (Design, Playback) - Basic boolean implemented
- [x] Implement mode switcher UI component - Switch widget in AppBar
- [ ] Create providers for:
  - [ ] App mode state
  - [ ] Score state (current PDF, page)
  - [ ] Video state (URL, position, playing status)
  - [ ] Sync points collection
- [ ] Ensure UI responds to mode changes

**Status**: Partially complete - basic mode switching implemented, state management architecture needed

## Phase 5: Rectangle Drawing & Selection (Design Mode)
**Goal**: Enable rectangle drawing and manipulation on the score

- [ ] Implement custom painter for rectangle overlay
- [ ] Add gesture detection for drawing rectangles
- [ ] Create rectangle data model
- [ ] Implement rectangle selection with visual feedback
- [ ] Add rectangle manipulation:
  - [ ] Move selected rectangle
  - [ ] Delete selected rectangle
- [ ] Store rectangles per PDF page
- [ ] Show rectangle boundaries clearly

**Status**: Not started - folder structure exists but no implementation

## Phase 6: Sync Point Creation (Design Mode)
**Goal**: Link rectangles to video timestamps

- [ ] Create sync point data model
- [ ] Implement sync button functionality
- [ ] Capture current video timestamp on sync
- [ ] Link timestamp to selected rectangle
- [ ] Handle multiple timestamps per rectangle
- [ ] Implement red-black tree for timestamp storage
- [ ] Add visual indicators for synced rectangles

**Status**: Not started - folder structure exists but no implementation

## Phase 7: Sync Point Management UI
**Goal**: Allow users to view and edit sync points

- [ ] Create sync points list view
- [ ] Display all sync points with:
  - [ ] Rectangle ID/description
  - [ ] Associated timestamp(s)
  - [ ] Page number
- [ ] Implement sync point editing:
  - [ ] Modify timestamp
  - [ ] Delete sync point
- [ ] Add sync point validation
- [ ] Update UI when sync points change

**Status**: Not started

## Phase 8: Playback Mode Synchronization
**Goal**: Implement automatic score-video synchronization

- [ ] Track video playback position in real-time
- [ ] Implement efficient timestamp lookup in red-black tree
- [ ] Find and highlight rectangle for current timestamp
- [ ] Handle page turning when sync point is on different page
- [ ] Smooth transitions between sync points
- [ ] Handle edge cases (no sync points, gaps in timeline)

**Status**: Not started

## Phase 9: Interactive Playback
**Goal**: Enable user interaction during playback

- [ ] Detect taps on rectangles during playback
- [ ] Implement video seeking to rectangle's timestamp
- [ ] Handle rectangles with multiple timestamps:
  - [ ] Show timestamp selection dialog
  - [ ] Allow user to choose specific timestamp
- [ ] Maintain playback state after seeking

**Status**: Not started

## Phase 10: Polish & Error Handling
**Goal**: Refine user experience and handle edge cases

- [ ] Add loading indicators throughout the app
- [ ] Implement comprehensive error handling:
  - [ ] Invalid PDF files
  - [ ] YouTube video loading failures
  - [ ] Network connectivity issues
- [ ] Add confirmation dialogs for destructive actions
- [ ] Optimize performance for large PDFs
- [ ] Implement proper logging with `dart:developer`
- [ ] Add helpful empty states and instructions

**Status**: Not started

## Phase 11: Testing & Documentation
**Goal**: Ensure reliability and maintainability

- [ ] Write unit tests for:
  - [ ] Red-black tree implementation
  - [ ] Sync point logic
  - [ ] Mode switching
- [ ] Create widget tests for key components
- [ ] Add integration tests for full workflows
- [ ] Document complex algorithms
- [ ] Create user guide for app features

**Status**: Not started

## Phase 12: Platform-Specific Optimization
**Goal**: Ensure smooth performance on iOS and Android

- [ ] Test on various screen sizes
- [ ] Optimize PDF rendering performance
- [ ] Fine-tune YouTube player for each platform
- [ ] Handle platform-specific permissions
- [ ] Test gesture responsiveness
- [ ] Address any platform-specific UI issues

**Status**: Not started

## Current Project Status

### ✅ Completed Features
- Flutter project setup with proper app ID
- Landscape-only orientation configuration
- Basic Material theme with light mode
- Split-screen layout (50/50 split) implemented
- Mode switching UI with switch in AppBar
- Basic folder structure for organized development

### 🚧 In Progress
- None currently

### 📋 Next Priority Tasks
1. **Add PDF viewer dependency** - Choose between `syncfusion_flutter_pdfviewer` or `flutter_pdfview`
2. **Set up state management** - Implement Provider or Riverpod architecture
3. **Add YouTube player dependency** - Install `youtube_player_flutter`
4. **Create proper widget separation** - Move placeholder widgets to separate files

### 📁 Project Structure Status
```
lib/
├── main.dart ✅ (Contains full basic implementation)
├── models/ ⏳ (Folder created, needs implementation)
├── providers/ ⏳ (Folder created, needs implementation)
├── screens/ ⏳ (Folder created, needs implementation)
├── utils/ ⏳ (Folder created, needs implementation)
└── widgets/
    ├── score_viewer/ ⏳ (Folder created, needs implementation)
    └── video_player/ ⏳ (Folder created, needs implementation)
```

### 🎯 Success Criteria Progress

- ✅ App runs smoothly on both iOS and Android in landscape mode
- ⏳ PDFs load and navigate quickly (not implemented)
- ⏳ YouTube videos play without stuttering (not implemented)
- ⏳ Sync points accurately link score positions to video timestamps (not implemented)
- ✅ Mode switching is instant and preserves state (basic implementation)
- ⏳ Rectangle drawing and selection feels responsive (not implemented)
- ⏳ Playback synchronization is accurate within 100ms (not implemented)
- ⏳ All user interactions have appropriate feedback (basic implementation)

**Overall Progress**: **Phase 1 Complete** (1/12 phases) - Foundation is solid for rapid development of remaining features.