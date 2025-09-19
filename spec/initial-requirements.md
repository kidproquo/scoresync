
I want to build an iOS and Android app, called Score Sync, that allows syncing YouTube videos with PDF music scores.

The app should be built with Flutter and have the following features:
- Main screen split into two halves - left half with a score viewer and right half with a YouTube player
- A score viewer, where user can provide a music score PDF which needs to be displayed page by page
    - viewer shold have page navigation - next page, previous page, first page and last page
- A YouTube player where user can input the video url and load the videos
    - With playback controls (play/pause/stop, rewind 10s, forward 10s, seek bar), and speed controls
    - player should show current playback position
- App will have two modes - Design and Playback
    - In Design mode
        - the user can draw rectangles to highlight areas on the score
        - each rectangle will have an associated video timestamp
        - user can play the video, pause it and then hit a sync button to assign the current timestamp to the selected rectangle
        - app should maintain the timestamp - rectangle link (a "sync point") in a quick lookup datastructure - maybe a red-black tree
        - one timestamp can have only one rectangle associated with it, however one rectangle can have multiple timestamps associated with it (repeated sections, etc.)
        - app should show the "sync points" in the UI for user to review. user can edit a sync point - tweak the timestamp or delete the sync point
        - user can select a rectangle and move it around
        - user can delete a rectangle, which will also delete associated sync points
    - in Playback mode
        - the score and the video will be in sync
        - track the current timestamp of the video, 
        - lookup the datastructure for associated rectangle whose timestamp is largest less than or equal to current timestamp and highlight it
        - if user taps on a rectangle, then seek to the associated timestamp in the video. if rectangle has multiple timestamps associated with it then allow user to select



## Other requirements

- use me.princesamuel.scoresync as the app id
- only support landscape mode

### Theming

- The app uses light mode
- Theming should be done by setting the `theme` in the `MaterialApp`, rather than hardcoding colors and sizes in the widgets themselves

### Code Style

- Ensure proper separation of concerns by creating a suitable folder structure
- Prefer small composable widgets over large ones
- Prefer using flex values over hardcoded sizes when creating widgets inside rows/columns, ensuring the UI adapts to various screen sizes
- Use `log` from `dart:developer` rather than `print` or `debugPrint` for logging
