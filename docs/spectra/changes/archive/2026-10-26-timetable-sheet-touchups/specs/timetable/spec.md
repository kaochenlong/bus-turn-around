## MODIFIED Requirements

### Requirement: One sheet per vehicle with round-trip rows

The page SHALL show one sheet per vehicle, in vehicle number order, each sheet marked with its vehicle number and titled 車次 followed by that number: the run number the paper trip sheet carries in its top left corner, one per sheet. The rows of a sheet SHALL pair the vehicle's consecutive trips: the first and second trip form row 1, the third and fourth row 2, and so on; a last trip without a following trip SHALL form a row on its own. The columns SHALL follow the paper trip sheet, in order: driver number, driver name, the departure time of the first trip, the name of that trip's first stop, dispatcher, the arrival time of the first trip, the stop in whole minutes from that arrival to the second trip's departure, the departure time of the second trip, accumulated mileage, the arrival time of the second trip, the stop in whole minutes from that arrival to the next row's first departure (blank on the last row), trip mileage, and dispatcher again. The driver number, driver name, dispatcher and mileage cells SHALL be blank for filling in by hand, and rows SHALL carry no row number. On screen every row SHALL start with the control that deletes it, followed by its times, its first stop's name and its stops in the paper's order; the hand-filled columns SHALL NOT be shown on screen and SHALL be printed as described in "Printing the timetable". On a row of a single trip the second trip's departure, arrival and the first stop SHALL be blank. A time on or after 24:00 SHALL be shown as the next day's time. A trip marked as using the all-day run time SHALL be marked on its row. The page SHALL NOT contain any vehicle identifier from the data.

#### Scenario: Rows of vehicle 1

- **WHEN** vehicle 1 runs direction 0 from 甲站 06:00 to 06:50 and direction 1 from 乙站 07:30 to 08:15 and has no further trip
- **THEN** its sheet is titled 車次 1 and has one row whose time and stop cells read 06:00, 甲站, 06:50, 40, 07:30, 08:15 and a blank last stop, with the hand-filled cells blank

#### Scenario: Trailing single trip

- **WHEN** vehicle 3's only trip runs direction 1 from 乙站 07:00 to 07:45
- **THEN** its sheet has one row whose time and stop cells read 07:00, 乙站, 07:45 and blank second-trip cells

#### Scenario: Time past midnight

- **WHEN** a trip departs at 23:40 with a planned run time of 50 minutes
- **THEN** its arrival is shown as the next day's 00:30

#### Scenario: Hand-filled columns on screen

- **WHEN** the sheets are laid out and shown on screen
- **THEN** no driver number, driver name, dispatcher or mileage cell is shown, and the first cell of every row holds the control that deletes that row

### Requirement: Manual edits recomputed in the browser

The two departure times of each row SHALL be editable cells. The page SHALL offer, per row, a control that deletes that row's trips, and, per sheet, a control that adds a row from a typed departure time of the sheet's first direction, whose second trip departs at the first trip's arrival plus the hold at that end. On an edit the browser SHALL recompute, without a request and storing nothing, every arrival, stop, four-hour credit and header total from the departures as they now stand, leaving every other departure time unchanged. A stop that comes out negative SHALL be shown as a negative number of minutes. A trip SHALL be marked edited when a departure different from its current one was typed, or when it belongs to an added row, until the timetable is laid out again; edited departure cells SHALL be marked on the page and counted in the header.

A typed time SHALL be read as a time of the service day, with hours 00 to 29 and minutes 00 to 59, written either as one or two digits of hours, a colon and two digits of minutes, or as three or four digits without a colon whose last two digits are the minutes; spaces around it SHALL be ignored. An accepted departure SHALL be shown in its field as two digits of hours, a colon and two digits of minutes. A typed departure equal to the trip's current departure SHALL change nothing in the timetable but the field's writing, and the trip SHALL NOT be marked edited because of it. A departure field SHALL be submitted when Enter is pressed in it or when it is left, and only when something was typed into it since the page last wrote a time into it; typing the time it already shows SHALL count as typing. Pressing Enter in or leaving a departure field with nothing typed since then SHALL change nothing and SHALL NOT clear a rejection.

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

### Requirement: Adding a vehicle

Below the sheets the page SHALL offer a control that adds a vehicle from a chosen direction and a typed departure time: a new sheet numbered one above the highest vehicle number on the page, whose first trip departs in the chosen direction at the typed time and whose second trip departs at the first trip's arrival plus the hold at that end, both marked edited. The added vehicle SHALL count in the header's totals and SHALL take further rows through its own add control like any sheet. The typed time SHALL be read as in "Manual edits recomputed in the browser". After a vehicle is added, the add-vehicle field SHALL be empty and SHALL have the focus. A typed time that cannot be read SHALL be rejected as for an added row: the control is marked invalid, nothing is added, the field is marked as an error, and a message beside the control quotes the typed text, when anything was typed, and gives the accepted writings, cleared like the other rejection marks. Laying the timetable out again from the controls SHALL discard added vehicles like other manual edits. Without JavaScript the control SHALL be hidden.

#### Scenario: Adding a vehicle

- **WHEN** the four-departure timetable shows vehicles 1 to 3 and the dispatcher adds a vehicle in direction 1 at 15:00, the planned run time of direction 1 in the 15 hour is 45 minutes, the hold at that end is 15 minutes and the planned run time of direction 0 in the 16 hour is 50 minutes
- **THEN** a sheet 4 appears with one row 15:00, 乙站, 15:45, 15, 16:00, 16:50, both departure cells marked edited, and the header counts 4 vehicles and 2 edited cells

#### Scenario: Adding a vehicle typed without a colon

- **WHEN** the four-departure timetable shows vehicles 1 to 3 and the dispatcher adds a vehicle in direction 1 typed as 1500
- **THEN** a sheet 4 appears as for 15:00, and the add-vehicle field is empty and has the focus

#### Scenario: Rejected vehicle time

- **WHEN** the dispatcher adds a vehicle with the time typed as `25:70`
- **THEN** the control is marked invalid, the header still counts 3 vehicles, and a message beside the control quotes `25:70` and gives the accepted writings

#### Scenario: Rejected vehicle time after coming back

- **WHEN** the dispatcher adds a vehicle with the time typed as `25:70`, leaves for the home page and comes back with the browser's back button
- **THEN** no message beside the add-vehicle control is shown and nothing on the page is marked as an error or invalid

#### Scenario: Numbering after a deleted vehicle

- **WHEN** vehicle 2's only row was deleted so the page shows vehicles 1 and 3, and the dispatcher adds a vehicle
- **THEN** the new sheet is vehicle 4

### Requirement: Printing the timetable

The page SHALL carry print styles under which each vehicle's sheet is printed as a form like the paper trip sheet, on a page of its own: a title line with blanks for the company and the depot and the route name; a line with 車次 and the sheet's number, a blank 車號 for filling in by hand, and blanks for the year, month, day and weekday; a line naming what the sheet was laid out from (the covered day or days with their day type, the percentile and the rest minutes in use); and the table with all the paper trip sheet's columns, including the hand-filled ones that are not shown on screen, ruled lines around every cell, rows tall enough to write in, and blank rows added after the trips until the sheet has at least 14 rows. The page's header, the sheet's on-screen title, the site name bar, the controls, the regeneration statement, the print control, the add-vehicle control, the edit controls, the messages about rejected times and the typed-time fields are not printed; departure times are printed as text; a row is not split across pages; and the overrun table, the limitations and the attribution footer follow on a page of their own after the last sheet. The blank rows SHALL NOT be shown on screen. The print styles SHALL break pages with both the `break-*` and the older `page-break-*` properties, so that Safari breaks them too, and SHALL lay the pages out landscape by default. The page SHALL offer a print control that opens the browser's print dialog.

#### Scenario: Print control

- **WHEN** the timetable page is opened and the sheets are laid out
- **THEN** a print control is visible and activating it calls the browser's print function

#### Scenario: One vehicle per printed page

- **WHEN** the page is printed with three vehicles laid out from the four-departure day of 2026-10-19 at p85 with 15 rest minutes
- **THEN** each of the three sheets ends with a page break, each is headed by the form's title with the route name, 車次 and its number, a blank 車號, the date blanks and the line with 2026-10-19, its day type, p85 and 15 rest minutes, each prints at least 14 rows of which the blank ones are not shown on screen, the page's header is not printed, and the overrun table, the limitations and the footer are printed after the last sheet on a page of their own

#### Scenario: Hand-filled columns printed

- **WHEN** the page is printed
- **THEN** every sheet prints the driver number, driver name, dispatcher and mileage columns in the paper's order, blank, and no delete control and no message about a rejected time is printed
