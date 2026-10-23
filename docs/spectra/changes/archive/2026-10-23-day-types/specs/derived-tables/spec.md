## MODIFIED Requirements

### Requirement: Day eligibility

A day D SHALL be loaded only when `bus_event/<D>/` contains at least one hour file, `static/<D>/` contains `GetRoute.gz`, `GetStop.gz` and `GetPathDetail.gz`, the read window of D has ended, shown by an hour file `bus_event/<D+1>/01.jsonl` or `bus_event/<D+1>/01.jsonl.gz`, `external/taipei-mrt-exits/` contains at least one MRT entrance snapshot, and `external/office-calendar/<year of D>/` contains at least one office calendar snapshot as defined by `day-types` whose newest file has a row for D. A day that fails these checks SHALL fail with a message naming the missing file or directory; a missing entrance snapshot SHALL name `bin/rails external:mrt_exits`, and a missing calendar snapshot SHALL name `bin/rails external:office_calendar YEAR=<year of D>`. When both snapshots are missing, the message SHALL name the entrance snapshot.

#### Scenario: Read window not over

- **WHEN** the task is asked for a day whose next day has no 01 hour file yet
- **THEN** that day fails with a message naming the missing hour file and nothing is written for it

#### Scenario: No entrance snapshot

- **WHEN** the data root has no file under `external/taipei-mrt-exits/`
- **THEN** the day fails with a message naming `bin/rails external:mrt_exits` and nothing is written for it

#### Scenario: No calendar snapshot

- **WHEN** the data root has an entrance snapshot but no file under `external/office-calendar/2026/`, and day 2026-10-19 is loaded
- **THEN** the day fails with a message naming `bin/rails external:office_calendar YEAR=2026` and nothing is written for it

## ADDED Requirements

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
