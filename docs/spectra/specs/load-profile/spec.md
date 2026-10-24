# load-profile Specification

## Purpose

Attach the on-board passenger count reported in `bus_seat_event` to reconstructed trips, and summarize per-stop load, net boarding between stops, and whether the count is zero before boarding at the first stop and after alighting at the last stop. The count is derived from fare-card taps, not from counting people.

## Requirements

### Requirement: Joining counts to trips

For each trip, the system SHALL select the deduplicated `bus_seat_event` records with the same `BusID`, the same route `Id` after sub-route mapping, the same `GoBack`, and a `DataTime` between the trip's start time and end time inclusive. For each stop of the trip the on-board count SHALL be the `RemainingNum` of the departure record (`CarOnStop` 0) when present, otherwise of the arrival record. The system SHALL report the share of trips with at least one count record and the share of observed trip stops with a count.

#### Scenario: Departure count preferred

- **WHEN** a stop within a trip has an arrival record with `RemainingNum` 11 and a departure record with `RemainingNum` 14
- **THEN** the stop's on-board count is 14

#### Scenario: Record outside the trip window

- **WHEN** a `bus_seat_event` record of the same vehicle has a `DataTime` 3 minutes after the trip's end time
- **THEN** it is not attached to that trip


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
### Requirement: Net boarding

For each stop with a count, the system SHALL compute net boarding as the stop's count minus the count of the previous stop with a count within the same trip, and SHALL record the span as the difference of the two sequence numbers. A span greater than 1 SHALL be flagged as crossing missing stops. The first counted stop of a trip SHALL have no net boarding.

#### Scenario: Net boarding across a missing stop

- **WHEN** sequence 2 has count 10, sequence 3 has no count and sequence 4 has count 7
- **THEN** sequence 4 has net boarding -3 with span 2 and is flagged

##### Example: Net boarding along one trip

| Seq | Count | Net boarding | Span |
| --- | --- | --- | --- |
| 0 | 0 | none | none |
| 1 | 5 | 5 | 1 |
| 2 | 10 | 5 | 1 |
| 3 | none | none | none |
| 4 | 7 | -3 | 2 |


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
### Requirement: Time bands

The system SHALL assign each trip to a band by the hour of its start time: morning peak for 07:00 to 08:59, daytime for 09:00 to 16:59, evening peak for 17:00 to 18:59, other for every other hour.

#### Scenario: Band boundaries

- **WHEN** trips start at 06:59, 07:00, 08:59, 09:00, 16:59, 17:00, 18:59 and 19:00
- **THEN** their bands are other, morning peak, morning peak, daytime, daytime, evening peak, evening peak, other


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
### Requirement: Profile table

The system SHALL report, per direction, band and sequence number: the stop name from `GetStop.gz` `nameZh`, the number of trips with a count at that stop, the median count and the 90th percentile count. Only stops with at least one count SHALL appear.

#### Scenario: Aggregating three trips

- **WHEN** three morning-peak trips in direction 0 have counts 10, 12 and 20 at sequence 3
- **THEN** the row for direction 0, morning peak, sequence 3 reports 3 trips, median 12 and p90 18.4


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
### Requirement: Terminal reset check and anomalies

For each complete trip the system SHALL take two counts from deduplicated `bus_seat_event` records with the trip's `BusID`, route `Id` and `GoBack`. The pre-boarding count SHALL be the `RemainingNum` of the latest arrival record (`CarOnStop` 1) at the direction's first stop with a `DataTime` no later than the trip's start time and no earlier than 60 minutes before it. The post-alighting count SHALL be the `RemainingNum` of the earliest departure record (`CarOnStop` 0) at the direction's last stop with a `DataTime` no earlier than the trip's end time and no later than 60 minutes after it. For each direction and each end the system SHALL report one row naming the stop at that end (`nameZh` of the direction's first or last stop): the number of the direction's complete trips with a record, the number without one, and, over the trips with a record, the share where the count equals 0, the share where it is at most 2, and the maximum. Every direction of the route SHALL have both rows, also when it has no complete trip. These records SHALL NOT be attached to the trip for net boarding or the profile table. The system SHALL also report the number of negative counts and the number of consecutive counted stops within a trip whose counts differ by more than 30.

#### Scenario: Reset shares

- **WHEN** four complete trips have pre-boarding counts 0, 0, 2 and 9
- **THEN** the first-stop row of direction 0 shows 4 trips with a record, 50% equal to 0, 75% at most 2 and a maximum of 9

#### Scenario: Directions reported separately

- **WHEN** one complete trip in direction 0 has a pre-boarding count of 0 and one complete trip in direction 1 has a pre-boarding count of 5
- **THEN** the first-stop row of direction 0 shows 1 trip, 100% equal to 0 and the name of direction 0's first stop, and the first-stop row of direction 1 shows 1 trip, 0% equal to 0 and the name of direction 1's first stop

#### Scenario: Pre-boarding count before the trip starts

- **WHEN** a complete trip departs its first stop at 08:42 with a departure record of 3, and the same vehicle has an arrival record of 0 at that stop at 08:40
- **THEN** the trip's pre-boarding count is 0 and the profile count at that stop stays 3

#### Scenario: Post-alighting count after the trip ends

- **WHEN** a complete trip arrives at its last stop at 11:30 with an arrival record of 7, and the same vehicle has a departure record of 0 at that stop at 11:33
- **THEN** the trip's post-alighting count is 0 and the 11:33 record is not attached to the trip

#### Scenario: Record beyond the 60-minute window

- **WHEN** the only arrival record at a complete trip's first stop is 61 minutes before the trip's start time
- **THEN** the trip is counted as having no pre-boarding record

#### Scenario: Jump anomaly

- **WHEN** consecutive counted stops in a trip read 3 and 40
- **THEN** the jump count increases by one

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
### Requirement: Counts of member route trips at shared stops

For a trip of a member route, each stop's on-board count SHALL be attributed to the page route's stop of the same direction that has the same `stopLocationId` in the day's `GetStop.gz`, and SHALL carry that stop's sequence number in the health card's profile and in the stored trip stop counts. A count at a stop the page route does not serve in that direction SHALL be left out of the profile and of the stored counts, and SHALL be counted in the quality report as an unmatched count. Counts of the page route's own trips SHALL keep their sequence numbers. Net boarding SHALL be computed on each trip's own stop list before this attribution, so that a count at a stop only the member route serves still takes part in the net boarding of its trip.

#### Scenario: Shared stop pooled

- **WHEN** the run is for route 9001 with member route 9050 on 2026-10-23, and TEST-0005's two 9050 trips in direction 0 carry 5 and 4 at 乙站, route 9050's sequence 1 with `stopLocationId` 81001, which is also route 9001's sequence 1 of direction 0
- **THEN** direction 0 at sequence 1 has two trips with counts 5 and 4, stored under route 9001's sequence 1

##### Example: direction 0 of the member day

| Route 9001 sequence | Stop | Trips with a count | Counts |
| --- | --- | --- | --- |
| 0 | 甲站 | 2 | 3, 2 |
| 1 | 乙站 | 2 | 5, 4 |
| 2 | 丙站 | 0 | none: route 9050 does not serve it and no 9001 trip ran direction 0 that day |
| 3 | 丁站 | 2 | 6, 5 |
| 4 | 戊站 | 2 | 2, 1 |

#### Scenario: Stop only the member route serves

- **WHEN** TEST-0005's 9050 trips carry 7 and 6 at 己站 (`stopLocationId` 85002), which route 9001 does not serve
- **THEN** neither count appears in the profile or in the stored counts, and the quality report counts 2 unmatched counts

#### Scenario: Page route counts unchanged

- **WHEN** TEST-0005's 9001 trip in direction 1 carries 4, 6, 5, 3 and 1 at sequences 5 to 9
- **THEN** those counts keep sequences 5 to 9

#### Scenario: Net boarding before attribution

- **WHEN** TEST-0005's first 9050 trip carries 5 at 乙站 (sequence 1 of route 9050), 7 at 己站 (sequence 2) and 6 at 丁站 (sequence 3)
- **THEN** the trip's net boarding at 己站 is 2 and at 丁站 is -1, each with a span of 1

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