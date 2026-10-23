## MODIFIED Requirements

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

### Requirement: Replace one route day atomically

Writing a day SHALL happen in one database transaction that first deletes the existing route day of the same route `Id` and Taipei day, together with all its stops, trips, layovers, trip stop counts, ends, end toilets and end cells, and then inserts the eight files. A failure at any step SHALL leave the previously stored data of that day unchanged. Loading the same day twice from the same input SHALL leave the same rows.

#### Scenario: Reload is idempotent

- **WHEN** the fixture day 2026-10-19 of route 9001 is loaded twice
- **THEN** the number of trips, layovers, trip stop counts, ends, end toilets and end cells stored for that day equals the number after the first load

#### Scenario: Failure keeps the old day

- **WHEN** a day is already stored and a later load of the same day fails while inserting
- **THEN** the stored trips of that day are the ones from the earlier load
