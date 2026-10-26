## MODIFIED Requirements

### Requirement: Manual edits recomputed in the browser

The two departure times of each row SHALL be editable cells. The page SHALL offer, per row, a control that deletes that row's trips, and, per sheet, a control that adds a row from a typed departure time of the sheet's first direction, whose second trip departs at the first trip's arrival plus the hold at that end. On an edit the browser SHALL recompute, without a request and storing nothing, the edited vehicle's sheet as described below, and every stop, four-hour credit and header total from the sheets as they now stand; no other vehicle's sheet SHALL change. A stop that comes out negative SHALL be shown as a negative number of minutes. A trip SHALL be marked edited when a departure different from its current one was typed, or when it belongs to an added row, until the timetable is laid out again; edited departure cells SHALL be marked on the page and counted in the header.

Every trip SHALL have an original departure and SHALL be either typed or not typed. A trip laid out from the controls SHALL NOT be typed, and its original departure SHALL be its laid-out departure. A trip whose departure the dispatcher typed into a departure cell, an add field or the add-vehicle field SHALL be typed, and its original departure SHALL be the typed time. The second trip of an added row or an added vehicle SHALL NOT be typed, and its original departure SHALL be the first trip's arrival plus the hold at that end when the row or vehicle was added. After a departure is changed, a row is deleted, a row is added or a vehicle is added, that vehicle's sheet SHALL be recomputed trip by trip in sheet order: a typed trip SHALL depart at its typed time; the first trip of the sheet, when it is not typed, SHALL depart at its original departure; any other trip that is not typed SHALL depart at the later of its original departure and the previous trip's arrival plus the hold at the end where the previous trip arrives; every arrival SHALL be the trip's departure plus the planned run time of its departure's hour. No trip SHALL depart earlier than its original departure. A trip that is not typed and departs later than its original departure SHALL be marked pushed. A pushed departure cell SHALL carry a mark distinct from the edited mark and SHALL state how many minutes later than its original departure it departs and that original departure; the header SHALL count pushed departure cells separately from edited cells, and a cell that is both SHALL count in both. Pushed marks SHALL NOT be printed.

A typed time SHALL be read as a time of the service day, with hours 00 to 29 and minutes 00 to 59, written either as one or two digits of hours, a colon and two digits of minutes, or as three or four digits without a colon whose last two digits are the minutes; spaces around it SHALL be ignored. An accepted departure SHALL be shown in its field as two digits of hours, a colon and two digits of minutes. A typed departure equal to the trip's current departure SHALL change nothing in the timetable but the field's writing, and the trip SHALL NOT be marked edited or become typed because of it. A departure field SHALL be submitted when Enter is pressed in it or when it is left, and only when something was typed into it since the page last wrote a time into it; typing the time it already shows SHALL count as typing. Pressing Enter in or leaving a departure field with nothing typed since then SHALL change nothing and SHALL NOT clear a rejection.

Editing a departure SHALL leave the keyboard focus where the dispatcher put it: after Enter the focus SHALL stay in that field, after Tab it SHALL move to the next control in the page's order, and a field or control clicked right after typing SHALL take the click. After a row is added, the focus SHALL be in that sheet's add field, which SHALL be empty.

A typed time that cannot be read SHALL be rejected. A rejected departure cell SHALL be marked invalid and keep its previous departure; a rejected add control SHALL be marked invalid and add nothing. The rejected field SHALL be marked as an error, and a message on its sheet SHALL quote the typed text, when anything was typed, and give the accepted writings; the message SHALL NOT be printed. Only the latest rejected field on the page SHALL be marked: a later rejection SHALL move the mark and the message to that field, and the next accepted typed time, the trip's current departure typed again included, deleted row, added row or vehicle, or new layout SHALL clear them. A page brought back with the browser's back button SHALL show no rejection mark or message.

#### Scenario: Changing a return departure

- **WHEN** vehicle 1's row reads 06:00, 甲站, 06:50, 40, 07:30, 08:15 and the dispatcher types 07:20 as the second departure with a planned run time of 45 minutes in the 07 hour
- **THEN** the row reads 06:00, 甲站, 06:50, 30, 07:20, 08:05, the 07:20 cell is marked edited, and the header counts 1 edited cell

#### Scenario: Typed without a colon

- **WHEN** that row reads 06:00, 甲站, 06:50, 40, 07:30, 08:15 and the dispatcher types 0720 as the second departure
- **THEN** the field reads 07:20, the row reads 06:00, 甲站, 06:50, 30, 07:20, 08:05, and the header counts 1 edited cell

#### Scenario: Same departure typed again

- **WHEN** that row's second departure is 07:30 and the dispatcher types 0730 into it
- **THEN** the field reads 07:30, the cell is not marked edited, and the header counts 0 edited cells

#### Scenario: Edit that does not connect

- **WHEN** the dispatcher types 06:45 as the second departure of that row
- **THEN** the row's first stop reads −5

#### Scenario: Pushing the return trip

- **WHEN** vehicle 1's row reads 06:00, 甲站, 06:50, 40, 07:30, 08:15, the hold at both ends is 15 minutes, the planned run time of direction 0 in the 06 hour is 50 minutes and of direction 1 in the 07 hour is 45 minutes, and the dispatcher types 06:45 as the first departure
- **THEN** the row reads 06:45, 甲站, 07:35, 15, 07:50, 08:35, the 06:45 cell is marked edited, the 07:50 cell is marked pushed and states 20 minutes and 07:30, every other sheet is unchanged, and the header counts 1 edited cell and 1 pushed cell

#### Scenario: Typing the earlier departure back

- **WHEN** that row reads 06:45, 甲站, 07:35, 15, 07:50, 08:35 after the push and the dispatcher types 06:00 as the first departure
- **THEN** the row reads 06:00, 甲站, 06:50, 40, 07:30, 08:15, no cell is marked pushed, and the header counts 1 edited cell and 0 pushed cells

#### Scenario: Same time typed into a pushed cell

- **WHEN** the 07:50 cell of that row is marked pushed and the dispatcher types 0750 into it
- **THEN** the field reads 07:50, the cell is still marked pushed and is not marked edited, and the header still counts 1 edited cell and 1 pushed cell

#### Scenario: Pushing later rows

- **WHEN** vehicle 1's sheet reads 06:00, 甲站, 06:50, 40, 07:30, 08:15, 75 and 09:30, 甲站, 10:20, 15, 10:35, 11:20, the hold at both ends is 15 minutes, direction 0 runs 50 minutes and direction 1 runs 45 minutes in every hour, and the dispatcher types a time as the first departure
- **THEN** the sheet reads as below, the typed cell is marked edited, and exactly the listed cells are marked pushed

##### Example: First departure typed

| Typed | Row 1 | Row 2 | Pushed cells |
| --- | --- | --- | --- |
| 06:10 | 06:10, 甲站, 07:00, 30, 07:30, 08:15, 75 | 09:30, 甲站, 10:20, 15, 10:35, 11:20 | none |
| 05:30 | 05:30, 甲站, 06:20, 70, 07:30, 08:15, 75 | 09:30, 甲站, 10:20, 15, 10:35, 11:20 | none |
| 07:00 | 07:00, 甲站, 07:50, 15, 08:05, 08:50, 40 | 09:30, 甲站, 10:20, 15, 10:35, 11:20 | 08:05, 35 minutes after 07:30 |
| 08:00 | 08:00, 甲站, 08:50, 15, 09:05, 09:50, 15 | 10:05, 甲站, 10:55, 15, 11:10, 11:55 | 09:05, 95 minutes after 07:30; 10:05, 35 minutes after 09:30; 11:10, 35 minutes after 10:35 |

#### Scenario: Typed departures are not pushed

- **WHEN** on that two-row sheet the dispatcher types 09:00 as row 2's first departure and then 08:00 as row 1's first departure
- **THEN** row 1 reads 08:00, 甲站, 08:50, 15, 09:05, 09:50, −50, row 2 reads 09:00, 甲站, 09:50, 45, 10:35, 11:20, the 08:00 and 09:00 cells are marked edited, and only the 09:05 cell is marked pushed

#### Scenario: Deleting a row lets later trips go back

- **WHEN** on that two-row sheet the dispatcher types 08:00 as row 1's first departure and then deletes row 1
- **THEN** the sheet has one row reading 09:30, 甲站, 10:20, 15, 10:35, 11:20 and no cell is marked pushed

#### Scenario: The return of an added row follows its first departure

- **WHEN** the dispatcher added the row 11:00, 甲站, 11:48, 15, 12:03, 12:49 to vehicle 1 as in Adding a row, with the planned run time of direction 0 in the 11 hour 48 minutes, the hold 15 minutes and the planned run time of direction 1 in the 12 hour 46 minutes, and then types 11:30 as that row's first departure
- **THEN** that row reads 11:30, 甲站, 12:18, 15, 12:33, 13:19, both its departure cells are marked edited, the 12:33 cell is also marked pushed and states 30 minutes and 12:03, and the header counts 2 edited cells and 1 pushed cell

#### Scenario: Focus after Enter

- **WHEN** the dispatcher types 0720 as that row's second departure and presses Enter
- **THEN** the field reads 07:20, the row's first stop reads 30, and the focus is still in that field

#### Scenario: Focus after Tab

- **WHEN** the dispatcher types 0605 as that row's first departure and presses Tab
- **THEN** the field reads 06:05 and the focus is in the same row's second departure field

#### Scenario: Clicking another field right after typing

- **WHEN** the dispatcher types 0720 as that row's second departure and then clicks the row's first departure field
- **THEN** the second departure reads 07:20 and the focus is in the first departure field

#### Scenario: Deleting a row

- **WHEN** a sheet has rows departing 06:00 and 08:30 and the dispatcher deletes the first row
- **THEN** the sheet has one row numbered 1 departing 08:30

#### Scenario: Adding a row

- **WHEN** the dispatcher adds a row to vehicle 1 with the departure 11:00, the planned run time of direction 0 in the 11 hour is 48 minutes, the hold at that end is 15 minutes and the planned run time of direction 1 in the 12 hour is 46 minutes
- **THEN** the sheet gains a row 11:00, 甲站, 11:48, 15, 12:03, 12:49 with both departure cells marked edited

#### Scenario: Focus after adding a row

- **WHEN** the dispatcher types 1100 into vehicle 1's add field and presses Enter
- **THEN** the sheet gains the row departing 11:00, and the focus is in vehicle 1's add field, which is empty

#### Scenario: Malformed time

- **WHEN** a departure time is typed as `25:70`
- **THEN** the cell is marked invalid and keeps its previous departure, the field is marked as an error, a message on its sheet quotes `25:70` and gives the accepted writings, and no time, stop or header total changes

#### Scenario: Rejection cleared by the next accepted time

- **WHEN** vehicle 1's second departure was rejected as `23:70` and the dispatcher then types 0605 as the row's first departure
- **THEN** no field on the page is marked as an error and the message is gone

#### Scenario: Rejection cleared by the same time typed again

- **WHEN** vehicle 1's second departure was rejected as `23:70` and reads 07:30 again, and the dispatcher types 07:30 into it and presses Enter or Tab
- **THEN** no field on the page is marked as an error and the message is gone

#### Scenario: Enter with nothing typed

- **WHEN** vehicle 1's second departure was rejected as `23:70` and the dispatcher presses Enter in vehicle 2's first departure field without typing
- **THEN** vehicle 1's second departure field is still marked as an error and its message stays

#### Scenario: Leaving a field after its rejection

- **WHEN** the dispatcher types 0720 as vehicle 1's second departure and presses Enter, then types `23:70` and presses Enter, and then presses Tab
- **THEN** the field is still marked as an error and the message still quotes `23:70`

#### Scenario: Reading a typed time

- **WHEN** a time is typed into a departure field, an add field or the add-vehicle field
- **THEN** it is accepted as minutes of the service day and shown in the departure field as below, or rejected

##### Example: Typed times

| Typed | Accepted as | Shown as | Notes |
| --- | --- | --- | --- |
| 06:00 | 360 minutes | 06:00 | |
| 6:00 | 360 minutes | 06:00 | one-digit hour |
| 0600 | 360 minutes | 06:00 | no colon |
| 600 | 360 minutes | 06:00 | three digits: one-digit hour |
| 24:45 | 1485 minutes | 24:45 | after midnight, same service day |
| 2445 | 1485 minutes | 24:45 | no colon, after midnight |
| 23:70 | rejected | | minutes above 59 |
| 25:70 | rejected | | minutes above 59 |
| 2370 | rejected | | minutes above 59 |
| 30:00 | rejected | | hours above 29 |
| 60 | rejected | | two digits are not a time |
| 06:0 | rejected | | minutes need two digits |
| 12345 | rejected | | more than four digits |

### Requirement: Header, controls and limitations of the timetable

The page SHALL show, before the sheets: the route name; the covered days and their day type as the route page states them; the average number of distinct vehicles per covered day as `buffer-trade` reports it; the number of vehicles of the timetable and the number of departures per direction, recomputed from the sheets as shown; the number of manually edited cells; and the number of pushed cells, counted as in "Manual edits recomputed in the browser". It SHALL show controls for the percentile, the rest minutes and the departures per direction and hour, filled with the values in use, and next to the controls the statement that changing them lays the timetable out again and discards manual edits. Changing a control SHALL lay the timetable out again in the browser without a request. After the sheets and the overrun table, the page SHALL state the limitations of the timetable: a sheet is a vehicle and not a driver; planned run times are measured percentiles, not guarantees; the hold at a pass-through end is the measured median and is not rest; a negative stop means a typed departure leaves before the previous trip's arrival, while departures that were not typed are pushed later to keep the hold at that end; trips missing a terminal are left out of run times; the default departures are the measured average and include every trip. The page SHALL carry the attribution footer of `site-layout`. The document title SHALL carry the route name, the word 班表 and the site name.

#### Scenario: Header content

- **WHEN** the timetable of route 9001 for 2026-10-19 is laid out with defaults from the four-departure day
- **THEN** the header shows the route name, 2026-10-19 with its day type, the vehicles per day of the covered days, 3 vehicles, 2 departures in each direction, 0 edited cells and 0 pushed cells, and the controls read p 85, 15 rest minutes and the measured departures

#### Scenario: Regeneration in the browser

- **WHEN** the dispatcher changes the departures of direction 0 in hour 6 from 2 to 1 on the four-departure day
- **THEN** without a request the page shows 2 vehicles, 1 departure in direction 0 and 2 in direction 1, and the statement that changing the controls discards manual edits is present next to the controls

#### Scenario: Attribution on the timetable page

- **WHEN** `/routes/9001/timetable` is requested
- **THEN** exactly one `footer[data-attribution][data-license="OGDL-Taiwan-1.0"]` is present

#### Scenario: Limitation of negative stops

- **WHEN** `/routes/9001/timetable` is requested
- **THEN** the limitations state that a negative stop means a typed departure leaves before the previous trip's arrival and that departures that were not typed are pushed later to keep the hold at that end
