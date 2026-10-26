# stop-to-stop-speed Specification

## Purpose

Measure how fast buses move between adjacent stops of a route from the vehicles' GPS reports placed on the route shape registered by 臺北市公共運輸處, store it per trip, and show it on the route page as a grid of shaded cells per direction and time band, so that a reader sees which part of the route is slowest and at what time of day. It measures vehicles, not drivers, and leaves out the stretch around each stop where buses brake, stop and pull away.

## Requirements

### Requirement: Stop position along the route shape

For each route day the system SHALL place every stop of the page route on the route shape of its direction for that day, as defined by `route-shape`, at the metres along the shape from the shape's first point. Coordinates SHALL be turned into plane metres with the Earth radius of 6,371,000 metres, the longitude scaled by the cosine of the mean latitude of the direction's shape points. The stops of a direction SHALL be placed in sequence order: a stop's position is the nearest point of the shape at or after the position of the last placed stop of the direction, the first stop searching the whole shape, and among the candidate points no more than `stop_tie_meters` (15) farther than the nearest one, the point earliest along the shape SHALL be taken. A stop whose nearest point is more than `shape_snap_meters` (50) away SHALL have no position, and so SHALL every stop of a member route and every stop of a direction without a shape that day. A leg SHALL be the part of a direction between two consecutive stops that have positions, identified by the sequence number of its first stop; a stop without a position SHALL be passed over, so the leg before it runs to the next placed stop.

#### Scenario: Fixture stops placed

- **WHEN** route 9001 on the fixture day 2026-10-19 is analysed with the fixture route shapes file
- **THEN** outbound stops 91000 to 91004 are at 0.0, 278.0, 556.0, 834.0 and 1111.9 metres, inbound stops 91005 to 91009 are at the same five values, the outbound legs are 0, 1, 2 and 3 and the inbound legs are 5, 6, 7 and 8

#### Scenario: Stop too far from the shape

- **WHEN** a direction's shape bends away so that one of its stops is more than 50 metres from it
- **THEN** that stop has no position and one leg runs from the stop before it to the stop after it

##### Example: outbound shape bent 60 metres east at 丙站

- **GIVEN** a route shapes file built in the test whose outbound row is `LINESTRING (121.5 25.05, 121.5 25.0525, 121.500596 25.055, 121.5 25.0575, 121.5 25.06)`, so 丙站 (25.055, 121.5) is 58.7 metres from the shape
- **WHEN** route 9001 on 2026-10-19 is analysed with it
- **THEN** 91002 has no position, 91000, 91001, 91003 and 91004 are at 0.0, 278.0, 846.8 and 1124.8 metres, and the outbound legs are 0, 1 and 3, leg 1 running from 91001 to 91003

#### Scenario: Stop near two passes of the shape

- **WHEN** a direction's shape passes a stop twice and the stop is nearer the later pass by less than 15 metres
- **THEN** the stop is placed on the earlier pass

##### Example: stop between the outbound and the return pass

- **GIVEN** a shape built in the test that runs north along longitude 121.5 from 25.05 to 25.06, 20 metres east, and back south to 25.05, and a stop 12 metres east of the northbound line, 8 metres from the southbound one
- **WHEN** the stops are placed
- **THEN** that stop is placed on the northbound line, at the metres of its latitude from 25.05, and the stops after it are placed after it


<!-- @trace
source: stop-to-stop-speed
updated: 2026-10-26
code:
  - app/components/stop_speed_grid_component.rb
  - app/components/data_limitations_component.yml
  - analysis/README.md
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - spec/fixtures/analysis/README.md
  - app/models/trip_stop_speed.rb
  - analysis/gps_reports.sql
  - analysis/stop_speeds.sql
  - app/components/stop_speed_grid_component.yml
  - docs/data-sources.md
  - analysis/turnaround_facilities.sql
  - app/models/raw_day_check.rb
  - analysis/derived_export.sql
  - app/models/end_nature_survey_command.rb
  - analysis/params.sql
  - db/schema.rb
  - app/models/route_day_loader.rb
  - analysis/40_load_profile.sql
  - app/models/route_day_stop.rb
  - app/models/trip.rb
  - docs/decisions.md
  - app/views/routes/show.html.erb
  - db/migrate/20261026054634_create_trip_stop_speeds.rb
  - app/components/stop_speed_grid_component.html.erb
  - app/models/route_page/stop_speeds.rb
tests:
  - spec/requests/routes_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/analysis/end_nature_export_spec.rb
  - spec/components/stop_speed_grid_component_spec.rb
  - spec/analysis/end_nature_evidence_spec.rb
  - spec/analysis/gps_reports_spec.rb
  - spec/analysis/stop_speeds_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/models/route_page/stop_speeds_spec.rb
-->

---
### Requirement: Stop speed of a trip

For each trip of the page route as defined by `trip-reconstruction`, except a trip whose start comes from an arrival, the system SHALL take the GPS reports of the trip's vehicle, as kept in `gps_reports` and deduplicated by `(BusID, DataTime)`, from the trip's start time to its end time, both included. Each report SHALL be placed at the nearest point of the shape of the trip's direction, the point earliest along the shape among equally near ones, and a report more than `shape_snap_meters` (50) from the shape SHALL be left out. Consecutive placed reports of the trip in time order SHALL form a pair, and a pair SHALL count only when its two reports are more than 0 and at most `pair_max_seconds` (40) seconds apart, the later report is not behind the earlier one along the shape, and it covers at most `pair_max_meters_per_second` (25) metres per second. A counted pair SHALL belong to the leg whose first stop is at or before the pair's midpoint along the shape and whose last stop is after it, and SHALL be dropped when that midpoint is less than `stop_zone_meters` (40) from either stop of the leg, before the first placed stop or at or after the last placed stop of the direction. For each trip and leg with at least one counted pair, the system SHALL keep the metres and the seconds of its counted pairs, summed, the metres rounded to one decimal, and the time band of the earlier report of the leg's first counted pair, with the hour boundaries of the time bands of `load-profile`. Trips of member routes SHALL have no rows. The speed of a set of rows SHALL be their summed metres divided by their summed seconds.

#### Scenario: Fixture day

- **WHEN** route 9001 on the fixture day 2026-10-19 is analysed with the fixture GPS files
- **THEN** the trip of TEST-0001 starting 06:00:00 has one row, leg 1 in band other with 200.0 metres and 40 seconds, and no other trip has a row; the report of 06:30:00 at 25.0604, 121.5003 is 53.8 metres from the outbound shape and is left out

#### Scenario: Pairs counted and left out

- **WHEN** a trip's reports include pairs near a stop, far apart in time, going backwards, too fast and with a report off the shape
- **THEN** only the remaining pairs count, each in the leg of its midpoint

##### Example: reports built in the test for TEST-0001's outbound trip starting 06:00:00

| Report | Time | Latitude, longitude | Along the outbound shape |
| --- | --- | --- | --- |
| 1 | 06:10:00 | 25.052698, 121.5 | 300.0 m |
| 2 | 06:10:20 | 25.053597, 121.5 | 400.0 m |
| 3 | 06:10:40 | 25.054497, 121.5 | 500.0 m |
| 4 | 06:11:00 | 25.055396, 121.5 | 600.0 m |
| 5 | 06:11:20 | 25.056295, 121.5 | 700.0 m |
| 6 | 06:12:10 | 25.056655, 121.5 | 740.0 m |
| 7 | 06:12:30 | 25.056565, 121.5 | 730.0 m |
| 8 | 06:12:40 | 25.059353, 121.5 | 1040.0 m |
| 9 | 06:12:50 | 25.059893, 121.500596 | 60.0 m east of the shape, left out |
| 10 | 06:13:00 | 25.059803, 121.5 | 1090.0 m |

| Pair | Outcome |
| --- | --- |
| 1–2, 2–3 | leg 1, counted |
| 3–4 | midpoint 550.0 m is 6.0 m from 91002, dropped |
| 4–5 | leg 2, counted |
| 5–6 | 50 seconds apart, not counted |
| 6–7 | backwards, not counted |
| 7–8 | 31.0 metres per second, not counted |
| 8–10 | leg 3, counted |

- **THEN** the trip's rows are leg 1 with 200.0 metres and 40 seconds, leg 2 with 100.0 metres and 20 seconds and leg 3 with 50.0 metres and 20 seconds, all in band other, that is 18.0, 18.0 and 9.0 km/h

#### Scenario: Band from the time the vehicle reached the leg

- **WHEN** the reports of TEST-0002's outbound trip starting 06:35:00, a trip in band other by its start, are 25.052698, 121.5 at 07:05:00 and 25.053597, 121.5 at 07:05:20
- **THEN** its leg 1 row is in band morning peak with 100.0 metres and 20 seconds

#### Scenario: Start from an arrival left out

- **WHEN** TEST-0002's outbound trip starting 10:20:00, whose start comes from an arrival, has reports at 300.0 and 400.0 metres along the outbound shape at 10:30:00 and 10:30:20
- **THEN** that trip has no row

#### Scenario: Member route trips left out

- **WHEN** route 9001 with member route 9050 on 2026-10-23 is analysed with that day's route shapes file and with reports built in the test along the outbound shape of 9001 during TEST-0005's 9050 trip starting 07:00:00, and along the inbound shape of 9001 during TEST-0005's 9001 trip starting 08:00:00 at 25.057302, 121.5003 at 08:10:00 and 25.056403, 121.5003 at 08:10:20
- **THEN** the 9050 trip has no row, and the 9001 trip has a leg 6 row in band morning peak with 100.0 metres and 20 seconds

#### Scenario: Direction without a shape

- **WHEN** route 9001 on the fixture day 2026-10-19 is analysed with a route shapes file holding `[]`, with the reports of the example above for TEST-0001's outbound trip
- **THEN** no trip has a row and none of the stops 91000 to 91009 has a position


<!-- @trace
source: stop-to-stop-speed
updated: 2026-10-26
code:
  - app/components/stop_speed_grid_component.rb
  - app/components/data_limitations_component.yml
  - analysis/README.md
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - spec/fixtures/analysis/README.md
  - app/models/trip_stop_speed.rb
  - analysis/gps_reports.sql
  - analysis/stop_speeds.sql
  - app/components/stop_speed_grid_component.yml
  - docs/data-sources.md
  - analysis/turnaround_facilities.sql
  - app/models/raw_day_check.rb
  - analysis/derived_export.sql
  - app/models/end_nature_survey_command.rb
  - analysis/params.sql
  - db/schema.rb
  - app/models/route_day_loader.rb
  - analysis/40_load_profile.sql
  - app/models/route_day_stop.rb
  - app/models/trip.rb
  - docs/decisions.md
  - app/views/routes/show.html.erb
  - db/migrate/20261026054634_create_trip_stop_speeds.rb
  - app/components/stop_speed_grid_component.html.erb
  - app/models/route_page/stop_speeds.rb
tests:
  - spec/requests/routes_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/analysis/end_nature_export_spec.rb
  - spec/components/stop_speed_grid_component_spec.rb
  - spec/analysis/end_nature_evidence_spec.rb
  - spec/analysis/gps_reports_spec.rb
  - spec/analysis/stop_speeds_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/models/route_page/stop_speeds_spec.rb
-->

---
### Requirement: Stop speed grid on the route page

The run time card SHALL show, after the run time summary of `run-time`, a stop speed block titled 哪一段開最慢？ with a note saying that a darker cell is slower, that the band is the time the vehicle reached that leg, that the 40 metres around each stop are left out so stopping and boarding are not in it, and that the numbers are in the table below. For each direction the legs, their first and last stop names and their metres SHALL come from the page route's stops of the latest covered day on which that direction has stops with positions, and the stop speed rows of every covered day SHALL be pooled by direction, leg and band: the speed of a cell is the pooled metres divided by the pooled seconds, and its trips are the number of rows pooled; a row whose leg is not a leg of that day SHALL NOT count. Each direction SHALL have a grid with one row per time band in the order morning peak, daytime, evening peak, other and one cell per leg in stop order; under the grid a line SHALL mark every stop at the boundary of its legs, with the stop's name written top to bottom below its mark and no two stop names overlapping. A cell with at least 5 trips, the small-sample threshold of the run time summary, SHALL be shaded as the requirement "Stop speed shade and legend" says; a cell with 1 to 4 trips or with none SHALL be drawn as an outline without fill. Inside a disclosure that is closed by default and whose rows are all in the server response, the block SHALL show a table per direction with one row per leg naming its first and last stop and its metres, and for each band the speed in km/h to one decimal and the number of trips, marking a cell with fewer than 5 trips as a small sample and writing — for a cell without rows. The grids SHALL be inline SVG drawn by the server, with no chart library and no tooltip, and the block SHALL contain no vehicle identifier.

#### Scenario: Block in place

- **WHEN** the page of route 9001 is rendered for the fixture day 2026-10-19 after `derived:load`
- **THEN** the stop speed block follows the run time tables inside the run time card, every cell of both grids is an outline because no cell has 5 trips, and the closed table's outbound row for leg 1 reads 18.0 km/h with 1 trip in band other, marked as a small sample, and — in the other three bands

#### Scenario: Speed pooled over the covered days

- **WHEN** day one stores two trips of 300.0 metres in 60 seconds and day two one trip of 300.0 metres in 180 seconds for direction 0, leg 1, band daytime, and the page covers both days
- **THEN** the table cell reads 10.8 km/h with 3 trips, not the mean of the trips' or the days' speeds

#### Scenario: No vehicle identifier

- **WHEN** the page of route 9001 is rendered for the fixture day 2026-10-19 after `derived:load`
- **THEN** the stop speed block contains none of TEST-0001, TEST-0002, TEST-0003 and TEST-0004

#### Scenario: Stop names written top to bottom

- **WHEN** a visitor on a 1400 px wide screen opens the page of route 9001 for the fixture day 2026-10-19 after `derived:load`
- **THEN** the outbound grid has one mark for each of 甲站, 乙站, 丙站, 丁站 and 戊站 in that order, each of the five names is drawn taller than it is wide and centred below its mark, and no two of the names overlap


<!-- @trace
source: stop-to-stop-speed
updated: 2026-10-26
code:
  - app/components/stop_speed_grid_component.rb
  - app/components/data_limitations_component.yml
  - analysis/README.md
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - spec/fixtures/analysis/README.md
  - app/models/trip_stop_speed.rb
  - analysis/gps_reports.sql
  - analysis/stop_speeds.sql
  - app/components/stop_speed_grid_component.yml
  - docs/data-sources.md
  - analysis/turnaround_facilities.sql
  - app/models/raw_day_check.rb
  - analysis/derived_export.sql
  - app/models/end_nature_survey_command.rb
  - analysis/params.sql
  - db/schema.rb
  - app/models/route_day_loader.rb
  - analysis/40_load_profile.sql
  - app/models/route_day_stop.rb
  - app/models/trip.rb
  - docs/decisions.md
  - app/views/routes/show.html.erb
  - db/migrate/20261026054634_create_trip_stop_speeds.rb
  - app/components/stop_speed_grid_component.html.erb
  - app/models/route_page/stop_speeds.rb
tests:
  - spec/requests/routes_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/analysis/end_nature_export_spec.rb
  - spec/components/stop_speed_grid_component_spec.rb
  - spec/analysis/end_nature_evidence_spec.rb
  - spec/analysis/gps_reports_spec.rb
  - spec/analysis/stop_speeds_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/models/route_page/stop_speeds_spec.rb
-->

---
### Requirement: Stop speed shade and legend

Within a direction, let P be the largest seconds per kilometre among the cells with at least 5 trips. A shaded cell's level SHALL be the ceiling of 4 × its seconds per kilometre ÷ P, compared exactly, so that a value on a boundary takes the lighter level, and levels 1 to 4 SHALL be four steps of one hue from light to dark, level 4 the darkest; a cell with fewer than 5 trips SHALL NOT set P. Above the grids the block SHALL show a legend reading 快, the four steps and 慢, and each direction SHALL show a line with the speed range of each level computed from the speed v of the direction's slowest shaded cell: level 1 at 4v and above, level 2 from 2v to 4v, level 3 from 4v/3 to 2v and level 4 below 4v/3, in km/h to one decimal. A direction without a shaded cell SHALL show no range line. No cell SHALL be colored to say whether its speed passes a threshold, and the block SHALL say that the shades compare legs of the same direction only.

#### Scenario: Four levels

- **WHEN** a direction's shaded cells are 5.0, 7.5, 10.0 and 20.0 km/h
- **THEN** their levels are 4, 3, 2 and 1

##### Example: levels and ranges built in the test

| Cell speed | Seconds per km | 4 × ÷ 720 | Level |
| --- | --- | --- | --- |
| 5.0 km/h | 720 | 4.0 | 4 |
| 7.5 km/h | 480 | 2.67 | 3 |
| 10.0 km/h | 360 | 2.0 | 2 |
| 20.0 km/h | 180 | 1.0 | 1 |

- **THEN** the range line of that direction gives 20.0 and above for level 1, 10.0 to 20.0 for level 2, 6.7 to 10.0 for level 3 and below 6.7 for level 4

#### Scenario: Small samples do not set the scale

- **WHEN** a direction has a cell of 3.0 km/h with 4 trips and cells of 6.0 and 12.0 km/h with 5 trips each
- **THEN** the 3.0 km/h cell is an outline, the 6.0 km/h cell is level 4, the 12.0 km/h cell is level 2, and the range line starts at 24.0 and above

#### Scenario: No shaded cell

- **WHEN** no cell of a direction has 5 trips
- **THEN** every cell of that direction is an outline and that direction shows no range line


<!-- @trace
source: stop-to-stop-speed
updated: 2026-10-26
code:
  - app/components/stop_speed_grid_component.rb
  - app/components/data_limitations_component.yml
  - analysis/README.md
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - spec/fixtures/analysis/README.md
  - app/models/trip_stop_speed.rb
  - analysis/gps_reports.sql
  - analysis/stop_speeds.sql
  - app/components/stop_speed_grid_component.yml
  - docs/data-sources.md
  - analysis/turnaround_facilities.sql
  - app/models/raw_day_check.rb
  - analysis/derived_export.sql
  - app/models/end_nature_survey_command.rb
  - analysis/params.sql
  - db/schema.rb
  - app/models/route_day_loader.rb
  - analysis/40_load_profile.sql
  - app/models/route_day_stop.rb
  - app/models/trip.rb
  - docs/decisions.md
  - app/views/routes/show.html.erb
  - db/migrate/20261026054634_create_trip_stop_speeds.rb
  - app/components/stop_speed_grid_component.html.erb
  - app/models/route_page/stop_speeds.rb
tests:
  - spec/requests/routes_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/analysis/end_nature_export_spec.rb
  - spec/components/stop_speed_grid_component_spec.rb
  - spec/analysis/end_nature_evidence_spec.rb
  - spec/analysis/gps_reports_spec.rb
  - spec/analysis/stop_speeds_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/models/route_page/stop_speeds_spec.rb
-->

---
### Requirement: Stop speed grid on narrow screens

Below 640 px wide, the stop speed block SHALL show one direction at a time, the outbound direction first, with a control that switches the direction without reloading the page and without changing the page address, and SHALL show each leg of that direction as a row naming its first and last stop followed by four squares for the bands in the grid's order, each shaded or outlined as the grid's cell. At 640 px wide or wider, the block SHALL show the grids of both directions and SHALL NOT show the control or the rows. Without JavaScript, both directions' grids and rows SHALL be in the response with none of them marked as hidden, and the control SHALL NOT be shown.

#### Scenario: Switching on a phone

- **WHEN** a visitor on a 390 px wide screen opens a stored day with stop speeds in both directions and switches the stop speed block to inbound
- **THEN** only the inbound leg rows are displayed, no grid is displayed and the page address is unchanged

#### Scenario: Wide screens show both grids

- **WHEN** a visitor on a 1400 px wide screen opens the same stored day
- **THEN** both directions' grids are displayed and neither the leg rows nor the direction switch of the stop speed block is displayed

#### Scenario: Without JavaScript

- **WHEN** the page of a stored day with stop speeds is fetched without running any script
- **THEN** the response contains both directions' grids and leg rows, none of them is marked as hidden, and the direction switch is not shown


<!-- @trace
source: stop-to-stop-speed
updated: 2026-10-26
code:
  - app/components/stop_speed_grid_component.rb
  - app/components/data_limitations_component.yml
  - analysis/README.md
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - spec/fixtures/analysis/README.md
  - app/models/trip_stop_speed.rb
  - analysis/gps_reports.sql
  - analysis/stop_speeds.sql
  - app/components/stop_speed_grid_component.yml
  - docs/data-sources.md
  - analysis/turnaround_facilities.sql
  - app/models/raw_day_check.rb
  - analysis/derived_export.sql
  - app/models/end_nature_survey_command.rb
  - analysis/params.sql
  - db/schema.rb
  - app/models/route_day_loader.rb
  - analysis/40_load_profile.sql
  - app/models/route_day_stop.rb
  - app/models/trip.rb
  - docs/decisions.md
  - app/views/routes/show.html.erb
  - db/migrate/20261026054634_create_trip_stop_speeds.rb
  - app/components/stop_speed_grid_component.html.erb
  - app/models/route_page/stop_speeds.rb
tests:
  - spec/requests/routes_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/analysis/end_nature_export_spec.rb
  - spec/components/stop_speed_grid_component_spec.rb
  - spec/analysis/end_nature_evidence_spec.rb
  - spec/analysis/gps_reports_spec.rb
  - spec/analysis/stop_speeds_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/models/route_page/stop_speeds_spec.rb
-->

---
### Requirement: Stop speed block without speeds

When no trip of the page route on the covered days has a stop speed row, the stop speed block SHALL show its title and one sentence saying that the covered days have no stop speeds, either because they were loaded before stop speeds existed and need to be loaded again or because their snapshot had no route shape, and SHALL show no grid, legend, row or table. When the covered days have rows but a direction has no leg, that direction SHALL say that it has no stop speeds while the other direction is shown.

#### Scenario: Days loaded before stop speeds

- **WHEN** the page of route 9001 covers 2026-10-19 stored with its 27 trips and no stop speed row, as a day loaded before stop speeds existed
- **THEN** the stop speed block shows its title and that sentence, and no grid, legend, leg row or table, while the run time tables before it are shown as usual

#### Scenario: Direction without legs

- **WHEN** the covered days have stop speed rows for direction 0 and no stop of direction 1 has a position on any of them
- **THEN** direction 1 says that it has no stop speeds and direction 0's grid, rows and table are shown

<!-- @trace
source: stop-to-stop-speed
updated: 2026-10-26
code:
  - app/components/stop_speed_grid_component.rb
  - app/components/data_limitations_component.yml
  - analysis/README.md
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - spec/fixtures/analysis/README.md
  - app/models/trip_stop_speed.rb
  - analysis/gps_reports.sql
  - analysis/stop_speeds.sql
  - app/components/stop_speed_grid_component.yml
  - docs/data-sources.md
  - analysis/turnaround_facilities.sql
  - app/models/raw_day_check.rb
  - analysis/derived_export.sql
  - app/models/end_nature_survey_command.rb
  - analysis/params.sql
  - db/schema.rb
  - app/models/route_day_loader.rb
  - analysis/40_load_profile.sql
  - app/models/route_day_stop.rb
  - app/models/trip.rb
  - docs/decisions.md
  - app/views/routes/show.html.erb
  - db/migrate/20261026054634_create_trip_stop_speeds.rb
  - app/components/stop_speed_grid_component.html.erb
  - app/models/route_page/stop_speeds.rb
tests:
  - spec/requests/routes_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/analysis/end_nature_export_spec.rb
  - spec/components/stop_speed_grid_component_spec.rb
  - spec/analysis/end_nature_evidence_spec.rb
  - spec/analysis/gps_reports_spec.rb
  - spec/analysis/stop_speeds_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/models/route_page/stop_speeds_spec.rb
-->