# Looping between measures

We will use the sync point badge menu to mark start and end of the loop. 

In Loop Mode, the player will always play between start and end - timestamps in Video Mode and beats in Beat Mode. So stopping should seek to start of the loop.

- Add a menu item in the menu to mark the highlighted beat as a start or end of the loop
- Validate the end always comes after start
- Activate only when both start and end are valid
- In Beat Mode, loop will start at the first beat of the measure, end will be the last beat of the measure
- Respect count-in settings for loop
- Show an icon in the overlay to indicate Loop Active
- Use a different color for rectangle to highlight start and end of the loop
