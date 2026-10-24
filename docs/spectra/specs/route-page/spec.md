# route-page Specification

## Purpose

A web page per route that shows drivers and station managers how the route ran on a Taipei day or over the last 7 days: trip counts, run times, layovers at each end and the load profile. It reads only the derived tables and never shows a vehicle identifier.

## Requirements

### Requirement: Route page address and parameters

The system SHALL serve `GET /routes/:route_id` for route `Id`s listed in the route list configuration, and SHALL respond 404 with the site's not-found page, as defined by `not-found-page`, for any other route `Id`. The optional parameter `day` (`YYYY-MM-DD`) selects a Taipei day and defaults to the latest day stored for the route; the optional parameter `range` is `day` or `7d` and defaults to `day`; the optional parameter `buffer` is the buffer in minutes of `buffer-trade` and defaults to 15. A malformed `day`, any other `range` value or a `buffer` value that `buffer-trade` rejects SHALL respond 400.

#### Scenario: Route not configured

- **WHEN** a visitor requests `/routes/9999` and 9999 is not in the route list
- **THEN** the response is 404 and its body is the content of `public/404.html`

#### Scenario: Defaults

- **WHEN** route 9001 has stored days 2026-10-19 and 2026-10-20 and a visitor requests `/routes/9001`
- **THEN** the page shows 2026-10-20 with the range of one day and a buffer of 15 minutes

#### Scenario: Bad parameter

- **WHEN** a visitor requests `/routes/9001?range=30d`
- **THEN** the response is 400

#### Scenario: Bad buffer

- **WHEN** a visitor requests `/routes/9001?buffer=21`
- **THEN** the response is 400


<!-- @trace
source: site-easter-eggs
updated: 2026-10-24
code:
  - config/locales/tw.yml
  - app/components/attribution_component.html.erb
  - config/locales/en.yml
  - app/models/route_day.rb
  - config/map.yml
  - spec/support/duckdb.rb
  - app/models/route_page/cycles.rb
  - app/components/end_map_component.yml
  - analysis/turnaround_facilities.sql
  - app/components/cycle_table_component.yml
  - app/components/home_hero_component.yml
  - spec/fixtures/analysis/README.md
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - public/turnaround/favicon.ico
  - spec/fixtures/analysis/bus_data/2026-10-19/12.jsonl
  - docs/data-sources.md
  - bin/health-card
  - analysis/params.sql
  - app/assets/images/turnaround-logo.webp
  - spec/factories/route_day_end_toilets.rb
  - public/turnaround/icon-16.png
  - app/components/load_chart_component.rb
  - app/components/turnaround_facilities_component.rb
  - spec/fixtures/analysis/external/public-toilets/2026-10-19.csv
  - Gemfile
  - app/components/turnaround_facilities_component.yml
  - app/frontend/stylesheets/application.css
  - spec/factories/route_day_ends.rb
  - app/frontend/end_map/runtime.js
  - app/frontend/hero/scene.js
  - app/components/home_hero_component.html.erb
  - lib/tasks/external.rake
  - spec/fixtures/analysis/bus_data/2026-10-19/11.jsonl
  - app/assets/images/home-hero-wide.webp
  - app/models/route_day_end.rb
  - app/models/map_tiles.rb
  - app/models/route_day_loader.rb
  - config/initializers/mime_types.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/08.jsonl
  - app/views/layouts/application.html.erb
  - app/models/route_page/end_map.rb
  - app/components/attribution_component.yml
  - app/frontend/rest_command.js
  - analysis/derived_export.sql
  - app/components/turnaround_facilities_component.html.erb
  - db/migrate/20261023190654_add_turnaround_facilities_to_derived_tables.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/07.jsonl
  - app/models/public_toilets_snapshot.rb
  - app/components/cycle_table_component.rb
  - public/turnaround/apple-touch-icon.png
  - app/models/route_day_end_cell.rb
  - spec/factories/route_days.rb
  - spec/factories/route_day_end_cells.rb
  - config/deploy.yml
  - app/models/route_day_end_toilet.rb
  - app/components/section_nav_component.yml
  - Dockerfile
  - public/turnaround/icon-32.png
  - app/components/end_map_component.rb
  - app/views/routes/show.html.erb
  - app/components/site_bar_component.html.erb
  - app/models/derived_load_command.rb
  - app/components/load_chart_component.html.erb
  - package.json
  - app/components/attribution_component.rb
  - app/components/section_nav_component.rb
  - app/models/route_page/facilities.rb
  - app/frontend/hero/runtime.js
  - app/frontend/entrypoints/application.js
  - app/components/cycle_table_component.html.erb
  - .ruby-version
  - analysis/README.md
  - public/turnaround/og-image-v2.jpg
  - db/schema.rb
  - app/assets/images/home-hero-narrow.webp
  - app/components/end_map_component.html.erb
  - app/components/data_limitations_component.yml
  - Gemfile.lock
tests:
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_page/end_map_spec.rb
  - spec/requests/easter_eggs_spec.rb
  - spec/system/load_chart_hover_spec.rb
  - spec/models/route_day_spec.rb
  - spec/analysis/params_spec.rb
  - spec/system/rest_command_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/requests/routes_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/components/cycle_table_component_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/models/route_page/facilities_spec.rb
  - spec/models/map_tiles_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/components/load_chart_component_spec.rb
  - spec/requests/not_found_page_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/models/public_toilets_snapshot_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/system/end_map_spec.rb
  - spec/models/route_page/cycles_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/requests/route_page_fixture_spec.rb
-->

---
### Requirement: Day coverage

With `range=day` the page SHALL cover the selected day. With `range=7d` it SHALL cover the selected day and those of the six Taipei days before it that are stored for the route and have the same day type as the selected day, as defined by `day-types`. The page SHALL state whether the covered days are weekdays or holidays, and SHALL list each covered date with its day of week and with its calendar note when it has one. The page SHALL link to the latest stored day on or before the selected day whose day type differs from the selected day's, keeping the range and naming that day and its day type; when there is no such day, the page SHALL NOT show that link. When the selected day is not stored, the page SHALL respond 200, state that the day has no data and list the stored days.

#### Scenario: Seven days with gaps

- **WHEN** route 9001 has the stored weekdays 2026-10-19, 2026-10-20 and 2026-10-22 and a visitor requests `?day=2026-10-22&range=7d`
- **THEN** the page covers exactly 2026-10-19, 2026-10-20 and 2026-10-22, states that they are weekdays and lists them with their days of week

#### Scenario: Seven days keep the selected day's type

- **WHEN** route 9001 has stored weekdays and holidays in the same seven Taipei days and a visitor selects a holiday with `range=7d`
- **THEN** the page covers only the holidays of those seven days and links to the latest weekday before them

##### Example: the Retrocession Day weekend

- **GIVEN** route 9001 has the stored weekdays 2026-10-19 to 2026-10-23 and the stored holidays 2026-10-24, 2026-10-25 and 2026-10-26, the last with the note 補假
- **WHEN** a visitor requests `/routes/9001?day=2026-10-26&range=7d`
- **THEN** the page states holidays, covers exactly 2026-10-24（六）, 2026-10-25（日） and 2026-10-26（一） with the note 補假, and links to `/routes/9001?day=2026-10-23&range=7d`, naming 2026-10-23（五） and weekdays

#### Scenario: No day of the other type before the selected day

- **WHEN** route 9001 has the stored weekdays 2026-10-19 to 2026-10-23 and the stored holidays 2026-10-24 to 2026-10-26, and a visitor requests `?day=2026-10-23&range=7d`
- **THEN** the page covers 2026-10-19 to 2026-10-23, states weekdays and shows no link to holidays

#### Scenario: One day states its type

- **WHEN** route 9001 has the stored weekday 2026-10-23 and the stored holiday 2026-10-26 with the note 補假, and a visitor requests `/routes/9001` without parameters
- **THEN** the page covers 2026-10-26, states that it is a holiday, shows the note 補假 and links to `/routes/9001?day=2026-10-23&range=day`

#### Scenario: Day without data

- **WHEN** a visitor requests `?day=2026-10-25` for route 9001 and that day is not stored
- **THEN** the response is 200, the page says the day has no data and lists the stored days


<!-- @trace
source: day-types
updated: 2026-10-23
code:
  - lib/tasks/external.rake
  - app/models/office_calendar_snapshot.rb
  - docs/data-sources.md
  - config/locales/tw.yml
  - app/models/route_day_loader.rb
  - app/components/data_limitations_component.yml
  - app/components/route_coverage_component.rb
  - app/components/route_coverage_component.yml
  - app/models/mrt_exits_snapshot.rb
  - app/components/route_coverage_component.html.erb
  - db/schema.rb
  - app/components/route_list_component.html.erb
  - db/migrate/20261022230942_add_day_type_to_route_days.rb
  - spec/factories/route_days.rb
  - app/components/attribution_component.html.erb
  - app/components/attribution_component.yml
  - config/locales/en.yml
  - spec/fixtures/analysis/README.md
  - app/models/route_page/coverage.rb
  - app/components/application_component.rb
  - app/components/route_list_component.yml
  - app/models/http_fetcher.rb
  - spec/fixtures/analysis/external/office-calendar/2026/2026-10-19.csv
  - app/models/route_day.rb
  - db/migrate/20261022231802_require_day_type_on_route_days.rb
tests:
  - spec/components/mrt_overlap_component_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/components/route_summary_component_spec.rb
  - spec/models/route_page/buffer_trade_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/components/load_profile_table_component_spec.rb
  - spec/components/run_time_table_component_spec.rb
  - spec/system/home_hero_spec.rb
  - spec/models/http_fetcher_spec.rb
  - spec/models/route_day_spec.rb
  - spec/components/buffer_trade_component_spec.rb
  - spec/components/layover_chart_component_spec.rb
  - spec/components/load_chart_component_spec.rb
  - spec/components/application_component_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/route_page/coverage_spec.rb
  - spec/components/layover_table_component_spec.rb
  - spec/components/route_list_component_spec.rb
  - spec/models/home_page/route_list_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/models/office_calendar_snapshot_spec.rb
  - spec/requests/pages_spec.rb
  - spec/requests/routes_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/models/route_page/run_times_spec.rb
  - spec/components/route_coverage_component_spec.rb
-->

---
### Requirement: Page content

The page SHALL show, in this order: a summary with the route name, departure and destination, the covered days, the number of trips and of complete trips, and the key numbers of the requirement "Key numbers in the summary"; the section links of the requirement "Section links"; the stop sequence block of the requirement "Stop sequence block"; the layover distribution chart, followed by the layovers per direction of the ending trip, each row naming that direction's last stop and the nature of that end as defined by `turnaround-ends` (stopping or pass-through), with the number of layovers, p10, p50, p90 and the share under 15 minutes as defined by `layover-metrics`; the round trip and cycle block of the requirement "Round trip and cycle block"; the turnaround facilities as defined by `turnaround-facilities`, one part per end in direction order, each with the direction, the last stop, the nature of the end, the location source with its check numbers, the number of toilet places within 300 and 500 metres, the nearest place with its number of toilets, the places within 500 metres inside a disclosure that is closed by default, the day of the location used and the day of the toilet snapshot that day was loaded with, each part followed by that end's map container and map data as defined by `turnaround-map` and by the line stating the share of the covered days' standstill reports that the drawn cells cover; the buffer estimate as defined by `buffer-trade` for the selected buffer, with the number of covered days, measured layovers at stopping ends, measured layovers at pass-through ends when the route has such an end, and trips, the rest achievement, the lower and upper added vehicle-hours per day, the lower and upper added vehicles with their busiest hour, and the vehicles per day; the run time summary of `run-time` per direction, with the number of excluded trips; the load chart along the route, followed by the MRT overlap as defined by `mrt-overlap`, with each direction's number of stops and overlap share at 300, 500 and 800 metres, the overlap stretches at 500 metres with their first and last sequence numbers and stop names, the on-board counts of each stretch per time band, and the day of the entrance snapshot used; and the load profile as defined by `load-profile`, per direction, time band and stop, each cell giving the median, the p90 and the number of trips with a count, inside a disclosure that is closed by default and whose rows are all present in the server response. Percentiles SHALL be computed over all trips of the covered days, not combined from daily values. The MRT overlap SHALL NOT mark any share as above or below a review threshold, and the turnaround facilities SHALL NOT judge whether the toilets are enough. When the stops of the covered days carry no nearest-entrance distance, the MRT overlap block SHALL say that the days need to be loaded again instead of showing shares; when the covered days carry no end rows, the turnaround facilities block SHALL say the same and SHALL contain no map container. The buffer estimate SHALL offer a control that sets the buffer from 0 to 20 minutes; changing it SHALL replace only the buffer estimate block and SHALL update the page address with the `buffer` parameter while keeping `day` and `range`.

#### Scenario: Seven-day percentile pools trips

- **WHEN** day one has layovers of 10 and 20 minutes in direction 0 and day two has one of 30 minutes, and the page covers both days
- **THEN** the direction 0 layover row reports 3 layovers and a p50 of 20.0

#### Scenario: Overlap block in place

- **WHEN** a stored day whose stops carry nearest-entrance distances is rendered
- **THEN** the blocks appear in the order summary, stop sequence, layover chart, layovers, round trips and cycles, turnaround facilities, buffer estimate, run times, load chart, MRT overlap, load profile, limitations, and the MRT overlap block names the entrance snapshot day

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

- **WHEN** a visitor requests `/routes/9001?day=2026-10-19&range=7d&buffer=10`
- **THEN** the buffer estimate uses 10 minutes, and its control carries the buffer 10 with the day 2026-10-19 and the range 7d, targeting only the buffer estimate block

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

The page SHALL state the data limitations that apply to its numbers: a vehicle is not a driver and a layover is an upper bound on rest; on-board counts come from fare-card taps and do not return to zero between trips; 10-second polling misses stops and trips missing a terminal are left out of run times; weekdays and holidays follow the office calendar of 行政院人事行政總處, and days off for typhoons are not in that calendar and count as the calendar says; a stop near an MRT entrance does not mean the bus segment can be replaced by the MRT, distances are straight-line, and the entrance data is updated irregularly; the buffer estimate counts vehicle-hours, not driver hours, uses only measured layovers at stopping ends, and its added vehicles are an hourly average, not a schedule; which end buses stop at is a fact verified route by route and written into the configuration, not computed from the data, and it goes stale when the operator changes how the route turns around; layovers at a pass-through end are not rest opportunities and the buffer estimate does not count them; round trips and cycles use only trips whose terminals were observed and that pair up as stored layovers, so their counts are lower than the trip counts, a vehicle's first loop of a day has no cycle, and a cycle is the rhythm of a vehicle, not the roster of one driver; the turnaround point location of a stopping end is where the vehicles stood still during that day's measured layovers, as reported by GPS every 10 seconds, which can be missing for a day, and it is where the vehicle stood, not where the driver went; a pass-through end is anchored on its last stop because buses do not stop there; the toilet data is the national registry of 環境部, updated monthly, with one row per toilet that the page groups into places by address, the toilet distances are straight-line, and the data has no opening hours and says nothing about whether a driver is allowed to use a toilet; the squares on the maps are cells of about 20 metres that at least three vehicles stood in on a day, their shade sums GPS reports taken every 10 seconds and is not minutes stood and not rest, cells with fewer vehicles are left out, and the basemap is third-party data shown as it is.

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
source: turnaround-map
updated: 2026-10-24
code:
  - app/models/route_day_end_toilet.rb
  - app/components/attribution_component.html.erb
  - app/components/data_limitations_component.yml
  - app/views/routes/show.html.erb
  - analysis/params.sql
  - app/components/attribution_component.rb
  - analysis/derived_export.sql
  - app/components/section_nav_component.yml
  - output/branding-v2/a-bus/favicon-preview.png
  - app/components/home_hero_component.yml
  - output/branding-v2/a-bus/favicon.ico
  - app/components/turnaround_facilities_component.rb
  - .ruby-version
  - .kamal/secrets
  - app/components/attribution_component.yml
  - app/components/home_hero_component.html.erb
  - app/components/end_map_component.yml
  - public/turnaround/og-image-v2.jpg
  - app/components/end_map_component.rb
  - spec/support/duckdb.rb
  - app/assets/images/home-hero-wide.webp
  - app/components/section_nav_component.rb
  - app/models/route_day.rb
  - app/components/cycle_table_component.html.erb
  - config/environments/production.rb
  - app/models/route_page/facilities.rb
  - app/components/end_map_component.html.erb
  - config/map.yml
  - public/turnaround/icon-32.png
  - tools/hero/index.html
  - config/locales/en.yml
  - app/components/site_bar_component.html.erb
  - db/migrate/20261023190654_add_turnaround_facilities_to_derived_tables.rb
  - app/components/home_hero_component.rb
  - lib/tasks/external.rake
  - spec/factories/route_day_end_toilets.rb
  - app/models/map_tiles.rb
  - app/views/layouts/application.html.erb
  - app/frontend/hero/runtime.js
  - bin/health-card
  - app/frontend/stylesheets/application.css
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - app/assets/images/home-hero-narrow.webp
  - docs/data-sources.md
  - spec/fixtures/analysis/bus_data/2026-10-19/11.jsonl
  - public/turnaround/icon-16.png
  - app/components/turnaround_facilities_component.yml
  - app/assets/images/home-hero-tall.webp
  - app/assets/images/turnaround-logo.webp
  - public/turnaround/apple-touch-icon.png
  - output/branding-v2/a-bus/logo.png
  - config/deploy.yml
  - app/models/route_page/cycles.rb
  - app/models/route_page/end_map.rb
  - config/database.yml
  - spec/fixtures/analysis/bus_data/2026-10-19/12.jsonl
  - docs/decisions.md
  - package.json
  - spec/fixtures/analysis/README.md
  - spec/factories/route_day_end_cells.rb
  - app/components/cycle_table_component.yml
  - spec/factories/route_day_ends.rb
  - Dockerfile
  - analysis/turnaround_facilities.sql
  - config/credentials/production.yml.enc
  - spec/fixtures/analysis/bus_data/2026-10-19/07.jsonl
  - app/components/turnaround_facilities_component.html.erb
  - app/models/derived_load_command.rb
  - app/frontend/entrypoints/application.js
  - app/frontend/hero/scene.js
  - tools/hero/export.js
  - spec/fixtures/analysis/external/public-toilets/2026-10-19.csv
  - config/locales/tw.yml
  - app/models/route_day_end.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/08.jsonl
  - app/models/route_day_end_cell.rb
  - app/models/route_day_loader.rb
  - Gemfile.lock
  - app/frontend/end_map/runtime.js
  - app/models/public_toilets_snapshot.rb
  - public/turnaround/favicon.ico
  - Gemfile
  - db/schema.rb
  - analysis/README.md
  - app/components/cycle_table_component.rb
  - spec/factories/route_days.rb
tests:
  - spec/models/map_tiles_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/system/end_map_spec.rb
  - spec/models/route_page/cycles_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/cycle_table_component_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/models/route_page/facilities_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/models/route_page/end_map_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/assets/home_hero_images_spec.rb
  - spec/requests/routes_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/public_toilets_snapshot_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/components/home_hero_component_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/system/home_hero_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/analysis/fixtures_spec.rb
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

The page SHALL show, after the section links and before the layover distribution chart, a stop sequence block built from the stops stored for the latest covered day. The block SHALL hold a disclosure that is closed by default, whose summary gives each direction's number of stops and whose rows are all present in the server response. Inside, the block SHALL list each direction in direction order with its stop names in sequence order, marking the first as the first stop and the last as the last stop, and SHALL NOT show sequence numbers. After each direction's last stop, a row SHALL state the nature of that end as defined by `turnaround-ends` (stopping or pass-through) and SHALL name the first stop of the other direction as where the next trip starts; when the other direction has no stops, the row SHALL state only the nature. The block SHALL state the static snapshot day of the latest covered day. When the latest covered day has no stops, the block SHALL state that the covered days have no stop sequence and SHALL show no list. The block SHALL NOT mark stops as near the MRT, SHALL NOT show on-board counts and SHALL NOT mark which stops another route shares.

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

#### Scenario: Only one direction stored

- **WHEN** the latest covered day has stops only in direction 0
- **THEN** the block lists direction 0 only, and its turnaround row states the nature of that end without naming a next first stop

#### Scenario: No stops stored

- **WHEN** the latest covered day has no stops
- **THEN** the block states that the covered days have no stop sequence and shows no list, and every other block renders as before


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