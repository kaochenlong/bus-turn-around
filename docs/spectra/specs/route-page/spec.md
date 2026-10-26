# route-page Specification

## Purpose

A web page per route that shows drivers and station managers how the route ran on a Taipei day or over the last 7 days: trip counts, run times, layovers at each end and the load profile. It reads only the derived tables and never shows a vehicle identifier.

## Requirements

### Requirement: Route page address and parameters

The system SHALL serve `GET /routes/:route_id` for route `Id`s listed in the route list configuration, and SHALL respond 404 with the site's not-found page, as defined by `not-found-page`, for any other route `Id`. The optional parameter `day` (`YYYY-MM-DD`) selects a Taipei day and defaults to the latest day stored for the route; the optional parameter `range` is `day` or `7d` and defaults to `day`; the optional parameter `buffer` is the buffer in minutes of `buffer-trade`, shown as the rest, and defaults to 15; the optional parameter `late` is the lateness of `buffer-trade` and defaults to 0; the optional parameters `from` and `to` are the first and last selected hours of `buffer-trade` and default to 0 and 24; the optional parameter `end` is the selected end of `buffer-trade` and defaults to every stopping end. A malformed `day`, any other `range` value, or a `buffer`, `late`, `from`, `to` or `end` value that `buffer-trade` rejects SHALL respond 400.

#### Scenario: Route not configured

- **WHEN** a visitor requests `/routes/9999` and 9999 is not in the route list
- **THEN** the response is 404 and its body is the content of `public/404.html`

#### Scenario: Defaults

- **WHEN** route 9001 has stored days 2026-10-19 and 2026-10-20 and a visitor requests `/routes/9001`
- **THEN** the page shows 2026-10-20 with the range of one day, a buffer of 15 minutes and a lateness of 0 minutes over the whole day at every stopping end

#### Scenario: Bad parameter

- **WHEN** a visitor requests `/routes/9001?range=30d`
- **THEN** the response is 400

#### Scenario: Bad buffer

- **WHEN** a visitor requests `/routes/9001?buffer=21`
- **THEN** the response is 400

#### Scenario: Bad lateness, hours or end

- **WHEN** a visitor requests the page of route 9001 with one of the values below
- **THEN** the response is 400

##### Example: rejected estimate parameters

| Request | Why |
| --- | --- |
| `/routes/9001?late=21` | the lateness is above 20 |
| `/routes/9001?from=10&to=9` | the first hour is not below the last |
| `/routes/9001?end=2` | not a direction |


<!-- @trace
source: buffer-trade-cost-curve
updated: 2026-10-24
code:
  - app/components/mrt_overlap_component.html.erb
  - analysis/end_nature_survey.sql
  - app/components/buffer_trade_component.yml
  - app/components/buffer_trade_component.html.erb
  - app/components/layover_chart_component.rb
  - lib/analysis_run.rb
  - lib/tasks/survey.rake
  - app/components/route_coverage_component.html.erb
  - app/components/layover_table_component.html.erb
  - app/components/run_time_table_component.html.erb
  - app/components/stop_sequence_component.yml
  - app/models/route_day_loader.rb
  - app/components/layover_table_component.yml
  - analysis/end_nature_evidence.sql
  - app/controllers/routes_controller.rb
  - app/components/cycle_table_component.html.erb
  - app/components/home_hero_component.html.erb
  - app/components/load_chart_component.html.erb
  - config/route_page.yml
  - app/models/route_page/buffer_trade.rb
  - app/components/data_limitations_component.yml
  - docs/decisions.md
  - app/components/turnaround_facilities_component.html.erb
  - analysis/params.sql
  - app/components/layover_chart_component.yml
  - app/models/raw_day_check.rb
  - docs/background.md
  - app/components/origin_story_component.html.erb
  - app/components/site_bar_component.rb
  - analysis/README.md
  - app/components/turnaround_facilities_component.yml
  - README.md
  - app/models/newest_snapshot.rb
  - app/components/buffer_trade_component.rb
  - app/components/site_bar_component.yml
  - app/components/site_bar_component.html.erb
  - app/frontend/entrypoints/application.js
  - analysis/end_nature_export.sql
  - app/components/section_nav_component.html.erb
  - app/components/layover_chart_component.html.erb
  - app/models/derived_load_command.rb
  - app/models/end_nature_survey_command.rb
  - app/views/routes/show.html.erb
  - app/components/route_summary_component.yml
tests:
  - spec/analysis/end_nature_export_spec.rb
  - spec/components/route_summary_component_spec.rb
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/system/rest_command_spec.rb
  - spec/components/layover_table_component_spec.rb
  - spec/models/raw_day_check_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/components/buffer_trade_component_spec.rb
  - spec/components/cycle_table_component_spec.rb
  - spec/models/route_page/ends_spec.rb
  - spec/models/end_nature_survey_command_spec.rb
  - spec/system/end_map_spec.rb
  - spec/components/layover_chart_component_spec.rb
  - spec/models/newest_snapshot_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/route_page/cycles_spec.rb
  - spec/analysis/end_nature_evidence_spec.rb
  - spec/components/stop_sequence_component_spec.rb
  - spec/models/route_page/buffer_trade_spec.rb
  - spec/analysis/analysis_run_spec.rb
  - spec/analysis/end_nature_survey_spec.rb
  - spec/requests/routes_spec.rb
  - spec/system/buffer_trade_spec.rb
-->

---
### Requirement: Day coverage

With `range=day` the page SHALL cover the selected day. With `range=7d` it SHALL cover the selected day and those of the six Taipei days before it that are stored for the route and have the same day type as the selected day, as defined by `day-types`. The page SHALL state whether the covered days are weekdays or holidays in a day type tag, and SHALL list each covered date as a tag whose text is the date with its day of week and nothing else. A covered date with a calendar note SHALL carry the note as the title of its tag, shown when a pointer rests on the tag, and a covered date without a note SHALL carry no title. The day type tag and every date tag SHALL be green when the covered days are holidays and SHALL keep the neutral grey of the page's tags when they are weekdays. The page SHALL link to the latest stored day on or before the selected day whose day type differs from the selected day's, keeping the range and naming that day and its day type; when there is no such day, the page SHALL NOT show that link. When the selected day is not stored, the page SHALL respond 200, state that the day has no data and list the stored days.

#### Scenario: Seven days with gaps

- **WHEN** route 9001 has the stored weekdays 2026-10-19, 2026-10-20 and 2026-10-22 and a visitor requests `?day=2026-10-22&range=7d`
- **THEN** the page covers exactly 2026-10-19, 2026-10-20 and 2026-10-22, states that they are weekdays and lists them with their days of week

#### Scenario: Seven days keep the selected day's type

- **WHEN** route 9001 has stored weekdays and holidays in the same seven Taipei days and a visitor selects a holiday with `range=7d`
- **THEN** the page covers only the holidays of those seven days and links to the latest weekday before them

##### Example: the Retrocession Day weekend

- **GIVEN** route 9001 has the stored weekdays 2026-10-19 to 2026-10-23 and the stored holidays 2026-10-24, 2026-10-25 and 2026-10-26, the last with the note 補假
- **WHEN** a visitor requests `/routes/9001?day=2026-10-26&range=7d`
- **THEN** the page states holidays, covers exactly the tags 2026-10-24（六）, 2026-10-25（日） and 2026-10-26（一）, the last with the title 補假 and the other two with no title, and links to `/routes/9001?day=2026-10-23&range=7d`, naming 2026-10-23（五） and weekdays

#### Scenario: No day of the other type before the selected day

- **WHEN** route 9001 has the stored weekdays 2026-10-19 to 2026-10-23 and the stored holidays 2026-10-24 to 2026-10-26, and a visitor requests `?day=2026-10-23&range=7d`
- **THEN** the page covers 2026-10-19 to 2026-10-23, states weekdays and shows no link to holidays

#### Scenario: One day states its type

- **WHEN** route 9001 has the stored weekday 2026-10-23 and the stored holiday 2026-10-26 with the note 補假, and a visitor requests `/routes/9001` without parameters
- **THEN** the page covers 2026-10-26, states that it is a holiday, shows the tag 2026-10-26（一） with the title 補假 and links to `/routes/9001?day=2026-10-23&range=day`

#### Scenario: Tag colour follows the day type

- **WHEN** a visitor requests a day of route 9001 with `range=7d`
- **THEN** the day type tag and every date tag are green when the covered days are holidays and grey when they are weekdays

##### Example: both day types

- **GIVEN** route 9001 has the stored weekdays 2026-10-19 to 2026-10-23 and the stored holidays 2026-10-24 to 2026-10-26

| Request | Day type tag | Date tags |
| --- | --- | --- |
| `?day=2026-10-26&range=7d` | 假日, green | 2026-10-24（六）, 2026-10-25（日）, 2026-10-26（一）, all green |
| `?day=2026-10-23&range=7d` | 平日, grey | 2026-10-19（一） to 2026-10-23（五）, all grey |

#### Scenario: Day without data

- **WHEN** a visitor requests `?day=2026-10-25` for route 9001 and that day is not stored
- **THEN** the response is 200, the page says the day has no data and lists the stored days


<!-- @trace
source: covered-day-holiday-chip
updated: 2026-10-26
code:
  - .github/skills/spectra-ingest/SKILL.md
  - app/components/route_coverage_component.html.erb
  - .github/skills/spectra-propose/SKILL.md
  - .agents/skills/spectra-ingest/SKILL.md
  - app/components/application_component.rb
  - app/components/timetable_header_component.html.erb
  - .agents/skills/spectra-propose/SKILL.md
tests:
  - spec/components/application_component_spec.rb
  - spec/requests/routes_spec.rb
  - spec/components/route_coverage_component_spec.rb
  - spec/components/timetable_header_component_spec.rb
-->

---
### Requirement: Page content

The page SHALL show, in this order: a summary with the route name, departure and destination, the covered days, the number of trips and of complete trips, and the key numbers of the requirement "Key numbers in the summary"; the section links of the requirement "Section links"; the stop sequence block of the requirement "Stop sequence block"; the layover distribution chart, followed by the layovers per direction of the ending trip, each row naming that direction's last stop and the nature of that end as defined by `turnaround-ends` (stopping or pass-through), with the number of layovers, p10, p50, p90 and the share under 15 minutes as defined by `layover-metrics`; the round trip and cycle block of the requirement "Round trip and cycle block"; the turnaround facilities as defined by `turnaround-facilities`, one part per end in direction order, each with the direction, the last stop, the nature of the end, the location source with its check numbers, the number of toilet places within 300 and 500 metres, the nearest place with its number of toilets, the places within 500 metres inside a disclosure that is closed by default, the day of the location used and the day of the toilet snapshot that day was loaded with, each part followed by that end's map container and map data as defined by `turnaround-map` and by the line stating the share of the covered days' standstill reports that the drawn cells cover; the buffer estimate as defined by `buffer-trade` for the selected buffer, lateness, hours and end, with the number of covered days, trips and measured layovers at stopping ends over all hours, the number of layovers in the base when hours or an end are selected, measured layovers at pass-through ends when the route has such an end, the minutes to hold with the buffer and the lateness it adds up from, the rest achievement now and, with a lateness above zero, the rest achievement with the same vehicles, the lower and upper added vehicle-hours per day, the cost of one more minute, the lower and upper added vehicles with their busiest hour, the curve of the requirement "Buffer estimate curve", the added vehicles of every hour inside a disclosure that is closed by default, and the vehicles per day; the run time summary of `run-time` per direction, with the number of excluded trips, followed in the same card by the stop speed block of `stop-to-stop-speed`; the load chart along the route, followed by the MRT overlap as defined by `mrt-overlap`, with each direction's number of stops and overlap share at 300, 500 and 800 metres, the overlap stretches at 500 metres with their first and last sequence numbers and stop names, the on-board counts of each stretch per time band, and the day of the entrance snapshot used; and the load profile as defined by `load-profile`, per direction, time band and stop, each cell giving the median, the p90 and the number of trips with a count, inside a disclosure that is closed by default and whose rows are all present in the server response. Percentiles SHALL be computed over all trips of the covered days, not combined from daily values. The MRT overlap SHALL NOT mark any share as above or below a review threshold, and the turnaround facilities SHALL NOT judge whether the toilets are enough. When the stops of the covered days carry no nearest-entrance distance, the MRT overlap block SHALL say that the days need to be loaded again instead of showing shares; when the covered days carry no end rows, the turnaround facilities block SHALL say the same and SHALL contain no map container. When the base of the buffer estimate is empty, the block SHALL say that no layover could be measured, naming the selected hours and end when either is selected, SHALL show none of its figures and no curve, and SHALL keep its controls. The buffer estimate SHALL offer the controls of the requirement "Buffer estimate controls".

#### Scenario: Seven-day percentile pools trips

- **WHEN** day one has layovers of 10 and 20 minutes in direction 0 and day two has one of 30 minutes, and the page covers both days
- **THEN** the direction 0 layover row reports 3 layovers and a p50 of 20.0

#### Scenario: Overlap block in place

- **WHEN** a stored day whose stops carry nearest-entrance distances is rendered
- **THEN** the blocks appear in the order summary, stop sequence, layover chart, layovers, round trips and cycles, turnaround facilities, buffer estimate, run times, stop speeds, load chart, MRT overlap, load profile, limitations, and the MRT overlap block names the entrance snapshot day

#### Scenario: Distances missing

- **WHEN** a stored day was loaded before stops carried nearest-entrance distances
- **THEN** the MRT overlap block asks for the day to be loaded again and shows no share

#### Scenario: Facilities block in place

- **WHEN** a stored day whose ends carry a location is rendered for a route whose direction 0 is a pass-through end and direction 1 a stopping end
- **THEN** the turnaround facilities block shows direction 0 with source `end_stop` and direction 1 with source `standstill` and its three check numbers, each with its place counts, nearest place with its number of toilets, closed place list, location day and the toilet snapshot day of that location day, and each end's part is followed by a map container holding that end's map data and by its coverage line

#### Scenario: Map container without JavaScript

- **WHEN** the page of a stored day with end rows is fetched without running any script
- **THEN** each end's map container is in the state `pending` with its map data and its sentence, and every number of the facilities block is in the response

#### Scenario: End rows missing

- **WHEN** every covered day was stored without end rows
- **THEN** the turnaround facilities block asks for the days to be loaded again, shows no location and contains no map container, and every other block renders as before

#### Scenario: Buffer from the address

- **WHEN** a visitor requests `/routes/9001?day=2026-10-19&range=7d&buffer=10&late=5`
- **THEN** the buffer estimate holds 15 minutes, made of a buffer of 10 and a lateness of 5, and its controls carry the buffer 10 and the lateness 5 with the day 2026-10-19 and the range 7d, targeting only the buffer estimate block

#### Scenario: End nature on the layover rows

- **WHEN** the layovers of a route whose direction 0 is a pass-through end and direction 1 a stopping end are rendered
- **THEN** direction 0's row is labelled pass-through, direction 1's row is labelled stopping, and both rows keep the counts and percentiles of `layover-metrics`

#### Scenario: Both ends stopping

- **WHEN** route 9001 is configured with both ends as stopping ends and its page is rendered
- **THEN** both layover rows are labelled stopping and the buffer estimate reports no pass-through layovers

#### Scenario: Pass-through layovers in the estimate block

- **WHEN** the buffer estimate of a route whose direction 0 is a pass-through end is rendered with 3 layovers ending in direction 0 and 2 ending in direction 1
- **THEN** the block reports 2 measured layovers at stopping ends and 3 layovers at the pass-through end as not counted

#### Scenario: Load profile closed by default

- **WHEN** a stored day with load profile rows is rendered
- **THEN** the load profile table is inside a disclosure that is closed, and the response contains a row for every stop that has a count

#### Scenario: No layover in the selected hours on the page

- **WHEN** a visitor requests `/routes/9001?day=2026-10-19&from=12&to=13` and no layover at a stopping end ends between 12:00 and 13:00 on that day
- **THEN** the buffer estimate says that no layover could be measured from 12 to 13, shows no figure and no curve, and still shows its controls


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
### Requirement: No vehicle identifiers on the page

The rendered page SHALL NOT contain any `BusID` value.

#### Scenario: Fixture plates absent

- **WHEN** the fixture day of route 9001 is stored and its page is rendered
- **THEN** none of `TEST-0001` to `TEST-0004` appears in the response body


<!-- @trace
source: zhongshan-route-page
updated: 2026-10-22
code:
  - app/components/route_summary_component.yml
  - app/components/load_profile_table_component.yml
  - app/components/layover_table_component.rb
  - app/components/route_summary_component.rb
  - app/controllers/routes_controller.rb
  - analysis/derived_export.sql
  - app/components/data_limitations_component.html.erb
  - app/components/route_coverage_component.rb
  - app/components/route_coverage_component.yml
  - app/models/route_page/run_times.rb
  - app/components/load_profile_table_component.rb
  - db/migrate/20261021184616_create_derived_tables.rb
  - app/components/run_time_table_component.yml
  - app/models/trip_stop_count.rb
  - app/components/data_limitations_component.rb
  - app/components/route_summary_component.html.erb
  - db/schema.rb
  - bin/health-card
  - app/views/routes/show.html.erb
  - config/route_page.yml
  - lib/analysis_run.rb
  - app/frontend/stylesheets/application.css
  - app/components/route_coverage_component.html.erb
  - app/models/route_page/summary.rb
  - app/components/load_profile_table_component.html.erb
  - app/components/run_time_table_component.html.erb
  - app/models/route_day_stop.rb
  - app/components/layover_table_component.yml
  - app/models/derived_load_command.rb
  - analysis/README.md
  - app/components/run_time_table_component.rb
  - app/models/route_day.rb
  - app/models/route_page/load_profile.rb
  - app/models/route_page/layover_stats.rb
  - app/models/trip.rb
  - lib/tasks/derived.rake
  - app/models/route_day_loader.rb
  - app/models/route_page/coverage.rb
  - app/models/route_page.rb
  - app/components/layover_table_component.html.erb
  - app/models/layover.rb
  - app/components/data_limitations_component.yml
  - config/routes.rb
tests:
  - spec/components/run_time_table_component_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/models/route_page/run_times_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/requests/routes_spec.rb
  - spec/components/layover_table_component_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/components/route_coverage_component_spec.rb
  - spec/analysis/analysis_run_spec.rb
  - spec/components/load_profile_table_component_spec.rb
  - spec/components/route_summary_component_spec.rb
-->

---
### Requirement: Data limitations on the page

The page SHALL state the data limitations that apply to its numbers: a vehicle is not a driver and a layover is an upper bound on rest; on-board counts come from fare-card taps and do not return to zero between trips; 10-second polling misses stops and trips missing a terminal are left out of run times; weekdays and holidays follow the office calendar of 行政院人事行政總處, and days off for typhoons are not in that calendar and count as the calendar says; a stop near an MRT entrance does not mean the bus segment can be replaced by the MRT, distances are straight-line, and the entrance data is updated irregularly; the buffer estimate counts vehicle-hours, not driver hours, uses only measured layovers at stopping ends, and its added vehicles are an hourly average, not a schedule; the lateness of the buffer estimate is an assumption that every arrival at a stopping end is that many minutes later than measured, the lateness of the measured days is already in the measured layovers, and lateness longer than a layover would delay the next departure, which the estimate does not follow; the selected hours of the buffer estimate are the hours buses arrive at the stopping end; which end buses stop at is a fact verified route by route and written into the configuration, not computed from the data, and it goes stale when the operator changes how the route turns around; layovers at a pass-through end are not rest opportunities and the buffer estimate does not count them; round trips and cycles use only trips whose terminals were observed and that pair up as stored layovers, so their counts are lower than the trip counts, a vehicle's first loop of a day has no cycle, and a cycle is the rhythm of a vehicle, not the roster of one driver; the turnaround point location of a stopping end is where the vehicles stood still during that day's measured layovers, as reported by GPS every 10 seconds, which can be missing for a day, and it is where the vehicle stood, not where the driver went; a pass-through end is anchored on its last stop because buses do not stop there; the toilet data is the national registry of 環境部, updated monthly, with one row per toilet that the page groups into places by address, the toilet distances are straight-line, and the data has no opening hours and says nothing about whether a driver is allowed to use a toilet; the squares on the maps are cells of about 20 metres that at least three vehicles stood in on a day, their shade sums GPS reports taken every 10 seconds and is not minutes stood and not rest, cells with fewer vehicles are left out, and the basemap is third-party data shown as it is; the route map draws the route shape registered by 臺北市公共運輸處, not measured GPS, so temporary detours and diversions do not appear on it, and the registered shape can be older than the stop list; the stop speeds come from consecutive GPS reports of a vehicle placed on that registered route shape, the 40 metres around each stop are left out so braking, stopping and boarding are not in them, two stops 80 metres apart or closer have no speed, trips whose start is only an arrival are left out, and the shades compare the legs of one direction only.

#### Scenario: Limitations present

- **WHEN** any route page with data is rendered
- **THEN** it contains a 資料限制 section with the statements above

#### Scenario: No statement that days are mixed

- **WHEN** a route page with data is rendered with either range
- **THEN** it does not state that weekdays and holidays are not separated

##### Example: both ranges of a stored weekday

- **GIVEN** route 9001 has the stored weekday 2026-10-19
- **WHEN** a visitor requests `/routes/9001?day=2026-10-19` and `/routes/9001?day=2026-10-19&range=7d`
- **THEN** neither response contains 沒有分平日與假日


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
### Requirement: Layover distribution chart

The page SHALL show, per direction of the ending trip, a horizontal bar chart of the layovers of the covered days as defined by `layover-metrics`, counted in the bins of the health card: lower bounds 0, 5, 10, 15, 30 and 60 minutes, each bin including its lower bound and excluding the next one, the last bin open-ended. Each bar SHALL give its bin and its count, and bar lengths SHALL be proportional to the count within the direction. The chart SHALL draw a divider between the bins below 15 minutes and the bins from 15 minutes, and SHALL NOT colour any bin as compliant or non-compliant. Each direction's chart SHALL be titled with that direction's last stop and the first stop of the other direction, where the next trip starts, both from the latest of the covered days, and SHALL state the nature of that end as defined by `turnaround-ends` (stopping or pass-through). A direction without layovers SHALL show that it has none instead of bars. The bin counts SHALL equal the health card's `bin_counts` on the same input.

#### Scenario: Bins follow the card

- **WHEN** the fixture day 2026-10-19 is loaded for route 9001 and the page covers that day
- **THEN** each direction's bar counts equal the health card's `bin_counts` for that direction

##### Example: fixture day

- **GIVEN** the fixture day 2026-10-19 of route 9001
- **WHEN** the layover distribution is read
- **THEN** direction 0 has counts 0, 0, 6, 3, 1, 0 and direction 1 has counts 0, 0, 3, 3, 0, 3 for the bins from 0, 5, 10, 15, 30 and 60 minutes

#### Scenario: Bin edges

- **WHEN** direction 0 has layovers of 4.9, 5.0, 14.9, 15.0 and 75.0 minutes
- **THEN** the counts are 1, 1, 1, 1, 0, 1 for the bins from 0, 5, 10, 15, 30 and 60 minutes

#### Scenario: Title names both stops

- **WHEN** direction 0's last stop is 戊站 and direction 1's first stop is 己站 on the latest covered day
- **THEN** direction 0's chart is titled with 戊站 and 己站

#### Scenario: Title states the end nature

- **WHEN** direction 0 is a pass-through end and direction 1 a stopping end
- **THEN** direction 0's chart title states pass-through and direction 1's chart title states stopping

#### Scenario: Direction without layovers

- **WHEN** a covered day has no layover ending in direction 1
- **THEN** direction 1's chart shows that it has no layovers and no bars


<!-- @trace
source: zhongshan-turnaround-ends
updated: 2026-10-22
code:
  - config/route_page.yml
  - app/components/layover_chart_component.rb
  - app/components/layover_chart_component.yml
  - app/components/layover_chart_component.html.erb
  - app/controllers/routes_controller.rb
  - app/components/buffer_trade_component.html.erb
  - app/components/layover_table_component.html.erb
  - app/components/buffer_trade_component.rb
  - app/components/buffer_trade_component.yml
  - app/components/layover_table_component.yml
  - app/models/route_page/buffer_trade.rb
  - app/components/layover_table_component.rb
  - app/components/data_limitations_component.yml
  - app/models/route_page/ends.rb
  - app/views/routes/show.html.erb
  - app/models/route_page.rb
tests:
  - spec/models/route_page/buffer_trade_spec.rb
  - spec/components/buffer_trade_component_spec.rb
  - spec/components/layover_chart_component_spec.rb
  - spec/components/layover_table_component_spec.rb
  - spec/requests/routes_spec.rb
  - spec/models/route_page/ends_spec.rb
-->

---
### Requirement: Load chart along the route

The page SHALL show, per direction, a line chart of the load profile as defined by `load-profile` over the covered days: the horizontal axis SHALL be the stop sequence of the latest covered day, and the vertical axis the median on-board count at each stop. The chart SHALL offer the time bands morning peak, daytime, evening peak and other, one shown at a time, morning peak shown first; switching bands SHALL NOT reload the page. All bands of one direction SHALL share one vertical scale whose top is at least the largest median of that direction in any band. A stop without a count in the shown band SHALL break the line instead of being filled. The overlap stretches at 500 metres as defined by `mrt-overlap` SHALL be drawn as shaded spans over their first to last sequence numbers, without any review threshold; when the stops carry no nearest-entrance distance, no span SHALL be drawn. The chart SHALL name the first and last stop of the direction. Each shaded span SHALL carry a number, counted from 1 in stop order within its direction, and the chart SHALL NOT contain any text naming a span. Below each direction's chart, outside the area that scrolls sideways, the page SHALL list that direction's spans in the same order, each entry giving the span's number and the first and last stop of the span; a direction without a shaded span SHALL have no such list. While the pointer rests on a shaded span, including its number, or on its entry in that list, the page SHALL highlight that span and that entry and no other span or entry, and the highlight SHALL end when the pointer leaves them; pointing SHALL NOT be needed to read any span's name.

Below 640 px wide, the page SHALL show the same medians as one row per stop of the latest covered day instead of the line chart, in stop order, each row giving the stop name, a bar whose length is proportional to the median on the direction's shared scale, and the median, with the same time bands and band switch as the chart. A stop without a count in the shown band SHALL show a dash and no bar. The rows of each overlap stretch at 500 metres SHALL be shaded, and the stretch SHALL be named with its first and last stop before its first row; when the stops carry no nearest-entrance distance, no row SHALL be shaded.

#### Scenario: Points per band

- **WHEN** direction 0 has medians 3.0 at sequence 0 and 8.0 at sequence 1 in the morning peak, and 5.0 at sequence 0 in the daytime
- **THEN** the morning peak line has points at sequence 0 with 3.0 and sequence 1 with 8.0, and the daytime line has one point at sequence 0 with 5.0 and a break at sequence 1

#### Scenario: Shared scale

- **WHEN** direction 0's largest median is 8.0 in the morning peak and 5.0 in the daytime
- **THEN** both bands of direction 0 use the same vertical scale, whose top is at least 8.0

#### Scenario: Shaded overlap stretch

- **WHEN** direction 0 has an overlap stretch at 500 metres from sequence 2 to sequence 4
- **THEN** direction 0's chart has one shaded span from sequence 2 to sequence 4 carrying the number 1, and the list below direction 0's chart has one entry, 1, named with the stops at those sequences

#### Scenario: Spans numbered in stop order

- **WHEN** direction 0 has two overlap stretches at 500 metres, one from sequence 0 to sequence 1 and one from sequence 3 to sequence 4
- **THEN** the span over sequences 0 to 1 carries the number 1 and the span over sequences 3 to 4 carries the number 2, the list below direction 0's chart gives entry 1 before entry 2, each named with the first and last stop of its span, and no text inside the chart names either span

##### Example: two stretches

- **GIVEN** direction 0's stops at sequences 0 to 4 are 甲站, 乙站, 丙站, 丁站, 戊站 with nearest-entrance distances 400, 450, 900, 250 and 300 metres
- **WHEN** the page is rendered
- **THEN** the spans carry 1 over sequences 0 to 1 and 2 over sequences 3 to 4, and the list below the chart reads 1 甲站–乙站, then 2 丁站–戊站

#### Scenario: Distances missing on the chart

- **WHEN** the stops of the covered days carry no nearest-entrance distance
- **THEN** the load charts show their lines and no shaded span, no span number, and no list of spans below the charts

##### Example: no distances

- **GIVEN** direction 0's stops at sequences 0 to 4 carry no nearest-entrance distance, and sequence 0 has a morning peak count of 3
- **WHEN** the page is rendered
- **THEN** direction 0's chart has its line, no shaded span, no span number, and no list below it

#### Scenario: Pointing at a list entry

- **WHEN** direction 0 has spans numbered 1 and 2 and the pointer rests on entry 2 of the list below direction 0's chart
- **THEN** span 2 and entry 2 of direction 0 are highlighted, and no other span or entry on the page is

##### Example: second entry of two

- **GIVEN** direction 0's stops at sequences 0 to 4 are 甲站, 乙站, 丙站, 丁站, 戊站 with nearest-entrance distances 400, 450, 900, 250 and 300 metres, and direction 1's stops at sequences 5 to 9 have 300, 350, 900, 900 and 900 metres
- **WHEN** the pointer rests on direction 0's entry 2, 丁站–戊站
- **THEN** the highlighted elements are direction 0's span 2 and entry 2 only

#### Scenario: Pointing at a span

- **WHEN** direction 0 has spans numbered 1 and 2, direction 1 has a span numbered 1, and the pointer rests on the number of direction 0's span 1
- **THEN** span 1 and entry 1 of direction 0 are highlighted, and direction 1's span 1 and entry 1 and every other span or entry are not

#### Scenario: Pointer moved away

- **WHEN** the pointer leaves a highlighted span or entry for a place outside every span and entry
- **THEN** no span or entry is highlighted

#### Scenario: Rows on a narrow screen

- **WHEN** direction 0 has a morning peak median of 3.0 at sequence 0 and no count at sequence 1
- **THEN** direction 0's per-stop rows for the morning peak give 3.0 with a bar at sequence 0, and a dash without a bar at sequence 1

#### Scenario: Shaded rows

- **WHEN** direction 0 has an overlap stretch at 500 metres from sequence 2 to sequence 4
- **THEN** direction 0's per-stop rows at sequences 2 to 4 are shaded, and the stretch is named with the stops at sequences 2 and 4 before the row of sequence 2


<!-- @trace
source: load-chart-stretch-markers
updated: 2026-10-24
code:
  - app/controllers/routes_controller.rb
  - app/components/load_chart_component.html.erb
  - app/frontend/entrypoints/application.js
  - app/components/load_chart_component.rb
  - app/frontend/rest_command.js
  - public/robots.txt
  - public/404.html
  - bin/health-card
  - config/initializers/mime_types.rb
  - docs/data-sources.md
  - app/components/attribution_component.yml
  - app/views/layouts/application.html.erb
tests:
  - spec/system/rest_command_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/requests/routes_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/system/load_chart_hover_spec.rb
  - spec/components/load_chart_component_spec.rb
  - spec/requests/easter_eggs_spec.rb
  - spec/requests/not_found_page_spec.rb
-->

---
### Requirement: Key numbers in the summary

The summary SHALL show, after the trip counts, three key numbers, each with the same text as a value that a table of the page shows: the p50 of every stopping end as defined by `turnaround-ends` and the share under 15 minutes of every stopping end, both taken from that end's layover row and each labelled with that end's last stop; and the overlap share at 500 metres of each direction, taken from the MRT overlap. When the route has no stopping end, the summary SHALL state that no end is a stopping end instead of the two layover numbers. When a layover row shows a dash, the key number SHALL show a dash. When the MRT overlap asks for the days to be loaded again, the overlap number SHALL be a dash. The layover numbers SHALL link to the layover block and the overlap number SHALL link to the MRT overlap block. No key number SHALL be marked as meeting or missing a threshold, and the summary SHALL NOT show any value that no table of the page shows.

#### Scenario: One stopping end

- **WHEN** route 9001 is configured with direction 0 as a pass-through end and direction 1 as a stopping end, and the covered layovers ending in direction 1 are 10, 20 and 30 minutes
- **THEN** the summary gives direction 1's last stop with a p50 of 20.0 and a share under 15 minutes of 33.3%, the same text as direction 1's layover row, and gives no layover number for direction 0

#### Scenario: Both ends stopping

- **WHEN** route 9001 is configured with both ends as stopping ends and both directions have layovers
- **THEN** each of the two layover key numbers has one line per end, each line labelled with that end's last stop and holding the text of that end's layover row

#### Scenario: No stopping end

- **WHEN** both ends of the route are pass-through ends
- **THEN** the summary states that no end is a stopping end and gives no layover number

#### Scenario: Stopping end without layovers

- **WHEN** direction 1 is a stopping end and no covered layover ends in direction 1
- **THEN** both layover key numbers show a dash for direction 1's last stop, as direction 1's layover row does

#### Scenario: Distances missing in the summary

- **WHEN** the stops of the covered days carry no nearest-entrance distance
- **THEN** the overlap key number is a dash

#### Scenario: Key numbers link to their blocks

- **WHEN** a stored day is rendered
- **THEN** the layover key numbers link to the layover block and the overlap key number links to the MRT overlap block


<!-- @trace
source: 02-route-page-mobile-first
updated: 2026-10-23
code:
  - spec/fixtures/analysis/external/office-calendar/2026/2026-10-19.csv
  - app/components/route_coverage_component.rb
  - app/models/http_fetcher.rb
  - app/components/load_chart_component.yml
  - analysis/10_load.sql
  - app/components/card_component.rb
  - app/components/layover_chart_component.html.erb
  - spec/fixtures/analysis/bus_event/2026-10-19/14.jsonl
  - app/components/layover_chart_component.yml
  - app/views/routes/show.html.erb
  - app/models/route_day_loader.rb
  - app/views/pages/home.html.erb
  - app/components/route_summary_component.rb
  - app/components/site_bar_component.rb
  - analysis/30_layovers.sql
  - app/components/load_profile_table_component.rb
  - app/components/route_coverage_component.html.erb
  - analysis/params.sql
  - db/migrate/20261022231802_require_day_type_on_route_days.rb
  - app/components/home_hero_component.html.erb
  - analysis/README.md
  - app/components/load_chart_component.html.erb
  - app/components/route_summary_component.yml
  - app/components/route_summary_component.html.erb
  - app/components/buffer_trade_component.yml
  - app/components/data_sources_component.html.erb
  - lib/tasks/external.rake
  - app/components/attribution_component.html.erb
  - app/models/route_page/layover_stats.rb
  - app/components/card_component.html.erb
  - app/components/section_nav_component.html.erb
  - app/components/buffer_trade_component.html.erb
  - app/components/route_coverage_component.yml
  - config/locales/tw.yml
  - app/components/route_list_component.yml
  - app/components/run_time_table_component.yml
  - app/components/route_list_component.html.erb
  - app/components/run_time_table_component.rb
  - db/migrate/20261022230942_add_day_type_to_route_days.rb
  - app/components/site_bar_component.html.erb
  - spec/factories/route_days.rb
  - app/models/route_day.rb
  - app/components/run_time_table_component.html.erb
  - config/locales/en.yml
  - app/components/application_component.rb
  - db/schema.rb
  - app/components/data_limitations_component.html.erb
  - spec/support/duckdb.rb
  - app/components/mrt_overlap_component.rb
  - bin/health-card
  - app/models/office_calendar_snapshot.rb
  - app/frontend/stylesheets/application.css
  - app/models/route_page/coverage.rb
  - spec/fixtures/analysis/README.md
  - app/components/buffer_trade_component.rb
  - app/components/load_profile_table_component.html.erb
  - app/components/mrt_overlap_component.html.erb
  - app/components/layover_table_component.rb
  - app/components/layover_chart_component.rb
  - app/components/load_chart_component.rb
  - docs/data-sources.md
  - app/components/layover_table_component.html.erb
  - app/components/section_nav_component.yml
  - app/components/load_profile_table_component.yml
  - app/components/data_limitations_component.yml
  - analysis/60_export.sql
  - app/models/mrt_exits_snapshot.rb
  - spec/fixtures/analysis/bus_event/2026-10-19/15.jsonl
  - app/components/data_limitations_component.rb
  - app/views/layouts/application.html.erb
  - app/components/section_nav_component.rb
  - app/components/layover_table_component.yml
  - app/components/attribution_component.yml
  - app/components/home_hero_component.rb
tests:
  - spec/models/route_day_loader_spec.rb
  - spec/analysis/card_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/system/route_page_layout_spec.rb
  - spec/models/route_page/run_times_spec.rb
  - spec/components/buffer_trade_component_spec.rb
  - spec/models/http_fetcher_spec.rb
  - spec/models/office_calendar_snapshot_spec.rb
  - spec/requests/routes_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/requests/pages_spec.rb
  - spec/analysis/layovers_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/route_page/coverage_spec.rb
  - spec/components/layover_chart_component_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/run_time_table_component_spec.rb
  - spec/models/route_day_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/analysis/params_spec.rb
  - spec/components/card_component_spec.rb
  - spec/components/load_chart_component_spec.rb
  - spec/models/home_page/route_list_spec.rb
  - spec/components/mrt_overlap_component_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/components/data_limitations_component_spec.rb
  - spec/analysis/load_spec.rb
  - spec/components/layover_table_component_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/analysis/duckdb_helpers_spec.rb
  - spec/components/route_list_component_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/components/route_coverage_component_spec.rb
  - spec/system/home_hero_spec.rb
  - spec/components/load_profile_table_component_spec.rb
  - spec/components/application_component_spec.rb
  - spec/models/route_page/buffer_trade_spec.rb
  - spec/components/route_summary_component_spec.rb
-->

---
### Requirement: Section links

After the summary, the page SHALL show one link to each of the layover, round trip and cycle, turnaround facilities, buffer estimate, run time, load chart, MRT overlap and limitations blocks, in page order, each pointing by its fragment to an element of the page that contains that block. The links SHALL work without JavaScript and SHALL NOT carry a `data-section` attribute. When the selected day has no data, the page SHALL NOT show the section links.

#### Scenario: Links in page order

- **WHEN** a stored day is rendered
- **THEN** there are eight section links in the order layovers, round trips and cycles, turnaround facilities, buffer estimate, run times, load chart, MRT overlap, limitations, and each link's fragment names an element that contains the block of that name

#### Scenario: No links without data

- **WHEN** a visitor requests a day of route 9001 that is not stored
- **THEN** the response is 200 and shows no section links


<!-- @trace
source: turnaround-facilities
updated: 2026-10-24
code:
  - app/components/cycle_table_component.yml
  - app/frontend/hero/scene.js
  - app/components/turnaround_facilities_component.html.erb
  - app/frontend/hero/runtime.js
  - spec/factories/route_day_ends.rb
  - app/components/section_nav_component.yml
  - spec/factories/route_days.rb
  - app/models/route_page/facilities.rb
  - app/models/public_toilets_snapshot.rb
  - output/branding-v2/a-bus/favicon.ico
  - app/models/route_day_end_toilet.rb
  - app/models/route_page/cycles.rb
  - app/components/turnaround_facilities_component.yml
  - spec/fixtures/analysis/bus_data/2026-10-19/11.jsonl
  - app/models/route_day_end_cell.rb
  - app/models/derived_load_command.rb
  - app/components/site_bar_component.html.erb
  - app/components/cycle_table_component.rb
  - analysis/README.md
  - app/components/attribution_component.yml
  - spec/fixtures/analysis/bus_data/2026-10-19/08.jsonl
  - analysis/derived_export.sql
  - config/environments/production.rb
  - app/frontend/end_map/runtime.js
  - spec/factories/route_day_end_toilets.rb
  - analysis/turnaround_facilities.sql
  - app/components/home_hero_component.yml
  - app/components/home_hero_component.rb
  - app/assets/images/home-hero-wide.webp
  - public/turnaround/icon-16.png
  - config/locales/tw.yml
  - app/assets/images/home-hero-narrow.webp
  - app/models/route_day.rb
  - app/components/section_nav_component.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/12.jsonl
  - Gemfile.lock
  - config/map.yml
  - spec/fixtures/analysis/external/public-toilets/2026-10-19.csv
  - config/database.yml
  - app/components/data_limitations_component.yml
  - app/components/end_map_component.html.erb
  - public/turnaround/og-image-v2.jpg
  - app/components/end_map_component.rb
  - db/schema.rb
  - tools/hero/export.js
  - .kamal/secrets
  - app/frontend/entrypoints/application.js
  - app/models/route_day_end.rb
  - public/turnaround/icon-32.png
  - config/locales/en.yml
  - app/frontend/stylesheets/application.css
  - docs/decisions.md
  - app/views/layouts/application.html.erb
  - .ruby-version
  - tools/hero/index.html
  - app/components/attribution_component.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - analysis/params.sql
  - public/turnaround/favicon.ico
  - app/models/route_page/end_map.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/07.jsonl
  - app/assets/images/home-hero-tall.webp
  - bin/health-card
  - Gemfile
  - app/components/cycle_table_component.html.erb
  - output/branding-v2/a-bus/favicon-preview.png
  - config/deploy.yml
  - package.json
  - app/components/home_hero_component.html.erb
  - app/components/attribution_component.html.erb
  - spec/factories/route_day_end_cells.rb
  - spec/fixtures/analysis/README.md
  - output/branding-v2/a-bus/logo.png
  - app/assets/images/turnaround-logo.webp
  - public/turnaround/apple-touch-icon.png
  - lib/tasks/external.rake
  - Dockerfile
  - spec/support/duckdb.rb
  - app/views/routes/show.html.erb
  - db/migrate/20261023190654_add_turnaround_facilities_to_derived_tables.rb
  - config/credentials/production.yml.enc
  - app/components/turnaround_facilities_component.rb
  - app/models/map_tiles.rb
  - docs/data-sources.md
  - app/components/end_map_component.yml
  - app/models/route_day_loader.rb
tests:
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/assets/home_hero_images_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/route_page/cycles_spec.rb
  - spec/models/map_tiles_spec.rb
  - spec/models/route_day_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/system/end_map_spec.rb
  - spec/components/home_hero_component_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/requests/routes_spec.rb
  - spec/components/cycle_table_component_spec.rb
  - spec/models/route_page/facilities_spec.rb
  - spec/models/route_page/end_map_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/models/public_toilets_snapshot_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/system/home_hero_spec.rb
-->

---
### Requirement: Run time bars

At 640 px wide or wider, each run time row SHALL show a bar from its p50 to its p95 with a mark at its p85, on one scale shared by both directions of the block: from the smallest p50 of the block rounded down to a multiple of 10 minutes to the largest p95 of the block rounded up to a multiple of 10 minutes, and at least 10 minutes long. A small-sample row SHALL keep its bar. A direction without rows SHALL NOT affect the scale; when neither direction has a row, the block SHALL show no scale, no bars and no bar legend. Below 640 px wide, the rows SHALL show their numbers without the bars.

#### Scenario: Shared scale for both directions

- **WHEN** direction 0 has one row with p50 55.0, p85 64.0 and p95 68.0, and direction 1 one row with p50 40.0, p85 45.0 and p95 52.0
- **THEN** the scale runs from 40 to 70 minutes, direction 0's bar runs from 55.0 to 68.0 with its mark at 64.0, and direction 1's bar runs from 40.0 to 52.0 with its mark at 45.0

##### Example: scale ends

| Smallest p50 | Largest p95 | Scale | Notes |
| ------------ | ----------- | ----- | ----- |
| 54.7 | 102.3 | 50 to 110 | rounded outwards |
| 40.0 | 70.0 | 40 to 70 | multiples kept |
| 60.0 | 60.0 | 60 to 70 | at least 10 minutes long |

#### Scenario: No rows, no scale

- **WHEN** neither direction of the covered days has a trip with a run time
- **THEN** the run time block states for each direction that there is no trip to compute, and shows no scale, no bar and no bar legend

#### Scenario: No bars on a narrow screen

- **WHEN** a visitor on a 390 px wide screen opens a stored day with run times
- **THEN** the run time rows show their numbers and no bar is displayed


<!-- @trace
source: 02-route-page-mobile-first
updated: 2026-10-23
code:
  - spec/fixtures/analysis/external/office-calendar/2026/2026-10-19.csv
  - app/components/route_coverage_component.rb
  - app/models/http_fetcher.rb
  - app/components/load_chart_component.yml
  - analysis/10_load.sql
  - app/components/card_component.rb
  - app/components/layover_chart_component.html.erb
  - spec/fixtures/analysis/bus_event/2026-10-19/14.jsonl
  - app/components/layover_chart_component.yml
  - app/views/routes/show.html.erb
  - app/models/route_day_loader.rb
  - app/views/pages/home.html.erb
  - app/components/route_summary_component.rb
  - app/components/site_bar_component.rb
  - analysis/30_layovers.sql
  - app/components/load_profile_table_component.rb
  - app/components/route_coverage_component.html.erb
  - analysis/params.sql
  - db/migrate/20261022231802_require_day_type_on_route_days.rb
  - app/components/home_hero_component.html.erb
  - analysis/README.md
  - app/components/load_chart_component.html.erb
  - app/components/route_summary_component.yml
  - app/components/route_summary_component.html.erb
  - app/components/buffer_trade_component.yml
  - app/components/data_sources_component.html.erb
  - lib/tasks/external.rake
  - app/components/attribution_component.html.erb
  - app/models/route_page/layover_stats.rb
  - app/components/card_component.html.erb
  - app/components/section_nav_component.html.erb
  - app/components/buffer_trade_component.html.erb
  - app/components/route_coverage_component.yml
  - config/locales/tw.yml
  - app/components/route_list_component.yml
  - app/components/run_time_table_component.yml
  - app/components/route_list_component.html.erb
  - app/components/run_time_table_component.rb
  - db/migrate/20261022230942_add_day_type_to_route_days.rb
  - app/components/site_bar_component.html.erb
  - spec/factories/route_days.rb
  - app/models/route_day.rb
  - app/components/run_time_table_component.html.erb
  - config/locales/en.yml
  - app/components/application_component.rb
  - db/schema.rb
  - app/components/data_limitations_component.html.erb
  - spec/support/duckdb.rb
  - app/components/mrt_overlap_component.rb
  - bin/health-card
  - app/models/office_calendar_snapshot.rb
  - app/frontend/stylesheets/application.css
  - app/models/route_page/coverage.rb
  - spec/fixtures/analysis/README.md
  - app/components/buffer_trade_component.rb
  - app/components/load_profile_table_component.html.erb
  - app/components/mrt_overlap_component.html.erb
  - app/components/layover_table_component.rb
  - app/components/layover_chart_component.rb
  - app/components/load_chart_component.rb
  - docs/data-sources.md
  - app/components/layover_table_component.html.erb
  - app/components/section_nav_component.yml
  - app/components/load_profile_table_component.yml
  - app/components/data_limitations_component.yml
  - analysis/60_export.sql
  - app/models/mrt_exits_snapshot.rb
  - spec/fixtures/analysis/bus_event/2026-10-19/15.jsonl
  - app/components/data_limitations_component.rb
  - app/views/layouts/application.html.erb
  - app/components/section_nav_component.rb
  - app/components/layover_table_component.yml
  - app/components/attribution_component.yml
  - app/components/home_hero_component.rb
tests:
  - spec/models/route_day_loader_spec.rb
  - spec/analysis/card_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/system/route_page_layout_spec.rb
  - spec/models/route_page/run_times_spec.rb
  - spec/components/buffer_trade_component_spec.rb
  - spec/models/http_fetcher_spec.rb
  - spec/models/office_calendar_snapshot_spec.rb
  - spec/requests/routes_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/requests/pages_spec.rb
  - spec/analysis/layovers_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/route_page/coverage_spec.rb
  - spec/components/layover_chart_component_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/run_time_table_component_spec.rb
  - spec/models/route_day_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/analysis/params_spec.rb
  - spec/components/card_component_spec.rb
  - spec/components/load_chart_component_spec.rb
  - spec/models/home_page/route_list_spec.rb
  - spec/components/mrt_overlap_component_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/components/data_limitations_component_spec.rb
  - spec/analysis/load_spec.rb
  - spec/components/layover_table_component_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/analysis/duckdb_helpers_spec.rb
  - spec/components/route_list_component_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/components/route_coverage_component_spec.rb
  - spec/system/home_hero_spec.rb
  - spec/components/load_profile_table_component_spec.rb
  - spec/components/application_component_spec.rb
  - spec/models/route_page/buffer_trade_spec.rb
  - spec/components/route_summary_component_spec.rb
-->

---
### Requirement: One direction at a time on narrow screens

Below 640 px wide, the run time block and the per-stop load rows SHALL each show one direction at a time, the outbound direction first, with a control that switches the direction without reloading the page and without changing the page address. At 640 px wide or wider, both directions of the run time block SHALL be shown and the control SHALL NOT be shown. Without JavaScript, both directions of the run time block and of the per-stop load rows SHALL be in the response with neither marked as hidden, and the controls SHALL NOT be shown.

#### Scenario: Switching on a phone

- **WHEN** a visitor on a 390 px wide screen opens a stored day with run times in both directions and switches the run time block to inbound
- **THEN** only the inbound run time table is displayed and the page address is unchanged

#### Scenario: Wide screens show both directions

- **WHEN** a visitor on a 1400 px wide screen opens the same stored day
- **THEN** both run time tables are displayed and no direction switch is displayed

#### Scenario: Without JavaScript

- **WHEN** the page of a stored day is fetched without running any script
- **THEN** the response contains both directions' run time tables and both directions' per-stop load rows, and none of them is marked as hidden

<!-- @trace
source: 02-route-page-mobile-first
updated: 2026-10-23
code:
  - spec/fixtures/analysis/external/office-calendar/2026/2026-10-19.csv
  - app/components/route_coverage_component.rb
  - app/models/http_fetcher.rb
  - app/components/load_chart_component.yml
  - analysis/10_load.sql
  - app/components/card_component.rb
  - app/components/layover_chart_component.html.erb
  - spec/fixtures/analysis/bus_event/2026-10-19/14.jsonl
  - app/components/layover_chart_component.yml
  - app/views/routes/show.html.erb
  - app/models/route_day_loader.rb
  - app/views/pages/home.html.erb
  - app/components/route_summary_component.rb
  - app/components/site_bar_component.rb
  - analysis/30_layovers.sql
  - app/components/load_profile_table_component.rb
  - app/components/route_coverage_component.html.erb
  - analysis/params.sql
  - db/migrate/20261022231802_require_day_type_on_route_days.rb
  - app/components/home_hero_component.html.erb
  - analysis/README.md
  - app/components/load_chart_component.html.erb
  - app/components/route_summary_component.yml
  - app/components/route_summary_component.html.erb
  - app/components/buffer_trade_component.yml
  - app/components/data_sources_component.html.erb
  - lib/tasks/external.rake
  - app/components/attribution_component.html.erb
  - app/models/route_page/layover_stats.rb
  - app/components/card_component.html.erb
  - app/components/section_nav_component.html.erb
  - app/components/buffer_trade_component.html.erb
  - app/components/route_coverage_component.yml
  - config/locales/tw.yml
  - app/components/route_list_component.yml
  - app/components/run_time_table_component.yml
  - app/components/route_list_component.html.erb
  - app/components/run_time_table_component.rb
  - db/migrate/20261022230942_add_day_type_to_route_days.rb
  - app/components/site_bar_component.html.erb
  - spec/factories/route_days.rb
  - app/models/route_day.rb
  - app/components/run_time_table_component.html.erb
  - config/locales/en.yml
  - app/components/application_component.rb
  - db/schema.rb
  - app/components/data_limitations_component.html.erb
  - spec/support/duckdb.rb
  - app/components/mrt_overlap_component.rb
  - bin/health-card
  - app/models/office_calendar_snapshot.rb
  - app/frontend/stylesheets/application.css
  - app/models/route_page/coverage.rb
  - spec/fixtures/analysis/README.md
  - app/components/buffer_trade_component.rb
  - app/components/load_profile_table_component.html.erb
  - app/components/mrt_overlap_component.html.erb
  - app/components/layover_table_component.rb
  - app/components/layover_chart_component.rb
  - app/components/load_chart_component.rb
  - docs/data-sources.md
  - app/components/layover_table_component.html.erb
  - app/components/section_nav_component.yml
  - app/components/load_profile_table_component.yml
  - app/components/data_limitations_component.yml
  - analysis/60_export.sql
  - app/models/mrt_exits_snapshot.rb
  - spec/fixtures/analysis/bus_event/2026-10-19/15.jsonl
  - app/components/data_limitations_component.rb
  - app/views/layouts/application.html.erb
  - app/components/section_nav_component.rb
  - app/components/layover_table_component.yml
  - app/components/attribution_component.yml
  - app/components/home_hero_component.rb
tests:
  - spec/models/route_day_loader_spec.rb
  - spec/analysis/card_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/system/route_page_layout_spec.rb
  - spec/models/route_page/run_times_spec.rb
  - spec/components/buffer_trade_component_spec.rb
  - spec/models/http_fetcher_spec.rb
  - spec/models/office_calendar_snapshot_spec.rb
  - spec/requests/routes_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/requests/pages_spec.rb
  - spec/analysis/layovers_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/route_page/coverage_spec.rb
  - spec/components/layover_chart_component_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/run_time_table_component_spec.rb
  - spec/models/route_day_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/analysis/params_spec.rb
  - spec/components/card_component_spec.rb
  - spec/components/load_chart_component_spec.rb
  - spec/models/home_page/route_list_spec.rb
  - spec/components/mrt_overlap_component_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/components/data_limitations_component_spec.rb
  - spec/analysis/load_spec.rb
  - spec/components/layover_table_component_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/analysis/duckdb_helpers_spec.rb
  - spec/components/route_list_component_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/components/route_coverage_component_spec.rb
  - spec/system/home_hero_spec.rb
  - spec/components/load_profile_table_component_spec.rb
  - spec/components/application_component_spec.rb
  - spec/models/route_page/buffer_trade_spec.rb
  - spec/components/route_summary_component_spec.rb
-->

---
### Requirement: Round trip and cycle block

The page SHALL show, after the layovers and before the buffer estimate, a block with the round trips and cycles of the covered days as defined by `round-trip-cycle`: a note naming the first stop of the lead direction and the last stop of the back direction from the latest covered day, or the words 起站 and 末站 when the covered days carry no stops; a sentence built only from the all-day row, giving the round trip p50 and p85 and the cycle p10 and p50 with the same text as that row's cells; and two tables by departure hour, one for round trips with the count, p50 and p85 and one for cycles with the count, p10 and p50, each ending with the all-day row, each row with fewer than 5 values of its measure marked as a small sample, and a dash where a measure has no value. Below 640 px wide the page SHALL show one table at a time with a switch that does not change the address, round trips first; without JavaScript both tables SHALL be present. When the covered days have no round trip, the block SHALL state that no round trip could be computed and SHALL show neither the sentence nor the tables. When there are round trips but no cycle, the sentence SHALL give only the round trip numbers. The block SHALL NOT mark any value as meeting or missing a threshold and SHALL NOT colour values by their size.

#### Scenario: Tables from stored trips and layovers

- **WHEN** the covered day has round trips of 150 minutes in hour 6 and 110 minutes in hour 8, and a cycle of 121 minutes in hour 8
- **THEN** the round trip table has rows for hours 06 and 08 and an all-day row of 2 round trips with p50 130.0 and p85 144.0, and the cycle table has a row for hour 08 and an all-day row of 1 cycle with p10 121.0 and p50 121.0, each hourly row marked as a small sample

#### Scenario: Sentence equals the all-day row

- **WHEN** the all-day row reports a round trip p50 of 151.3 and p85 of 169.6 and a cycle p10 of 146.8 and p50 of 181.6
- **THEN** the sentence contains 151.3, 169.6, 146.8 and 181.6 exactly as the all-day row shows them

#### Scenario: Stops named in the note

- **WHEN** the latest covered day's lead direction starts at 甲站 and its back direction ends at 戊站
- **THEN** the note names 甲站 as where a round trip leaves and 戊站 as where it returns

##### Example: stops of the latest covered day

- **GIVEN** the covered days are 2026-10-19 and 2026-10-20 of route 9001, and 2026-10-20's stops are direction 0 sequence 0 甲站 and direction 1 sequence 9 戊站
- **WHEN** the block is rendered with both ends `stop`
- **THEN** the note carries `data-first-stop` 甲站 and `data-last-stop` 戊站, read from 2026-10-20

#### Scenario: No round trip

- **WHEN** the covered days have trips but no pair qualifies as a round trip
- **THEN** the block states that no round trip could be computed and contains no table and no sentence

##### Example: one trip without its last stop

- **GIVEN** the covered day has one direction 0 trip from 06:00 to 06:40 with completeness `missing_end` and no stored layover
- **WHEN** the block is rendered
- **THEN** the response contains the no-round-trip statement and no `table` element inside the block

#### Scenario: Round trips without a cycle

- **WHEN** the covered days have round trips and no cycle
- **THEN** the sentence gives the round trip p50 and p85 only, and the cycle table has only the all-day row with 0 cycles and dashes

#### Scenario: One table at a time on a narrow screen

- **WHEN** a stored day is rendered
- **THEN** the block has a switch between the round trip table and the cycle table that is hidden until JavaScript runs, and both tables are in the server response

##### Example: server response of a day with one round trip

- **GIVEN** the covered day has one round trip of 150 minutes in hour 6
- **WHEN** the block is rendered without JavaScript
- **THEN** the response has one switch element with the `x-cloak` attribute and two tables, one for round trips with rows for hour 06 and the all-day row, one for cycles with the all-day row of 0 cycles

<!-- @trace
source: run-time-vs-cycle
updated: 2026-10-24
code:
  - app/components/origin_story_component.yml
  - app/views/routes/show.html.erb
  - app/assets/images/home-hero-tall.webp
  - output/branding-v1/apple-touch-icon.png
  - .kamal/secrets
  - app/components/home_hero_component.html.erb
  - output/branding-v2/a-bus/favicon.ico
  - app/views/layouts/application.html.erb
  - app/components/site_bar_component.html.erb
  - output/branding-v1/turnaround-logo-source.png
  - app/components/home_hero_component.rb
  - output/branding-v1/turnaround-icon-512.png
  - output/branding-v2/a-bus/concept.png
  - output/branding-v2/c-terminal/favicon.ico
  - app/models/route_page/cycles.rb
  - output/branding-v2/b-monogram/favicon-preview.png
  - public/turnaround/icon-32.png
  - output/branding-v2/c-terminal/concept.png
  - config/credentials/production.yml.enc
  - output/branding-v2/c-terminal/logo.png
  - output/branding-v1/turnaround-logo.png
  - app/components/cycle_table_component.yml
  - output/branding-v2/b-monogram/logo.png
  - app/assets/images/home-hero-wide.webp
  - public/turnaround/favicon.ico
  - app/views/pages/home.html.erb
  - app/frontend/entrypoints/application.js
  - config/database.yml
  - app/frontend/stylesheets/application.css
  - app/components/origin_story_component.html.erb
  - output/branding-v1/favicon-16.png
  - app/components/home_hero_component.yml
  - docs/decisions.md
  - app/components/data_limitations_component.yml
  - app/assets/images/home-hero-narrow.webp
  - output/branding-v2/b-monogram/concept.png
  - output/branding-v2/c-terminal/favicon-preview.png
  - tools/hero/export.js
  - output/branding-v2/a-bus/favicon-preview.png
  - app/frontend/hero/scene.js
  - docs/background.md
  - output/branding-v1/favicon-32.png
  - app/components/origin_story_component.rb
  - output/branding-v1/favicon.ico
  - output/branding-v2/b-monogram/favicon.ico
  - app/components/cycle_table_component.html.erb
  - app/components/section_nav_component.rb
  - app/components/section_nav_component.yml
  - public/turnaround/apple-touch-icon.png
  - output/branding-v1/turnaround-icon-source.png
  - config/deploy.yml
  - app/components/cycle_table_component.rb
  - output/branding-v2/a-bus/logo.png
  - tools/hero/index.html
  - output/branding-v1/prompts.txt
  - output/branding-v2/prompts.txt
  - app/assets/images/turnaround-logo.webp
  - config/environments/production.rb
  - public/turnaround/icon-16.png
  - app/frontend/hero/runtime.js
tests:
  - spec/assets/home_hero_images_spec.rb
  - spec/components/home_hero_component_spec.rb
  - spec/components/cycle_table_component_spec.rb
  - spec/models/route_page/cycles_spec.rb
  - spec/components/origin_story_component_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/requests/routes_spec.rb
  - spec/requests/pages_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/system/home_hero_spec.rb
-->

---
### Requirement: Stop sequence block

The page SHALL show, after the section links and before the layover distribution chart, a stop sequence block built from the stops stored for the latest covered day. Between its heading and its disclosure, outside the disclosure, the block SHALL show the route map as defined by `route-shape`, or that capability's sentence when the covered days have no route shape. The block SHALL hold a disclosure that is closed by default, whose summary gives each direction's number of stops and whose rows are all present in the server response. Inside, the block SHALL list each direction in direction order with its stop names in sequence order, marking the first as the first stop and the last as the last stop, and SHALL NOT show sequence numbers. After each direction's last stop, a row SHALL state the nature of that end as defined by `turnaround-ends` (stopping or pass-through) and SHALL name the first stop of the other direction as where the next trip starts; when the other direction has no stops, the row SHALL state only the nature. The block SHALL state the static snapshot day of the latest covered day. When the latest covered day has no stops, the block SHALL state that the covered days have no stop sequence and SHALL show no list. The block SHALL NOT mark stops as near the MRT, SHALL NOT show on-board counts and SHALL NOT mark which stops another route shares.

#### Scenario: Stops of the latest covered day

- **WHEN** the page covers two days whose stops differ
- **THEN** the block lists the stops of the later day and states that day's static snapshot day

##### Example: two weekdays given oldest first

- **GIVEN** route 9001's covered days are 2026-10-19 and 2026-10-20, given oldest first as the day coverage orders them; 2026-10-19's direction 0 stops are 甲站 and 乙站, and 2026-10-20's direction 0 stops are 甲站, 丙站 and 戊站, with the static snapshot day 2026-10-20
- **WHEN** the block is rendered
- **THEN** direction 0 lists 甲站, 丙站 and 戊站 in that order, and the block names the snapshot day 2026-10-20

#### Scenario: Turnaround row after each direction

- **WHEN** the latest covered day has stops in both directions, and the route's direction 0 is a pass-through end and direction 1 a stopping end
- **THEN** direction 0's list ends with its last stop marked as the last stop, followed by a pass-through row naming direction 1's first stop, and direction 1's list ends with its last stop, followed by a stopping row naming direction 0's first stop

##### Example: the same name at the stopping end

- **GIVEN** the latest covered day's direction 0 stops are 甲站 (sequence 0), 乙站 (1) and 戊站 (2), its direction 1 stops are 己站 (3), 丁站 (4) and 甲站 (5), and the ends are 0 `pass_through` and 1 `stop`
- **WHEN** the block is rendered
- **THEN** direction 0 reads 甲站 marked first stop, 乙站, 戊站 marked last stop, followed by a pass-through row naming 己站; and direction 1 reads 己站 marked first stop, 丁站, 甲站 marked last stop, followed by a stopping row naming 甲站

#### Scenario: No sequence numbers

- **WHEN** direction 1's stops carry the sequence numbers 3 to 5
- **THEN** each row of the list shows only its stop name, with the first stop and last stop marks, and no row shows a sequence number

#### Scenario: List closed by default

- **WHEN** a stored day with stops is rendered
- **THEN** the stop list is inside a disclosure that is closed, its summary gives each direction's number of stops, and the response contains a row for every stop of the latest covered day

#### Scenario: Route map above the list

- **WHEN** a stored day with stops and route shapes is rendered
- **THEN** the block's route map container comes after the block's heading and before the closed disclosure, and is not inside the disclosure

#### Scenario: Only one direction stored

- **WHEN** the latest covered day has stops only in direction 0
- **THEN** the block lists direction 0 only, and its turnaround row states the nature of that end without naming a next first stop

#### Scenario: No stops stored

- **WHEN** the latest covered day has no stops
- **THEN** the block states that the covered days have no stop sequence and shows no list, and every other block renders as before


<!-- @trace
source: 03-route-shape-map
updated: 2026-10-24
code:
  - app/components/route_coverage_component.html.erb
  - spec/fixtures/analysis/bus_seat_event/2026-10-23/07.jsonl
  - spec/support/duckdb.rb
  - spec/fixtures/analysis/static/2026-10-19/GetRoute.gz
  - spec/factories/route_days.rb
  - app/components/route_coverage_component.rb
  - app/components/route_list_component.html.erb
  - app/components/route_map_component.html.erb
  - docs/data-sources.md
  - analysis/params.sql
  - analysis/README.md
  - spec/fixtures/analysis/bus_seat_event/2026-10-23/09.jsonl
  - analysis/route_shape.sql
  - spec/factories/route_day_end_cells.rb
  - app/models/route_day_stop.rb
  - app/models/trip.rb
  - app/models/derived_load_command.rb
  - analysis/derived_export.sql
  - app/components/stop_sequence_component.html.erb
  - bin/health-card
  - analysis/40_load_profile.sql
  - spec/factories/route_day_shapes.rb
  - app/frontend/route_map/runtime.js
  - spec/fixtures/analysis/README.md
  - app/components/buffer_trade_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetStop.gz
  - db/schema.rb
  - spec/fixtures/analysis/static/2026-10-23/GetRoute.gz
  - analysis/10_load.sql
  - app/components/route_list_component.rb
  - db/migrate/20261024050100_add_member_route_columns_to_derived_tables.rb
  - docs/background.md
  - app/components/stop_sequence_component.rb
  - spec/fixtures/analysis/bus_data/2026-10-23/07.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-23/08.jsonl
  - app/components/end_map_component.html.erb
  - app/components/route_map_component.rb
  - app/models/route_day_loader.rb
  - config/route_page.yml
  - app/components/buffer_trade_component.yml
  - spec/factories/route_day_end_toilets.rb
  - analysis/60_export.sql
  - app/components/route_map_component.yml
  - app/models/route_day.rb
  - app/frontend/entrypoints/application.js
  - app/models/route_page/route_shape.rb
  - lib/analysis_run.rb
  - app/models/route_page/load_profile.rb
  - analysis/turnaround_facilities.sql
  - spec/fixtures/analysis/static/2026-10-19/GetPathDetail.gz
  - app/views/routes/show.html.erb
  - docs/decisions.md
  - spec/fixtures/analysis/static/2026-10-23/GetBusShape.gz
  - spec/fixtures/analysis/bus_event/2026-10-23/07.jsonl
  - spec/fixtures/analysis/static/2026-10-19/GetBusShape.gz
  - config/locales/tw.yml
  - spec/fixtures/analysis/bus_event/2026-10-23/09.jsonl
  - spec/fixtures/analysis/static/2026-10-23/GetPathDetail.gz
  - app/frontend/maps/base_map.js
  - app/models/route_page.rb
  - app/frontend/stylesheets/application.css
  - config/locales/en.yml
  - app/frontend/end_map/runtime.js
  - spec/fixtures/analysis/bus_event/2026-10-24/01.jsonl
  - app/components/application_component.rb
  - spec/fixtures/analysis/bus_event/2026-10-23/08.jsonl
  - db/migrate/20261024050200_backfill_route_id_on_derived_rows.rb
  - app/components/attribution_component.yml
  - app/models/route_day_shape.rb
  - spec/fixtures/analysis/static/2026-10-19/GetStop.gz
  - app/components/data_limitations_component.yml
  - db/migrate/20261024050300_require_route_id_on_derived_rows.rb
  - spec/factories/route_day_ends.rb
  - analysis/50_quality.sql
  - db/migrate/20261024035750_create_route_day_shapes.rb
  - analysis/mrt_overlap.sql
tests:
  - spec/components/route_list_component_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/analysis/params_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/system/end_map_spec.rb
  - spec/analysis/mrt_overlap_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/analysis/trips_spec.rb
  - spec/models/route_page/ends_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/components/route_coverage_component_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/models/route_page/route_shape_spec.rb
  - spec/requests/routes_spec.rb
  - spec/analysis/layovers_spec.rb
  - spec/analysis/profile_spec.rb
  - spec/models/route_day_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/analysis/analysis_run_spec.rb
  - spec/analysis/quality_spec.rb
  - spec/analysis/load_spec.rb
  - spec/analysis/route_shape_spec.rb
  - spec/system/route_map_spec.rb
  - spec/components/route_map_component_spec.rb
  - spec/requests/pages_spec.rb
  - spec/migrations/member_route_columns_spec.rb
  - spec/analysis/card_spec.rb
  - spec/models/route_day_loader_spec.rb
-->

---
### Requirement: Route name and Id in the header

When the page covers stored days, the page heading SHALL be the route name of the latest covered day alone, without the route's Id. The line under the heading SHALL give the departure and destination of the latest covered day followed by the label 路線 Id and the route's Id, so that the Id appears once in the header.

#### Scenario: Name alone, Id beside the departure and destination

- **WHEN** route 9001's latest covered day has route name 測試幹線, departure 甲站 and destination 戊站
- **THEN** the page heading reads 測試幹線, and the line under it reads 甲站－戊站 followed by 路線 Id 9001

#### Scenario: Selected day not stored

- **WHEN** the selected day is not stored for the route
- **THEN** the page shows neither the heading with the route name nor the line with the Id, and states that the day has no data as the requirement "Day coverage" describes

<!-- @trace
source: 02-route-stop-sequence
updated: 2026-10-24
code:
  - app/models/route_day_end_cell.rb
  - config/locales/en.yml
  - output/branding-v2/a-bus/logo.png
  - app/components/route_coverage_component.html.erb
  - app/components/route_list_component.yml
  - app/models/route_day_end.rb
  - bin/health-card
  - app/frontend/entrypoints/application.js
  - app/controllers/routes_controller.rb
  - db/schema.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/12.jsonl
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - analysis/params.sql
  - app/models/route_day_end_toilet.rb
  - app/components/stop_sequence_component.html.erb
  - app/components/stop_sequence_component.yml
  - app/models/route_page/stop_sequence.rb
  - app/components/section_nav_component.yml
  - app/models/route_day_loader.rb
  - app/components/attribution_component.rb
  - config/map.yml
  - public/robots.txt
  - docs/data-sources.md
  - app/components/turnaround_facilities_component.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/08.jsonl
  - app/components/turnaround_facilities_component.html.erb
  - spec/support/duckdb.rb
  - app/views/routes/show.html.erb
  - .ruby-version
  - app/models/derived_load_command.rb
  - app/components/layover_chart_component.yml
  - Dockerfile
  - app/frontend/stylesheets/application.css
  - app/components/home_hero_component.yml
  - app/components/load_chart_component.html.erb
  - app/models/map_tiles.rb
  - config/locales/tw.yml
  - app/components/data_limitations_component.yml
  - app/components/section_nav_component.rb
  - app/views/layouts/application.html.erb
  - app/components/attribution_component.yml
  - output/branding-v2/a-bus/favicon-preview.png
  - Gemfile
  - app/models/route_day.rb
  - package.json
  - app/frontend/rest_command.js
  - app/models/route_page/end_map.rb
  - spec/fixtures/analysis/external/public-toilets/2026-10-19.csv
  - analysis/turnaround_facilities.sql
  - analysis/derived_export.sql
  - app/components/end_map_component.html.erb
  - app/components/route_coverage_component.yml
  - app/frontend/end_map/runtime.js
  - app/frontend/hero/scene.js
  - app/components/home_hero_component.html.erb
  - app/components/end_map_component.rb
  - app/components/end_map_component.yml
  - config/deploy.yml
  - app/models/route_page/facilities.rb
  - db/migrate/20261023190654_add_turnaround_facilities_to_derived_tables.rb
  - public/404.html
  - output/branding-v2/a-bus/favicon.ico
  - analysis/README.md
  - spec/fixtures/analysis/README.md
  - spec/fixtures/analysis/bus_data/2026-10-19/11.jsonl
  - spec/factories/route_day_end_toilets.rb
  - spec/factories/route_days.rb
  - app/components/load_chart_component.rb
  - lib/tasks/external.rake
  - app/components/attribution_component.html.erb
  - app/components/turnaround_facilities_component.yml
  - spec/factories/route_day_end_cells.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/07.jsonl
  - app/assets/images/home-hero-wide.webp
  - app/assets/images/home-hero-narrow.webp
  - Gemfile.lock
  - app/components/stop_sequence_component.rb
  - config/initializers/mime_types.rb
  - spec/factories/route_day_ends.rb
  - public/turnaround/og-image-v2.jpg
  - app/frontend/hero/runtime.js
  - app/models/public_toilets_snapshot.rb
  - app/components/route_list_component.html.erb
tests:
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_day_spec.rb
  - spec/requests/pages_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/requests/routes_spec.rb
  - spec/system/rest_command_spec.rb
  - spec/models/public_toilets_snapshot_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/route_page/stop_sequence_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/models/route_page/end_map_spec.rb
  - spec/components/route_list_component_spec.rb
  - spec/components/load_chart_component_spec.rb
  - spec/system/load_chart_hover_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/models/map_tiles_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/requests/not_found_page_spec.rb
  - spec/components/stop_sequence_component_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/route_page/facilities_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/system/end_map_spec.rb
  - spec/components/route_coverage_component_spec.rb
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/requests/easter_eggs_spec.rb
-->

---
### Requirement: Route Ids of a page with member routes

When the page route lists member routes in the route list configuration, the line under the heading SHALL give the departure and destination of the latest covered day followed by the label 路線 Id and every route `Id` of the page, the page route first, joined by 「・」. The page SHALL stay at `/routes/<page Id>`, and a member route's `Id` SHALL NOT have a page of its own.

#### Scenario: Two Ids in the header

- **WHEN** route 9001 lists 9050 under `member_routes` and its latest covered day has departure 甲站 and destination 戊站
- **THEN** the line under the heading reads 甲站－戊站 followed by 路線 Id 9001・9050

#### Scenario: Member route address

- **WHEN** a visitor requests `/routes/9050` and 9050 is listed only under route 9001's `member_routes`
- **THEN** the response is 404 and its body is the content of `public/404.html`

#### Scenario: Single route unchanged

- **WHEN** route 10712 lists no member routes
- **THEN** the line under the heading ends with 路線 Id 10712


<!-- @trace
source: 02-route-307-page
updated: 2026-10-24
code:
  - db/migrate/20261024050300_require_route_id_on_derived_rows.rb
  - app/components/turnaround_facilities_component.rb
  - analysis/10_load.sql
  - bin/health-card
  - spec/fixtures/analysis/README.md
  - analysis/params.sql
  - spec/fixtures/analysis/bus_event/2026-10-23/07.jsonl
  - app/components/turnaround_facilities_component.yml
  - analysis/60_export.sql
  - docs/background.md
  - app/models/route_day.rb
  - analysis/50_quality.sql
  - app/components/data_limitations_component.yml
  - spec/factories/route_day_ends.rb
  - spec/fixtures/analysis/static/2026-10-19/GetPathDetail.gz
  - README.md
  - app/components/data_limitations_component.rb
  - db/migrate/20261024035750_create_route_day_shapes.rb
  - spec/fixtures/analysis/static/2026-10-23/GetProvider.gz
  - analysis/depots.sql
  - spec/fixtures/analysis/static/2026-10-19/GetBusShape.gz
  - app/components/stop_sequence_component.yml
  - spec/fixtures/analysis/bus_data/2026-10-23/07.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-23/07.jsonl
  - app/components/attribution_component.html.erb
  - app/models/trip.rb
  - app/frontend/maps/base_map.js
  - app/models/route_page/route_shape.rb
  - app/models/route_page/stop_sequence.rb
  - config/depot_inspections.yml
  - analysis/40_load_profile.sql
  - analysis/route_shape.sql
  - spec/factories/route_day_shapes.rb
  - db/schema.rb
  - app/models/route_page/depots.rb
  - spec/fixtures/analysis/static/2026-10-23/GetBusShape.gz
  - app/models/route_page/depot_inspections.rb
  - db/migrate/20261024062215_create_route_day_depots.rb
  - app/models/route_day_depot.rb
  - spec/fixtures/analysis/static/2026-10-19/GetRoute.gz
  - app/components/end_map_component.html.erb
  - app/models/route_day_loader.rb
  - config/locales/en.yml
  - analysis/README.md
  - spec/fixtures/analysis/bus_event/2026-10-23/08.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-23/09.jsonl
  - app/components/route_map_component.html.erb
  - spec/factories/route_day_depots.rb
  - spec/factories/route_day_end_cells.rb
  - app/components/attribution_component.yml
  - spec/fixtures/analysis/static/2026-10-23/GetRoute.gz
  - app/models/route_page/load_profile.rb
  - app/frontend/route_map/runtime.js
  - spec/fixtures/analysis/static/2026-10-19/GetStop.gz
  - app/components/route_map_component.rb
  - app/models/route_page/layover_stats.rb
  - app/models/derived_load_command.rb
  - spec/fixtures/analysis/bus_seat_event/2026-10-23/08.jsonl
  - db/migrate/20261024050200_backfill_route_id_on_derived_rows.rb
  - app/frontend/entrypoints/application.js
  - app/models/route_day_shape.rb
  - analysis/turnaround_facilities.sql
  - app/models/pto_assessment_snapshot.rb
  - docs/data-sources.md
  - app/frontend/stylesheets/application.css
  - app/components/application_component.rb
  - analysis/derived_export.sql
  - spec/fixtures/analysis/static/2026-10-19/GetProvider.gz
  - app/components/route_list_component.rb
  - analysis/mrt_overlap.sql
  - app/models/route_page/mrt_overlap.rb
  - app/models/route_page/summary.rb
  - config/route_page.yml
  - lib/tasks/external.rake
  - spec/factories/route_day_end_toilets.rb
  - spec/factories/route_days.rb
  - spec/fixtures/analysis/static/2026-10-23/GetStop.gz
  - app/components/route_map_component.yml
  - spec/fixtures/analysis/bus_event/2026-10-23/09.jsonl
  - app/models/tdx_s2s_travel_time_snapshot.rb
  - app/components/turnaround_facilities_component.html.erb
  - app/components/buffer_trade_component.yml
  - app/views/routes/show.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetPathDetail.gz
  - db/migrate/20261024050100_add_member_route_columns_to_derived_tables.rb
  - app/frontend/end_map/runtime.js
  - app/models/route_day_stop.rb
  - app/components/route_coverage_component.html.erb
  - app/models/route_page.rb
  - spec/fixtures/analysis/bus_event/2026-10-24/01.jsonl
  - app/components/route_list_component.html.erb
  - spec/support/duckdb.rb
  - app/components/data_limitations_component.html.erb
  - app/components/route_coverage_component.rb
  - app/components/stop_sequence_component.html.erb
  - config/locales/tw.yml
  - lib/analysis_run.rb
  - app/components/buffer_trade_component.html.erb
  - app/components/stop_sequence_component.rb
  - docs/decisions.md
tests:
  - spec/models/route_day_spec.rb
  - spec/migrations/member_route_columns_spec.rb
  - spec/analysis/depots_spec.rb
  - spec/models/route_page/route_shape_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/components/data_limitations_component_spec.rb
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/load_spec.rb
  - spec/models/route_page/depots_spec.rb
  - spec/models/route_page/summary_spec.rb
  - spec/analysis/card_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/analysis/trips_spec.rb
  - spec/models/pto_assessment_snapshot_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/tdx_s2s_travel_time_snapshot_spec.rb
  - spec/requests/routes_spec.rb
  - spec/requests/pages_spec.rb
  - spec/models/route_page/stop_sequence_spec.rb
  - spec/components/attribution_component_spec.rb
  - spec/system/route_map_spec.rb
  - spec/components/route_coverage_component_spec.rb
  - spec/analysis/profile_spec.rb
  - spec/analysis/mrt_overlap_spec.rb
  - spec/analysis/quality_spec.rb
  - spec/components/route_list_component_spec.rb
  - spec/analysis/route_shape_spec.rb
  - spec/models/route_page/depot_inspections_spec.rb
  - spec/analysis/layovers_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/analysis/analysis_run_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/components/route_map_component_spec.rb
  - spec/models/route_page/ends_spec.rb
  - spec/system/end_map_spec.rb
  - spec/analysis/params_spec.rb
  - spec/components/stop_sequence_component_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/analysis/cli_spec.rb
-->

---
### Requirement: Member route note in the stop sequence block

For each direction, after the page route's stops and before the turnaround row, the block SHALL state, for every member route whose stops of that direction differ from the page route's on the latest covered day, the member route's name and `Id`, the page route's stops of that direction the member does not serve in sequence order, and the stops the member serves instead in the member's sequence order, the comparison being made by `stopLocationId`. A member route whose stops of a direction equal the page route's SHALL get no such line in that direction, and a page without member routes SHALL have none.

#### Scenario: Member differs in one stop

- **WHEN** on the latest covered day route 9001's direction 0 is 甲站、乙站、丙站、丁站、戊站 and member route 9050's direction 0 is 甲站、乙站、己站、丁站、戊站 with the same `stopLocationId` except at the third stop
- **THEN** direction 0 carries the line 測試幹線經己站（路線 Id 9050）在這個方向不停 丙站，改停 己站。 and direction 1 carries the line 測試幹線經己站（路線 Id 9050）在這個方向不停 丙站對面，改停 己站對面。

#### Scenario: No member routes

- **WHEN** route 10712 lists no member routes
- **THEN** no direction of its stop sequence block carries such a line


<!-- @trace
source: 02-route-307-page
updated: 2026-10-24
code:
  - db/migrate/20261024050300_require_route_id_on_derived_rows.rb
  - app/components/turnaround_facilities_component.rb
  - analysis/10_load.sql
  - bin/health-card
  - spec/fixtures/analysis/README.md
  - analysis/params.sql
  - spec/fixtures/analysis/bus_event/2026-10-23/07.jsonl
  - app/components/turnaround_facilities_component.yml
  - analysis/60_export.sql
  - docs/background.md
  - app/models/route_day.rb
  - analysis/50_quality.sql
  - app/components/data_limitations_component.yml
  - spec/factories/route_day_ends.rb
  - spec/fixtures/analysis/static/2026-10-19/GetPathDetail.gz
  - README.md
  - app/components/data_limitations_component.rb
  - db/migrate/20261024035750_create_route_day_shapes.rb
  - spec/fixtures/analysis/static/2026-10-23/GetProvider.gz
  - analysis/depots.sql
  - spec/fixtures/analysis/static/2026-10-19/GetBusShape.gz
  - app/components/stop_sequence_component.yml
  - spec/fixtures/analysis/bus_data/2026-10-23/07.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-23/07.jsonl
  - app/components/attribution_component.html.erb
  - app/models/trip.rb
  - app/frontend/maps/base_map.js
  - app/models/route_page/route_shape.rb
  - app/models/route_page/stop_sequence.rb
  - config/depot_inspections.yml
  - analysis/40_load_profile.sql
  - analysis/route_shape.sql
  - spec/factories/route_day_shapes.rb
  - db/schema.rb
  - app/models/route_page/depots.rb
  - spec/fixtures/analysis/static/2026-10-23/GetBusShape.gz
  - app/models/route_page/depot_inspections.rb
  - db/migrate/20261024062215_create_route_day_depots.rb
  - app/models/route_day_depot.rb
  - spec/fixtures/analysis/static/2026-10-19/GetRoute.gz
  - app/components/end_map_component.html.erb
  - app/models/route_day_loader.rb
  - config/locales/en.yml
  - analysis/README.md
  - spec/fixtures/analysis/bus_event/2026-10-23/08.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-23/09.jsonl
  - app/components/route_map_component.html.erb
  - spec/factories/route_day_depots.rb
  - spec/factories/route_day_end_cells.rb
  - app/components/attribution_component.yml
  - spec/fixtures/analysis/static/2026-10-23/GetRoute.gz
  - app/models/route_page/load_profile.rb
  - app/frontend/route_map/runtime.js
  - spec/fixtures/analysis/static/2026-10-19/GetStop.gz
  - app/components/route_map_component.rb
  - app/models/route_page/layover_stats.rb
  - app/models/derived_load_command.rb
  - spec/fixtures/analysis/bus_seat_event/2026-10-23/08.jsonl
  - db/migrate/20261024050200_backfill_route_id_on_derived_rows.rb
  - app/frontend/entrypoints/application.js
  - app/models/route_day_shape.rb
  - analysis/turnaround_facilities.sql
  - app/models/pto_assessment_snapshot.rb
  - docs/data-sources.md
  - app/frontend/stylesheets/application.css
  - app/components/application_component.rb
  - analysis/derived_export.sql
  - spec/fixtures/analysis/static/2026-10-19/GetProvider.gz
  - app/components/route_list_component.rb
  - analysis/mrt_overlap.sql
  - app/models/route_page/mrt_overlap.rb
  - app/models/route_page/summary.rb
  - config/route_page.yml
  - lib/tasks/external.rake
  - spec/factories/route_day_end_toilets.rb
  - spec/factories/route_days.rb
  - spec/fixtures/analysis/static/2026-10-23/GetStop.gz
  - app/components/route_map_component.yml
  - spec/fixtures/analysis/bus_event/2026-10-23/09.jsonl
  - app/models/tdx_s2s_travel_time_snapshot.rb
  - app/components/turnaround_facilities_component.html.erb
  - app/components/buffer_trade_component.yml
  - app/views/routes/show.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetPathDetail.gz
  - db/migrate/20261024050100_add_member_route_columns_to_derived_tables.rb
  - app/frontend/end_map/runtime.js
  - app/models/route_day_stop.rb
  - app/components/route_coverage_component.html.erb
  - app/models/route_page.rb
  - spec/fixtures/analysis/bus_event/2026-10-24/01.jsonl
  - app/components/route_list_component.html.erb
  - spec/support/duckdb.rb
  - app/components/data_limitations_component.html.erb
  - app/components/route_coverage_component.rb
  - app/components/stop_sequence_component.html.erb
  - config/locales/tw.yml
  - lib/analysis_run.rb
  - app/components/buffer_trade_component.html.erb
  - app/components/stop_sequence_component.rb
  - docs/decisions.md
tests:
  - spec/models/route_day_spec.rb
  - spec/migrations/member_route_columns_spec.rb
  - spec/analysis/depots_spec.rb
  - spec/models/route_page/route_shape_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/components/data_limitations_component_spec.rb
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/load_spec.rb
  - spec/models/route_page/depots_spec.rb
  - spec/models/route_page/summary_spec.rb
  - spec/analysis/card_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/analysis/trips_spec.rb
  - spec/models/pto_assessment_snapshot_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/tdx_s2s_travel_time_snapshot_spec.rb
  - spec/requests/routes_spec.rb
  - spec/requests/pages_spec.rb
  - spec/models/route_page/stop_sequence_spec.rb
  - spec/components/attribution_component_spec.rb
  - spec/system/route_map_spec.rb
  - spec/components/route_coverage_component_spec.rb
  - spec/analysis/profile_spec.rb
  - spec/analysis/mrt_overlap_spec.rb
  - spec/analysis/quality_spec.rb
  - spec/components/route_list_component_spec.rb
  - spec/analysis/route_shape_spec.rb
  - spec/models/route_page/depot_inspections_spec.rb
  - spec/analysis/layovers_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/analysis/analysis_run_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/components/route_map_component_spec.rb
  - spec/models/route_page/ends_spec.rb
  - spec/system/end_map_spec.rb
  - spec/analysis/params_spec.rb
  - spec/components/stop_sequence_component_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/analysis/cli_spec.rb
-->

---
### Requirement: Data limitation of a page with member routes

When the page route lists member routes, the data limitations block SHALL add one item stating which route `Id`s the page counts as one route; that trips, run times, layovers, round trips, cycles and the rest estimate pool their vehicles; that the stop speeds count only the page route's trips; that the load chart, the MRT overlap and the stop sequence use the page route's stops, with the member routes' on-board counts pooled at the stops both serve and the stops only a member serves left out; and the number of trips of each route `Id` over the covered days. A page without member routes SHALL NOT show this item.

#### Scenario: Trip counts per Id

- **WHEN** the page of route 9001 with member route 9050 covers 2026-10-23, whose stored trips are one of 9001 and two of 9050
- **THEN** the data limitations block has an item that names 9001 and 9050 and contains 9001 1 趟、9050 2 趟

#### Scenario: Absent without member routes

- **WHEN** the page of route 10712 is shown
- **THEN** the data limitations block has no item about counting route `Id`s as one route


#### Scenario: Stop speeds of the page route only

- **WHEN** the page of route 9001 with member route 9050 covers 2026-10-23
- **THEN** the item about counting route `Id`s as one route says that the stop speeds count only the trips of 9001


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
### Requirement: Data limitation of depot inspection scores

The data limitations block of every route page SHALL include one item stating that the depot inspection scores are what 臺北市公共運輸處 recorded when inspecting the operators' stations for the evaluation, not the facilities of the turnaround point; that whether a vehicle returns to its depot during a layover is not measured; that the scores are copied from the report's appendix with both printed columns kept apart, neither averaged nor interpreted; and that the list covers only the stations inspected that term, so a station absent from it is not known to lack rest facilities.

#### Scenario: Item present on a route page

- **WHEN** `/routes/9001` is requested and 9001 has stored days
- **THEN** the data limitations block contains an item mentioning 調度站查核分數, 不是折返點 and 兩欄

<!-- @trace
source: 03-depot-inspection-scores
updated: 2026-10-24
code:
  - db/migrate/20261024050200_backfill_route_id_on_derived_rows.rb
  - spec/factories/route_day_end_toilets.rb
  - app/frontend/entrypoints/application.js
  - app/components/data_limitations_component.rb
  - db/migrate/20261024050300_require_route_id_on_derived_rows.rb
  - app/models/route_page/depot_inspections.rb
  - app/components/buffer_trade_component.yml
  - app/components/stop_sequence_component.yml
  - docs/data-sources.md
  - docs/background.md
  - config/route_page.yml
  - spec/support/duckdb.rb
  - README.md
  - app/models/route_page/mrt_overlap.rb
  - app/views/routes/show.html.erb
  - spec/factories/route_day_ends.rb
  - spec/fixtures/analysis/bus_event/2026-10-23/09.jsonl
  - lib/tasks/external.rake
  - spec/fixtures/analysis/bus_data/2026-10-23/07.jsonl
  - analysis/10_load.sql
  - app/models/route_page/summary.rb
  - analysis/derived_export.sql
  - analysis/route_shape.sql
  - app/components/route_map_component.html.erb
  - db/migrate/20261024062215_create_route_day_depots.rb
  - spec/fixtures/analysis/bus_event/2026-10-23/08.jsonl
  - spec/fixtures/analysis/README.md
  - spec/fixtures/analysis/static/2026-10-19/GetStop.gz
  - app/models/derived_load_command.rb
  - analysis/50_quality.sql
  - app/components/route_list_component.rb
  - analysis/README.md
  - spec/fixtures/analysis/bus_event/2026-10-23/07.jsonl
  - app/models/route_day_loader.rb
  - db/schema.rb
  - app/components/end_map_component.html.erb
  - spec/factories/route_days.rb
  - spec/fixtures/analysis/static/2026-10-19/GetProvider.gz
  - spec/fixtures/analysis/bus_seat_event/2026-10-23/07.jsonl
  - app/models/tdx_s2s_travel_time_snapshot.rb
  - app/components/route_map_component.rb
  - analysis/turnaround_facilities.sql
  - analysis/60_export.sql
  - app/components/attribution_component.html.erb
  - app/components/route_list_component.html.erb
  - app/frontend/end_map/runtime.js
  - spec/fixtures/analysis/static/2026-10-23/GetRoute.gz
  - app/models/route_page/route_shape.rb
  - app/frontend/route_map/runtime.js
  - config/locales/en.yml
  - app/models/route_day_stop.rb
  - app/components/turnaround_facilities_component.yml
  - spec/fixtures/analysis/static/2026-10-23/GetProvider.gz
  - bin/health-card
  - app/components/buffer_trade_component.html.erb
  - spec/factories/route_day_shapes.rb
  - spec/fixtures/analysis/static/2026-10-23/GetStop.gz
  - app/models/route_day.rb
  - spec/fixtures/analysis/static/2026-10-23/GetPathDetail.gz
  - app/components/data_limitations_component.html.erb
  - analysis/params.sql
  - config/locales/tw.yml
  - app/components/stop_sequence_component.rb
  - analysis/depots.sql
  - app/models/route_page/depots.rb
  - app/components/route_coverage_component.rb
  - config/depot_inspections.yml
  - app/models/route_page/stop_sequence.rb
  - analysis/40_load_profile.sql
  - spec/fixtures/analysis/static/2026-10-19/GetBusShape.gz
  - app/components/stop_sequence_component.html.erb
  - app/models/route_page.rb
  - app/models/route_page/layover_stats.rb
  - lib/analysis_run.rb
  - app/components/route_coverage_component.html.erb
  - app/components/application_component.rb
  - app/components/data_limitations_component.yml
  - app/frontend/stylesheets/application.css
  - app/frontend/maps/base_map.js
  - spec/fixtures/analysis/bus_seat_event/2026-10-23/08.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-23/09.jsonl
  - analysis/mrt_overlap.sql
  - app/models/route_page/load_profile.rb
  - spec/factories/route_day_end_cells.rb
  - db/migrate/20261024050100_add_member_route_columns_to_derived_tables.rb
  - app/models/route_day_shape.rb
  - app/models/trip.rb
  - spec/fixtures/analysis/bus_event/2026-10-24/01.jsonl
  - app/models/route_day_depot.rb
  - spec/fixtures/analysis/static/2026-10-23/GetBusShape.gz
  - app/components/attribution_component.yml
  - app/components/route_map_component.yml
  - docs/decisions.md
  - app/components/turnaround_facilities_component.html.erb
  - db/migrate/20261024035750_create_route_day_shapes.rb
  - app/components/turnaround_facilities_component.rb
  - app/models/pto_assessment_snapshot.rb
  - spec/fixtures/analysis/static/2026-10-19/GetPathDetail.gz
  - spec/fixtures/analysis/static/2026-10-19/GetRoute.gz
  - spec/factories/route_day_depots.rb
tests:
  - spec/analysis/params_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/requests/routes_spec.rb
  - spec/components/route_map_component_spec.rb
  - spec/analysis/layovers_spec.rb
  - spec/analysis/load_spec.rb
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/migrations/member_route_columns_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/route_page/summary_spec.rb
  - spec/models/route_page/depot_inspections_spec.rb
  - spec/components/data_limitations_component_spec.rb
  - spec/models/route_page/depots_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/analysis/mrt_overlap_spec.rb
  - spec/system/route_map_spec.rb
  - spec/components/stop_sequence_component_spec.rb
  - spec/analysis/quality_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/profile_spec.rb
  - spec/components/attribution_component_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/analysis/trips_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/analysis/card_spec.rb
  - spec/components/route_list_component_spec.rb
  - spec/models/route_page/ends_spec.rb
  - spec/models/route_page/stop_sequence_spec.rb
  - spec/requests/pages_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/analysis/depots_spec.rb
  - spec/components/route_coverage_component_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_page/route_shape_spec.rb
  - spec/models/tdx_s2s_travel_time_snapshot_spec.rb
  - spec/models/pto_assessment_snapshot_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/system/end_map_spec.rb
  - spec/analysis/analysis_run_spec.rb
  - spec/analysis/route_shape_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/requests/site_layout_spec.rb
-->

---
### Requirement: Buffer estimate controls

The buffer estimate SHALL offer, in one form that requests the route page with the `get` method and carries the current `day` and `range`: a control for the buffer from 0 to 20 minutes, a control for the lateness from 0 to 20 minutes, a choice of the first hour from 0 to 23 that offers only hours below the selected last hour and a choice of the last hour from 1 to 24 that offers only hours above the selected first hour, and, only when both ends of the route are stopping ends, a choice of the end among every stopping end and each stopping end named as `buffer-trade` names it. The block SHALL carry an identifier that differs on every response that renders it. With JavaScript, moving the buffer or the lateness control SHALL replace every figure, the curve marker and the hourly values of the block with those of the curve point at the new minutes to hold, taken from the curve data in the response, without sending a request; it SHALL replace the page address with one whose `buffer` and `late` are the new values and whose other parameters are kept, without adding a history entry; and leaving the page and coming back through the history SHALL show the moved values. Changing the hours or the end SHALL send the form, replace only the buffer estimate block and update the page address with every parameter of the form. Without JavaScript, the form SHALL have a submit button that is not marked hidden, and the response SHALL show the figures of the requested values; a pair of hours that `buffer-trade` rejects SHALL respond 400 like any other rejected parameter.

#### Scenario: Moving the buffer control

- **WHEN** a visitor opens `/routes/9001?day=2026-10-19&range=7d` with JavaScript and moves the buffer control from 15 to 10
- **THEN** every figure of the block equals the curve point at 10 minutes to hold, the block's identifier is unchanged, the page address carries `buffer=10` with `day=2026-10-19` and `range=7d`, and the history has as many entries as before

#### Scenario: Changing the hours

- **WHEN** a visitor with JavaScript sets the first hour to 9
- **THEN** the block's identifier changes, and the page address carries `from=9`, `to=24` and the current `buffer`, `late`, `day` and `range`

#### Scenario: Back to a moved estimate

- **WHEN** a visitor with JavaScript moves the lateness control to 6, follows a link to another page and goes back through the history
- **THEN** the lateness control shows 6 and the figures are those of the curve point at the buffer plus 6

#### Scenario: Controls without JavaScript

- **WHEN** the page of a stored day with layovers is fetched without running any script
- **THEN** the buffer estimate contains a form with the fields `buffer`, `late`, `from`, `to`, `day` and `range` and a submit button that is not marked hidden

#### Scenario: Hour choices stay valid

- **WHEN** the buffer estimate is rendered with the first hour 9 and the last hour 12
- **THEN** the first-hour choices are 0 to 11 and the last-hour choices are 10 to 24

#### Scenario: End choice only with two stopping ends

- **WHEN** the buffer estimate is rendered for a route whose both ends are stopping ends and for a route whose direction 0 is a pass-through end
- **THEN** the first offers the end choice with every stopping end and the two named ends, and the second offers no end choice


<!-- @trace
source: buffer-trade-cost-curve
updated: 2026-10-24
code:
  - app/components/mrt_overlap_component.html.erb
  - analysis/end_nature_survey.sql
  - app/components/buffer_trade_component.yml
  - app/components/buffer_trade_component.html.erb
  - app/components/layover_chart_component.rb
  - lib/analysis_run.rb
  - lib/tasks/survey.rake
  - app/components/route_coverage_component.html.erb
  - app/components/layover_table_component.html.erb
  - app/components/run_time_table_component.html.erb
  - app/components/stop_sequence_component.yml
  - app/models/route_day_loader.rb
  - app/components/layover_table_component.yml
  - analysis/end_nature_evidence.sql
  - app/controllers/routes_controller.rb
  - app/components/cycle_table_component.html.erb
  - app/components/home_hero_component.html.erb
  - app/components/load_chart_component.html.erb
  - config/route_page.yml
  - app/models/route_page/buffer_trade.rb
  - app/components/data_limitations_component.yml
  - docs/decisions.md
  - app/components/turnaround_facilities_component.html.erb
  - analysis/params.sql
  - app/components/layover_chart_component.yml
  - app/models/raw_day_check.rb
  - docs/background.md
  - app/components/origin_story_component.html.erb
  - app/components/site_bar_component.rb
  - analysis/README.md
  - app/components/turnaround_facilities_component.yml
  - README.md
  - app/models/newest_snapshot.rb
  - app/components/buffer_trade_component.rb
  - app/components/site_bar_component.yml
  - app/components/site_bar_component.html.erb
  - app/frontend/entrypoints/application.js
  - analysis/end_nature_export.sql
  - app/components/section_nav_component.html.erb
  - app/components/layover_chart_component.html.erb
  - app/models/derived_load_command.rb
  - app/models/end_nature_survey_command.rb
  - app/views/routes/show.html.erb
  - app/components/route_summary_component.yml
tests:
  - spec/analysis/end_nature_export_spec.rb
  - spec/components/route_summary_component_spec.rb
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/system/rest_command_spec.rb
  - spec/components/layover_table_component_spec.rb
  - spec/models/raw_day_check_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/components/buffer_trade_component_spec.rb
  - spec/components/cycle_table_component_spec.rb
  - spec/models/route_page/ends_spec.rb
  - spec/models/end_nature_survey_command_spec.rb
  - spec/system/end_map_spec.rb
  - spec/components/layover_chart_component_spec.rb
  - spec/models/newest_snapshot_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/route_page/cycles_spec.rb
  - spec/analysis/end_nature_evidence_spec.rb
  - spec/components/stop_sequence_component_spec.rb
  - spec/models/route_page/buffer_trade_spec.rb
  - spec/analysis/analysis_run_spec.rb
  - spec/analysis/end_nature_survey_spec.rb
  - spec/requests/routes_spec.rb
  - spec/system/buffer_trade_spec.rb
-->

---
### Requirement: Buffer estimate curve

When the base of the buffer estimate holds a layover, the block SHALL show the curve of `buffer-trade` as an inline SVG drawn by the server, without a chart library, tooltip, zoom or animation: the minutes to hold from 0 to 40 along the horizontal axis, the added vehicle-hours per day along the vertical axis from 0 to the upper bound at 40 minutes, a line for the lower bound and a line for the upper bound through the 41 points, the area between them, and a marker at the selected minutes to hold on both lines. The response SHALL carry the curve data: for every point, the figures the block shows, formatted as the block shows them, and the coordinates of the marker. The SVG SHALL have the role `img` and a label stating the range of both bounds.

#### Scenario: Curve from the response

- **WHEN** the page of a stored day with layovers is requested with `buffer=15&late=6`
- **THEN** the curve has a lower line and an upper line of 41 points each, the marker stands at 21 minutes with the coordinates of the curve data's point at 21, and the figures shown equal that point's

#### Scenario: No curve without a base

- **WHEN** the base of the buffer estimate is empty
- **THEN** the block contains neither the curve nor the curve data

##### Example: hours without layovers

- **GIVEN** route 9001 has the stored day 2026-10-19 whose layovers at stopping ends all end before 12:00
- **WHEN** a visitor requests `/routes/9001?day=2026-10-19&from=12&to=13`
- **THEN** the buffer estimate contains no curve SVG and no curve data, and still contains its form

<!-- @trace
source: buffer-trade-cost-curve
updated: 2026-10-24
code:
  - app/components/mrt_overlap_component.html.erb
  - analysis/end_nature_survey.sql
  - app/components/buffer_trade_component.yml
  - app/components/buffer_trade_component.html.erb
  - app/components/layover_chart_component.rb
  - lib/analysis_run.rb
  - lib/tasks/survey.rake
  - app/components/route_coverage_component.html.erb
  - app/components/layover_table_component.html.erb
  - app/components/run_time_table_component.html.erb
  - app/components/stop_sequence_component.yml
  - app/models/route_day_loader.rb
  - app/components/layover_table_component.yml
  - analysis/end_nature_evidence.sql
  - app/controllers/routes_controller.rb
  - app/components/cycle_table_component.html.erb
  - app/components/home_hero_component.html.erb
  - app/components/load_chart_component.html.erb
  - config/route_page.yml
  - app/models/route_page/buffer_trade.rb
  - app/components/data_limitations_component.yml
  - docs/decisions.md
  - app/components/turnaround_facilities_component.html.erb
  - analysis/params.sql
  - app/components/layover_chart_component.yml
  - app/models/raw_day_check.rb
  - docs/background.md
  - app/components/origin_story_component.html.erb
  - app/components/site_bar_component.rb
  - analysis/README.md
  - app/components/turnaround_facilities_component.yml
  - README.md
  - app/models/newest_snapshot.rb
  - app/components/buffer_trade_component.rb
  - app/components/site_bar_component.yml
  - app/components/site_bar_component.html.erb
  - app/frontend/entrypoints/application.js
  - analysis/end_nature_export.sql
  - app/components/section_nav_component.html.erb
  - app/components/layover_chart_component.html.erb
  - app/models/derived_load_command.rb
  - app/models/end_nature_survey_command.rb
  - app/views/routes/show.html.erb
  - app/components/route_summary_component.yml
tests:
  - spec/analysis/end_nature_export_spec.rb
  - spec/components/route_summary_component_spec.rb
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/system/rest_command_spec.rb
  - spec/components/layover_table_component_spec.rb
  - spec/models/raw_day_check_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/components/buffer_trade_component_spec.rb
  - spec/components/cycle_table_component_spec.rb
  - spec/models/route_page/ends_spec.rb
  - spec/models/end_nature_survey_command_spec.rb
  - spec/system/end_map_spec.rb
  - spec/components/layover_chart_component_spec.rb
  - spec/models/newest_snapshot_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/route_page/cycles_spec.rb
  - spec/analysis/end_nature_evidence_spec.rb
  - spec/components/stop_sequence_component_spec.rb
  - spec/models/route_page/buffer_trade_spec.rb
  - spec/analysis/analysis_run_spec.rb
  - spec/analysis/end_nature_survey_spec.rb
  - spec/requests/routes_spec.rb
  - spec/system/buffer_trade_spec.rb
-->

---
### Requirement: Link to the timetable

The buffer estimate block SHALL contain one link to the route's timetable page as defined by `timetable`, whose address carries the page's current `day`, `range` and `buffer` and SHALL NOT carry `late`, `from`, `to` or `end`. The link SHALL load the whole timetable page, not the block's frame. When the selected day has no data, the buffer estimate block is not shown and so carries no such link.

#### Scenario: Link carries the current parameters

- **WHEN** a visitor opens `/routes/9001?day=2026-10-19&range=7d&buffer=10&late=6&from=9&to=12`
- **THEN** the buffer estimate block contains a link to `/routes/9001/timetable` whose query is exactly `day=2026-10-19`, `range=7d` and `buffer=10`

#### Scenario: No link without data

- **WHEN** a visitor requests a day of route 9001 that is not stored
- **THEN** the response is 200 and the page's own content contains no link to `/routes/9001/timetable`

#### Scenario: Link leaves the frame

- **WHEN** a visitor activates the link in a browser
- **THEN** the whole page changes to the timetable page with the same `day`, `range` and `buffer`

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
### Requirement: Document title and share text

When the page covers stored days, the page SHALL set its document title to the route name of the latest covered day, the separator ｜ and the site name, as 中山幹線｜折返點 TurnAround; a page with member routes SHALL use the page route's name alone. The page SHALL also set its share text, which the layout's `description`, `og:description` and `twitter:description` metas carry as defined by `site-layout`. The share text SHALL be one string composed of: the departure and destination of the latest covered day joined by －; a comma; the coverage, which for the range `day` is the selected day with its weekday followed by its day type, as 2026-10-22（四）平日, and for the range `7d` is 到 <day with weekday> 為止的最近 7 天，<day type> <count> 天 where count is the number of covered days; a colon; one clause per stopping end as defined by `turnaround-ends`, in direction order, joined by ；, reading 停車端<last stop>：量到 <count> 次折返停留，中位數 <p50> 分鐘，<share> 不到 15 分鐘 when the end has layovers over the covered days and 停車端<last stop>：折返停留 0 次 when it has none, or, when the route has no stopping end, 兩端都是直接折返，沒有停車的一端; a full stop; and the closing sentence 折返停留是駕駛休息的上限，不是工時。. The last stop, count, p50 and share of each clause SHALL be the values of that end's row in the layover table of the same page, formatted as the table formats minutes and shares, so that the share text and the summary key numbers never differ. When the selected day is not stored or the route has no stored days, the page SHALL set neither a title nor share text, so that the layout falls back to the site name and the site description.

#### Scenario: Title of a page with data

- **WHEN** route 9001's latest covered day has the route name 測試幹線 and `/routes/9001` is requested
- **THEN** the document title is 測試幹線｜折返點 TurnAround

#### Scenario: Member routes stay out of the title

- **WHEN** route 9001 lists 9050 under `member_routes` and `/routes/9001` is requested for a stored day
- **THEN** the document title is 測試幹線｜折返點 TurnAround, without any name or Id of 9050

#### Scenario: Share text with one stopping end

- **WHEN** route 9001 is configured with direction 0 as a pass-through end and direction 1 as a stopping end, the stored weekday 2026-10-19 has departure 甲站, destination 戊站 and the last stop 甲站 in direction 1, three layovers of 10, 20 and 30 minutes end in direction 1, and `/routes/9001?day=2026-10-19` is requested
- **THEN** the three description metas are 甲站－戊站，2026-10-19（一）平日：停車端甲站：量到 3 次折返停留，中位數 20.0 分鐘，33.3% 不到 15 分鐘。折返停留是駕駛休息的上限，不是工時。

#### Scenario: Share text with both ends stopping

- **WHEN** both ends of route 9001 are stopping ends, the stored weekday 2026-10-19 has the last stops 戊站 in direction 0 and 甲站 in direction 1, one layover of 5 minutes ends in direction 0 and three of 10, 20 and 30 minutes end in direction 1, and `/routes/9001?day=2026-10-19` is requested
- **THEN** the share text's clauses are 停車端戊站：量到 1 次折返停留，中位數 5.0 分鐘，100.0% 不到 15 分鐘；停車端甲站：量到 3 次折返停留，中位數 20.0 分鐘，33.3% 不到 15 分鐘

#### Scenario: Share text without a stopping end

- **WHEN** both ends of route 9001 are pass-through ends and `/routes/9001` is requested for a stored day
- **THEN** the share text's clause is 兩端都是直接折返，沒有停車的一端

#### Scenario: Stopping end without layovers

- **WHEN** direction 1 of route 9001 is a stopping end whose last stop is 甲站, no layover ends in direction 1 over the covered days, and `/routes/9001` is requested for a stored day
- **THEN** that end's clause is 停車端甲站：折返停留 0 次

#### Scenario: Coverage wording of the seven-day range

- **WHEN** route 9001 has the stored weekdays 2026-10-19 and 2026-10-20 and `/routes/9001?day=2026-10-20&range=7d` is requested
- **THEN** the coverage part of the share text is 到 2026-10-20（二）為止的最近 7 天，平日 2 天

##### Example: coverage wording per range

| Request | Covered days | Coverage part |
| ------- | ------------ | ------------- |
| `/routes/9001?day=2026-10-20` | 2026-10-20 | 2026-10-20（二）平日 |
| `/routes/9001?day=2026-10-20&range=7d` | 2026-10-19, 2026-10-20 | 到 2026-10-20（二）為止的最近 7 天，平日 2 天 |

#### Scenario: Share text uses the summary's values

- **WHEN** a stored day with layovers at a stopping end is rendered
- **THEN** the count, p50 and share in that end's clause of the share text equal the count, the p50 and the share of that end's line in the summary key numbers and in the layover table

#### Scenario: Selected day not stored

- **WHEN** `/routes/9001?day=2026-10-21` is requested and 9001 has no stored day 2026-10-21
- **THEN** the document title is 折返點 TurnAround and the three description metas are the site description

<!-- @trace
source: share-preview-home-figure
updated: 2026-10-25
code:
  - app/models/route_page/format.rb
  - app/models/route_page/share_preview.rb
  - config/locales/tw.yml
  - app/models/home_page/stop_end_figures.rb
  - app/components/route_list_component.yml
  - app/components/application_component.rb
  - app/controllers/pages_controller.rb
  - config/locales/en.yml
  - app/views/routes/show.html.erb
  - app/components/route_list_component.rb
  - app/models/home_page/route_list.rb
  - app/views/layouts/application.html.erb
  - app/components/route_list_component.html.erb
  - app/models/route_page/layover_stats.rb
tests:
  - spec/requests/routes_spec.rb
  - spec/models/route_page/format_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/route_list_component_spec.rb
  - spec/models/home_page/stop_end_figures_spec.rb
  - spec/requests/pages_spec.rb
  - spec/models/route_page/share_preview_spec.rb
  - spec/models/home_page/route_list_spec.rb
-->