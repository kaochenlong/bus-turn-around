## ADDED Requirements

### Requirement: Day dispatch view follows the clock

While a day is shown, the day dispatch view SHALL follow now, as "Departures at an end" defines it, without any action of the dispatcher: at every whole minute of the browser's clock, and at once when the page is shown again after being hidden, the mark and the line of now on the timeline as `day-dispatch-timeline` defines them, the departures' statuses and their line of now, and the vehicles at the selected end with the minutes they have stood SHALL be drawn for the new now. The clock SHALL NOT draw the timeline's lanes and trips anew, so a trip being dragged, selected or focused stays as it is. While the focus is in the departures, the departures SHALL stay as drawn and SHALL be drawn for now once the focus has left them; while a message about a refused change shows under one of them, they SHALL stay as drawn. The view SHALL follow the clock only while a day is shown, and leaving the page SHALL stop the clock.

#### Scenario: A minute passes

- **WHEN** a day is shown at 17:59 with the 18:00 departure from 甲站 on vehicle 1, which stands at 甲站, and the clock reaches 18:01 while the dispatcher does nothing
- **THEN** the mark of now shows 18:01, the 18:00 departure is departed with the line of now after it, and vehicle 1 is no longer listed as standing at 甲站

#### Scenario: Page shown again

- **WHEN** the page was hidden while a day showed at 17:30 and is shown again at 17:42:20
- **THEN** the mark of now shows 17:42 at once, without waiting for 17:43

#### Scenario: Focus in the departures

- **WHEN** the focus is on the vehicle menu of the 18:20 departure from 甲站 at 17:59 and the clock reaches 18:01
- **THEN** the mark of now shows 18:01, the departures stay as drawn at 17:59 with the focus still on that menu, and once the focus has left the departures the 18:00 departure is departed
