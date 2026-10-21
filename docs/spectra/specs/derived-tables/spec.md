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

A day D SHALL be loaded only when `bus_event/<D>/` contains at least one hour file, `static/<D>/` contains `GetRoute.gz`, `GetStop.gz` and `GetPathDetail.gz`, the read window of D has ended, shown by an hour file `bus_event/<D+1>/01.jsonl` or `bus_event/<D+1>/01.jsonl.gz`, and `external/taipei-mrt-exits/` contains at least one MRT entrance snapshot. A day that fails these checks SHALL fail with a message naming the missing file or directory; a missing snapshot SHALL name `bin/rails external:mrt_exits`.

#### Scenario: Read window not over

- **WHEN** the task is asked for a day whose next day has no 01 hour file yet
- **THEN** that day fails with a message naming the missing hour file and nothing is written for it

#### Scenario: No entrance snapshot

- **WHEN** the data root has no file under `external/taipei-mrt-exits/`
- **THEN** the day fails with a message naming `bin/rails external:mrt_exits` and nothing is written for it


<!-- @trace
source: zhongshan-mrt-overlap
updated: 2026-10-22
code:
  - lib/tasks/external.rake
  - analysis/mrt_overlap.sql
  - docs/data-sources.md
  - app/components/mrt_overlap_component.yml
  - db/migrate/20261021193708_add_mrt_overlap_to_derived_tables.rb
  - app/components/data_limitations_component.yml
  - analysis/10_load.sql
  - app/models/route_page/mrt_overlap.rb
  - app/models/route_day.rb
  - analysis/derived_export.sql
  - spec/fixtures/analysis/README.md
  - app/models/route_day_loader.rb
  - app/models/mrt_exits_snapshot.rb
  - spec/fixtures/analysis/static/2026-10-19/GetStop.gz
  - app/components/mrt_overlap_component.rb
  - app/models/route_day_stop.rb
  - db/schema.rb
  - app/components/mrt_overlap_component.html.erb
  - analysis/README.md
  - app/views/routes/show.html.erb
  - spec/fixtures/analysis/external/taipei-mrt-exits/2026-10-19.csv
tests:
  - spec/analysis/fixtures_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/models/route_day_spec.rb
  - spec/requests/routes_spec.rb
  - spec/analysis/mrt_overlap_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/components/mrt_overlap_component_spec.rb
  - spec/models/mrt_exits_snapshot_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/analysis/derived_export_spec.rb
-->

---
### Requirement: Derived export

For an eligible day the system SHALL run `analysis/params.sql`, every numbered stage file in file name order, then `analysis/mrt_overlap.sql` with the newest MRT entrance snapshot by file name date, and then `analysis/derived_export.sql`, which SHALL write five CSV files: the route day (route `Id`, name, departure, destination, static snapshot day, and the day of the entrance snapshot used), the stops of both directions (direction, sequence number, stop name, latitude, longitude, nearest entrance name and distance as defined by `mrt-overlap`), the trips of the day as defined by `trip-reconstruction` together with each trip's time band from `load-profile`, the layovers as defined by `layover-metrics` with the end time of the trip and the start time of the next trip, and the per-stop on-board counts of each trip as defined by `load-profile`. Timestamps SHALL be written with the `+08:00` offset. Rows SHALL be sorted so that two runs over the same input produce byte-identical files.

#### Scenario: Stage order shared with the health card

- **WHEN** `bin/health-card` and `derived:load` assemble their SQL
- **THEN** both put the variable settings first, `analysis/params.sql` second and the numbered stage files after it in file name order, and only `derived:load` appends `analysis/mrt_overlap.sql` and `analysis/derived_export.sql`

#### Scenario: Newest snapshot used

- **WHEN** the snapshot folder holds `2026-10-20.csv` and `2026-10-22.csv` and day 2026-10-19 is loaded
- **THEN** the distances come from `2026-10-22.csv` and the stored route day records 2026-10-22 as its entrance snapshot day


<!-- @trace
source: zhongshan-mrt-overlap
updated: 2026-10-22
code:
  - lib/tasks/external.rake
  - analysis/mrt_overlap.sql
  - docs/data-sources.md
  - app/components/mrt_overlap_component.yml
  - db/migrate/20261021193708_add_mrt_overlap_to_derived_tables.rb
  - app/components/data_limitations_component.yml
  - analysis/10_load.sql
  - app/models/route_page/mrt_overlap.rb
  - app/models/route_day.rb
  - analysis/derived_export.sql
  - spec/fixtures/analysis/README.md
  - app/models/route_day_loader.rb
  - app/models/mrt_exits_snapshot.rb
  - spec/fixtures/analysis/static/2026-10-19/GetStop.gz
  - app/components/mrt_overlap_component.rb
  - app/models/route_day_stop.rb
  - db/schema.rb
  - app/components/mrt_overlap_component.html.erb
  - analysis/README.md
  - app/views/routes/show.html.erb
  - spec/fixtures/analysis/external/taipei-mrt-exits/2026-10-19.csv
tests:
  - spec/analysis/fixtures_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/models/route_day_spec.rb
  - spec/requests/routes_spec.rb
  - spec/analysis/mrt_overlap_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/components/mrt_overlap_component_spec.rb
  - spec/models/mrt_exits_snapshot_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/analysis/derived_export_spec.rb
-->

---
### Requirement: Replace one route day atomically

Writing a day SHALL happen in one database transaction that first deletes the existing route day of the same route `Id` and Taipei day, together with all its stops, trips, layovers and trip stop counts, and then inserts the five files. A failure at any step SHALL leave the previously stored data of that day unchanged. Loading the same day twice from the same input SHALL leave the same rows.

#### Scenario: Reload is idempotent

- **WHEN** the fixture day 2026-10-19 of route 9001 is loaded twice
- **THEN** the number of trips, layovers and trip stop counts stored for that day equals the number after the first load

#### Scenario: Failure keeps the old day

- **WHEN** a day is already stored and a later load of the same day fails while inserting
- **THEN** the stored trips of that day are the ones from the earlier load


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