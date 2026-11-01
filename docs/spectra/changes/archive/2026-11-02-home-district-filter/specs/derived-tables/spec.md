## MODIFIED Requirements

### Requirement: Day eligibility

A day D SHALL be loaded only when `bus_event/<D>/` contains at least one hour file, `bus_data/<D>/` contains at least one hour file, `static/<D>/` contains `GetRoute.gz`, `GetStop.gz` and `GetPathDetail.gz`, the read window of D has ended, shown by an hour file `bus_event/<D+1>/01.jsonl` or `bus_event/<D+1>/01.jsonl.gz`, `external/taipei-mrt-exits/` contains at least one MRT entrance snapshot, `external/public-toilets/` contains at least one public toilet snapshot as defined by `turnaround-facilities`, `external/stop-districts/` contains at least one stop district snapshot as defined by `stop-districts`, and `external/office-calendar/<year of D>/` contains at least one office calendar snapshot as defined by `day-types` whose newest file has a row for D. A day that fails these checks SHALL fail with a message naming the missing file or directory; a missing entrance snapshot SHALL name `bin/rails external:mrt_exits`, a missing toilet snapshot SHALL name `bin/rails external:public_toilets`, a missing stop district snapshot SHALL name `bin/rails external:stop_districts`, and a missing calendar snapshot SHALL name `bin/rails external:office_calendar YEAR=<year of D>`. When the entrance snapshot is missing together with any other snapshot, the message SHALL name the entrance snapshot; when the toilet snapshot is missing together with the stop district or calendar snapshot, the message SHALL name the toilet snapshot; when only the stop district and calendar snapshots are missing, the message SHALL name the stop district snapshot.

#### Scenario: Read window not over

- **WHEN** the task is asked for a day whose next day has no 01 hour file yet
- **THEN** that day fails with a message naming the missing hour file and nothing is written for it

#### Scenario: No entrance snapshot

- **WHEN** the data root has no file under `external/taipei-mrt-exits/`
- **THEN** the day fails with a message naming `bin/rails external:mrt_exits` and nothing is written for it

#### Scenario: No calendar snapshot

- **WHEN** the data root has an entrance snapshot, a toilet snapshot and a stop district snapshot but no file under `external/office-calendar/2026/`, and day 2026-10-19 is loaded
- **THEN** the day fails with a message naming `bin/rails external:office_calendar YEAR=2026` and nothing is written for it

#### Scenario: No toilet snapshot

- **WHEN** the data root has an entrance snapshot but no file under `external/public-toilets/`
- **THEN** the day fails with a message naming `bin/rails external:public_toilets` and nothing is written for it

#### Scenario: No stop district snapshot

- **WHEN** the data root has an entrance snapshot and a toilet snapshot but no file under `external/stop-districts/`
- **THEN** the day fails with a message naming `bin/rails external:stop_districts` and nothing is written for it

#### Scenario: No vehicle position files

- **WHEN** `bus_event/<D>/` has hour files but `bus_data/<D>/` has none
- **THEN** the day fails with a message naming the `bus_data/<D>` directory and nothing is written for it

## ADDED Requirements

### Requirement: Stop district rows stored with the route day

The derived export SHALL write `stops.csv` with the column `district` between `stop_location_id` and `shape_meters`, holding each stop's district as defined by `stop-districts` and empty for a stop without one, and SHALL write `districts.csv` with the columns `county, town, n_locations, share, qualifies`, one row per district of the page route's stop locations as defined by `stop-districts`, ordered by `n_locations` descending, then `county`, then `town`; `route_day.csv` SHALL carry `stop_districts_day`, the day of the stop district snapshot used, after `public_toilets_day`. The loader SHALL store `district` on `route_day_stops`, `stop_districts_day` on `route_days`, and each district row in `route_day_districts` against the route day, keyed uniquely by route day, county and town and deleted with the route day, inside the same transaction as the other tables; two district rows with the same county and town SHALL fail the day and leave the previously stored day unchanged. The summary line of a written route day SHALL name the number of district rows as 行政區 N 區. `bin/push-derived` SHALL carry `route_day_districts` with the other derived tables.

#### Scenario: Fixture day district rows stored

- **WHEN** `derived:load ROUTE=9001 DAY=2026-10-19` runs with the fixture snapshot `external/stop-districts/2026-10-19.csv`
- **THEN** `route_day_districts` has two rows for that route day, 臺北市 測試區 with 9 locations, share 0.9 and qualifying, and 新北市 甲區 with 1 location, share 0.1 and qualifying; the route day's `stop_districts_day` is 2026-10-19; the outbound stops at 81000 to 81004 of that route day store the district 臺北市測試區; and the summary line ends with 行政區 2 區

#### Scenario: District rows replaced with the day

- **WHEN** the same route day is loaded again
- **THEN** `route_day_districts` still has exactly two rows for that route day, and the counts of trips, layovers and trip stop counts are unchanged

#### Scenario: Duplicate district rows

- **WHEN** the staged district rows hold two rows with the same county and town
- **THEN** the load fails and the previously stored day is unchanged

#### Scenario: Derived tables pushed

- **WHEN** `bin/push-derived` lists the derived tables
- **THEN** `route_day_districts` is listed among the tables that reference `route_days`
