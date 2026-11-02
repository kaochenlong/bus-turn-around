## ADDED Requirements

### Requirement: Published schedule rows stored with the route day

The derived export SHALL run `analysis/published_schedule.sql` before `analysis/derived_export.sql` and SHALL also write `published_headways.csv` with the columns `route_id, path_attribute_id, date_value, start_minute, end_minute, low_minutes, high_minutes` and `published_departures.csv` with the columns `route_id, path_attribute_id, date_value, minute`, each ordered by all its columns, as defined by the requirement "Published schedule read from the static snapshot" of `published-schedule`. The loader SHALL store the rows in `route_day_published_headways` and `route_day_published_departures`, deleted with the route day and written inside the same transaction as the other tables, and SHALL store on the route day `published_schedule_day`, the day of the static snapshot read. `GetSemiTimeTable.gz` and `GetTimeTable.gz` SHALL NOT be required for a day to be eligible: a snapshot without one of them SHALL print a line naming the file, the route and the day, and leave that file's rows empty; when both are missing `published_schedule_day` SHALL be empty. `bin/push-derived` SHALL carry both tables with the other derived tables.

#### Scenario: Fixture day rows stored

- **WHEN** `derived:load ROUTE=9001 DAY=2026-10-19` runs
- **THEN** `route_day_published_headways` has 18 rows for that route day, `route_day_published_departures` has 6 rows, and the route day's `published_schedule_day` is 2026-10-19

#### Scenario: Rows replaced with the day

- **WHEN** the same route day is loaded again
- **THEN** both tables still have 18 and 6 rows for that route day, and the counts of trips, layovers and trip stop counts are unchanged

#### Scenario: Same bytes on two runs

- **WHEN** the fixture day 2026-10-19 of route 9001 is exported twice
- **THEN** both runs write `published_headways.csv` and `published_departures.csv` with identical bytes

#### Scenario: Snapshot without the files

- **WHEN** the day's static snapshot holds `GetRoute.gz`, `GetStop.gz` and `GetPathDetail.gz` but neither `GetSemiTimeTable.gz` nor `GetTimeTable.gz`
- **THEN** the day is loaded, two lines name the missing files, both tables have no rows for that route day and its `published_schedule_day` is empty

#### Scenario: Derived tables pushed

- **WHEN** `bin/push-derived` lists the derived tables
- **THEN** `route_day_published_headways` and `route_day_published_departures` are listed among the tables that reference `route_days`
