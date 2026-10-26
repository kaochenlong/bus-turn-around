# derived-tables Specification

## Purpose

Compute the per-trip results of one route and one Taipei day from the raw n-gear files with the validated DuckDB stages, and store them in PostgreSQL derived tables that the web pages read. Loading a day replaces that route and day as a whole, so a day can be recomputed any number of times with the same result.

## Requirements

### Requirement: Load task invocation

The system SHALL provide the rake task `derived:load` taking the environment variables `ROUTE` (a route `Id`) and either `DAY` or both `FROM` and `TO` (Taipei days, `YYYY-MM-DD`, `FROM` not after `TO`). `ROUTE` SHALL be a page route, a key of the route list configuration, or a route the configuration does not mention at all; a route `Id` listed under another route's `member_routes` SHALL be a usage error whose message names the page route to use instead. The task SHALL run the analysis with the page route's member route `Id`s. The raw data root SHALL come only from the environment variable `TURNAROUND_DATA`. The task SHALL process the days in ascending order and print one line per day with either the counts written (trips, layovers, trip stop counts) or the reason the day failed.

#### Scenario: Usage error

- **WHEN** the task runs without `ROUTE`, without `TURNAROUND_DATA`, with only one of `FROM` and `TO`, with `FROM` after `TO`, or with a malformed date
- **THEN** it prints the usage, exits with a non-zero status and writes nothing

#### Scenario: Member route given as ROUTE

- **WHEN** the task runs with `ROUTE=9050` and 9050 is listed under route 9001's `member_routes`
- **THEN** it prints that 9050 belongs to the page of 9001 and that `ROUTE=9001` loads it, exits with a non-zero status and writes nothing

#### Scenario: DuckDB missing

- **WHEN** `duckdb` is not on PATH
- **THEN** the task prints that the DuckDB CLI is required together with `brew install duckdb`, exits with a non-zero status and writes nothing


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
### Requirement: Day eligibility

A day D SHALL be loaded only when `bus_event/<D>/` contains at least one hour file, `bus_data/<D>/` contains at least one hour file, `static/<D>/` contains `GetRoute.gz`, `GetStop.gz` and `GetPathDetail.gz`, the read window of D has ended, shown by an hour file `bus_event/<D+1>/01.jsonl` or `bus_event/<D+1>/01.jsonl.gz`, `external/taipei-mrt-exits/` contains at least one MRT entrance snapshot, `external/public-toilets/` contains at least one public toilet snapshot as defined by `turnaround-facilities`, and `external/office-calendar/<year of D>/` contains at least one office calendar snapshot as defined by `day-types` whose newest file has a row for D. A day that fails these checks SHALL fail with a message naming the missing file or directory; a missing entrance snapshot SHALL name `bin/rails external:mrt_exits`, a missing toilet snapshot SHALL name `bin/rails external:public_toilets`, and a missing calendar snapshot SHALL name `bin/rails external:office_calendar YEAR=<year of D>`. When the entrance snapshot is missing together with any other snapshot, the message SHALL name the entrance snapshot; when only the toilet and calendar snapshots are missing, the message SHALL name the toilet snapshot.

#### Scenario: Read window not over

- **WHEN** the task is asked for a day whose next day has no 01 hour file yet
- **THEN** that day fails with a message naming the missing hour file and nothing is written for it

#### Scenario: No entrance snapshot

- **WHEN** the data root has no file under `external/taipei-mrt-exits/`
- **THEN** the day fails with a message naming `bin/rails external:mrt_exits` and nothing is written for it

#### Scenario: No calendar snapshot

- **WHEN** the data root has an entrance snapshot and a toilet snapshot but no file under `external/office-calendar/2026/`, and day 2026-10-19 is loaded
- **THEN** the day fails with a message naming `bin/rails external:office_calendar YEAR=2026` and nothing is written for it

#### Scenario: No toilet snapshot

- **WHEN** the data root has an entrance snapshot but no file under `external/public-toilets/`
- **THEN** the day fails with a message naming `bin/rails external:public_toilets` and nothing is written for it

#### Scenario: No vehicle position files

- **WHEN** `bus_event/<D>/` has hour files but `bus_data/<D>/` has none
- **THEN** the day fails with a message naming the `bus_data/<D>` directory and nothing is written for it


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
### Requirement: Derived export

For an eligible day the system SHALL run `analysis/params.sql`, every numbered stage file in file name order, then `analysis/mrt_overlap.sql` with the newest MRT entrance snapshot by file name date, then `analysis/gps_reports.sql`, then `analysis/turnaround_facilities.sql` with the newest public toilet snapshot by file name date and the natures of the route's two ends from the configuration defined by `turnaround-ends` (or `unknown` for both when the route is not configured), then `analysis/route_shape.sql` with the route shapes file of the day's static snapshot as defined by `route-shape`, then `analysis/depots.sql` with the operators file of the day's static snapshot as defined by the requirement "Depot rows stored with the route day", then `analysis/stop_speeds.sql` as defined by `stop-to-stop-speed`, and then `analysis/derived_export.sql`, which SHALL write eleven CSV files: the route day (route `Id`, name, departure, destination, static snapshot day, the day of the entrance snapshot used, the day of the toilet snapshot used and the member routes' names), the stops of both directions of every route `Id` of the run (direction, sequence number, stop name, latitude, longitude, nearest entrance name and distance as defined by `mrt-overlap`, route `Id`, stop location, and the position along the route shape as defined by `stop-to-stop-speed`), the trips of the day as defined by `trip-reconstruction` together with each trip's time band from `load-profile` and its route `Id`, the layovers as defined by `layover-metrics` with the end time of the trip and the start time of the next trip, the per-stop on-board counts of each trip as defined by `load-profile`, the ends of the route (direction, last stop sequence number, name, latitude and longitude, location source, location latitude and longitude, numbers of layovers, located layovers and standstill reports, and metres from the location to the last stop) as defined by `turnaround-facilities`, the toilets within the radius of each located end (direction, name, category, address, latitude, longitude, metres) as defined by `turnaround-facilities`, the standstill cells of each end (direction, cell latitude, cell longitude, numbers of standstill reports, vehicles and layovers) as defined by `turnaround-facilities`, the route shapes, one row per direction (direction, update time, the points as a JSON array of latitude and longitude pairs, and the reason when the direction has no shape that can be kept or had more than one row) as defined by `route-shape`, the depots of the day's trips as defined by the requirement "Depot rows stored with the route day", and the stop speeds as defined by the requirement "Stop speed rows stored with the route day". `analysis/gps_reports.sql` SHALL keep the GPS reports of every vehicle that has a trip of the day, one per `(BusID, DataTime)`, for `analysis/turnaround_facilities.sql`, `analysis/stop_speeds.sql` and the survey of `end-nature-survey`. The `bus_data` hour files SHALL be read only by `analysis/gps_reports.sql`, over the same read window as the stage files, and the route shapes file only by `analysis/route_shape.sql`, so that `bin/health-card` and its inspection files do not change. Timestamps SHALL be written with the `+08:00` offset. Rows SHALL be sorted so that two runs over the same input produce byte-identical files.

#### Scenario: Stage order shared with the health card

- **WHEN** `bin/health-card` and `derived:load` assemble their SQL
- **THEN** both put the variable settings first, `analysis/params.sql` second and the numbered stage files after it in file name order, and only `derived:load` appends `analysis/mrt_overlap.sql`, `analysis/gps_reports.sql`, `analysis/turnaround_facilities.sql`, `analysis/route_shape.sql`, `analysis/depots.sql`, `analysis/stop_speeds.sql` and `analysis/derived_export.sql` in that order

#### Scenario: Newest snapshot used

- **WHEN** the snapshot folder holds `2026-10-20.csv` and `2026-10-22.csv` and day 2026-10-19 is loaded
- **THEN** the distances come from `2026-10-22.csv` and the stored route day records 2026-10-22 as its entrance snapshot day

#### Scenario: Newest toilet snapshot used

- **WHEN** `external/public-toilets/` holds `2026-10-20.csv` and `2026-10-23.csv` and day 2026-10-19 is loaded
- **THEN** the toilets come from `2026-10-23.csv` and the stored route day records 2026-10-23 as its toilet snapshot day

#### Scenario: Every file written

- **WHEN** the fixture day 2026-10-19 of route 9001 is exported twice
- **THEN** both runs write `route_day.csv`, `stops.csv`, `trips.csv`, `layovers.csv`, `trip_stop_counts.csv`, `ends.csv`, `end_toilets.csv`, `end_cells.csv`, `shapes.csv`, `depots.csv` and `stop_speeds.csv` with identical bytes, and the health card's inspection files are unchanged

#### Scenario: GPS read in one place

- **WHEN** the SQL files of `analysis/` are read and the fixture day 2026-10-19 of route 9001 is exported
- **THEN** only `analysis/gps_reports.sql` passes `bus_data` to `day_files`, and the ends, end toilets and standstill cells written are those of the fixture examples of `turnaround-facilities`


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
### Requirement: Replace one route day atomically

Writing a day SHALL happen in one database transaction that first deletes the existing route day of the same route `Id` and Taipei day, together with all its stops, trips, layovers, trip stop counts, ends, end toilets, end cells and shapes, and then inserts the nine files, taking from the route shapes file only the rows that have points. A failure at any step SHALL leave the previously stored data of that day unchanged. Loading the same day twice from the same input SHALL leave the same rows.

#### Scenario: Reload is idempotent

- **WHEN** the fixture day 2026-10-19 of route 9001 is loaded twice
- **THEN** the number of trips, layovers, trip stop counts, ends, end toilets, end cells and shapes stored for that day equals the number after the first load

#### Scenario: Failure keeps the old day

- **WHEN** a day is already stored and a later load of the same day fails while inserting
- **THEN** the stored trips of that day are the ones from the earlier load


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
### Requirement: Range loading stops at the first failure

When loading a range, the task SHALL stop at the first day that fails, keep every day already written in that run, and print the days that were written.

#### Scenario: Middle day fails

- **WHEN** a range of three days is loaded and the second day is not eligible
- **THEN** the first day is stored, the second and third are not, and the output names the first day as written and the second as failed


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
### Requirement: Stored trips match the health card

For the same input files, route, member routes and day, the stored data SHALL reproduce the health card's numbers when aggregated with the route page queries, the card being rendered with the same member routes through `--also-route`: the number of trips and complete trips, for each direction the number of layovers with their p10, p50 and p90 and the share under 15 minutes, and for each direction, band and stop the number of trips with a count, the median and the p90.

#### Scenario: Fixture day agrees with the card

- **WHEN** the fixture route 9001 on 2026-10-19 is both rendered by `bin/health-card` and loaded by `derived:load`
- **THEN** every number listed above computed from the database equals the corresponding number in the card's JSON

#### Scenario: Member day agrees with the card

- **WHEN** the fixture route 9001 with member route 9050 on 2026-10-23 is both rendered by `bin/health-card --route 9001 --also-route 9050 --day 2026-10-23` and loaded by `derived:load ROUTE=9001 DAY=2026-10-23`
- **THEN** every number listed above computed from the database equals the corresponding number in the card's JSON, among them 3 trips, 3 complete trips and one layover of 10.0 minutes in each direction


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
### Requirement: Route day carries its day type

Every stored route day SHALL carry its day type, `weekday` or `holiday`, and its note as defined by `day-types`, together with the file name date of the calendar snapshot they came from. The day type and the snapshot day SHALL NOT be empty; the note is empty when the calendar row has none. They SHALL be written in the same transaction as the rest of the route day, so loading a day again after a newer snapshot replaces them.

#### Scenario: Fixture day is a weekday

- **WHEN** the fixture day 2026-10-19 of route 9001 is loaded with the fixture calendar snapshot `external/office-calendar/2026/2026-10-19.csv`
- **THEN** the stored route day has the day type weekday, no note and the calendar snapshot day 2026-10-19

#### Scenario: Holiday from the calendar

- **WHEN** the fixture day 2026-10-19 is loaded with a calendar snapshot whose row for that day is `20261019,一,2,補假`
- **THEN** the stored route day has the day type holiday and the note 補假

#### Scenario: Day type required

- **WHEN** a route day without a day type is inserted
- **THEN** the database rejects the row

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
### Requirement: Member routes in the stored rows

For every route `Id` of a run, the stored stops SHALL carry that route `Id` and each stop's `stopLocationId`, keyed uniquely by route day, route `Id`, direction and sequence number. Every stored trip SHALL carry the route `Id` its events were mapped to. Stored trip stop counts SHALL carry the page route's sequence numbers as defined by `load-profile`. The route day SHALL store the names of its member routes keyed by their `Id`. A route day of a route without member routes SHALL store its own `Id` on every stop and trip and an empty name map. Rows stored before this requirement SHALL carry the route day's route `Id` on every stop and trip, and no `stopLocationId`, until the day is loaded again.

#### Scenario: Member day rows

- **WHEN** `derived:load ROUTE=9001 DAY=2026-10-23` runs with the test configuration listing 9050 under 9001's `member_routes`
- **THEN** the route day has 20 stops, 10 with route `Id` 9001 and 10 with 9050, each with its `stopLocationId`; 3 trips, two with route `Id` 9050 and one with 9001; and the member names `{"9050": "測試幹線經己站"}`

#### Scenario: Single route day

- **WHEN** `derived:load ROUTE=9001 DAY=2026-10-19` runs with the same configuration
- **THEN** every stop of 2026-10-19 with route `Id` 9001 and every trip carries route `Id` 9001, the 10 stops of 9050 are stored with route `Id` 9050 and no trips, and the member names are `{"9050": "測試幹線經己站"}`

#### Scenario: Rows loaded before the change

- **WHEN** the migration runs on a database holding route days loaded before it
- **THEN** every stop and trip of those days carries its route day's route `Id`, its `stopLocationId` is empty, and the route day's member names are `{}`

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
### Requirement: Depot rows stored with the route day

The derived export SHALL write `depots.csv` with the columns `station_id, provider_name, station_name, n_buses, n_trips`, ordered by `n_buses` descending then `station_id` ascending, and the loader SHALL store its rows in `route_day_depots`, keyed uniquely by route day and `station_id` and deleted with the route day. `GetProvider.gz` SHALL NOT be required for a day to be eligible: without it the rows carry empty names.

#### Scenario: Fixture day depots

- **WHEN** `derived:load ROUTE=9001 DAY=2026-10-19` runs
- **THEN** `route_day_depots` has one row for that route day with `station_id` 19001, 測試客運, 測試站, `n_buses` 4 and `n_trips` equal to the day's number of trips

#### Scenario: Depot rows replaced with the day

- **WHEN** the same route day is loaded again
- **THEN** its previous depot rows are gone and the new ones are present, inside the same transaction as the other tables

##### Example: reload of the fixture day

- **GIVEN** route 9001's 2026-10-19 is stored with one depot row for `station_id` 19001
- **WHEN** `derived:load ROUTE=9001 DAY=2026-10-19` runs again
- **THEN** `route_day_depots` still has exactly one row for that route day, its `id` differs from the previous row's, and the counts of trips, layovers and trip stop counts are unchanged

#### Scenario: Eligible without GetProvider.gz

- **WHEN** the day's static snapshot holds `GetRoute.gz`, `GetStop.gz` and `GetPathDetail.gz` but no `GetProvider.gz`
- **THEN** the day is loaded and its depot rows have empty names

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
### Requirement: Nightly load command

The system SHALL provide the executable `bin/nightly-load`, run from a checkout of this repository on the machine that holds the raw files, which loads the route days the production database lacks by running the route day loader of `derived:load` against the production database over an ssh port forward. Without arguments it SHALL print the plan and SHALL NOT write to the database. With `--load` it SHALL load the selected route days. `--recompute` SHALL be accepted alone or together with `--load` and includes the stored route days in the selection. The environment variable `ROUTE` (a page route `Id`) SHALL be accepted only together with `--recompute`; a `ROUTE` listed under another route's `member_routes` SHALL be a usage error whose message names the page route to use instead, and a `ROUTE` that is not a page route SHALL be a usage error. Any other argument SHALL be a usage error. The raw data root SHALL come only from the environment variable `TURNAROUND_DATA`, and the database password from `WEBSITE_DATABASE_PASSWORD`; when either is missing the command SHALL print the usage and exit with a non-zero status. The executable SHALL run Rails in the `production` environment: it SHALL set `RAILS_ENV` to `production` when the variable is unset and SHALL stop with a message when it is set to anything else; it SHALL set `SECRET_KEY_BASE_DUMMY` to `1` when neither `SECRET_KEY_BASE` nor `SECRET_KEY_BASE_DUMMY` is set; and it SHALL default `DB_HOST` to `127.0.0.1` and `DB_PORT` to the value of `TUNNEL_PORT`, itself defaulting to a fixed local port. The DuckDB CLI SHALL be required on the `PATH` with the same message as `derived:load`. A usage error, a missing environment variable, an invalid day configuration or a missing DuckDB CLI SHALL stop the command before the port forward is opened.

Before reading the database the command SHALL open an ssh port forward from `127.0.0.1:<DB_PORT>` to the database port on the loopback interface (`127.0.0.1`) of the host that `config/deploy.yml` names as the database accessory's host, as the configured ssh user (`root` when none is configured), with `BatchMode=yes`, `ExitOnForwardFailure=yes` and without a remote command, SHALL wait until the local port accepts a connection, and SHALL close the forward when the command finishes, whatever the outcome. When ssh exits before the port accepts a connection, or the port does not accept one within 20 seconds, the command SHALL print the reason and exit with a non-zero status without reading or writing the database.

The plan SHALL print, in this order: the target as `<user>@<host>` with the database name, and whether the migration versions agree; the page routes; the day range from the first day to the last candidate day, marked as the last day whose read window is over, with every skipped day in that range and its reason; the number of stored route days and, per route, the first day, the last day and the number of days; the number of route days to load with the route `Id`s grouped by day; the days whose raw files are incomplete, one line per day with the message of the day eligibility check; and, when `--load` was not given, a last line that says production was not touched and that `--load` loads. The exit status SHALL be 0 when there is nothing to load or every selected route day was written and no candidate day had incomplete raw files, and non-zero otherwise.

#### Scenario: Usage errors

- **WHEN** the command runs with any of the inputs below
- **THEN** it prints the usage with the reason, exits with a non-zero status, opens no port forward and writes nothing

##### Example: inputs that are usage errors

| Input | Reason |
| --- | --- |
| `--push` | unknown argument |
| `--load` without `TURNAROUND_DATA` | missing data root |
| `--load` without `WEBSITE_DATABASE_PASSWORD` | missing database password |
| `ROUTE=9001` without `--recompute` | `ROUTE` only narrows a recompute |
| `ROUTE=9050 --recompute` when 9050 is listed under route 9001's `member_routes` | message names 9001 as the page route to use |
| `ROUTE=4242 --recompute` when 4242 is not a page route | not a page route |

#### Scenario: Environment other than production

- **WHEN** `bin/nightly-load` is started with `RAILS_ENV=test`
- **THEN** it prints that it writes production and that `RAILS_ENV` has to be `production`, and exits with a non-zero status before Rails is loaded

#### Scenario: Plan writes nothing

- **WHEN** the command runs without `--load` while the fixture day 2026-10-19 is a candidate that the database lacks for route 9001
- **THEN** it prints 2026-10-19 with route 9001 under the route days to load, prints the last line naming `--load`, the loader is not invoked, and the row counts of `route_days` and every table linked to it are unchanged

#### Scenario: Port forward cannot be opened

- **WHEN** the ssh process exits before the local port accepts a connection
- **THEN** the command prints that the forward failed together with what ssh printed, exits with a non-zero status, and neither reads nor writes the database

#### Scenario: Forward argument list

- **WHEN** `config/deploy.yml` names `203.0.113.5` as the database accessory's host, configures no ssh user, and `DB_PORT` is set
- **THEN** the forward is opened with `ssh -o BatchMode=yes -o ExitOnForwardFailure=yes … -N -L 127.0.0.1:<DB_PORT>:127.0.0.1:<database port> root@203.0.113.5`, and the process is terminated when the command finishes, also when the command failed

---
### Requirement: Route days selected for loading

The command SHALL select the route days to load as the product of the page routes (the keys of the route list configuration, in configuration order, or only `ROUTE` when given) and the candidate days, minus the route days the database already stores, unless `--recompute` is given, in which case the stored route days are included. The candidate days SHALL run from the configured first day to the last candidate day, excluding the configured skipped days. The last candidate day SHALL be the Taipei date of the current time minus two hours, minus one day, so that a day becomes a candidate at 02:00 Taipei time of the following day and not before. Every candidate day SHALL pass the day eligibility check of `derived:load` once; a day that fails it SHALL be reported with the check's message, SHALL have none of its route days loaded, and SHALL count as a day with incomplete raw files. The route days SHALL be loaded in ascending day order and, within a day, in the configuration order of the routes.

#### Scenario: Last candidate day follows the clock

- **WHEN** the plan is computed at the Taipei times below with the first day 2026-10-19 and no skipped days
- **THEN** the day range ends at the last candidate day shown

##### Example: 02:00 is the boundary

| Current time (Taipei) | Last candidate day |
| --- | --- |
| 2026-10-26 01:59 | 2026-10-24 |
| 2026-10-26 02:00 | 2026-10-25 |
| 2026-10-26 23:59 | 2026-10-25 |

#### Scenario: Stored and skipped route days are left out

- **WHEN** the page routes are 9001 and 9100, the candidate days are 2026-10-19 to 2026-10-23, 2026-10-20 is skipped with a reason, and the database stores route 9001 on 2026-10-19 and route 9100 on 2026-10-19 and 2026-10-21
- **THEN** the route days to load are, in order, 9001 and 9100 on 2026-10-21 (only 9001), 2026-10-22 (both) and 2026-10-23 (both), the skipped day is printed with its reason, and the stored days are printed per route

##### Example: the order of the route days to load

- **GIVEN** the configuration lists 9001 before 9100
- **WHEN** the selection above is made
- **THEN** the route days are loaded in the order (2026-10-21, 9001), (2026-10-22, 9001), (2026-10-22, 9100), (2026-10-23, 9001), (2026-10-23, 9100)

#### Scenario: Recompute includes the stored route days

- **WHEN** the command runs with `--recompute` on the selection above
- **THEN** the route days to load also include (2026-10-19, 9001), (2026-10-19, 9100) and (2026-10-21, 9100), and 2026-10-20 is still left out

#### Scenario: Recompute narrowed to one route

- **WHEN** the command runs with `--recompute` and `ROUTE=9100` on the selection above
- **THEN** only route 9100's route days are selected: 2026-10-19, 2026-10-21, 2026-10-22 and 2026-10-23

#### Scenario: Day with incomplete raw files

- **WHEN** a candidate day fails the day eligibility check of `derived:load`
- **THEN** the day is printed with the check's message, none of its route days is loaded, the other candidate days are still loaded, and the exit status is non-zero

---
### Requirement: Derived days configuration

The system SHALL read the first day and the skipped days from `config/derived_days.yml`, a file with exactly two keys: `first_day`, a date written `YYYY-MM-DD`, and `skipped_days`, a mapping from dates written `YYYY-MM-DD` to a non-empty reason. The mapping SHALL be allowed to be empty. The file SHALL NOT have per-environment sections. A missing key, an extra key, a malformed date or a blank reason SHALL make `bin/nightly-load` print what is wrong, exit with a non-zero status and open no port forward.

#### Scenario: Valid configuration

- **WHEN** the file has `first_day: 2026-10-19` and `skipped_days` mapping 2026-10-23 and 2026-10-24 each to a reason
- **THEN** the first day is 2026-10-19 and both days are skipped with those reasons

#### Scenario: Invalid configuration

- **WHEN** the file has any of the faults below
- **THEN** the command prints the fault, exits with a non-zero status and opens no port forward

##### Example: faults

| File content | Fault |
| --- | --- |
| no `first_day` key | missing key |
| `first_day: 2026-13-01` | malformed date |
| `skipped_days` with the key `2026-10-23` and an empty value | blank reason |
| `skipped_days` with the key `yesterday` | malformed date |
| an extra key `last_day` | extra key |

---
### Requirement: Migration versions agree before loading

After opening the port forward and before writing anything, the command SHALL compare the set of versions in the database's `schema_migrations` with the set of versions of the migration files of the checkout. When the sets differ, the command SHALL print the versions only the database has and the versions only the checkout has, exit with a non-zero status and write nothing.

#### Scenario: Database has a version the checkout lacks

- **WHEN** `schema_migrations` holds the version 20991231000000 and no migration file has it
- **THEN** the command prints that version as present only in the database, exits with a non-zero status, and the loader is not invoked

#### Scenario: Checkout has a version the database lacks

- **WHEN** the checkout has a migration version that `schema_migrations` does not hold
- **THEN** the command prints that version as present only in the checkout, exits with a non-zero status, and the loader is not invoked

#### Scenario: Versions agree

- **WHEN** both sets are equal
- **THEN** the plan says the versions agree and the command continues

---
### Requirement: One failing route day does not stop the others

With `--load`, the command SHALL load every selected route day with the route day loader of `derived:load`, each in the loader's own transaction. When a route day fails, the command SHALL print the day, the route `Id` and the failure message, and SHALL continue with the next route day; route days written before and after it SHALL stay. For every route day written the command SHALL print the day, the route `Id` and the counts the loader returns, worded as `derived:load` words them. The command SHALL end with one line giving the numbers of route days written, route days failed and days with incomplete raw files, and SHALL exit with a non-zero status when either of the last two is not zero.

#### Scenario: One route day fails

- **WHEN** route days (2026-10-19, 9001), (2026-10-19, 9100) and (2026-10-23, 9001) are selected and the loader raises for (2026-10-19, 9100)
- **THEN** the output has a failure line naming 2026-10-19 and 9100 with the message, the other two route days are written, the last line reports 2 written, 1 failed and 0 days with incomplete raw files, and the exit status is non-zero

#### Scenario: Fixture route day written

- **WHEN** the command runs with `--load` on the fixture data root with route 9001 and the single candidate day 2026-10-19
- **THEN** it prints `2026-10-19 9001 寫入：趟次 27、折返停留 18、趟次站 96、兩端公廁 5 間、靜止格 1 格`, the database stores that route day, the last line reports 1 written, 0 failed and 0 days with incomplete raw files, and the exit status is 0

#### Scenario: Nothing to load

- **WHEN** every selected route day is already stored and no candidate day has incomplete raw files
- **THEN** the command prints that there is nothing to load and exits with status 0

---
### Requirement: One load at a time

Before opening the port forward, the command SHALL take an exclusive, non-blocking lock on the file `tmp/nightly-load.lock` under the checkout root and hold it until it finishes. When the lock is held by another process, the command SHALL print `另一個 bin/nightly-load 還在跑，這次不做`, exit with status 0, and open no port forward.

#### Scenario: Lock held

- **WHEN** another process holds the lock on `tmp/nightly-load.lock` and the command runs with `--load`
- **THEN** it prints `另一個 bin/nightly-load 還在跑，這次不做`, exits with status 0, opens no port forward and the loader is not invoked

#### Scenario: Lock released

- **WHEN** a run has finished, with or without failures
- **THEN** the lock is released and the next run takes it

---
### Requirement: Push refuses to drop route days it does not have

`bin/push-derived --push` SHALL, after its existing version and schema checks and before dumping, read the `(route_id, day)` pairs of the production `route_days` and compare them with this database's. When production has a pair this database lacks, the command SHALL print those route days per route as the route `Id`, the first day, the last day and the number of days, SHALL say that they were written into production by the nightly load, that a push would delete them and that a recompute is `bin/nightly-load --recompute` on the machine that holds the raw files, SHALL exit with a non-zero status, and SHALL NOT dump, back up or replace anything. When production has no such pair, the behavior of the push SHALL be unchanged.

#### Scenario: Production has a day this database lacks

- **WHEN** this database stores route 9001 on 2026-10-19 and production stores route 9001 on 2026-10-19 and 2026-10-20
- **THEN** `--push` prints route 9001 with 2026-10-20 to 2026-10-20 and 1 day, names `bin/nightly-load --recompute`, exits with a non-zero status, and no dump, backup or replace command is run

#### Scenario: Production has nothing this database lacks

- **WHEN** production stores exactly the route days this database stores
- **THEN** `--push` proceeds to dump, back up, replace and verify as before

---
### Requirement: Stop speed rows stored with the route day

The derived export SHALL write `stop_speeds.csv` with the columns `bus_id, start_time, seq, band, meters, seconds`, ordered by `bus_id`, `start_time` and `seq`, one row per trip and leg as defined by `stop-to-stop-speed`, and `stops.csv` SHALL end with the column `shape_meters`, to one decimal and empty for a stop without a position. The loader SHALL store each stop speed row in `trip_stop_speeds` against the stored trip of the same route day with the same vehicle and start time, keyed uniquely by trip and `seq` and deleted with its trip, and SHALL store `shape_meters` on `route_day_stops`, inside the same transaction as the other tables. A staged stop speed row that finds no trip SHALL fail the day and leave the previously stored day unchanged. `bin/push-derived` SHALL carry `trip_stop_speeds` with the other derived tables.

#### Scenario: Fixture day stop speeds stored

- **WHEN** `derived:load ROUTE=9001 DAY=2026-10-19` runs
- **THEN** `trip_stop_speeds` has one row for that route day, for the trip of TEST-0001 starting 06:00:00, with `seq` 1, band `other`, 200.0 metres and 40 seconds, and the outbound stops 91000 to 91004 of that route day store `shape_meters` 0.0, 278.0, 556.0, 834.0 and 1111.9

#### Scenario: Stop speed rows replaced with the day

- **WHEN** the same route day is loaded again
- **THEN** `trip_stop_speeds` still has exactly one row for that route day, and the counts of trips, layovers and trip stop counts are unchanged

#### Scenario: Row without a trip

- **WHEN** a staged stop speed row names a vehicle and start time that no stored trip of the route day has
- **THEN** the load fails naming `trip_stop_speeds` and the previously stored day is unchanged

#### Scenario: Derived tables pushed

- **WHEN** `bin/push-derived` lists the derived tables
- **THEN** `trip_stop_speeds` is listed after `trip_stop_counts`, among the tables that reference `trips`

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