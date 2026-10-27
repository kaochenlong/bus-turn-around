# day-dispatch-record Specification

## Purpose

Let a dispatcher keep the day dispatch of the `day-dispatch` capability outside the browser: print it as a record of what changed and the resulting paper trip sheets, and export its change log and its sheets as files the operator can store, so the record survives cleared browser data or another computer. The files are made in the browser; nothing is sent to the server.

## Requirements

### Requirement: Printing the day record

The day dispatch view SHALL offer a control that opens the browser's print dialog for the day record. The day record SHALL print, in this order: first a summary page with the route name, the date, what the day was laid out from (the covered days with their day type, the percentile and the rest minutes), a line saying that the recorded arrivals, vehicle changes and typed departures were entered by the dispatcher and not measured, the figures of the day dispatch, every vehicle's rest in the tightest four hours with its planned value, labelled as what one person would get driving the whole sheet and printed as numbers only, without marking anything as compliant or non-compliant, and every change of the change log with the time it was recorded, what it did and its reason, undone changes included and marked as undone; then one sheet per vehicle, in vehicle number order and each on a page of its own, in the paper trip sheet layout the timetable capability prints, with the day's current trips and a line naming the date and what the day was laid out from, its times written as the timetable's printed sheets write them, so that a time past midnight prints as the next day's time; then, on a page of their own, the day record's data limitations and the attribution footer. The data limitations SHALL say that the recorded arrivals, vehicle changes and typed departures were entered by the dispatcher and not measured, that a sheet is a vehicle and not a driver, that the planned run times are measured percentiles and not guarantees, and how times past midnight are written on paper and in the exported files. The view's header, figures, timeline, departures panel, forms and controls SHALL NOT be printed, and the summary page, the sheets and the data limitations of the day record SHALL NOT show on screen. The print styles SHALL use a page of their own, so that printing the timetable and the other pages is unchanged.

#### Scenario: Order of the printed record

- **WHEN** the dispatcher prints a day dispatch of two vehicles with three changes, the last of them undone
- **THEN** the print shows first the summary with the three changes and the last one marked as undone, then vehicle 1's sheet and vehicle 2's sheet on pages of their own, then the data limitations and the attribution footer, and no control of the view, on four pages in all

#### Scenario: Nothing of the record on screen

- **WHEN** the day dispatch view shows a day
- **THEN** the summary page, the sheets and the data limitations of the day record are not visible, and the view's header, figures and timeline are


<!-- @trace
source: 03-day-dispatch-record
updated: 2026-10-27
code:
  - app/components/day_record_limitations_component.rb
  - app/frontend/timetable/day_page.js
  - app/views/timetables/show.html.erb
  - app/frontend/stylesheets/application.css
  - app/frontend/timetable/day_record.js
  - app/components/day_dispatch_component.yml
  - app/frontend/timetable/component.js
  - app/components/day_dispatch_component.html.erb
  - app/components/day_record_limitations_component.yml
  - app/components/day_dispatch_component.rb
  - app/frontend/timetable/day_view.js
  - app/components/timetable_sheet_component.rb
  - README.md
  - app/frontend/timetable/format.js
  - app/components/day_record_limitations_component.html.erb
  - app/frontend/timetable/sheet_view.js
  - app/frontend/timetable/day_timeline_view.js
tests:
  - spec/system/timetable_day_timeline_spec.rb
  - app/frontend/timetable/format.test.js
  - spec/components/day_dispatch_component_spec.rb
  - app/frontend/timetable/day_record.test.js
  - spec/system/timetable_day_record_spec.rb
  - spec/components/timetable_sheet_component_spec.rb
-->

---
### Requirement: Marks on the printed sheets

On a printed sheet, the departure of a trip whose vehicle differs from its planned vehicle SHALL carry ＊, the arrival of a trip with a recorded arrival SHALL carry †, and the departure of a typed trip SHALL carry ‡, each mark right after the time and ＊ before ‡ in the same cell. Under each sheet, notes SHALL explain every mark of that sheet, one note per line: the ＊ trips planned on the same vehicle share one note that lists their departures and names that vehicle; each † has a note naming the planned arrival and each ‡ a note naming the departure before it was typed; the ＊ notes come first, then the † notes, then the ‡ notes, each in time order. A sheet without marks SHALL have no notes. The marks SHALL NOT depend on colour.

#### Scenario: Notes under the sheets

- **WHEN** vehicle 10 runs the 17:40 departure planned on vehicle 8, and vehicle 8's 16:00 trip has a recorded arrival of 17:52 against a planned 17:14
- **THEN** vehicle 10's sheet marks the 17:40 departure with ＊ and notes that it was planned on vehicle 8, and vehicle 8's sheet marks the 17:52 arrival with † and notes that 17:14 was planned

##### Example: Grouped notes

- **GIVEN** vehicle 8 runs the 18:10, 19:40, 21:20 and 23:00 departures planned on vehicle 10, its 16:00 trip has a recorded arrival of 17:52 against a planned 17:14, and its 18:10 departure was typed from 18:00
- **WHEN** vehicle 8's sheet is printed
- **THEN** its departure cells read 18:10＊‡, 19:40＊, 21:20＊ and 23:00＊, its arrival cell reads 17:52†, and its notes read, in this order: "＊ 18:10、19:40、21:20、23:00 原排 10 號車", "† 17:52 是記下的回到時刻，原定 17:14", "‡ 18:10 改過，原本 18:00"


<!-- @trace
source: 03-day-dispatch-record
updated: 2026-10-27
code:
  - app/components/day_record_limitations_component.rb
  - app/frontend/timetable/day_page.js
  - app/views/timetables/show.html.erb
  - app/frontend/stylesheets/application.css
  - app/frontend/timetable/day_record.js
  - app/components/day_dispatch_component.yml
  - app/frontend/timetable/component.js
  - app/components/day_dispatch_component.html.erb
  - app/components/day_record_limitations_component.yml
  - app/components/day_dispatch_component.rb
  - app/frontend/timetable/day_view.js
  - app/components/timetable_sheet_component.rb
  - README.md
  - app/frontend/timetable/format.js
  - app/components/day_record_limitations_component.html.erb
  - app/frontend/timetable/sheet_view.js
  - app/frontend/timetable/day_timeline_view.js
tests:
  - spec/system/timetable_day_timeline_spec.rb
  - app/frontend/timetable/format.test.js
  - spec/components/day_dispatch_component_spec.rb
  - app/frontend/timetable/day_record.test.js
  - spec/system/timetable_day_record_spec.rb
  - spec/components/timetable_sheet_component_spec.rb
-->

---
### Requirement: Exporting the change log

The day dispatch view SHALL offer a control that downloads the change log as a CSV file named `day-dispatch-<route Id>-<YYYY-MM-DD>-changes.csv`. The file SHALL be UTF-8 starting with a byte order mark, with CRLF line ends and a header row, and SHALL have one row per change in the order recorded, with the time recorded in Taipei time as `YYYY-MM-DD HH:MM`, the kind (recorded arrival, vehicle change or typed departure), the vehicle the change is about, the trip as its direction and departure, the vehicle a departure was given to (vehicle changes only), the recorded arrival or the typed departure (blank for vehicle changes), the reason, and whether it is undone. A field holding a comma, a double quote or a line break SHALL be quoted as RFC 4180 requires. Times SHALL be written as the timetable page writes service-day times, so that 24:07 stays 24:07.

#### Scenario: Two changes exported

- **WHEN** route 11764's day of 2026-10-27 has a recorded arrival of vehicle 8 at 17:52 with the reason 塞車 and then a vehicle change that was undone, and the dispatcher exports the change log
- **THEN** the file `day-dispatch-11764-2026-10-27-changes.csv` starts with a byte order mark and a header row, its first row is the recorded arrival with 17:52 and 塞車 and not undone, and its second row is the vehicle change marked as undone

##### Example: Reason with a comma

- **GIVEN** a recorded arrival whose reason is 塞車,事故
- **WHEN** the change log is exported
- **THEN** that row's reason field is written as "塞車,事故"


<!-- @trace
source: 03-day-dispatch-record
updated: 2026-10-27
code:
  - app/components/day_record_limitations_component.rb
  - app/frontend/timetable/day_page.js
  - app/views/timetables/show.html.erb
  - app/frontend/stylesheets/application.css
  - app/frontend/timetable/day_record.js
  - app/components/day_dispatch_component.yml
  - app/frontend/timetable/component.js
  - app/components/day_dispatch_component.html.erb
  - app/components/day_record_limitations_component.yml
  - app/components/day_dispatch_component.rb
  - app/frontend/timetable/day_view.js
  - app/components/timetable_sheet_component.rb
  - README.md
  - app/frontend/timetable/format.js
  - app/components/day_record_limitations_component.html.erb
  - app/frontend/timetable/sheet_view.js
  - app/frontend/timetable/day_timeline_view.js
tests:
  - spec/system/timetable_day_timeline_spec.rb
  - app/frontend/timetable/format.test.js
  - spec/components/day_dispatch_component_spec.rb
  - app/frontend/timetable/day_record.test.js
  - spec/system/timetable_day_record_spec.rb
  - spec/components/timetable_sheet_component_spec.rb
-->

---
### Requirement: Exporting the day's sheets

The day dispatch view SHALL offer a separate control that downloads the day's current sheets as a CSV file named `day-dispatch-<route Id>-<YYYY-MM-DD>-sheets.csv`, with the same encoding, line ends, header row and quoting as the change log, and one row per trip in vehicle number order and sheet order, with the vehicle, the direction, the first stop, the departure, the arrival, whether the arrival is recorded, the planned vehicle, whether the departure was typed, and the departure of the day plan.

#### Scenario: A changed trip in the sheets file

- **WHEN** vehicle 10 runs the 17:40 departure planned on vehicle 8 and the dispatcher exports the sheets
- **THEN** the file has a row for vehicle 10 with the 17:40 departure and vehicle 8 as its planned vehicle, among one row per trip of the day


<!-- @trace
source: 03-day-dispatch-record
updated: 2026-10-27
code:
  - app/components/day_record_limitations_component.rb
  - app/frontend/timetable/day_page.js
  - app/views/timetables/show.html.erb
  - app/frontend/stylesheets/application.css
  - app/frontend/timetable/day_record.js
  - app/components/day_dispatch_component.yml
  - app/frontend/timetable/component.js
  - app/components/day_dispatch_component.html.erb
  - app/components/day_record_limitations_component.yml
  - app/components/day_dispatch_component.rb
  - app/frontend/timetable/day_view.js
  - app/components/timetable_sheet_component.rb
  - README.md
  - app/frontend/timetable/format.js
  - app/components/day_record_limitations_component.html.erb
  - app/frontend/timetable/sheet_view.js
  - app/frontend/timetable/day_timeline_view.js
tests:
  - spec/system/timetable_day_timeline_spec.rb
  - app/frontend/timetable/format.test.js
  - spec/components/day_dispatch_component_spec.rb
  - app/frontend/timetable/day_record.test.js
  - spec/system/timetable_day_record_spec.rb
  - spec/components/timetable_sheet_component_spec.rb
-->

---
### Requirement: Day record files built in the browser

Printing and both exports SHALL be made in the browser from the day kept by `day-dispatch`, and SHALL NOT send anything about the day to the server. The two exports SHALL be two controls, each starting one download.

#### Scenario: Export without a request

- **WHEN** the dispatcher exports the change log
- **THEN** the download link carries the file name and a blob address, and the page sends no request to the server

<!-- @trace
source: 03-day-dispatch-record
updated: 2026-10-27
code:
  - app/components/day_record_limitations_component.rb
  - app/frontend/timetable/day_page.js
  - app/views/timetables/show.html.erb
  - app/frontend/stylesheets/application.css
  - app/frontend/timetable/day_record.js
  - app/components/day_dispatch_component.yml
  - app/frontend/timetable/component.js
  - app/components/day_dispatch_component.html.erb
  - app/components/day_record_limitations_component.yml
  - app/components/day_dispatch_component.rb
  - app/frontend/timetable/day_view.js
  - app/components/timetable_sheet_component.rb
  - README.md
  - app/frontend/timetable/format.js
  - app/components/day_record_limitations_component.html.erb
  - app/frontend/timetable/sheet_view.js
  - app/frontend/timetable/day_timeline_view.js
tests:
  - spec/system/timetable_day_timeline_spec.rb
  - app/frontend/timetable/format.test.js
  - spec/components/day_dispatch_component_spec.rb
  - app/frontend/timetable/day_record.test.js
  - spec/system/timetable_day_record_spec.rb
  - spec/components/timetable_sheet_component_spec.rb
-->