# route-page Specification

## Purpose

A web page per route that shows drivers and station managers how the route ran on a Taipei day or over the last 7 days: trip counts, run times, layovers at each end and the load profile. It reads only the derived tables and never shows a vehicle identifier.

## Requirements

### Requirement: Route page address and parameters

The system SHALL serve `GET /routes/:route_id` for route `Id`s listed in the route list configuration, and SHALL respond 404 for any other route `Id`. The optional parameter `day` (`YYYY-MM-DD`) selects a Taipei day and defaults to the latest day stored for the route; the optional parameter `range` is `day` or `7d` and defaults to `day`; the optional parameter `buffer` is the buffer in minutes of `buffer-trade` and defaults to 15. A malformed `day`, any other `range` value or a `buffer` value that `buffer-trade` rejects SHALL respond 400.

#### Scenario: Route not configured

- **WHEN** a visitor requests `/routes/9999` and 9999 is not in the route list
- **THEN** the response is 404

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
source: zhongshan-buffer-trade
updated: 2026-10-22
code:
  - app/components/data_limitations_component.yml
  - app/components/buffer_trade_component.rb
  - app/controllers/routes_controller.rb
  - app/views/routes/show.html.erb
  - app/models/route_page/buffer_trade.rb
  - app/components/buffer_trade_component.yml
  - app/components/buffer_trade_component.html.erb
tests:
  - spec/requests/routes_spec.rb
  - spec/models/route_page/buffer_trade_spec.rb
  - spec/components/buffer_trade_component_spec.rb
-->

---
### Requirement: Day coverage

With `range=day` the page SHALL cover the selected day. With `range=7d` it SHALL cover the selected day and the six Taipei days before it, using only the days stored for the route, and SHALL list the covered dates with their day of week and state that weekdays and holidays are not separated. When the selected day is not stored, the page SHALL respond 200, state that the day has no data and list the stored days.

#### Scenario: Seven days with gaps

- **WHEN** route 9001 has stored days 2026-10-19, 2026-10-20 and 2026-10-22 and a visitor requests `?day=2026-10-22&range=7d`
- **THEN** the page covers exactly 2026-10-19, 2026-10-20 and 2026-10-22 and lists them with their days of week

#### Scenario: Day without data

- **WHEN** a visitor requests `?day=2026-10-25` for route 9001 and that day is not stored
- **THEN** the response is 200, the page says the day has no data and lists the stored days


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
### Requirement: Page content

The page SHALL show, in this order: a summary with the route name, departure and destination, the covered days, the number of trips and of complete trips; the run time summary of `run-time` per direction, with the number of excluded trips; the layovers per direction of the ending trip, each row naming that direction's last stop, with the number of layovers, p10, p50, p90 and the share under 15 minutes as defined by `layover-metrics`; the buffer estimate as defined by `buffer-trade` for the selected buffer, with the number of covered days, measured layovers and trips, the rest achievement, the lower and upper added vehicle-hours per day, the lower and upper added vehicles with their busiest hour, and the vehicles per day; the MRT overlap as defined by `mrt-overlap`, with each direction's number of stops and overlap share at 300, 500 and 800 metres, the overlap stretches at 500 metres with their first and last sequence numbers and stop names, the on-board counts of each stretch per time band, and the day of the entrance snapshot used; and the load profile as defined by `load-profile`, per direction, time band and stop, each cell giving the median, the p90 and the number of trips with a count. Percentiles SHALL be computed over all trips of the covered days, not combined from daily values. The MRT overlap SHALL NOT mark any share as above or below a review threshold. When the stops of the covered days carry no nearest-entrance distance, the MRT overlap block SHALL say that the days need to be loaded again instead of showing shares. The buffer estimate SHALL offer a control that sets the buffer from 0 to 20 minutes; changing it SHALL replace only the buffer estimate block and SHALL update the page address with the `buffer` parameter while keeping `day` and `range`.

#### Scenario: Seven-day percentile pools trips

- **WHEN** day one has layovers of 10 and 20 minutes in direction 0 and day two has one of 30 minutes, and the page covers both days
- **THEN** the direction 0 layover row reports 3 layovers and a p50 of 20.0

#### Scenario: Overlap block in place

- **WHEN** a stored day whose stops carry nearest-entrance distances is rendered
- **THEN** the blocks appear in the order summary, run times, layovers, buffer estimate, MRT overlap, load profile, limitations, and the MRT overlap block names the entrance snapshot day

#### Scenario: Distances missing

- **WHEN** a stored day was loaded before stops carried nearest-entrance distances
- **THEN** the MRT overlap block asks for the day to be loaded again and shows no share

#### Scenario: Buffer from the address

- **WHEN** a visitor requests `/routes/9001?day=2026-10-19&range=7d&buffer=10`
- **THEN** the buffer estimate uses 10 minutes, and its control carries the buffer 10 with the day 2026-10-19 and the range 7d, targeting only the buffer estimate block


<!-- @trace
source: zhongshan-buffer-trade
updated: 2026-10-22
code:
  - app/components/data_limitations_component.yml
  - app/components/buffer_trade_component.rb
  - app/controllers/routes_controller.rb
  - app/views/routes/show.html.erb
  - app/models/route_page/buffer_trade.rb
  - app/components/buffer_trade_component.yml
  - app/components/buffer_trade_component.html.erb
tests:
  - spec/requests/routes_spec.rb
  - spec/models/route_page/buffer_trade_spec.rb
  - spec/components/buffer_trade_component_spec.rb
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

The page SHALL state the data limitations that apply to its numbers: a vehicle is not a driver and a layover is an upper bound on rest; on-board counts come from fare-card taps and do not return to zero between trips; 10-second polling misses stops and trips missing a terminal are left out of run times; the covered days do not separate weekdays and holidays; a stop near an MRT entrance does not mean the bus segment can be replaced by the MRT, distances are straight-line, and the entrance data is updated irregularly; the buffer estimate counts vehicle-hours, not driver hours, uses only measured layovers, and its added vehicles are an hourly average, not a schedule.

#### Scenario: Limitations present

- **WHEN** any route page with data is rendered
- **THEN** it contains a 資料限制 section with the statements above

<!-- @trace
source: zhongshan-buffer-trade
updated: 2026-10-22
code:
  - app/components/data_limitations_component.yml
  - app/components/buffer_trade_component.rb
  - app/controllers/routes_controller.rb
  - app/views/routes/show.html.erb
  - app/models/route_page/buffer_trade.rb
  - app/components/buffer_trade_component.yml
  - app/components/buffer_trade_component.html.erb
tests:
  - spec/requests/routes_spec.rb
  - spec/models/route_page/buffer_trade_spec.rb
  - spec/components/buffer_trade_component_spec.rb
-->