## Purpose

Make a timeline of every vehicle's day the main view of the day dispatch, with the departures of the `day-dispatch` capability beside it as a panel for detailed changes, so that a dispatcher sees at once how a vehicle change or a late return reshapes the rest of the day and can make the change by dragging, by keyboard or by touch. Every change goes through the rules of `day-dispatch`; this capability adds no rule of its own.

## ADDED Requirements

### Requirement: Timeline of the day dispatch

Starting or continuing a day dispatch SHALL show a timeline as its main view. The timeline SHALL have one lane per vehicle in vehicle number order and one time axis shared by every lane, running from the whole hour at or before the earliest departure to the whole hour after the latest arrival, recorded arrivals included, with times after midnight counted on from 24:00. Every trip SHALL be drawn on its current vehicle's lane from its departure to its arrival, the two directions told apart by lightness and named in a legend. A stop at a stopping end SHALL be labelled with its whole minutes where the gap between the two trips holds the label, and always when it is shorter than 15 minutes. A recorded arrival later than planned SHALL be drawn as an extension from the planned to the recorded arrival, labelled with the minutes late. A trip whose current vehicle differs from its planned vehicle SHALL be outlined, and its lane SHALL say from which departure it runs which vehicle's trips. A trip whose departure was typed SHALL be marked as typed. A mark on the time axis and a line across the lanes SHALL show now. Every lane SHALL end with the rest in the tightest four hours of its trips as `day-dispatch` defines it, with the planned value beside it when the two differ.

#### Scenario: Axis of the day

- **WHEN** the earliest departure of the day is 05:00 and the latest arrival is 24:56
- **THEN** the time axis runs from 05:00 to 25:00 and every lane uses it

#### Scenario: Late return and vehicle change on the timeline

- **WHEN** vehicle 8's 16:00 trip has a recorded arrival of 17:52 against a planned 17:14 and the 17:40 departure was given to vehicle 10
- **THEN** vehicle 8's lane draws an extension from 17:14 to 17:52 labelled 38 minutes late, the trips that changed vehicle are outlined, vehicle 8's lane says it runs vehicle 10's trips from 18:00 and vehicle 10's lane says it runs vehicle 8's trips from 17:40

#### Scenario: Short stop always labelled

- **WHEN** vehicle 10 arrives at the stopping end at 17:34 and departs from it again at 17:40
- **THEN** vehicle 10's lane labels that stop with 6 minutes

### Requirement: Departures panel below the timeline

The departures, vehicles and arrival form of `day-dispatch` SHALL be shown in a panel below the timeline, the timeline taking the whole width above it, and the departures SHALL open from the start at the end `day-dispatch` lists first, scrolled to their next departure. Selecting a trip on the timeline SHALL move the panel to the end that trip departs from and scroll it to that departure. Selecting the mark of now on the time axis SHALL move the panel to the end listed first and scroll it to its next departure. The departures SHALL scroll inside their own frame, so that moving the panel to a departure leaves the page where it is. The change log and its undo control SHALL follow the timeline.

#### Scenario: Selecting a trip moves the panel

- **WHEN** the panel lists 甲站 and the dispatcher selects vehicle 2's 18:05 trip that departs from 乙站
- **THEN** the panel lists the departures from 乙站 and shows the 18:05 departure

#### Scenario: Mark of now moves the panel back

- **WHEN** the panel lists 乙站 after the dispatcher selected a trip departing from 乙站, and the dispatcher selects the mark of now
- **THEN** the panel lists the departures from 甲站, the end listed first, and shows its next departure

### Requirement: Dragging a trip onto another vehicle's lane

Dropping a trip of vehicle A on vehicle B's lane SHALL have the same effect as giving that trip's departure to vehicle B in the panel, under the rule and the conditions of `day-dispatch`, so that the two vehicles exchange their trips from that departure onward. While the trip is dragged over a lane, that lane SHALL mark the trips that the change would exchange. When `day-dispatch` refuses the change, the trip SHALL return to its place and the lane SHALL show the message `day-dispatch` gives, announced to screen readers. Dragging SHALL start only for a mouse or a pen, not for touch.

#### Scenario: Drop on a vehicle at the same end

- **WHEN** the dispatcher drops vehicle 1's 17:40 departure from 甲站 on vehicle 2's lane and vehicle 2's first trip at or after 17:40 leaves from 甲站
- **THEN** the day is the same as after giving the 17:40 departure to vehicle 2 in the panel, and the change log lists one vehicle change

#### Scenario: Drop on a vehicle at the other end

- **WHEN** the dispatcher drops vehicle 1's 17:40 departure on vehicle 3's lane and vehicle 3's first trip at or after 17:40 leaves from 乙站
- **THEN** the trip returns to vehicle 1's lane, vehicle 3's lane says that vehicle 3 next leaves from 乙站, and the change log is unchanged

### Requirement: Dragging a trip along its lane

Dragging a trip along its own lane SHALL show, while dragging, the whole minute under the pointer, held within the time axis. Dropping it SHALL type that minute as the trip's departure under the rule of `day-dispatch`, so that only that trip changes and its arrival follows the planned run time of the new departure's hour. Dragging SHALL start only for a mouse or a pen, not for touch.

#### Scenario: Drop ten minutes later

- **WHEN** the planned run time of direction 0 in the 18 hour is 57 minutes and the dispatcher drags vehicle 1's 18:00 trip along its lane and drops it where the pointer shows 18:10
- **THEN** that trip departs at 18:10 and arrives at 19:07, it is marked as typed, and no other trip changes

### Requirement: Actions on a selected trip

Every trip on the timeline SHALL be a control that the keyboard reaches in order of departure. Pressing Enter on it, or tapping it on a touch screen, SHALL open three actions for it: give its departure to another vehicle, type its departure, and record its vehicle's arrival at the end it heads to. Each action SHALL have the same effect, the same refusals and the same wording as the matching control of the panel.

#### Scenario: Vehicle change by keyboard

- **WHEN** the dispatcher reaches vehicle 1's 17:40 trip with Tab, presses Enter, chooses to give it to another vehicle and picks vehicle 2
- **THEN** the day is the same as after dropping that trip on vehicle 2's lane

### Requirement: Scrolling many vehicles

When the lanes do not fit, the timeline SHALL scroll vertically inside its own frame, and the time axis and the mark of now SHALL stay visible at the top of the frame while the lanes scroll. When the time axis does not fit the width of the frame, the timeline SHALL scroll sideways inside the frame with the vehicle numbers kept in view, and SHALL open scrolled so that now is in view.

#### Scenario: Twenty-two lanes

- **WHEN** a day dispatch has 22 vehicles and the dispatcher scrolls the timeline to its last lane
- **THEN** the last lane is shown and the time axis is still shown at the top of the frame

#### Scenario: Narrow screen opens at now

- **WHEN** the page is 390 pixels wide and now is 17:55
- **THEN** the timeline opens with the 17:55 mark of now and the vehicle numbers in view
