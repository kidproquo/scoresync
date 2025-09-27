Feature: Metronome beat as the reference track

Instead of having video timestamp as the reference (Video Mode), we will have the metronome's beat (Beat Mode) to track the highlighted rectangles

In Beat Mode, app needs to track the current beat of the metronome. The sync points for the rectangles will be for the metronome beat - rectangle to beat number. 

## UI
- An option in the metronome settings panel to switch between Video Mode and Beat Mode
- Beat Mode will replace the video overlay with a metronome overlay 
    - Controls for the metronome - play/pause/stop
    - Beat visualization showing current beat and the total beats of the measure, based on time signature
    - Show the current measure number
    - No slider in design mode. Slider in playback mode lets you seek by measures, reseting the metronome counter to the first beat of the seeked to measure

## Other considerations
- Tracking the metronome is critical. So first get the tick callback working
```
metronome.tickStream.listen((int tick) {
  print("tick: $tick");
});
```
