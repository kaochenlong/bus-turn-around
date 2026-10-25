# timetable Specification

## Purpose

A printable per-vehicle timetable for one route and one day, laid out in the browser from the measured run times at a chosen percentile, the rest minutes and the departures per hour a dispatcher picks, so that the dispatcher edits a laid-out timetable instead of writing every departure by hand. The server supplies the measured data; the browser lays out, recomputes and prints. The site makes no claim about how the timetable is used.

## Requirements

### Requirement: Timetable page address and parameters

The system SHALL serve `GET /routes/:route_id/timetable` for route `Id`s listed in the route list configuration, and SHALL respond 404 with the site's not-found page for any other route `Id`. The parameters `day` and `range` SHALL select the covered days exactly as the route page does; the parameter `buffer` SHALL be the initial rest minutes with the same values, default and rejection rule as `buffer-trade`; the parameter `p` SHALL be the initial run time percentile, one of 50, 55, 60, 65, 70, 75, 80, 85, 90 and 95, defaulting to 85. A `p` outside the list, or any `day`, `range` or `buffer` value the route page rejects, SHALL respond 400. The page SHALL accept no other parameter for the departures per hour or for edited cells. When the selected day has no stored data, the page SHALL respond 200, state that the day has no data, and carry no timetable data.

#### Scenario: Defaults

- **WHEN** a visitor requests `/routes/9001/timetable` and route 9001 has stored days
- **THEN** the page covers the latest stored day with a range of one day and carries 15 rest minutes and the 85th percentile as the initial values

#### Scenario: Rejected percentile

- **WHEN** a visitor requests `/routes/9001/timetable?p=83`
- **THEN** the response is 400

#### Scenario: Route not configured

- **WHEN** a visitor requests `/routes/9999/timetable` and 9999 is not in the route list
- **THEN** the response is 404 and its body is the content of `public/404.html`

#### Scenario: Day without data

- **WHEN** a visitor requests `/routes/9001/timetable?day=2026-01-01` and that day is not stored
- **THEN** the response is 200, states that the day has no data, and contains neither timetable data nor a vehicle sheet


<!-- @trace
source: timetable-draft
updated: 2026-10-25
code:
  - app/components/timetable_overrun_table_component.yml
  - app/models/route_page.rb
  - app/components/timetable_limitations_component.rb
  - app/models/route_page/measured_departures.rb
  - app/components/timetable_header_component.rb
  - app/components/timetable_sheet_component.rb
  - app/components/timetable_header_component.html.erb
  - app/views/layouts/application.html.erb
  - config/locales/tw.yml
  - app/components/site_bar_component.rb
  - app/frontend/timetable/layout.js
  - app/components/timetable_overrun_table_component.html.erb
  - app/frontend/timetable/rows.js
  - package.json
  - app/frontend/timetable/rest_windows.js
  - app/components/timetable_sheet_component.yml
  - app/frontend/timetable/edits.js
  - app/frontend/timetable/component.js
  - app/models/route_page/timetable_overruns.rb
  - app/components/timetable_sheet_component.html.erb
  - app/components/buffer_trade_component.html.erb
  - app/controllers/application_controller.rb
  - app/views/timetables/show.html.erb
  - app/models/route_page/planned_run_times.rb
  - app/controllers/timetables_controller.rb
  - app/frontend/timetable/support.js
  - app/controllers/routes_controller.rb
  - app/components/timetable_header_component.yml
  - config/routes.rb
  - app/components/buffer_trade_component.yml
  - app/components/site_bar_component.html.erb
  - docs/use-cases.md
  - config/ci.rb
  - app/frontend/entrypoints/application.js
  - app/components/buffer_trade_component.rb
  - app/frontend/timetable/format.js
  - app/components/timetable_limitations_component.yml
  - app/frontend/stylesheets/application.css
  - app/components/timetable_overrun_table_component.rb
  - app/components/timetable_limitations_component.html.erb
  - app/components/site_bar_component.yml
  - app/models/route_page/timetable.rb
  - config/locales/en.yml
  - README.md
tests:
  - spec/models/route_page/timetable_spec.rb
  - spec/components/timetable_sheet_component_spec.rb
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/timetable_overrun_table_component_spec.rb
  - spec/system/timetable_layout_spec.rb
  - spec/requests/routes_spec.rb
  - spec/system/timetable_print_spec.rb
  - app/frontend/timetable/layout.test.js
  - spec/system/timetable_entry_spec.rb
  - spec/components/timetable_header_component_spec.rb
  - app/frontend/timetable/edits.test.js
  - app/frontend/timetable/rows.test.js
  - app/frontend/timetable/rest_windows.test.js
  - spec/models/route_page/planned_run_times_spec.rb
  - spec/models/route_page/measured_departures_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/format.test.js
  - spec/models/route_page/timetable_overruns_spec.rb
-->

---
### Requirement: Data for the browser

The page SHALL embed one JSON document in a `script` element of type `application/json` marked `data-timetable-data`, carrying: the initial percentile and rest minutes; the offered percentiles; the accepted ranges of the rest minutes and of the departures per hour; for each direction and each Taipei hour, the planned run time in whole minutes at every offered percentile together with whether that hour fell back to the whole day, computed by the Planned run time requirement; the default departures per hour of each direction, computed by the Default departures per hour requirement; the hold in whole minutes after a trip of each direction, computed by the Hold at each end requirement; the directions whose end is a stopping end, so that the browser knows which holds follow the rest control; and the name of the first stop of each direction on the latest covered day, among the page route's own stops. When a direction has no trip with a run time, the page SHALL carry no timetable data and SHALL name that direction as lacking run times.

#### Scenario: Data of the four-departure day

- **WHEN** the covered day holds direction 0 trips from 甲站 at 06:00 and 06:30 running 50 minutes and direction 1 trips from 乙站 at 07:00 and 07:30 running 45 minutes, both ends stop and the rest minutes are 15
- **THEN** the data gives direction 0 two departures in hour 6 and direction 1 two in hour 7, a planned run time of 50 minutes for direction 0 and 45 for direction 1 at every percentile and hour, each marked as using the all-day value, a hold of 15 minutes after either direction, both directions as stopping ends, and the stop names 甲站 and 乙站

##### Example: Planned run times in the data

| Direction | Hour | Trips in the hour | Value at p85 in the data |
| --- | --- | --- | --- |
| 0 | 6 | 44, 47, 50, 52, 60 | 55, not fallen back |
| 0 | 12 | none | the direction's all-day p85, fallen back |
| 1 | 22 | 40, 50 | the direction's all-day p85, fallen back |

#### Scenario: Direction without run times

- **WHEN** the covered days hold no direction 1 trip with a run time
- **THEN** the page carries no timetable data, shows no vehicle sheet and states that direction 1 has no run times


<!-- @trace
source: timetable-draft
updated: 2026-10-25
code:
  - app/components/timetable_overrun_table_component.yml
  - app/models/route_page.rb
  - app/components/timetable_limitations_component.rb
  - app/models/route_page/measured_departures.rb
  - app/components/timetable_header_component.rb
  - app/components/timetable_sheet_component.rb
  - app/components/timetable_header_component.html.erb
  - app/views/layouts/application.html.erb
  - config/locales/tw.yml
  - app/components/site_bar_component.rb
  - app/frontend/timetable/layout.js
  - app/components/timetable_overrun_table_component.html.erb
  - app/frontend/timetable/rows.js
  - package.json
  - app/frontend/timetable/rest_windows.js
  - app/components/timetable_sheet_component.yml
  - app/frontend/timetable/edits.js
  - app/frontend/timetable/component.js
  - app/models/route_page/timetable_overruns.rb
  - app/components/timetable_sheet_component.html.erb
  - app/components/buffer_trade_component.html.erb
  - app/controllers/application_controller.rb
  - app/views/timetables/show.html.erb
  - app/models/route_page/planned_run_times.rb
  - app/controllers/timetables_controller.rb
  - app/frontend/timetable/support.js
  - app/controllers/routes_controller.rb
  - app/components/timetable_header_component.yml
  - config/routes.rb
  - app/components/buffer_trade_component.yml
  - app/components/site_bar_component.html.erb
  - docs/use-cases.md
  - config/ci.rb
  - app/frontend/entrypoints/application.js
  - app/components/buffer_trade_component.rb
  - app/frontend/timetable/format.js
  - app/components/timetable_limitations_component.yml
  - app/frontend/stylesheets/application.css
  - app/components/timetable_overrun_table_component.rb
  - app/components/timetable_limitations_component.html.erb
  - app/components/site_bar_component.yml
  - app/models/route_page/timetable.rb
  - config/locales/en.yml
  - README.md
tests:
  - spec/models/route_page/timetable_spec.rb
  - spec/components/timetable_sheet_component_spec.rb
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/timetable_overrun_table_component_spec.rb
  - spec/system/timetable_layout_spec.rb
  - spec/requests/routes_spec.rb
  - spec/system/timetable_print_spec.rb
  - app/frontend/timetable/layout.test.js
  - spec/system/timetable_entry_spec.rb
  - spec/components/timetable_header_component_spec.rb
  - app/frontend/timetable/edits.test.js
  - app/frontend/timetable/rows.test.js
  - app/frontend/timetable/rest_windows.test.js
  - spec/models/route_page/planned_run_times_spec.rb
  - spec/models/route_page/measured_departures_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/format.test.js
  - spec/models/route_page/timetable_overruns_spec.rb
-->

---
### Requirement: Default departures per hour

For each direction and each Taipei hour, the default number of departures SHALL be the number of stored trips of the covered days whose start time falls in that hour, of every completeness, divided by the number of covered days and rounded half up to a whole number.

#### Scenario: Average over covered days

- **WHEN** the covered days are four weekdays and direction 0 has 5, 6, 5 and 5 trips starting in the 07 hour on those days
- **THEN** the default departures of direction 0 in hour 7 is 5

##### Example: Rounding of the average

| Trips per covered day in the hour | Covered days | Default |
| --- | --- | --- |
| 5, 6, 5, 5 | 4 | 5 |
| 4, 5, 5, 5 | 4 | 5 |
| 4, 5 | 2 | 5 |
| 0, 0, 1 | 3 | 0 |


<!-- @trace
source: timetable-draft
updated: 2026-10-25
code:
  - app/components/timetable_overrun_table_component.yml
  - app/models/route_page.rb
  - app/components/timetable_limitations_component.rb
  - app/models/route_page/measured_departures.rb
  - app/components/timetable_header_component.rb
  - app/components/timetable_sheet_component.rb
  - app/components/timetable_header_component.html.erb
  - app/views/layouts/application.html.erb
  - config/locales/tw.yml
  - app/components/site_bar_component.rb
  - app/frontend/timetable/layout.js
  - app/components/timetable_overrun_table_component.html.erb
  - app/frontend/timetable/rows.js
  - package.json
  - app/frontend/timetable/rest_windows.js
  - app/components/timetable_sheet_component.yml
  - app/frontend/timetable/edits.js
  - app/frontend/timetable/component.js
  - app/models/route_page/timetable_overruns.rb
  - app/components/timetable_sheet_component.html.erb
  - app/components/buffer_trade_component.html.erb
  - app/controllers/application_controller.rb
  - app/views/timetables/show.html.erb
  - app/models/route_page/planned_run_times.rb
  - app/controllers/timetables_controller.rb
  - app/frontend/timetable/support.js
  - app/controllers/routes_controller.rb
  - app/components/timetable_header_component.yml
  - config/routes.rb
  - app/components/buffer_trade_component.yml
  - app/components/site_bar_component.html.erb
  - docs/use-cases.md
  - config/ci.rb
  - app/frontend/entrypoints/application.js
  - app/components/buffer_trade_component.rb
  - app/frontend/timetable/format.js
  - app/components/timetable_limitations_component.yml
  - app/frontend/stylesheets/application.css
  - app/components/timetable_overrun_table_component.rb
  - app/components/timetable_limitations_component.html.erb
  - app/components/site_bar_component.yml
  - app/models/route_page/timetable.rb
  - config/locales/en.yml
  - README.md
tests:
  - spec/models/route_page/timetable_spec.rb
  - spec/components/timetable_sheet_component_spec.rb
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/timetable_overrun_table_component_spec.rb
  - spec/system/timetable_layout_spec.rb
  - spec/requests/routes_spec.rb
  - spec/system/timetable_print_spec.rb
  - app/frontend/timetable/layout.test.js
  - spec/system/timetable_entry_spec.rb
  - spec/components/timetable_header_component_spec.rb
  - app/frontend/timetable/edits.test.js
  - app/frontend/timetable/rows.test.js
  - app/frontend/timetable/rest_windows.test.js
  - spec/models/route_page/planned_run_times_spec.rb
  - spec/models/route_page/measured_departures_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/format.test.js
  - spec/models/route_page/timetable_overruns_spec.rb
-->

---
### Requirement: Planned run time at the chosen percentile

The planned run time of a trip of direction d departing in Taipei hour h SHALL be the p-th percentile, interpolated linearly between order statistics, of the run times as defined by `run-time` of the covered days' trips of direction d whose start time falls in hour h, rounded half up to a whole minute. When fewer than 5 such trips exist, the planned run time SHALL instead be the p-th percentile of all run times of direction d over every hour, and the trip SHALL be marked as using the all-day value. The hour of a departure at or after 24:00 SHALL be taken within the day, so a departure at 24:45 uses hour 0.

#### Scenario: Percentile of one hour

- **WHEN** direction 0 has run times 44, 47, 50, 52 and 60 minutes in the 06 hour and p is 85
- **THEN** the planned run time of a direction 0 trip departing in the 06 hour is 55 minutes

##### Example: Percentiles of the same five run times

| p | Interpolated value | Planned minutes |
| --- | --- | --- |
| 50 | 50.0 | 50 |
| 85 | 55.2 | 55 |
| 95 | 58.4 | 58 |

#### Scenario: Small sample falls back to the whole day

- **WHEN** direction 1 has 2 trips with a run time in the 22 hour and 40 over the whole day
- **THEN** a direction 1 trip departing in the 22 hour uses the percentile over the 40 run times and is marked as using the all-day value


<!-- @trace
source: timetable-draft
updated: 2026-10-25
code:
  - app/components/timetable_overrun_table_component.yml
  - app/models/route_page.rb
  - app/components/timetable_limitations_component.rb
  - app/models/route_page/measured_departures.rb
  - app/components/timetable_header_component.rb
  - app/components/timetable_sheet_component.rb
  - app/components/timetable_header_component.html.erb
  - app/views/layouts/application.html.erb
  - config/locales/tw.yml
  - app/components/site_bar_component.rb
  - app/frontend/timetable/layout.js
  - app/components/timetable_overrun_table_component.html.erb
  - app/frontend/timetable/rows.js
  - package.json
  - app/frontend/timetable/rest_windows.js
  - app/components/timetable_sheet_component.yml
  - app/frontend/timetable/edits.js
  - app/frontend/timetable/component.js
  - app/models/route_page/timetable_overruns.rb
  - app/components/timetable_sheet_component.html.erb
  - app/components/buffer_trade_component.html.erb
  - app/controllers/application_controller.rb
  - app/views/timetables/show.html.erb
  - app/models/route_page/planned_run_times.rb
  - app/controllers/timetables_controller.rb
  - app/frontend/timetable/support.js
  - app/controllers/routes_controller.rb
  - app/components/timetable_header_component.yml
  - config/routes.rb
  - app/components/buffer_trade_component.yml
  - app/components/site_bar_component.html.erb
  - docs/use-cases.md
  - config/ci.rb
  - app/frontend/entrypoints/application.js
  - app/components/buffer_trade_component.rb
  - app/frontend/timetable/format.js
  - app/components/timetable_limitations_component.yml
  - app/frontend/stylesheets/application.css
  - app/components/timetable_overrun_table_component.rb
  - app/components/timetable_limitations_component.html.erb
  - app/components/site_bar_component.yml
  - app/models/route_page/timetable.rb
  - config/locales/en.yml
  - README.md
tests:
  - spec/models/route_page/timetable_spec.rb
  - spec/components/timetable_sheet_component_spec.rb
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/timetable_overrun_table_component_spec.rb
  - spec/system/timetable_layout_spec.rb
  - spec/requests/routes_spec.rb
  - spec/system/timetable_print_spec.rb
  - app/frontend/timetable/layout.test.js
  - spec/system/timetable_entry_spec.rb
  - spec/components/timetable_header_component_spec.rb
  - app/frontend/timetable/edits.test.js
  - app/frontend/timetable/rows.test.js
  - app/frontend/timetable/rest_windows.test.js
  - spec/models/route_page/planned_run_times_spec.rb
  - spec/models/route_page/measured_departures_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/format.test.js
  - spec/models/route_page/timetable_overruns_spec.rb
-->

---
### Requirement: Hold at each end

After a trip arrives at the end of its direction, the vehicle SHALL be held before its next departure for the rest minutes when that end is a stopping end as defined by `turnaround-ends`, and for the median of the measured layovers of the covered days ending in that direction, as defined by `layover-metrics`, rounded half up to a whole minute, when that end is a pass-through end; with no such layover the hold at a pass-through end SHALL be 0 minutes. Changing the rest minutes SHALL change the hold at the stopping ends only.

#### Scenario: Hold at a stopping end

- **WHEN** direction 1 ends at a stopping end and the rest minutes are 15
- **THEN** a vehicle arriving from a direction 1 trip is available 15 minutes after its arrival

#### Scenario: Hold at a pass-through end

- **WHEN** direction 0 ends at a pass-through end and the layovers ending in direction 0 over the covered days have a median of 1.9 minutes
- **THEN** a vehicle arriving from a direction 0 trip is available 2 minutes after its arrival


<!-- @trace
source: timetable-draft
updated: 2026-10-25
code:
  - app/components/timetable_overrun_table_component.yml
  - app/models/route_page.rb
  - app/components/timetable_limitations_component.rb
  - app/models/route_page/measured_departures.rb
  - app/components/timetable_header_component.rb
  - app/components/timetable_sheet_component.rb
  - app/components/timetable_header_component.html.erb
  - app/views/layouts/application.html.erb
  - config/locales/tw.yml
  - app/components/site_bar_component.rb
  - app/frontend/timetable/layout.js
  - app/components/timetable_overrun_table_component.html.erb
  - app/frontend/timetable/rows.js
  - package.json
  - app/frontend/timetable/rest_windows.js
  - app/components/timetable_sheet_component.yml
  - app/frontend/timetable/edits.js
  - app/frontend/timetable/component.js
  - app/models/route_page/timetable_overruns.rb
  - app/components/timetable_sheet_component.html.erb
  - app/components/buffer_trade_component.html.erb
  - app/controllers/application_controller.rb
  - app/views/timetables/show.html.erb
  - app/models/route_page/planned_run_times.rb
  - app/controllers/timetables_controller.rb
  - app/frontend/timetable/support.js
  - app/controllers/routes_controller.rb
  - app/components/timetable_header_component.yml
  - config/routes.rb
  - app/components/buffer_trade_component.yml
  - app/components/site_bar_component.html.erb
  - docs/use-cases.md
  - config/ci.rb
  - app/frontend/entrypoints/application.js
  - app/components/buffer_trade_component.rb
  - app/frontend/timetable/format.js
  - app/components/timetable_limitations_component.yml
  - app/frontend/stylesheets/application.css
  - app/components/timetable_overrun_table_component.rb
  - app/components/timetable_limitations_component.html.erb
  - app/components/site_bar_component.yml
  - app/models/route_page/timetable.rb
  - config/locales/en.yml
  - README.md
tests:
  - spec/models/route_page/timetable_spec.rb
  - spec/components/timetable_sheet_component_spec.rb
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/timetable_overrun_table_component_spec.rb
  - spec/system/timetable_layout_spec.rb
  - spec/requests/routes_spec.rb
  - spec/system/timetable_print_spec.rb
  - app/frontend/timetable/layout.test.js
  - spec/system/timetable_entry_spec.rb
  - spec/components/timetable_header_component_spec.rb
  - app/frontend/timetable/edits.test.js
  - app/frontend/timetable/rows.test.js
  - app/frontend/timetable/rest_windows.test.js
  - spec/models/route_page/planned_run_times_spec.rb
  - spec/models/route_page/measured_departures_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/format.test.js
  - spec/models/route_page/timetable_overruns_spec.rb
-->

---
### Requirement: Departure times within an hour

When a direction has n departures in Taipei hour h, the k-th of them, counting k from 0, SHALL depart at hour h and minute `floor(k × 60 / n)`.

#### Scenario: Seven departures in one hour

- **WHEN** direction 0 has 7 departures in the 07 hour
- **THEN** they depart at 07:00, 07:08, 07:17, 07:25, 07:34, 07:42 and 07:51

##### Example: Spacing for other counts

| n | Minutes |
| --- | --- |
| 1 | 0 |
| 2 | 0, 30 |
| 5 | 0, 12, 24, 36, 48 |
| 0 | none |


<!-- @trace
source: timetable-draft
updated: 2026-10-25
code:
  - app/components/timetable_overrun_table_component.yml
  - app/models/route_page.rb
  - app/components/timetable_limitations_component.rb
  - app/models/route_page/measured_departures.rb
  - app/components/timetable_header_component.rb
  - app/components/timetable_sheet_component.rb
  - app/components/timetable_header_component.html.erb
  - app/views/layouts/application.html.erb
  - config/locales/tw.yml
  - app/components/site_bar_component.rb
  - app/frontend/timetable/layout.js
  - app/components/timetable_overrun_table_component.html.erb
  - app/frontend/timetable/rows.js
  - package.json
  - app/frontend/timetable/rest_windows.js
  - app/components/timetable_sheet_component.yml
  - app/frontend/timetable/edits.js
  - app/frontend/timetable/component.js
  - app/models/route_page/timetable_overruns.rb
  - app/components/timetable_sheet_component.html.erb
  - app/components/buffer_trade_component.html.erb
  - app/controllers/application_controller.rb
  - app/views/timetables/show.html.erb
  - app/models/route_page/planned_run_times.rb
  - app/controllers/timetables_controller.rb
  - app/frontend/timetable/support.js
  - app/controllers/routes_controller.rb
  - app/components/timetable_header_component.yml
  - config/routes.rb
  - app/components/buffer_trade_component.yml
  - app/components/site_bar_component.html.erb
  - docs/use-cases.md
  - config/ci.rb
  - app/frontend/entrypoints/application.js
  - app/components/buffer_trade_component.rb
  - app/frontend/timetable/format.js
  - app/components/timetable_limitations_component.yml
  - app/frontend/stylesheets/application.css
  - app/components/timetable_overrun_table_component.rb
  - app/components/timetable_limitations_component.html.erb
  - app/components/site_bar_component.yml
  - app/models/route_page/timetable.rb
  - config/locales/en.yml
  - README.md
tests:
  - spec/models/route_page/timetable_spec.rb
  - spec/components/timetable_sheet_component_spec.rb
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/timetable_overrun_table_component_spec.rb
  - spec/system/timetable_layout_spec.rb
  - spec/requests/routes_spec.rb
  - spec/system/timetable_print_spec.rb
  - app/frontend/timetable/layout.test.js
  - spec/system/timetable_entry_spec.rb
  - spec/components/timetable_header_component_spec.rb
  - app/frontend/timetable/edits.test.js
  - app/frontend/timetable/rows.test.js
  - app/frontend/timetable/rest_windows.test.js
  - spec/models/route_page/planned_run_times_spec.rb
  - spec/models/route_page/measured_departures_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/format.test.js
  - spec/models/route_page/timetable_overruns_spec.rb
-->

---
### Requirement: Vehicle assignment

The browser SHALL process the departures of both directions in time order, direction 0 first at equal times. For a departure of direction d, the candidates SHALL be the vehicles standing at the first stop of direction d whose available time is not later than the departure time; the departure SHALL go to the candidate with the earliest available time, the lower vehicle number at equal times. With no candidate, a new vehicle SHALL be created at that end, numbered in order of creation from 1, and take the departure. After a trip, the vehicle's arrival time SHALL be the departure plus the planned run time, its available time the arrival plus the hold at that end, and its position the other end. The number of vehicles of the timetable SHALL be the number created.

#### Scenario: A second departure before the first vehicle returns needs a new vehicle

- **WHEN** both ends are stopping ends with 15 rest minutes, direction 0 from 甲站 to 乙站 has 2 departures in the 06 hour with a planned run time of 50 minutes, and direction 1 from 乙站 to 甲站 has 2 departures in the 07 hour with a planned run time of 45 minutes
- **THEN** three vehicles are created, vehicle 1 runs 06:00 to 06:50 and 07:30 to 08:15, vehicle 2 runs 06:30 to 07:20, and vehicle 3 runs 07:00 to 07:45

##### Example: Assignment of the four departures

| Departure | Candidates at that end | Assigned | Arrival | Available |
| --- | --- | --- | --- | --- |
| 06:00 direction 0 | none | vehicle 1 created at 甲站 | 06:50 | 07:05 |
| 06:30 direction 0 | none | vehicle 2 created at 甲站 | 07:20 | 07:35 |
| 07:00 direction 1 | none (vehicle 1 available 07:05) | vehicle 3 created at 乙站 | 07:45 | 08:00 |
| 07:30 direction 1 | vehicle 1 (07:05) | vehicle 1 | 08:15 | 08:30 |

#### Scenario: The longest-waiting vehicle takes the departure

- **WHEN** vehicles 1 and 2 stand at 乙站 with available times 07:05 and 07:35 and direction 1 departs at 07:40 and at 08:00
- **THEN** the 07:40 departure goes to vehicle 1 and the 08:00 departure goes to vehicle 2


<!-- @trace
source: timetable-draft
updated: 2026-10-25
code:
  - app/components/timetable_overrun_table_component.yml
  - app/models/route_page.rb
  - app/components/timetable_limitations_component.rb
  - app/models/route_page/measured_departures.rb
  - app/components/timetable_header_component.rb
  - app/components/timetable_sheet_component.rb
  - app/components/timetable_header_component.html.erb
  - app/views/layouts/application.html.erb
  - config/locales/tw.yml
  - app/components/site_bar_component.rb
  - app/frontend/timetable/layout.js
  - app/components/timetable_overrun_table_component.html.erb
  - app/frontend/timetable/rows.js
  - package.json
  - app/frontend/timetable/rest_windows.js
  - app/components/timetable_sheet_component.yml
  - app/frontend/timetable/edits.js
  - app/frontend/timetable/component.js
  - app/models/route_page/timetable_overruns.rb
  - app/components/timetable_sheet_component.html.erb
  - app/components/buffer_trade_component.html.erb
  - app/controllers/application_controller.rb
  - app/views/timetables/show.html.erb
  - app/models/route_page/planned_run_times.rb
  - app/controllers/timetables_controller.rb
  - app/frontend/timetable/support.js
  - app/controllers/routes_controller.rb
  - app/components/timetable_header_component.yml
  - config/routes.rb
  - app/components/buffer_trade_component.yml
  - app/components/site_bar_component.html.erb
  - docs/use-cases.md
  - config/ci.rb
  - app/frontend/entrypoints/application.js
  - app/components/buffer_trade_component.rb
  - app/frontend/timetable/format.js
  - app/components/timetable_limitations_component.yml
  - app/frontend/stylesheets/application.css
  - app/components/timetable_overrun_table_component.rb
  - app/components/timetable_limitations_component.html.erb
  - app/components/site_bar_component.yml
  - app/models/route_page/timetable.rb
  - config/locales/en.yml
  - README.md
tests:
  - spec/models/route_page/timetable_spec.rb
  - spec/components/timetable_sheet_component_spec.rb
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/timetable_overrun_table_component_spec.rb
  - spec/system/timetable_layout_spec.rb
  - spec/requests/routes_spec.rb
  - spec/system/timetable_print_spec.rb
  - app/frontend/timetable/layout.test.js
  - spec/system/timetable_entry_spec.rb
  - spec/components/timetable_header_component_spec.rb
  - app/frontend/timetable/edits.test.js
  - app/frontend/timetable/rows.test.js
  - app/frontend/timetable/rest_windows.test.js
  - spec/models/route_page/planned_run_times_spec.rb
  - spec/models/route_page/measured_departures_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/format.test.js
  - spec/models/route_page/timetable_overruns_spec.rb
-->

---
### Requirement: One sheet per vehicle with round-trip rows

The page SHALL show one sheet per vehicle, in vehicle number order, each sheet marked with its vehicle number and titled 車次 followed by that number: the run number the paper trip sheet carries in its top left corner, one per sheet. The rows of a sheet SHALL pair the vehicle's consecutive trips: the first and second trip form row 1, the third and fourth row 2, and so on; a last trip without a following trip SHALL form a row on its own. The columns SHALL follow the paper trip sheet, in order: driver number, driver name, the departure time of the first trip, the name of that trip's first stop, dispatcher, the arrival time of the first trip, the stop in whole minutes from that arrival to the second trip's departure, the departure time of the second trip, accumulated mileage, the arrival time of the second trip, the stop in whole minutes from that arrival to the next row's first departure (blank on the last row), trip mileage, and dispatcher again. The driver number, driver name, dispatcher and mileage cells SHALL be blank for filling in by hand, and rows SHALL carry no row number. On a row of a single trip the second trip's departure, arrival and the first stop SHALL be blank. A time on or after 24:00 SHALL be shown as the next day's time. A trip marked as using the all-day run time SHALL be marked on its row. The page SHALL NOT contain any vehicle identifier from the data.

#### Scenario: Rows of vehicle 1

- **WHEN** vehicle 1 runs direction 0 from 甲站 06:00 to 06:50 and direction 1 from 乙站 07:30 to 08:15 and has no further trip
- **THEN** its sheet is titled 車次 1 and has one row whose time and stop cells read 06:00, 甲站, 06:50, 40, 07:30, 08:15 and a blank last stop, with the hand-filled cells blank

#### Scenario: Trailing single trip

- **WHEN** vehicle 3's only trip runs direction 1 from 乙站 07:00 to 07:45
- **THEN** its sheet has one row whose time and stop cells read 07:00, 乙站, 07:45 and blank second-trip cells

#### Scenario: Time past midnight

- **WHEN** a trip departs at 23:40 with a planned run time of 50 minutes
- **THEN** its arrival is shown as the next day's 00:30


<!-- @trace
source: timetable-draft
updated: 2026-10-25
code:
  - app/components/timetable_overrun_table_component.yml
  - app/models/route_page.rb
  - app/components/timetable_limitations_component.rb
  - app/models/route_page/measured_departures.rb
  - app/components/timetable_header_component.rb
  - app/components/timetable_sheet_component.rb
  - app/components/timetable_header_component.html.erb
  - app/views/layouts/application.html.erb
  - config/locales/tw.yml
  - app/components/site_bar_component.rb
  - app/frontend/timetable/layout.js
  - app/components/timetable_overrun_table_component.html.erb
  - app/frontend/timetable/rows.js
  - package.json
  - app/frontend/timetable/rest_windows.js
  - app/components/timetable_sheet_component.yml
  - app/frontend/timetable/edits.js
  - app/frontend/timetable/component.js
  - app/models/route_page/timetable_overruns.rb
  - app/components/timetable_sheet_component.html.erb
  - app/components/buffer_trade_component.html.erb
  - app/controllers/application_controller.rb
  - app/views/timetables/show.html.erb
  - app/models/route_page/planned_run_times.rb
  - app/controllers/timetables_controller.rb
  - app/frontend/timetable/support.js
  - app/controllers/routes_controller.rb
  - app/components/timetable_header_component.yml
  - config/routes.rb
  - app/components/buffer_trade_component.yml
  - app/components/site_bar_component.html.erb
  - docs/use-cases.md
  - config/ci.rb
  - app/frontend/entrypoints/application.js
  - app/components/buffer_trade_component.rb
  - app/frontend/timetable/format.js
  - app/components/timetable_limitations_component.yml
  - app/frontend/stylesheets/application.css
  - app/components/timetable_overrun_table_component.rb
  - app/components/timetable_limitations_component.html.erb
  - app/components/site_bar_component.yml
  - app/models/route_page/timetable.rb
  - config/locales/en.yml
  - README.md
tests:
  - spec/models/route_page/timetable_spec.rb
  - spec/components/timetable_sheet_component_spec.rb
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/timetable_overrun_table_component_spec.rb
  - spec/system/timetable_layout_spec.rb
  - spec/requests/routes_spec.rb
  - spec/system/timetable_print_spec.rb
  - app/frontend/timetable/layout.test.js
  - spec/system/timetable_entry_spec.rb
  - spec/components/timetable_header_component_spec.rb
  - app/frontend/timetable/edits.test.js
  - app/frontend/timetable/rows.test.js
  - app/frontend/timetable/rest_windows.test.js
  - spec/models/route_page/planned_run_times_spec.rb
  - spec/models/route_page/measured_departures_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/format.test.js
  - spec/models/route_page/timetable_overruns_spec.rb
-->

---
### Requirement: Rest in the tightest four-hour window of a sheet

For each vehicle the browser SHALL apply the window rule of `layover-metrics` to the sheet's planned trips: for each trip i, find the earliest trip j of the same vehicle whose arrival minus trip i's departure is at least 240 minutes; the credit of that window is the sum of the stops after trips i through j−1 that are at least 15 minutes long. The sheet SHALL state the smallest credit over its windows as the minutes of rest in the tightest four hours if one person drove the whole sheet. When no trip has such a j, the sheet SHALL state that it is shorter than four hours. The statement SHALL give the number only and SHALL NOT mark it as compliant or non-compliant.

#### Scenario: Credit of a four-trip sheet

- **WHEN** a vehicle runs 06:00 to 06:50, 07:30 to 08:15, 08:30 to 09:20 and 09:35 to 10:20
- **THEN** the sheet states 70 minutes of rest in the tightest four hours

##### Example: Windows of that sheet

| Window from | Earliest arrival at or past 240 minutes | Stops counted (at least 15 minutes) | Credit |
| --- | --- | --- | --- |
| 06:00 | 10:20 (trip 4) | 40, 15, 15 | 70 |
| 07:30 | none before the sheet ends | | no window |

#### Scenario: Short stops earn no credit

- **WHEN** a vehicle runs 06:00 to 06:50, 07:30 to 08:15, 08:25 to 09:15 and 09:25 to 10:10
- **THEN** the sheet states 40 minutes of rest in the tightest four hours

#### Scenario: Sheet shorter than four hours

- **WHEN** a vehicle's only trips run 06:00 to 06:50 and 07:30 to 08:15
- **THEN** the sheet states that it is shorter than four hours


<!-- @trace
source: timetable-draft
updated: 2026-10-25
code:
  - app/components/timetable_overrun_table_component.yml
  - app/models/route_page.rb
  - app/components/timetable_limitations_component.rb
  - app/models/route_page/measured_departures.rb
  - app/components/timetable_header_component.rb
  - app/components/timetable_sheet_component.rb
  - app/components/timetable_header_component.html.erb
  - app/views/layouts/application.html.erb
  - config/locales/tw.yml
  - app/components/site_bar_component.rb
  - app/frontend/timetable/layout.js
  - app/components/timetable_overrun_table_component.html.erb
  - app/frontend/timetable/rows.js
  - package.json
  - app/frontend/timetable/rest_windows.js
  - app/components/timetable_sheet_component.yml
  - app/frontend/timetable/edits.js
  - app/frontend/timetable/component.js
  - app/models/route_page/timetable_overruns.rb
  - app/components/timetable_sheet_component.html.erb
  - app/components/buffer_trade_component.html.erb
  - app/controllers/application_controller.rb
  - app/views/timetables/show.html.erb
  - app/models/route_page/planned_run_times.rb
  - app/controllers/timetables_controller.rb
  - app/frontend/timetable/support.js
  - app/controllers/routes_controller.rb
  - app/components/timetable_header_component.yml
  - config/routes.rb
  - app/components/buffer_trade_component.yml
  - app/components/site_bar_component.html.erb
  - docs/use-cases.md
  - config/ci.rb
  - app/frontend/entrypoints/application.js
  - app/components/buffer_trade_component.rb
  - app/frontend/timetable/format.js
  - app/components/timetable_limitations_component.yml
  - app/frontend/stylesheets/application.css
  - app/components/timetable_overrun_table_component.rb
  - app/components/timetable_limitations_component.html.erb
  - app/components/site_bar_component.yml
  - app/models/route_page/timetable.rb
  - config/locales/en.yml
  - README.md
tests:
  - spec/models/route_page/timetable_spec.rb
  - spec/components/timetable_sheet_component_spec.rb
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/timetable_overrun_table_component_spec.rb
  - spec/system/timetable_layout_spec.rb
  - spec/requests/routes_spec.rb
  - spec/system/timetable_print_spec.rb
  - app/frontend/timetable/layout.test.js
  - spec/system/timetable_entry_spec.rb
  - spec/components/timetable_header_component_spec.rb
  - app/frontend/timetable/edits.test.js
  - app/frontend/timetable/rows.test.js
  - app/frontend/timetable/rest_windows.test.js
  - spec/models/route_page/planned_run_times_spec.rb
  - spec/models/route_page/measured_departures_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/format.test.js
  - spec/models/route_page/timetable_overruns_spec.rb
-->

---
### Requirement: Overrun table against the measured trips

For each percentile q in 50, 55, 60, 65, 70, 75, 80, 85, 90 and 95, the page SHALL take every trip with a run time of the covered days, compute its planned run time at q by the Planned run time requirement, and its overrun as the run time minus the planned run time, zero when negative. The table SHALL give per q: the share of trips with an overrun above zero, the share of trips whose overrun is above zero and at least the initial rest minutes, and the median overrun in minutes to one decimal over the trips with an overrun above zero, or a dash when there is none. The row of the percentile in use SHALL be emphasized, and the emphasis SHALL move when the percentile is changed in the browser. The page SHALL state below the table that trips are judged one by one and that a late trip's effect on the next departure is not followed.

#### Scenario: Overruns of five trips

- **WHEN** the only trips with a run time are direction 0 in the 06 hour with 44, 47, 50, 52 and 60 minutes and the rest minutes are 15
- **THEN** the row of 50 reports 40.0% overrun, 0.0% exhausting the rest and a median overrun of 6.0, and the row of 85 reports 20.0%, 0.0% and 5.0

##### Example: Rows for those trips

| q | Planned | Overruns | Overrun share | Exhausted share | Median overrun |
| --- | --- | --- | --- | --- | --- |
| 50 | 50 | 2, 10 | 40.0% | 0.0% | 6.0 |
| 85 | 55 | 5 | 20.0% | 0.0% | 5.0 |
| 95 | 58 | 2 | 20.0% | 0.0% | 2.0 |

#### Scenario: Rest exhausted

- **WHEN** the rest minutes are 5 and the trips are those of the previous scenario
- **THEN** the row of 50 reports 20.0% exhausting the rest

#### Scenario: Emphasis follows the percentile

- **WHEN** the page was opened with p 85 and the dispatcher changes the percentile control to 50
- **THEN** the row of 50 is the only emphasized row


<!-- @trace
source: timetable-draft
updated: 2026-10-25
code:
  - app/components/timetable_overrun_table_component.yml
  - app/models/route_page.rb
  - app/components/timetable_limitations_component.rb
  - app/models/route_page/measured_departures.rb
  - app/components/timetable_header_component.rb
  - app/components/timetable_sheet_component.rb
  - app/components/timetable_header_component.html.erb
  - app/views/layouts/application.html.erb
  - config/locales/tw.yml
  - app/components/site_bar_component.rb
  - app/frontend/timetable/layout.js
  - app/components/timetable_overrun_table_component.html.erb
  - app/frontend/timetable/rows.js
  - package.json
  - app/frontend/timetable/rest_windows.js
  - app/components/timetable_sheet_component.yml
  - app/frontend/timetable/edits.js
  - app/frontend/timetable/component.js
  - app/models/route_page/timetable_overruns.rb
  - app/components/timetable_sheet_component.html.erb
  - app/components/buffer_trade_component.html.erb
  - app/controllers/application_controller.rb
  - app/views/timetables/show.html.erb
  - app/models/route_page/planned_run_times.rb
  - app/controllers/timetables_controller.rb
  - app/frontend/timetable/support.js
  - app/controllers/routes_controller.rb
  - app/components/timetable_header_component.yml
  - config/routes.rb
  - app/components/buffer_trade_component.yml
  - app/components/site_bar_component.html.erb
  - docs/use-cases.md
  - config/ci.rb
  - app/frontend/entrypoints/application.js
  - app/components/buffer_trade_component.rb
  - app/frontend/timetable/format.js
  - app/components/timetable_limitations_component.yml
  - app/frontend/stylesheets/application.css
  - app/components/timetable_overrun_table_component.rb
  - app/components/timetable_limitations_component.html.erb
  - app/components/site_bar_component.yml
  - app/models/route_page/timetable.rb
  - config/locales/en.yml
  - README.md
tests:
  - spec/models/route_page/timetable_spec.rb
  - spec/components/timetable_sheet_component_spec.rb
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/timetable_overrun_table_component_spec.rb
  - spec/system/timetable_layout_spec.rb
  - spec/requests/routes_spec.rb
  - spec/system/timetable_print_spec.rb
  - app/frontend/timetable/layout.test.js
  - spec/system/timetable_entry_spec.rb
  - spec/components/timetable_header_component_spec.rb
  - app/frontend/timetable/edits.test.js
  - app/frontend/timetable/rows.test.js
  - app/frontend/timetable/rest_windows.test.js
  - spec/models/route_page/planned_run_times_spec.rb
  - spec/models/route_page/measured_departures_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/format.test.js
  - spec/models/route_page/timetable_overruns_spec.rb
-->

---
### Requirement: Header, controls and limitations of the timetable

The page SHALL show, before the sheets: the route name; the covered days and their day type as the route page states them; the average number of distinct vehicles per covered day as `buffer-trade` reports it; the number of vehicles of the timetable and the number of departures per direction, recomputed from the sheets as shown; and the number of manually edited cells. It SHALL show controls for the percentile, the rest minutes and the departures per direction and hour, filled with the values in use, and next to the controls the statement that changing them lays the timetable out again and discards manual edits. Changing a control SHALL lay the timetable out again in the browser without a request. After the sheets and the overrun table, the page SHALL state the limitations of the timetable: a sheet is a vehicle and not a driver; planned run times are measured percentiles, not guarantees; the hold at a pass-through end is the measured median and is not rest; a negative stop means the trips do not connect; trips missing a terminal are left out of run times; the default departures are the measured average and include every trip. The page SHALL carry the attribution footer of `site-layout`. The document title SHALL carry the route name, the word 班表 and the site name.

#### Scenario: Header content

- **WHEN** the timetable of route 9001 for 2026-10-19 is laid out with defaults from the four-departure day
- **THEN** the header shows the route name, 2026-10-19 with its day type, the vehicles per day of the covered days, 3 vehicles, 2 departures in each direction and 0 edited cells, and the controls read p 85, 15 rest minutes and the measured departures

#### Scenario: Regeneration in the browser

- **WHEN** the dispatcher changes the departures of direction 0 in hour 6 from 2 to 1 on the four-departure day
- **THEN** without a request the page shows 2 vehicles, 1 departure in direction 0 and 2 in direction 1, and the statement that changing the controls discards manual edits is present next to the controls

#### Scenario: Attribution on the timetable page

- **WHEN** `/routes/9001/timetable` is requested
- **THEN** exactly one `footer[data-attribution][data-license="OGDL-Taiwan-1.0"]` is present


<!-- @trace
source: timetable-draft
updated: 2026-10-25
code:
  - app/components/timetable_overrun_table_component.yml
  - app/models/route_page.rb
  - app/components/timetable_limitations_component.rb
  - app/models/route_page/measured_departures.rb
  - app/components/timetable_header_component.rb
  - app/components/timetable_sheet_component.rb
  - app/components/timetable_header_component.html.erb
  - app/views/layouts/application.html.erb
  - config/locales/tw.yml
  - app/components/site_bar_component.rb
  - app/frontend/timetable/layout.js
  - app/components/timetable_overrun_table_component.html.erb
  - app/frontend/timetable/rows.js
  - package.json
  - app/frontend/timetable/rest_windows.js
  - app/components/timetable_sheet_component.yml
  - app/frontend/timetable/edits.js
  - app/frontend/timetable/component.js
  - app/models/route_page/timetable_overruns.rb
  - app/components/timetable_sheet_component.html.erb
  - app/components/buffer_trade_component.html.erb
  - app/controllers/application_controller.rb
  - app/views/timetables/show.html.erb
  - app/models/route_page/planned_run_times.rb
  - app/controllers/timetables_controller.rb
  - app/frontend/timetable/support.js
  - app/controllers/routes_controller.rb
  - app/components/timetable_header_component.yml
  - config/routes.rb
  - app/components/buffer_trade_component.yml
  - app/components/site_bar_component.html.erb
  - docs/use-cases.md
  - config/ci.rb
  - app/frontend/entrypoints/application.js
  - app/components/buffer_trade_component.rb
  - app/frontend/timetable/format.js
  - app/components/timetable_limitations_component.yml
  - app/frontend/stylesheets/application.css
  - app/components/timetable_overrun_table_component.rb
  - app/components/timetable_limitations_component.html.erb
  - app/components/site_bar_component.yml
  - app/models/route_page/timetable.rb
  - config/locales/en.yml
  - README.md
tests:
  - spec/models/route_page/timetable_spec.rb
  - spec/components/timetable_sheet_component_spec.rb
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/timetable_overrun_table_component_spec.rb
  - spec/system/timetable_layout_spec.rb
  - spec/requests/routes_spec.rb
  - spec/system/timetable_print_spec.rb
  - app/frontend/timetable/layout.test.js
  - spec/system/timetable_entry_spec.rb
  - spec/components/timetable_header_component_spec.rb
  - app/frontend/timetable/edits.test.js
  - app/frontend/timetable/rows.test.js
  - app/frontend/timetable/rest_windows.test.js
  - spec/models/route_page/planned_run_times_spec.rb
  - spec/models/route_page/measured_departures_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/format.test.js
  - spec/models/route_page/timetable_overruns_spec.rb
-->

---
### Requirement: Manual edits recomputed in the browser

The two departure times of each row SHALL be editable cells. The page SHALL offer, per row, a control that deletes that row's trips, and, per sheet, a control that adds a row from a typed departure time of the sheet's first direction, whose second trip departs at the first trip's arrival plus the hold at that end. On an edit the browser SHALL recompute, without a request and storing nothing, every arrival, stop, four-hour credit and header total from the departures as they now stand, leaving every other departure time unchanged. A stop that comes out negative SHALL be shown as a negative number of minutes. A trip SHALL be marked edited when its departure was typed, or when it belongs to an added row, until the timetable is laid out again; edited departure cells SHALL be marked on the page and counted in the header. A typed departure time that is not `HH:MM` of the service day, with hours 00 to 29 and minutes 00 to 59, SHALL be rejected: the cell SHALL be marked invalid and keep its previous departure.

#### Scenario: Changing a return departure

- **WHEN** vehicle 1's row reads 06:00, 甲站, 06:50, 40, 07:30, 08:15 and the dispatcher types 07:20 as the second departure with a planned run time of 45 minutes in the 07 hour
- **THEN** the row reads 06:00, 甲站, 06:50, 30, 07:20, 08:05, the 07:20 cell is marked edited, and the header counts 1 edited cell

#### Scenario: Edit that does not connect

- **WHEN** the dispatcher types 06:45 as the second departure of that row
- **THEN** the row's first stop reads −5

#### Scenario: Deleting a row

- **WHEN** a sheet has rows departing 06:00 and 08:30 and the dispatcher deletes the first row
- **THEN** the sheet has one row numbered 1 departing 08:30

#### Scenario: Adding a row

- **WHEN** the dispatcher adds a row to vehicle 1 with the departure 11:00, the planned run time of direction 0 in the 11 hour is 48 minutes, the hold at that end is 15 minutes and the planned run time of direction 1 in the 12 hour is 46 minutes
- **THEN** the sheet gains a row 11:00, 甲站, 11:48, 15, 12:03, 12:49 with both departure cells marked edited

#### Scenario: Malformed time

- **WHEN** a departure time is typed as `25:70`
- **THEN** the cell is marked invalid, keeps its previous departure, and nothing else on the page changes

##### Example: Typed times

| Typed | Accepted as | Notes |
| --- | --- | --- |
| 06:00 | 360 minutes | |
| 24:45 | 1485 minutes | after midnight, same service day |
| 25:70 | rejected | minutes above 59 |
| 6:00 | rejected | two digits each |
| 30:00 | rejected | hours above 29 |


<!-- @trace
source: timetable-draft
updated: 2026-10-25
code:
  - app/components/timetable_overrun_table_component.yml
  - app/models/route_page.rb
  - app/components/timetable_limitations_component.rb
  - app/models/route_page/measured_departures.rb
  - app/components/timetable_header_component.rb
  - app/components/timetable_sheet_component.rb
  - app/components/timetable_header_component.html.erb
  - app/views/layouts/application.html.erb
  - config/locales/tw.yml
  - app/components/site_bar_component.rb
  - app/frontend/timetable/layout.js
  - app/components/timetable_overrun_table_component.html.erb
  - app/frontend/timetable/rows.js
  - package.json
  - app/frontend/timetable/rest_windows.js
  - app/components/timetable_sheet_component.yml
  - app/frontend/timetable/edits.js
  - app/frontend/timetable/component.js
  - app/models/route_page/timetable_overruns.rb
  - app/components/timetable_sheet_component.html.erb
  - app/components/buffer_trade_component.html.erb
  - app/controllers/application_controller.rb
  - app/views/timetables/show.html.erb
  - app/models/route_page/planned_run_times.rb
  - app/controllers/timetables_controller.rb
  - app/frontend/timetable/support.js
  - app/controllers/routes_controller.rb
  - app/components/timetable_header_component.yml
  - config/routes.rb
  - app/components/buffer_trade_component.yml
  - app/components/site_bar_component.html.erb
  - docs/use-cases.md
  - config/ci.rb
  - app/frontend/entrypoints/application.js
  - app/components/buffer_trade_component.rb
  - app/frontend/timetable/format.js
  - app/components/timetable_limitations_component.yml
  - app/frontend/stylesheets/application.css
  - app/components/timetable_overrun_table_component.rb
  - app/components/timetable_limitations_component.html.erb
  - app/components/site_bar_component.yml
  - app/models/route_page/timetable.rb
  - config/locales/en.yml
  - README.md
tests:
  - spec/models/route_page/timetable_spec.rb
  - spec/components/timetable_sheet_component_spec.rb
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/timetable_overrun_table_component_spec.rb
  - spec/system/timetable_layout_spec.rb
  - spec/requests/routes_spec.rb
  - spec/system/timetable_print_spec.rb
  - app/frontend/timetable/layout.test.js
  - spec/system/timetable_entry_spec.rb
  - spec/components/timetable_header_component_spec.rb
  - app/frontend/timetable/edits.test.js
  - app/frontend/timetable/rows.test.js
  - app/frontend/timetable/rest_windows.test.js
  - spec/models/route_page/planned_run_times_spec.rb
  - spec/models/route_page/measured_departures_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/format.test.js
  - spec/models/route_page/timetable_overruns_spec.rb
-->

---
### Requirement: Adding a vehicle

Below the sheets the page SHALL offer a control that adds a vehicle from a chosen direction and a typed departure time: a new sheet numbered one above the highest vehicle number on the page, whose first trip departs in the chosen direction at the typed time and whose second trip departs at the first trip's arrival plus the hold at that end, both marked edited. The added vehicle SHALL count in the header's totals and SHALL take further rows through its own add control like any sheet. A typed time that is not `HH:MM` of the service day SHALL be rejected as for an added row: the control is marked invalid and nothing is added. Laying the timetable out again from the controls SHALL discard added vehicles like other manual edits. Without JavaScript the control SHALL be hidden.

#### Scenario: Adding a vehicle

- **WHEN** the four-departure timetable shows vehicles 1 to 3 and the dispatcher adds a vehicle in direction 1 at 15:00, the planned run time of direction 1 in the 15 hour is 45 minutes, the hold at that end is 15 minutes and the planned run time of direction 0 in the 16 hour is 50 minutes
- **THEN** a sheet 4 appears with one row 15:00, 乙站, 15:45, 15, 16:00, 16:50, both departure cells marked edited, and the header counts 4 vehicles and 2 edited cells

#### Scenario: Numbering after a deleted vehicle

- **WHEN** vehicle 2's only row was deleted so the page shows vehicles 1 and 3, and the dispatcher adds a vehicle
- **THEN** the new sheet is vehicle 4


<!-- @trace
source: timetable-draft
updated: 2026-10-25
code:
  - app/components/timetable_overrun_table_component.yml
  - app/models/route_page.rb
  - app/components/timetable_limitations_component.rb
  - app/models/route_page/measured_departures.rb
  - app/components/timetable_header_component.rb
  - app/components/timetable_sheet_component.rb
  - app/components/timetable_header_component.html.erb
  - app/views/layouts/application.html.erb
  - config/locales/tw.yml
  - app/components/site_bar_component.rb
  - app/frontend/timetable/layout.js
  - app/components/timetable_overrun_table_component.html.erb
  - app/frontend/timetable/rows.js
  - package.json
  - app/frontend/timetable/rest_windows.js
  - app/components/timetable_sheet_component.yml
  - app/frontend/timetable/edits.js
  - app/frontend/timetable/component.js
  - app/models/route_page/timetable_overruns.rb
  - app/components/timetable_sheet_component.html.erb
  - app/components/buffer_trade_component.html.erb
  - app/controllers/application_controller.rb
  - app/views/timetables/show.html.erb
  - app/models/route_page/planned_run_times.rb
  - app/controllers/timetables_controller.rb
  - app/frontend/timetable/support.js
  - app/controllers/routes_controller.rb
  - app/components/timetable_header_component.yml
  - config/routes.rb
  - app/components/buffer_trade_component.yml
  - app/components/site_bar_component.html.erb
  - docs/use-cases.md
  - config/ci.rb
  - app/frontend/entrypoints/application.js
  - app/components/buffer_trade_component.rb
  - app/frontend/timetable/format.js
  - app/components/timetable_limitations_component.yml
  - app/frontend/stylesheets/application.css
  - app/components/timetable_overrun_table_component.rb
  - app/components/timetable_limitations_component.html.erb
  - app/components/site_bar_component.yml
  - app/models/route_page/timetable.rb
  - config/locales/en.yml
  - README.md
tests:
  - spec/models/route_page/timetable_spec.rb
  - spec/components/timetable_sheet_component_spec.rb
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/timetable_overrun_table_component_spec.rb
  - spec/system/timetable_layout_spec.rb
  - spec/requests/routes_spec.rb
  - spec/system/timetable_print_spec.rb
  - app/frontend/timetable/layout.test.js
  - spec/system/timetable_entry_spec.rb
  - spec/components/timetable_header_component_spec.rb
  - app/frontend/timetable/edits.test.js
  - app/frontend/timetable/rows.test.js
  - app/frontend/timetable/rest_windows.test.js
  - spec/models/route_page/planned_run_times_spec.rb
  - spec/models/route_page/measured_departures_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/format.test.js
  - spec/models/route_page/timetable_overruns_spec.rb
-->

---
### Requirement: Parameters in the address

When the percentile or the rest minutes are changed in the browser, the page SHALL write the new `p` and `buffer` into the address without adding a history entry, keeping `day` and `range`, so that reloading the page lays the timetable out again with the same parameters. The departures per hour and the manual edits SHALL NOT be written into the address.

#### Scenario: Reload keeps the parameters

- **WHEN** the dispatcher opens `/routes/9001/timetable?day=2026-10-19&range=7d`, changes the rest minutes to 10 and the percentile to 50
- **THEN** the address reads `day=2026-10-19`, `range=7d`, `buffer=10` and `p=50`, the history has no new entry, and reloading shows 10 rest minutes and p 50


<!-- @trace
source: timetable-draft
updated: 2026-10-25
code:
  - app/components/timetable_overrun_table_component.yml
  - app/models/route_page.rb
  - app/components/timetable_limitations_component.rb
  - app/models/route_page/measured_departures.rb
  - app/components/timetable_header_component.rb
  - app/components/timetable_sheet_component.rb
  - app/components/timetable_header_component.html.erb
  - app/views/layouts/application.html.erb
  - config/locales/tw.yml
  - app/components/site_bar_component.rb
  - app/frontend/timetable/layout.js
  - app/components/timetable_overrun_table_component.html.erb
  - app/frontend/timetable/rows.js
  - package.json
  - app/frontend/timetable/rest_windows.js
  - app/components/timetable_sheet_component.yml
  - app/frontend/timetable/edits.js
  - app/frontend/timetable/component.js
  - app/models/route_page/timetable_overruns.rb
  - app/components/timetable_sheet_component.html.erb
  - app/components/buffer_trade_component.html.erb
  - app/controllers/application_controller.rb
  - app/views/timetables/show.html.erb
  - app/models/route_page/planned_run_times.rb
  - app/controllers/timetables_controller.rb
  - app/frontend/timetable/support.js
  - app/controllers/routes_controller.rb
  - app/components/timetable_header_component.yml
  - config/routes.rb
  - app/components/buffer_trade_component.yml
  - app/components/site_bar_component.html.erb
  - docs/use-cases.md
  - config/ci.rb
  - app/frontend/entrypoints/application.js
  - app/components/buffer_trade_component.rb
  - app/frontend/timetable/format.js
  - app/components/timetable_limitations_component.yml
  - app/frontend/stylesheets/application.css
  - app/components/timetable_overrun_table_component.rb
  - app/components/timetable_limitations_component.html.erb
  - app/components/site_bar_component.yml
  - app/models/route_page/timetable.rb
  - config/locales/en.yml
  - README.md
tests:
  - spec/models/route_page/timetable_spec.rb
  - spec/components/timetable_sheet_component_spec.rb
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/timetable_overrun_table_component_spec.rb
  - spec/system/timetable_layout_spec.rb
  - spec/requests/routes_spec.rb
  - spec/system/timetable_print_spec.rb
  - app/frontend/timetable/layout.test.js
  - spec/system/timetable_entry_spec.rb
  - spec/components/timetable_header_component_spec.rb
  - app/frontend/timetable/edits.test.js
  - app/frontend/timetable/rows.test.js
  - app/frontend/timetable/rest_windows.test.js
  - spec/models/route_page/planned_run_times_spec.rb
  - spec/models/route_page/measured_departures_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/format.test.js
  - spec/models/route_page/timetable_overruns_spec.rb
-->

---
### Requirement: Printing the timetable

The page SHALL carry print styles under which each vehicle's sheet is printed as a form like the paper trip sheet, on a page of its own: a title line with blanks for the company and the depot and the route name; a line with 車次 and the sheet's number, a blank 車號 for filling in by hand, and blanks for the year, month, day and weekday; a line naming what the sheet was laid out from (the covered day or days with their day type, the percentile and the rest minutes in use); and the table with ruled lines around every cell, rows tall enough to write in, and blank rows added after the trips until the sheet has at least 14 rows. The page's header, the sheet's on-screen title, the site name bar, the controls, the regeneration statement, the print control, the add-vehicle control, the edit controls and the typed-time fields are not printed; departure times are printed as text; a row is not split across pages; and the overrun table, the limitations and the attribution footer follow on a page of their own after the last sheet. The blank rows SHALL NOT be shown on screen. The print styles SHALL break pages with both the `break-*` and the older `page-break-*` properties, so that Safari breaks them too, and SHALL lay the pages out landscape by default. The page SHALL offer a print control that opens the browser's print dialog.

#### Scenario: Print control

- **WHEN** the timetable page is opened and the sheets are laid out
- **THEN** a print control is visible and activating it calls the browser's print function

#### Scenario: One vehicle per printed page

- **WHEN** the page is printed with three vehicles laid out from the four-departure day of 2026-10-19 at p85 with 15 rest minutes
- **THEN** each of the three sheets ends with a page break, each is headed by the form's title with the route name, 車次 and its number, a blank 車號, the date blanks and the line with 2026-10-19, its day type, p85 and 15 rest minutes, each prints at least 14 rows of which the blank ones are not shown on screen, the page's header is not printed, and the overrun table, the limitations and the footer are printed after the last sheet on a page of their own


<!-- @trace
source: timetable-draft
updated: 2026-10-25
code:
  - app/components/timetable_overrun_table_component.yml
  - app/models/route_page.rb
  - app/components/timetable_limitations_component.rb
  - app/models/route_page/measured_departures.rb
  - app/components/timetable_header_component.rb
  - app/components/timetable_sheet_component.rb
  - app/components/timetable_header_component.html.erb
  - app/views/layouts/application.html.erb
  - config/locales/tw.yml
  - app/components/site_bar_component.rb
  - app/frontend/timetable/layout.js
  - app/components/timetable_overrun_table_component.html.erb
  - app/frontend/timetable/rows.js
  - package.json
  - app/frontend/timetable/rest_windows.js
  - app/components/timetable_sheet_component.yml
  - app/frontend/timetable/edits.js
  - app/frontend/timetable/component.js
  - app/models/route_page/timetable_overruns.rb
  - app/components/timetable_sheet_component.html.erb
  - app/components/buffer_trade_component.html.erb
  - app/controllers/application_controller.rb
  - app/views/timetables/show.html.erb
  - app/models/route_page/planned_run_times.rb
  - app/controllers/timetables_controller.rb
  - app/frontend/timetable/support.js
  - app/controllers/routes_controller.rb
  - app/components/timetable_header_component.yml
  - config/routes.rb
  - app/components/buffer_trade_component.yml
  - app/components/site_bar_component.html.erb
  - docs/use-cases.md
  - config/ci.rb
  - app/frontend/entrypoints/application.js
  - app/components/buffer_trade_component.rb
  - app/frontend/timetable/format.js
  - app/components/timetable_limitations_component.yml
  - app/frontend/stylesheets/application.css
  - app/components/timetable_overrun_table_component.rb
  - app/components/timetable_limitations_component.html.erb
  - app/components/site_bar_component.yml
  - app/models/route_page/timetable.rb
  - config/locales/en.yml
  - README.md
tests:
  - spec/models/route_page/timetable_spec.rb
  - spec/components/timetable_sheet_component_spec.rb
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/timetable_overrun_table_component_spec.rb
  - spec/system/timetable_layout_spec.rb
  - spec/requests/routes_spec.rb
  - spec/system/timetable_print_spec.rb
  - app/frontend/timetable/layout.test.js
  - spec/system/timetable_entry_spec.rb
  - spec/components/timetable_header_component_spec.rb
  - app/frontend/timetable/edits.test.js
  - app/frontend/timetable/rows.test.js
  - app/frontend/timetable/rest_windows.test.js
  - spec/models/route_page/planned_run_times_spec.rb
  - spec/models/route_page/measured_departures_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/format.test.js
  - spec/models/route_page/timetable_overruns_spec.rb
-->

---
### Requirement: Without JavaScript

When the page is fetched without running any script, it SHALL contain the statement that the page needs JavaScript to lay out the timetable, no vehicle sheet, and no print control, while the header, the overrun table, the limitations and the attribution footer are present. Once the script runs, the statement SHALL be hidden.

#### Scenario: Server output

- **WHEN** `/routes/9001/timetable` is fetched without running any script on the four-departure day
- **THEN** the response contains the statement marked `data-needs-script`, the embedded timetable data, the overrun table and the limitations, and contains no vehicle sheet

#### Scenario: Script hides the statement

- **WHEN** the page is opened in a browser with JavaScript
- **THEN** the statement is not displayed and the sheets are

<!-- @trace
source: timetable-draft
updated: 2026-10-25
code:
  - app/components/timetable_overrun_table_component.yml
  - app/models/route_page.rb
  - app/components/timetable_limitations_component.rb
  - app/models/route_page/measured_departures.rb
  - app/components/timetable_header_component.rb
  - app/components/timetable_sheet_component.rb
  - app/components/timetable_header_component.html.erb
  - app/views/layouts/application.html.erb
  - config/locales/tw.yml
  - app/components/site_bar_component.rb
  - app/frontend/timetable/layout.js
  - app/components/timetable_overrun_table_component.html.erb
  - app/frontend/timetable/rows.js
  - package.json
  - app/frontend/timetable/rest_windows.js
  - app/components/timetable_sheet_component.yml
  - app/frontend/timetable/edits.js
  - app/frontend/timetable/component.js
  - app/models/route_page/timetable_overruns.rb
  - app/components/timetable_sheet_component.html.erb
  - app/components/buffer_trade_component.html.erb
  - app/controllers/application_controller.rb
  - app/views/timetables/show.html.erb
  - app/models/route_page/planned_run_times.rb
  - app/controllers/timetables_controller.rb
  - app/frontend/timetable/support.js
  - app/controllers/routes_controller.rb
  - app/components/timetable_header_component.yml
  - config/routes.rb
  - app/components/buffer_trade_component.yml
  - app/components/site_bar_component.html.erb
  - docs/use-cases.md
  - config/ci.rb
  - app/frontend/entrypoints/application.js
  - app/components/buffer_trade_component.rb
  - app/frontend/timetable/format.js
  - app/components/timetable_limitations_component.yml
  - app/frontend/stylesheets/application.css
  - app/components/timetable_overrun_table_component.rb
  - app/components/timetable_limitations_component.html.erb
  - app/components/site_bar_component.yml
  - app/models/route_page/timetable.rb
  - config/locales/en.yml
  - README.md
tests:
  - spec/models/route_page/timetable_spec.rb
  - spec/components/timetable_sheet_component_spec.rb
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/timetable_overrun_table_component_spec.rb
  - spec/system/timetable_layout_spec.rb
  - spec/requests/routes_spec.rb
  - spec/system/timetable_print_spec.rb
  - app/frontend/timetable/layout.test.js
  - spec/system/timetable_entry_spec.rb
  - spec/components/timetable_header_component_spec.rb
  - app/frontend/timetable/edits.test.js
  - app/frontend/timetable/rows.test.js
  - app/frontend/timetable/rest_windows.test.js
  - spec/models/route_page/planned_run_times_spec.rb
  - spec/models/route_page/measured_departures_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/format.test.js
  - spec/models/route_page/timetable_overruns_spec.rb
-->