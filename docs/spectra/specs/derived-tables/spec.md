# derived-tables Specification

## Purpose

Compute the per-trip results of one route and one Taipei day from the raw n-gear files with the validated DuckDB stages, and store them in PostgreSQL derived tables that the web pages read. Loading a day replaces that route and day as a whole, so a day can be recomputed any number of times with the same result.

## Requirements

### Requirement: Load task invocation

The system SHALL provide the rake task `derived:load` taking the environment variables `ROUTE` (a route `Id`) and either `DAY` or both `FROM` and `TO` (Taipei days, `YYYY-MM-DD`, `FROM` not after `TO`). The raw data root SHALL come only from the environment variable `TURNAROUND_DATA`. The task SHALL process the days in ascending order and print one line per day with either the counts written (trips, layovers, trip stop counts) or the reason the day failed.

#### Scenario: Usage error

- **WHEN** the task runs without `ROUTE`, without `TURNAROUND_DATA`, with only one of `FROM` and `TO`, with `FROM` after `TO`, or with a malformed date
- **THEN** it prints the usage, exits with a non-zero status and writes nothing

#### Scenario: DuckDB missing

- **WHEN** `duckdb` is not on PATH
- **THEN** the task prints that the DuckDB CLI is required together with `brew install duckdb`, exits with a non-zero status and writes nothing


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

For an eligible day the system SHALL run `analysis/params.sql`, every numbered stage file in file name order, then `analysis/mrt_overlap.sql` with the newest MRT entrance snapshot by file name date, then `analysis/turnaround_facilities.sql` with the newest public toilet snapshot by file name date and the natures of the route's two ends from the configuration defined by `turnaround-ends` (or `unknown` for both when the route is not configured), and then `analysis/derived_export.sql`, which SHALL write eight CSV files: the route day (route `Id`, name, departure, destination, static snapshot day, the day of the entrance snapshot used and the day of the toilet snapshot used), the stops of both directions (direction, sequence number, stop name, latitude, longitude, nearest entrance name and distance as defined by `mrt-overlap`), the trips of the day as defined by `trip-reconstruction` together with each trip's time band from `load-profile`, the layovers as defined by `layover-metrics` with the end time of the trip and the start time of the next trip, the per-stop on-board counts of each trip as defined by `load-profile`, the ends of the route (direction, last stop sequence number, name, latitude and longitude, location source, location latitude and longitude, numbers of layovers, located layovers and standstill reports, and metres from the location to the last stop) as defined by `turnaround-facilities`, the toilets within the radius of each located end (direction, name, category, address, latitude, longitude, metres) as defined by `turnaround-facilities`, and the standstill cells of each end (direction, cell latitude, cell longitude, numbers of standstill reports, vehicles and layovers) as defined by `turnaround-facilities`. The `bus_data` hour files SHALL be read only by `analysis/turnaround_facilities.sql`, over the same read window as the stage files, so that `bin/health-card` and its inspection files do not change. Timestamps SHALL be written with the `+08:00` offset. Rows SHALL be sorted so that two runs over the same input produce byte-identical files.

#### Scenario: Stage order shared with the health card

- **WHEN** `bin/health-card` and `derived:load` assemble their SQL
- **THEN** both put the variable settings first, `analysis/params.sql` second and the numbered stage files after it in file name order, and only `derived:load` appends `analysis/mrt_overlap.sql`, `analysis/turnaround_facilities.sql` and `analysis/derived_export.sql` in that order

#### Scenario: Newest snapshot used

- **WHEN** the snapshot folder holds `2026-10-20.csv` and `2026-10-22.csv` and day 2026-10-19 is loaded
- **THEN** the distances come from `2026-10-22.csv` and the stored route day records 2026-10-22 as its entrance snapshot day

#### Scenario: Newest toilet snapshot used

- **WHEN** `external/public-toilets/` holds `2026-10-20.csv` and `2026-10-23.csv` and day 2026-10-19 is loaded
- **THEN** the toilets come from `2026-10-23.csv` and the stored route day records 2026-10-23 as its toilet snapshot day

#### Scenario: Eight files written

- **WHEN** the fixture day 2026-10-19 of route 9001 is exported twice
- **THEN** both runs write `route_day.csv`, `stops.csv`, `trips.csv`, `layovers.csv`, `trip_stop_counts.csv`, `ends.csv`, `end_toilets.csv` and `end_cells.csv` with identical bytes, and the health card's inspection files are unchanged


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
### Requirement: Replace one route day atomically

Writing a day SHALL happen in one database transaction that first deletes the existing route day of the same route `Id` and Taipei day, together with all its stops, trips, layovers, trip stop counts, ends, end toilets and end cells, and then inserts the eight files. A failure at any step SHALL leave the previously stored data of that day unchanged. Loading the same day twice from the same input SHALL leave the same rows.

#### Scenario: Reload is idempotent

- **WHEN** the fixture day 2026-10-19 of route 9001 is loaded twice
- **THEN** the number of trips, layovers, trip stop counts, ends, end toilets and end cells stored for that day equals the number after the first load

#### Scenario: Failure keeps the old day

- **WHEN** a day is already stored and a later load of the same day fails while inserting
- **THEN** the stored trips of that day are the ones from the earlier load


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

For the same input files, route and day, the stored data SHALL reproduce the health card's numbers when aggregated with the route page queries: the number of trips and complete trips, for each direction the number of layovers with their p10, p50 and p90 and the share under 15 minutes, and for each direction, band and stop the number of trips with a count, the median and the p90.

#### Scenario: Fixture day agrees with the card

- **WHEN** the fixture route 9001 on 2026-10-19 is both rendered by `bin/health-card` and loaded by `derived:load`
- **THEN** every number listed above computed from the database equals the corresponding number in the card's JSON

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