# trip-reconstruction Specification

## Purpose

Rebuild measured trips for one route and one Taipei day from the raw stop-event files collected by n-gear, so that layover and load metrics share a single trip definition. A trip is one vehicle running one direction of one route from its first observed stop to its last observed stop.

## Requirements

### Requirement: Input window and Taipei-day assignment

For both `bus_event` and `bus_seat_event`, the system SHALL read the hourly files of hours 22 and 23 of day D-1, of every hour of the requested Taipei day D, and of hours 00 and 01 of day D+1, where both the day and the hour are taken from the file path. Hours inside that window that have no file SHALL be skipped without error, and files outside the window SHALL NOT be read. A trip SHALL belong to day D if and only if its start time falls on D. Trips whose start time falls outside D SHALL be discarded after segmentation.

#### Scenario: Trip crossing midnight belongs to the day it started

- **WHEN** a vehicle departs the first stop at 23:40 on D and arrives at the last stop at 00:50 on D+1
- **THEN** the trip is included in the output for D with start time 23:40 and end time 00:50 of the following calendar day

#### Scenario: Trip that started the previous evening is excluded

- **WHEN** a vehicle departs the first stop at 23:30 on D-1, recorded in the hour-23 file of D-1, and its events of the same trip continue until 00:20 on D in the hour-00 file of D
- **THEN** the trip starts on D-1 and no trip of that vehicle starting between 00:00 and 00:20 on D appears in the output for D

#### Scenario: Terminal dwell across midnight is excluded

- **WHEN** a vehicle passes the second-to-last stop at 22:59 on D-1, recorded in the hour-22 file of D-1, arrives at the last stop at 23:05 and departs the last stop at 00:02 on D
- **THEN** the trip starts on D-1 and no trip of that vehicle starting at 00:02 on D appears in the output for D

#### Scenario: Files outside the window are not read

- **WHEN** files exist for hour 21 of D-1 and for hour 02 of D+1
- **THEN** neither file is read and none of their events appear in any trip

#### Scenario: Missing hours are skipped

- **WHEN** the requested day is the first day of collection and no file exists for D-1
- **THEN** the existing files of D and D+1 are read and the run completes without error


<!-- @trace
source: zhongshan-first-health-card
updated: 2026-10-22
code:
  - spec/fixtures/analysis/bus_event/2026-10-19/08.jsonl.gz
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/16.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/13.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-20/02.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/08.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-20/00.jsonl
  - spec/fixtures/analysis/static/2026-10-19/GetRoute.gz
  - spec/fixtures/analysis/bus_seat_event/2026-10-20/01.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/17.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/10.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/15.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/20.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/16.jsonl
  - analysis/30_layovers.sql
  - spec/fixtures/analysis/bus_event/2026-10-19/00.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/14.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/17.jsonl
  - analysis/10_load.sql
  - Makefile
  - spec/fixtures/analysis/static/2026-10-19/GetStop.gz
  - analysis/20_trips.sql
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/21.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-20/02.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/11.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/07.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/11.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-20/01.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-18/21.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/00.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/07.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/19.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/09.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/22.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/19.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/22.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/14.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-20/00.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-18/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/09.jsonl
  - analysis/40_load_profile.sql
  - spec/fixtures/analysis/bus_event/2026-10-19/18.jsonl
  - analysis/60_export.sql
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/06.jsonl
  - spec/fixtures/analysis/static/2026-10-19/GetPathDetail.gz
  - spec/fixtures/analysis/bus_event/2026-10-19/20.jsonl
  - analysis/params.sql
  - analysis/README.md
  - spec/fixtures/analysis/bus_event/2026-10-18/22.jsonl
  - analysis/50_quality.sql
  - spec/support/duckdb.rb
  - spec/fixtures/analysis/bus_seat_event/2026-10-18/22.jsonl
  - docs/cards/15373-2026-10-19.md
  - spec/fixtures/analysis/bus_event/2026-10-18/21.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-18/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/18.jsonl
  - .rubocop.yml
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/12.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/06.jsonl
  - bin/health-card
  - spec/fixtures/analysis/bus_event/2026-10-19/13.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/15.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/10.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/12.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/21.jsonl
  - spec/fixtures/analysis/README.md
tests:
  - spec/analysis/quality_spec.rb
  - spec/analysis/card_spec.rb
  - spec/analysis/trips_spec.rb
  - spec/analysis/params_spec.rb
  - spec/analysis/layovers_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/analysis/duckdb_helpers_spec.rb
  - spec/analysis/profile_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/analysis/load_spec.rb
-->

---
### Requirement: Deduplication per feed

The system SHALL keep only events whose `RouteID` is one of the requested route's `pathAttributeId` values before deduplicating. Within one feed, the system SHALL then keep exactly one record per `(BusID, DataTime)` pair, keeping the record with the earliest `_fetched_at`. `bus_event` and `bus_seat_event` SHALL be deduplicated independently. The number of records read and the number removed SHALL be reported per feed, both counted after that route filter and over the whole read window.

#### Scenario: Duplicate across two hourly files

- **WHEN** the same record for `TEST-0001` at `DataTime` 07:59:58 appears in `07.jsonl` and in `08.jsonl.gz`
- **THEN** one record is kept and the removed count for `bus_event` increases by one


<!-- @trace
source: zhongshan-first-health-card
updated: 2026-10-22
code:
  - spec/fixtures/analysis/bus_event/2026-10-19/08.jsonl.gz
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/16.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/13.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-20/02.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/08.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-20/00.jsonl
  - spec/fixtures/analysis/static/2026-10-19/GetRoute.gz
  - spec/fixtures/analysis/bus_seat_event/2026-10-20/01.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/17.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/10.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/15.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/20.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/16.jsonl
  - analysis/30_layovers.sql
  - spec/fixtures/analysis/bus_event/2026-10-19/00.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/14.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/17.jsonl
  - analysis/10_load.sql
  - Makefile
  - spec/fixtures/analysis/static/2026-10-19/GetStop.gz
  - analysis/20_trips.sql
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/21.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-20/02.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/11.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/07.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/11.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-20/01.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-18/21.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/00.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/07.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/19.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/09.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/22.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/19.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/22.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/14.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-20/00.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-18/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/09.jsonl
  - analysis/40_load_profile.sql
  - spec/fixtures/analysis/bus_event/2026-10-19/18.jsonl
  - analysis/60_export.sql
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/06.jsonl
  - spec/fixtures/analysis/static/2026-10-19/GetPathDetail.gz
  - spec/fixtures/analysis/bus_event/2026-10-19/20.jsonl
  - analysis/params.sql
  - analysis/README.md
  - spec/fixtures/analysis/bus_event/2026-10-18/22.jsonl
  - analysis/50_quality.sql
  - spec/support/duckdb.rb
  - spec/fixtures/analysis/bus_seat_event/2026-10-18/22.jsonl
  - docs/cards/15373-2026-10-19.md
  - spec/fixtures/analysis/bus_event/2026-10-18/21.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-18/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/18.jsonl
  - .rubocop.yml
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/12.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/06.jsonl
  - bin/health-card
  - spec/fixtures/analysis/bus_event/2026-10-19/13.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/15.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/10.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/12.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/21.jsonl
  - spec/fixtures/analysis/README.md
tests:
  - spec/analysis/quality_spec.rb
  - spec/analysis/card_spec.rb
  - spec/analysis/trips_spec.rb
  - spec/analysis/params_spec.rb
  - spec/analysis/layovers_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/analysis/duckdb_helpers_spec.rb
  - spec/analysis/profile_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/analysis/load_spec.rb
-->

---
### Requirement: Sub-route to route and direction mapping

The system SHALL map each event's `RouteID` to a route `Id` using the `(Id, pathAttributeId)` pairs of the `GetRoute.gz` snapshot, and SHALL map each event's `StopID` to a sequence number using the `GetStop.gz` rows whose `routeId` equals that route `Id` and whose `goBack` equals the event's `GoBack`. Events whose `StopID` is not in that direction's stop list SHALL be excluded from trips and counted as unknown-stop events.

#### Scenario: Half-path events merge into the route

- **WHEN** events carry `RouteID` 9002 and `GetRoute.gz` lists `pathAttributeId` 9002 under `Id` 9001
- **THEN** those events are segmented together with `RouteID` 9001 events under route 9001

#### Scenario: Stop outside the direction's list

- **WHEN** an event with `GoBack` 0 carries a `StopID` that exists only in the `goBack` 1 stop list
- **THEN** the event is not part of any trip and the unknown-stop count increases by one


<!-- @trace
source: zhongshan-first-health-card
updated: 2026-10-22
code:
  - spec/fixtures/analysis/bus_event/2026-10-19/08.jsonl.gz
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/16.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/13.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-20/02.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/08.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-20/00.jsonl
  - spec/fixtures/analysis/static/2026-10-19/GetRoute.gz
  - spec/fixtures/analysis/bus_seat_event/2026-10-20/01.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/17.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/10.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/15.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/20.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/16.jsonl
  - analysis/30_layovers.sql
  - spec/fixtures/analysis/bus_event/2026-10-19/00.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/14.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/17.jsonl
  - analysis/10_load.sql
  - Makefile
  - spec/fixtures/analysis/static/2026-10-19/GetStop.gz
  - analysis/20_trips.sql
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/21.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-20/02.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/11.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/07.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/11.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-20/01.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-18/21.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/00.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/07.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/19.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/09.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/22.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/19.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/22.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/14.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-20/00.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-18/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/09.jsonl
  - analysis/40_load_profile.sql
  - spec/fixtures/analysis/bus_event/2026-10-19/18.jsonl
  - analysis/60_export.sql
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/06.jsonl
  - spec/fixtures/analysis/static/2026-10-19/GetPathDetail.gz
  - spec/fixtures/analysis/bus_event/2026-10-19/20.jsonl
  - analysis/params.sql
  - analysis/README.md
  - spec/fixtures/analysis/bus_event/2026-10-18/22.jsonl
  - analysis/50_quality.sql
  - spec/support/duckdb.rb
  - spec/fixtures/analysis/bus_seat_event/2026-10-18/22.jsonl
  - docs/cards/15373-2026-10-19.md
  - spec/fixtures/analysis/bus_event/2026-10-18/21.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-18/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/18.jsonl
  - .rubocop.yml
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/12.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/06.jsonl
  - bin/health-card
  - spec/fixtures/analysis/bus_event/2026-10-19/13.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/15.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/10.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/12.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/21.jsonl
  - spec/fixtures/analysis/README.md
tests:
  - spec/analysis/quality_spec.rb
  - spec/analysis/card_spec.rb
  - spec/analysis/trips_spec.rb
  - spec/analysis/params_spec.rb
  - spec/analysis/layovers_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/analysis/duckdb_helpers_spec.rb
  - spec/analysis/profile_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/analysis/load_spec.rb
-->

---
### Requirement: Sub-route stop sequence check

For every `pathAttributeId` mapped to the requested route, the system SHALL take its `stopId` sequence from `GetPathDetail.gz` ordered by `sequenceNo`, and SHALL determine the directions compared as the set of `goBack` values of the route's `GetStop.gz` rows whose `Id` appears in that sequence. The system SHALL compare the sequence with the route's stop list ordered by `seqNo`, restricted to the compared directions: one direction's list when the set has one value, the route's full list when it has both. Only the order of stops SHALL be compared, not the `sequenceNo` values, because `sequenceNo` starts at 0 for every sub-route. The system SHALL report, per sub-route, whether the two sequences are identical and which directions were compared. A sub-route none of whose stops appear in the route's stop list SHALL be reported as not identical with no direction compared.

#### Scenario: Identical sequences

- **WHEN** sub-route 9002's `GetPathDetail.gz` stops equal the route's `goBack` 0 stop list in order
- **THEN** the report marks sub-route 9002 as identical, compared with direction 0

#### Scenario: Different sequences

- **WHEN** sub-route 9003's `GetPathDetail.gz` stops omit one stop of the route's `goBack` 1 list
- **THEN** the report marks sub-route 9003 as not identical, compared with direction 1

#### Scenario: Sub-route spanning both directions

- **WHEN** sub-route 9001's `GetPathDetail.gz` stops equal the route's `goBack` 0 stop list followed by its `goBack` 1 stop list
- **THEN** the report marks sub-route 9001 as identical, compared with both directions


<!-- @trace
source: zhongshan-first-health-card
updated: 2026-10-22
code:
  - spec/fixtures/analysis/bus_event/2026-10-19/08.jsonl.gz
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/16.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/13.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-20/02.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/08.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-20/00.jsonl
  - spec/fixtures/analysis/static/2026-10-19/GetRoute.gz
  - spec/fixtures/analysis/bus_seat_event/2026-10-20/01.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/17.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/10.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/15.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/20.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/16.jsonl
  - analysis/30_layovers.sql
  - spec/fixtures/analysis/bus_event/2026-10-19/00.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/14.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/17.jsonl
  - analysis/10_load.sql
  - Makefile
  - spec/fixtures/analysis/static/2026-10-19/GetStop.gz
  - analysis/20_trips.sql
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/21.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-20/02.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/11.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/07.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/11.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-20/01.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-18/21.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/00.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/07.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/19.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/09.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/22.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/19.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/22.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/14.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-20/00.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-18/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/09.jsonl
  - analysis/40_load_profile.sql
  - spec/fixtures/analysis/bus_event/2026-10-19/18.jsonl
  - analysis/60_export.sql
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/06.jsonl
  - spec/fixtures/analysis/static/2026-10-19/GetPathDetail.gz
  - spec/fixtures/analysis/bus_event/2026-10-19/20.jsonl
  - analysis/params.sql
  - analysis/README.md
  - spec/fixtures/analysis/bus_event/2026-10-18/22.jsonl
  - analysis/50_quality.sql
  - spec/support/duckdb.rb
  - spec/fixtures/analysis/bus_seat_event/2026-10-18/22.jsonl
  - docs/cards/15373-2026-10-19.md
  - spec/fixtures/analysis/bus_event/2026-10-18/21.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-18/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/18.jsonl
  - .rubocop.yml
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/12.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/06.jsonl
  - bin/health-card
  - spec/fixtures/analysis/bus_event/2026-10-19/13.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/15.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/10.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/12.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/21.jsonl
  - spec/fixtures/analysis/README.md
tests:
  - spec/analysis/quality_spec.rb
  - spec/analysis/card_spec.rb
  - spec/analysis/trips_spec.rb
  - spec/analysis/params_spec.rb
  - spec/analysis/layovers_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/analysis/duckdb_helpers_spec.rb
  - spec/analysis/profile_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/analysis/load_spec.rb
-->

---
### Requirement: Trip segmentation

For each `(BusID, route Id)` the system SHALL order events by `DataTime` and SHALL start a new trip when any of the following holds relative to the previous event: `GoBack` differs; the sequence number is smaller; the time gap exceeds the configured split gap of 60 minutes.

#### Scenario: Direction change starts a new trip

- **WHEN** a vehicle's events go from `GoBack` 0 at sequence 4 to `GoBack` 1 at sequence 5
- **THEN** the `GoBack` 1 event begins a second trip

#### Scenario: Sequence going backwards starts a new trip

- **WHEN** a vehicle's `GoBack` 0 events reach sequence 4 and the next `GoBack` 0 event is at sequence 0
- **THEN** the sequence-0 event begins a second trip

##### Example: Segmentation cases

| Previous event | Next event | New trip |
| --- | --- | --- |
| GoBack 0, seq 3, 08:10 | GoBack 0, seq 4, 08:12 | no |
| GoBack 0, seq 4, 08:12 | GoBack 1, seq 5, 08:20 | yes |
| GoBack 0, seq 4, 08:12 | GoBack 0, seq 0, 08:30 | yes |
| GoBack 0, seq 2, 08:05 | GoBack 0, seq 3, 09:10 | yes, gap 65 minutes |
| GoBack 0, seq 2, 08:05 | GoBack 0, seq 2, 08:06 | no, same stop arrival then departure |


<!-- @trace
source: zhongshan-first-health-card
updated: 2026-10-22
code:
  - spec/fixtures/analysis/bus_event/2026-10-19/08.jsonl.gz
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/16.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/13.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-20/02.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/08.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-20/00.jsonl
  - spec/fixtures/analysis/static/2026-10-19/GetRoute.gz
  - spec/fixtures/analysis/bus_seat_event/2026-10-20/01.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/17.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/10.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/15.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/20.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/16.jsonl
  - analysis/30_layovers.sql
  - spec/fixtures/analysis/bus_event/2026-10-19/00.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/14.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/17.jsonl
  - analysis/10_load.sql
  - Makefile
  - spec/fixtures/analysis/static/2026-10-19/GetStop.gz
  - analysis/20_trips.sql
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/21.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-20/02.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/11.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/07.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/11.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-20/01.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-18/21.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/00.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/07.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/19.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/09.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/22.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/19.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/22.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/14.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-20/00.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-18/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/09.jsonl
  - analysis/40_load_profile.sql
  - spec/fixtures/analysis/bus_event/2026-10-19/18.jsonl
  - analysis/60_export.sql
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/06.jsonl
  - spec/fixtures/analysis/static/2026-10-19/GetPathDetail.gz
  - spec/fixtures/analysis/bus_event/2026-10-19/20.jsonl
  - analysis/params.sql
  - analysis/README.md
  - spec/fixtures/analysis/bus_event/2026-10-18/22.jsonl
  - analysis/50_quality.sql
  - spec/support/duckdb.rb
  - spec/fixtures/analysis/bus_seat_event/2026-10-18/22.jsonl
  - docs/cards/15373-2026-10-19.md
  - spec/fixtures/analysis/bus_event/2026-10-18/21.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-18/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/18.jsonl
  - .rubocop.yml
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/12.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/06.jsonl
  - bin/health-card
  - spec/fixtures/analysis/bus_event/2026-10-19/13.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/15.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/10.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/12.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/21.jsonl
  - spec/fixtures/analysis/README.md
tests:
  - spec/analysis/quality_spec.rb
  - spec/analysis/card_spec.rb
  - spec/analysis/trips_spec.rb
  - spec/analysis/params_spec.rb
  - spec/analysis/layovers_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/analysis/duckdb_helpers_spec.rb
  - spec/analysis/profile_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/analysis/load_spec.rb
-->

---
### Requirement: Trip start and end times

The trip start time SHALL be the `DataTime` of the departure event (`CarOnStop` 0) at the trip's first observed stop; when that stop has no departure event, the start time SHALL be its arrival time and the trip SHALL be flagged `start_from_arrival`. The trip end time SHALL be the `DataTime` of the arrival event (`CarOnStop` 1) at the trip's last observed stop; when that stop has no arrival event, the end time SHALL be its departure time and the trip SHALL be flagged `end_from_departure`.

#### Scenario: Terminal with arrival and departure

- **WHEN** the first observed stop has an arrival at 06:52 and a departure at 07:00
- **THEN** the trip start time is 07:00 and `start_from_arrival` is false

#### Scenario: Last stop with departure only

- **WHEN** the last observed stop has only a departure event at 08:31
- **THEN** the trip end time is 08:31 and `end_from_departure` is true


<!-- @trace
source: zhongshan-first-health-card
updated: 2026-10-22
code:
  - spec/fixtures/analysis/bus_event/2026-10-19/08.jsonl.gz
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/16.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/13.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-20/02.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/08.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-20/00.jsonl
  - spec/fixtures/analysis/static/2026-10-19/GetRoute.gz
  - spec/fixtures/analysis/bus_seat_event/2026-10-20/01.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/17.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/10.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/15.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/20.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/16.jsonl
  - analysis/30_layovers.sql
  - spec/fixtures/analysis/bus_event/2026-10-19/00.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/14.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/17.jsonl
  - analysis/10_load.sql
  - Makefile
  - spec/fixtures/analysis/static/2026-10-19/GetStop.gz
  - analysis/20_trips.sql
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/21.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-20/02.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/11.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/07.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/11.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-20/01.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-18/21.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/00.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/07.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/19.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/09.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/22.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/19.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/22.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/14.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-20/00.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-18/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/09.jsonl
  - analysis/40_load_profile.sql
  - spec/fixtures/analysis/bus_event/2026-10-19/18.jsonl
  - analysis/60_export.sql
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/06.jsonl
  - spec/fixtures/analysis/static/2026-10-19/GetPathDetail.gz
  - spec/fixtures/analysis/bus_event/2026-10-19/20.jsonl
  - analysis/params.sql
  - analysis/README.md
  - spec/fixtures/analysis/bus_event/2026-10-18/22.jsonl
  - analysis/50_quality.sql
  - spec/support/duckdb.rb
  - spec/fixtures/analysis/bus_seat_event/2026-10-18/22.jsonl
  - docs/cards/15373-2026-10-19.md
  - spec/fixtures/analysis/bus_event/2026-10-18/21.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-18/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/18.jsonl
  - .rubocop.yml
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/12.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/06.jsonl
  - bin/health-card
  - spec/fixtures/analysis/bus_event/2026-10-19/13.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/15.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/10.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/12.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/21.jsonl
  - spec/fixtures/analysis/README.md
tests:
  - spec/analysis/quality_spec.rb
  - spec/analysis/card_spec.rb
  - spec/analysis/trips_spec.rb
  - spec/analysis/params_spec.rb
  - spec/analysis/layovers_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/analysis/duckdb_helpers_spec.rb
  - spec/analysis/profile_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/analysis/load_spec.rb
-->

---
### Requirement: Completeness classification

The system SHALL classify each trip as `complete` when its first observed sequence number equals the smallest sequence number of its direction and its last observed sequence number equals the largest; as `missing_start` when only the first condition fails; as `missing_end` when only the second fails; and as `missing_both` when both fail.

#### Scenario: Classification by observed endpoints

- **WHEN** direction 0 has sequence numbers 0 to 4
- **THEN** trips are classified as in the table below

##### Example: Completeness cases

| First observed seq | Last observed seq | Classification |
| --- | --- | --- |
| 0 | 4 | complete |
| 1 | 4 | missing_start |
| 0 | 3 | missing_end |
| 1 | 3 | missing_both |


<!-- @trace
source: zhongshan-first-health-card
updated: 2026-10-22
code:
  - spec/fixtures/analysis/bus_event/2026-10-19/08.jsonl.gz
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/16.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/13.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-20/02.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/08.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-20/00.jsonl
  - spec/fixtures/analysis/static/2026-10-19/GetRoute.gz
  - spec/fixtures/analysis/bus_seat_event/2026-10-20/01.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/17.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/10.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/15.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/20.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/16.jsonl
  - analysis/30_layovers.sql
  - spec/fixtures/analysis/bus_event/2026-10-19/00.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/14.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/17.jsonl
  - analysis/10_load.sql
  - Makefile
  - spec/fixtures/analysis/static/2026-10-19/GetStop.gz
  - analysis/20_trips.sql
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/21.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-20/02.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/11.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/07.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/11.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-20/01.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-18/21.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/00.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/07.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/19.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/09.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/22.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/19.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/22.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/14.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-20/00.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-18/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/09.jsonl
  - analysis/40_load_profile.sql
  - spec/fixtures/analysis/bus_event/2026-10-19/18.jsonl
  - analysis/60_export.sql
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/06.jsonl
  - spec/fixtures/analysis/static/2026-10-19/GetPathDetail.gz
  - spec/fixtures/analysis/bus_event/2026-10-19/20.jsonl
  - analysis/params.sql
  - analysis/README.md
  - spec/fixtures/analysis/bus_event/2026-10-18/22.jsonl
  - analysis/50_quality.sql
  - spec/support/duckdb.rb
  - spec/fixtures/analysis/bus_seat_event/2026-10-18/22.jsonl
  - docs/cards/15373-2026-10-19.md
  - spec/fixtures/analysis/bus_event/2026-10-18/21.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-18/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/18.jsonl
  - .rubocop.yml
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/12.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/06.jsonl
  - bin/health-card
  - spec/fixtures/analysis/bus_event/2026-10-19/13.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/15.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/10.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/12.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/21.jsonl
  - spec/fixtures/analysis/README.md
tests:
  - spec/analysis/quality_spec.rb
  - spec/analysis/card_spec.rb
  - spec/analysis/trips_spec.rb
  - spec/analysis/params_spec.rb
  - spec/analysis/layovers_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/analysis/duckdb_helpers_spec.rb
  - spec/analysis/profile_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/analysis/load_spec.rb
-->

---
### Requirement: Trip record

For each trip the system SHALL output: vehicle `BusID`, route `Id`, the `pathAttributeId` carried by the majority of the trip's events, `GoBack`, start time, end time, first and last observed sequence numbers, number of events, number of distinct stops observed, completeness, `start_from_arrival`, `end_from_departure`. The system SHALL also report how many trips fall under each `pathAttributeId`.

#### Scenario: Majority sub-route recorded

- **WHEN** a trip has 30 events with `RouteID` 9001 and 2 events with `RouteID` 9002
- **THEN** the trip record's `pathAttributeId` is 9001 and the sub-route count for 9001 increases by one

<!-- @trace
source: zhongshan-first-health-card
updated: 2026-10-22
code:
  - spec/fixtures/analysis/bus_event/2026-10-19/08.jsonl.gz
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/16.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/13.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-20/02.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/08.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-20/00.jsonl
  - spec/fixtures/analysis/static/2026-10-19/GetRoute.gz
  - spec/fixtures/analysis/bus_seat_event/2026-10-20/01.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/17.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/10.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/15.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/20.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/16.jsonl
  - analysis/30_layovers.sql
  - spec/fixtures/analysis/bus_event/2026-10-19/00.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/14.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/17.jsonl
  - analysis/10_load.sql
  - Makefile
  - spec/fixtures/analysis/static/2026-10-19/GetStop.gz
  - analysis/20_trips.sql
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/21.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-20/02.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/11.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/07.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/11.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-20/01.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-18/21.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/00.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/07.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/19.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/09.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/22.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/19.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/22.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/14.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-20/00.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-18/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/09.jsonl
  - analysis/40_load_profile.sql
  - spec/fixtures/analysis/bus_event/2026-10-19/18.jsonl
  - analysis/60_export.sql
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/06.jsonl
  - spec/fixtures/analysis/static/2026-10-19/GetPathDetail.gz
  - spec/fixtures/analysis/bus_event/2026-10-19/20.jsonl
  - analysis/params.sql
  - analysis/README.md
  - spec/fixtures/analysis/bus_event/2026-10-18/22.jsonl
  - analysis/50_quality.sql
  - spec/support/duckdb.rb
  - spec/fixtures/analysis/bus_seat_event/2026-10-18/22.jsonl
  - docs/cards/15373-2026-10-19.md
  - spec/fixtures/analysis/bus_event/2026-10-18/21.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-18/23.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/18.jsonl
  - .rubocop.yml
  - spec/fixtures/analysis/bus_seat_event/2026-10-19/12.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/06.jsonl
  - bin/health-card
  - spec/fixtures/analysis/bus_event/2026-10-19/13.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/15.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/10.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/12.jsonl
  - spec/fixtures/analysis/bus_event/2026-10-19/21.jsonl
  - spec/fixtures/analysis/README.md
tests:
  - spec/analysis/quality_spec.rb
  - spec/analysis/card_spec.rb
  - spec/analysis/trips_spec.rb
  - spec/analysis/params_spec.rb
  - spec/analysis/layovers_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/analysis/duckdb_helpers_spec.rb
  - spec/analysis/profile_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/analysis/load_spec.rb
-->