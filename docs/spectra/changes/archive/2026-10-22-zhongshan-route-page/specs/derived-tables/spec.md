## Purpose

Compute the per-trip results of one route and one Taipei day from the raw n-gear files with the validated DuckDB stages, and store them in PostgreSQL derived tables that the web pages read. Loading a day replaces that route and day as a whole, so a day can be recomputed any number of times with the same result.

## ADDED Requirements

### Requirement: Load task invocation

The system SHALL provide the rake task `derived:load` taking the environment variables `ROUTE` (a route `Id`) and either `DAY` or both `FROM` and `TO` (Taipei days, `YYYY-MM-DD`, `FROM` not after `TO`). The raw data root SHALL come only from the environment variable `TURNAROUND_DATA`. The task SHALL process the days in ascending order and print one line per day with either the counts written (trips, layovers, trip stop counts) or the reason the day failed.

#### Scenario: Usage error

- **WHEN** the task runs without `ROUTE`, without `TURNAROUND_DATA`, with only one of `FROM` and `TO`, with `FROM` after `TO`, or with a malformed date
- **THEN** it prints the usage, exits with a non-zero status and writes nothing

#### Scenario: DuckDB missing

- **WHEN** `duckdb` is not on PATH
- **THEN** the task prints that the DuckDB CLI is required together with `brew install duckdb`, exits with a non-zero status and writes nothing

### Requirement: Day eligibility

A day D SHALL be loaded only when `bus_event/<D>/` contains at least one hour file, `static/<D>/` contains `GetRoute.gz`, `GetStop.gz` and `GetPathDetail.gz`, and the read window of D has ended, shown by an hour file `bus_event/<D+1>/01.jsonl` or `bus_event/<D+1>/01.jsonl.gz`. A day that fails these checks SHALL fail with a message naming the missing file or directory.

#### Scenario: Read window not over

- **WHEN** the task is asked for a day whose next day has no 01 hour file yet
- **THEN** that day fails with a message naming the missing hour file and nothing is written for it

### Requirement: Derived export

For an eligible day the system SHALL run `analysis/params.sql`, every numbered stage file in file name order, and then `analysis/derived_export.sql`, which SHALL write five CSV files: the route day (route `Id`, name, departure, destination, static snapshot day), the stops of both directions (direction, sequence number, stop name), the trips of the day as defined by `trip-reconstruction` together with each trip's time band from `load-profile`, the layovers as defined by `layover-metrics` with the end time of the trip and the start time of the next trip, and the per-stop on-board counts of each trip as defined by `load-profile`. Timestamps SHALL be written with the `+08:00` offset. Rows SHALL be sorted so that two runs over the same input produce byte-identical files.

#### Scenario: Stage order shared with the health card

- **WHEN** `bin/health-card` and `derived:load` assemble their SQL
- **THEN** both put the variable settings first, `analysis/params.sql` second and the numbered stage files after it in file name order, and only `derived:load` appends `analysis/derived_export.sql`

### Requirement: Replace one route day atomically

Writing a day SHALL happen in one database transaction that first deletes the existing route day of the same route `Id` and Taipei day, together with all its stops, trips, layovers and trip stop counts, and then inserts the five files. A failure at any step SHALL leave the previously stored data of that day unchanged. Loading the same day twice from the same input SHALL leave the same rows.

#### Scenario: Reload is idempotent

- **WHEN** the fixture day 2026-10-19 of route 9001 is loaded twice
- **THEN** the number of trips, layovers and trip stop counts stored for that day equals the number after the first load

#### Scenario: Failure keeps the old day

- **WHEN** a day is already stored and a later load of the same day fails while inserting
- **THEN** the stored trips of that day are the ones from the earlier load

### Requirement: Range loading stops at the first failure

When loading a range, the task SHALL stop at the first day that fails, keep every day already written in that run, and print the days that were written.

#### Scenario: Middle day fails

- **WHEN** a range of three days is loaded and the second day is not eligible
- **THEN** the first day is stored, the second and third are not, and the output names the first day as written and the second as failed

### Requirement: Stored trips match the health card

For the same input files, route and day, the stored data SHALL reproduce the health card's numbers when aggregated with the route page queries: the number of trips and complete trips, for each direction the number of layovers with their p10, p50 and p90 and the share under 15 minutes, and for each direction, band and stop the number of trips with a count, the median and the p90.

#### Scenario: Fixture day agrees with the card

- **WHEN** the fixture route 9001 on 2026-10-19 is both rendered by `bin/health-card` and loaded by `derived:load`
- **THEN** every number listed above computed from the database equals the corresponding number in the card's JSON
