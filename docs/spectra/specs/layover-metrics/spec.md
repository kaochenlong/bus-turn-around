# layover-metrics Specification

## Purpose

Measure the time a vehicle spends between two consecutive trips (折返停留) and test the sequence of trips against the four-hour rest rule of 汽車運輸業管理規則第 19 條之 2. The measure is an upper bound on driver rest because the data identifies vehicles, not drivers.

## Requirements

### Requirement: Layover definition

For each vehicle, the system SHALL order its trips by start time and SHALL compute a layover for each pair of consecutive trips as the next trip's start time minus the current trip's end time, only when the current trip observed the last stop of its direction (classified `complete` or `missing_start`), the next trip observed the first stop of its direction (classified `complete` or `missing_end`), the vehicle did not run another route between the two trips as defined by Runs on other routes between trips, and the difference is not negative. Pairs that do not qualify SHALL be counted in exactly one of four exclusion categories, taking the first that applies in this order: the current trip did not reach its last stop (`no_last_stop`); the next trip did not leave from its first stop (`no_first_stop`); the vehicle ran another route between the two trips (`other_route`); the difference is negative (`negative`). Excluded pairs SHALL be counted only; their time differences SHALL NOT be reported as layovers. The last trip of a vehicle on the day SHALL have no layover. Only trips take part: a segment that is not a trip under Segments observing too few stops are not trips SHALL NOT separate the trips before and after it, so those two trips are consecutive trips of the vehicle.

#### Scenario: Qualifying pair

- **WHEN** a complete trip ends at 08:30 and the same vehicle's next complete trip starts at 08:42, and the vehicle runs no other route in between
- **THEN** a layover of 12.0 minutes is recorded

#### Scenario: Endpoints observed on incomplete trips

- **WHEN** a trip classified `missing_start` ends at its last stop at 08:16 and the same vehicle's next trip, classified `missing_end`, leaves its first stop at 08:30
- **THEN** a layover of 14.0 minutes is recorded

#### Scenario: Current trip without its last stop

- **WHEN** a trip classified `missing_end` is followed by a complete trip
- **THEN** no layover is recorded for the pair and the `no_last_stop` count increases by one

#### Scenario: Next trip without its first stop

- **WHEN** a complete trip is followed by a trip classified `missing_start`
- **THEN** no layover is recorded for the pair and the `no_first_stop` count increases by one

#### Scenario: Both endpoints missing

- **WHEN** a trip classified `missing_end` is followed by a trip classified `missing_start`
- **THEN** no layover is recorded and only the `no_last_stop` count increases by one

#### Scenario: Another route between the trips

- **WHEN** a complete trip ends at 08:30, the vehicle then has records on route 9100 at three distinct stops, and its next complete trip starts at 09:30
- **THEN** no layover is recorded for the pair and the `other_route` count increases by one

#### Scenario: Route code set between the trips

- **WHEN** a complete trip ends at 08:30, the vehicle then has records on route 9100 at one stop, and its next complete trip starts at 08:42
- **THEN** a layover of 12.0 minutes is recorded and the `other_route` count does not change

#### Scenario: Another route on a pair that misses its last stop

- **WHEN** a trip classified `missing_end` is followed by a complete trip and the vehicle has records on route 9100 at three distinct stops between them
- **THEN** no layover is recorded and only the `no_last_stop` count increases by one

#### Scenario: Negative difference

- **WHEN** the next trip's start time is earlier than the current trip's end time
- **THEN** no layover is recorded and the negative-pair count increases by one

##### Example: Overlapping trips

- **GIVEN** a complete trip ending at 08:30 and the same vehicle's next complete trip starting at 08:28
- **WHEN** layovers are computed
- **THEN** the pair yields no layover and the negative-pair count is 1

#### Scenario: Segment that is not a trip between two trips

- **WHEN** a complete trip ends at its last stop at 09:30, the vehicle reports one arrival at that stop at 13:01, which is not a trip, and its next complete trip leaves the first stop of the other direction at 13:14, with no record on another route in between
- **THEN** one layover of 224.0 minutes is recorded for the pair of the 09:30 and 13:14 trips, and no layover ends at 13:01

#### Scenario: Arrival reported before the first trip of the day

- **WHEN** a vehicle's first record of the day is one arrival at a last stop at 06:09, which is not a trip, and its first trip leaves the first stop of the other direction at 06:19
- **THEN** no layover ends at 06:09

#### Scenario: Fixture day

- **WHEN** layovers are computed for the analysis fixture on 2026-10-19
- **THEN** the layovers and exclusion counts equal the values hand-computed in `spec/fixtures/analysis/README.md`

##### Example: Fixture day 2026-10-19

- **GIVEN** the trips of the analysis fixture for 2026-10-19, where TEST-0002 has records on route 9100 at three distinct stops between its trip ending at 12:08 and its trip starting at 17:10, and TEST-0001 has records on route 9100 at two distinct stops between its trip ending at 15:40 and its trip starting at 17:05
- **WHEN** layovers are computed
- **THEN** there are 18 layovers, 10 ending an outbound trip and 8 ending an inbound trip, TEST-0001's 85.0-minute layover after 15:40 is among them, and the exclusion counts are `no_last_stop` 3, `no_first_stop` 1, `other_route` 1 and `negative` 0

---
### Requirement: Layover distribution

The system SHALL report, overall and per direction of the trip that ended: the number of layovers, the 10th, 50th and 90th percentiles in minutes with one decimal using linear interpolation between order statistics, the share of layovers shorter than 15 minutes, and counts in the bins 0 to 5, 5 to 10, 10 to 15, 15 to 30, 30 to 60, and 60 or more minutes, each bin including its lower bound and excluding its upper bound.

#### Scenario: Percentiles with linear interpolation

- **WHEN** the layovers are 4, 8, 12, 20 and 45 minutes
- **THEN** p10 is 5.6, p50 is 12.0 and p90 is 35.0

##### Example: Bins and short share

- **GIVEN** layovers 4, 8, 12, 20, 45 minutes
- **WHEN** the distribution is reported
- **THEN** bins read 1, 1, 1, 1, 1, 0 and the share under 15 minutes is 60%


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
### Requirement: Rest-rule windows and chains

For each vehicle, the system SHALL use only runs of consecutive complete trips of the route, cutting the run at any trip that is not complete and between two consecutive trips when the vehicle ran another route between them as defined by Runs on other routes between trips. For each trip i in a run, the system SHALL find the earliest trip j in the same run such that trip j's end time minus trip i's start time is at least 240 minutes. When such j exists, the rest credit of the window SHALL be the sum of the layovers after trips i through j-1 that are at least 15 minutes long, and the window SHALL be flagged when the credit is below 30 minutes. Flagged windows of the same vehicle whose trip ranges overlap SHALL be merged into one chain.

#### Scenario: Short layovers earn no credit

- **WHEN** trips run 06:00 to 08:30 and 08:40 to 11:10 with a 10-minute layover between them
- **THEN** the window starting at the first trip spans 310 minutes with a credit of 0 and is flagged

#### Scenario: Two qualifying rests satisfy the rule

- **WHEN** three consecutive trips are separated by layovers of 20 and 20 minutes and the window spans at least 240 minutes
- **THEN** the credit is 40 minutes and the window is not flagged

#### Scenario: Overlapping windows form one chain

- **WHEN** the windows starting at trip 1 and at trip 2 of the same vehicle are both flagged and share trip 2
- **THEN** one chain is reported covering trips 1 through the later window's end

#### Scenario: Another route cuts the run

- **WHEN** complete trips run 10:20 to 11:08 and 11:20 to 12:08, the vehicle then runs another route, and its next complete trip runs 17:10 to 17:58
- **THEN** no rest window is formed from these trips and no chain is reported for them

##### Example: Fixture day keeps one chain

- **GIVEN** the analysis fixture for 2026-10-19, where TEST-0002 runs route 9100 between its trip ending at 12:08 and its trip starting at 17:10
- **WHEN** chains are computed
- **THEN** the only chain is TEST-0001's from 06:00 to 11:30 with 5 trips


<!-- @trace
source: layover-other-routes
updated: 2026-10-23
code:
  - db/migrate/20261022231802_require_day_type_on_route_days.rb
  - db/schema.rb
  - app/models/route_day.rb
  - app/components/route_coverage_component.html.erb
  - config/locales/en.yml
  - app/components/route_list_component.yml
  - spec/fixtures/analysis/bus_event/2026-10-19/15.jsonl
  - config/locales/tw.yml
  - app/models/mrt_exits_snapshot.rb
  - app/models/office_calendar_snapshot.rb
  - analysis/10_load.sql
  - app/components/attribution_component.yml
  - app/components/layover_table_component.yml
  - spec/factories/route_days.rb
  - analysis/README.md
  - app/components/route_coverage_component.yml
  - app/components/route_list_component.html.erb
  - analysis/30_layovers.sql
  - app/components/attribution_component.html.erb
  - app/components/route_coverage_component.rb
  - lib/tasks/external.rake
  - analysis/60_export.sql
  - app/models/route_day_loader.rb
  - spec/fixtures/analysis/external/office-calendar/2026/2026-10-19.csv
  - app/models/route_page/coverage.rb
  - spec/fixtures/analysis/README.md
  - db/migrate/20261022230942_add_day_type_to_route_days.rb
  - docs/data-sources.md
  - spec/fixtures/analysis/bus_event/2026-10-19/14.jsonl
  - spec/support/duckdb.rb
  - app/components/data_limitations_component.yml
  - bin/health-card
  - analysis/params.sql
  - app/models/http_fetcher.rb
  - app/components/application_component.rb
tests:
  - spec/components/mrt_overlap_component_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/components/load_profile_table_component_spec.rb
  - spec/components/buffer_trade_component_spec.rb
  - spec/models/route_page/buffer_trade_spec.rb
  - spec/models/route_page/run_times_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/card_spec.rb
  - spec/components/route_coverage_component_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/models/home_page/route_list_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/requests/pages_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/components/layover_table_component_spec.rb
  - spec/components/layover_chart_component_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/components/route_summary_component_spec.rb
  - spec/models/office_calendar_snapshot_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/models/http_fetcher_spec.rb
  - spec/components/application_component_spec.rb
  - spec/requests/routes_spec.rb
  - spec/analysis/duckdb_helpers_spec.rb
  - spec/components/run_time_table_component_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/route_page/coverage_spec.rb
  - spec/system/home_hero_spec.rb
  - spec/components/route_list_component_spec.rb
  - spec/analysis/layovers_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/components/load_chart_component_spec.rb
  - spec/analysis/load_spec.rb
  - spec/models/derived_load_command_spec.rb
-->

---
### Requirement: Chain report without vehicle identifiers

The system SHALL report the number of chains, the number of distinct vehicles with at least one chain, and for each chain its first trip start time, last trip end time and number of trips. The chain report included in the card SHALL NOT contain any `BusID` value.

#### Scenario: Chain row content

- **WHEN** a chain covers three trips from 06:00 to 11:10 for vehicle `TEST-0001`
- **THEN** the card lists a chain with start 06:00, end 11:10 and 3 trips, and the string `TEST-0001` does not appear in the card

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
### Requirement: Runs on other routes between trips

The system SHALL read, from the same `bus_event` hourly files of the read window, the records of every vehicle that has an event on the route, whose `RouteID` is neither 0 nor one of the `pathAttributeId`s of the page route or of its member routes, deduplicated by `(BusID, DataTime)`. A vehicle SHALL be taken to have run another route between two of its consecutive trips when those records with a `DataTime` later than the current trip's end time and earlier than the next trip's start time cover at least the number of distinct `StopID`s given by the constant `other_route_min_stops` of `analysis/params.sql`, which is 3. Records with `RouteID` 0 SHALL never count, because they mark non-revenue states such as the end of duty at a terminal, and a return to the depot belongs to the layover. Records of another route covering fewer distinct stops than the threshold SHALL NOT count, because they come from a route code set at a terminal, not from a run.

#### Scenario: Run on another route between two trips

- **WHEN** a vehicle's trip ends at 12:08, the vehicle has records on route 9100 at three distinct stops between 14:10 and 14:30, and its next trip on the route starts at 17:10
- **THEN** the vehicle ran another route between the two trips

#### Scenario: Route code set at a terminal

- **WHEN** a vehicle's trip ends at 15:40, the vehicle has records on route 9100 at two distinct stops between 15:50 and 15:55, and its next trip on the route starts at 17:05
- **THEN** the vehicle did not run another route between the two trips

##### Example: Threshold boundary

| Distinct stops of another route between the trips | Ran another route |
| --- | --- |
| 0 | no |
| 2 | no |
| 3 | yes |

#### Scenario: Records with RouteID 0

- **WHEN** the read window holds a record of a vehicle on the route whose `RouteID` is 0
- **THEN** that record is not among the records read for other routes

#### Scenario: Records of the route's own sub-routes

- **WHEN** the read window holds records whose `RouteID` is one of the route's `pathAttributeId`s
- **THEN** none of them is among the records read for other routes

#### Scenario: Records of a member route are not another route

- **WHEN** the run is for route 9001 with member route 9050 and the read window holds TEST-0005's records with `RouteID` 9050
- **THEN** none of them is among the records read for other routes, and TEST-0005's two pairs of consecutive trips on 2026-10-23 are layovers, not runs on another route

#### Scenario: Records outside the gap

- **WHEN** all of a vehicle's records on another route lie after the end of its last trip of the day
- **THEN** none of its pairs of consecutive trips counts as having run another route

##### Example: Control route after the last trip

- **GIVEN** TEST-0004's trips of the analysis fixture on 2026-10-19 end at 06:58, 08:03 and 09:03, and its 20 records on route 9100 lie between 13:10 and 22:50
- **WHEN** layovers are computed
- **THEN** TEST-0004's layovers are 17.0 and 12.0 minutes and neither of its two pairs ran another route


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
### Requirement: Layovers across member routes

A pair of consecutive trips of one vehicle SHALL qualify as a layover under the same conditions whichever route `Id` of the run each of the two trips belongs to, so that a vehicle switching between the page route and a member route at a terminal keeps its layover. The layover's direction SHALL be the direction of the trip that ended.

#### Scenario: Member route trip followed by a page route trip

- **WHEN** on 2026-10-23 TEST-0005's trip of route 9050 in direction 0 arrives at 07:50 and its trip of route 9001 in direction 1 departs at 08:00
- **THEN** the pair is a layover of 10.0 minutes in direction 0

#### Scenario: Page route trip followed by a member route trip

- **WHEN** TEST-0005's trip of route 9001 in direction 1 arrives at 08:50 and its trip of route 9050 in direction 0 departs at 09:00
- **THEN** the pair is a layover of 10.0 minutes in direction 1

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
### Requirement: Six-hour rest windows

Within the same runs as the requirement "Rest-rule windows and chains", for each trip i of a run the system SHALL find the earliest trip j in the same run such that trip j's end time minus trip i's start time is at least the constant `long_rest_window_minutes` of `analysis/params.sql`, which is 360. When such j exists, trip i starts a six-hour window, and the window SHALL be flagged when none of the layovers after trips i through j-1 is at least the constant `long_rest_min_minutes` of `analysis/params.sql`, which is 45. Six-hour windows SHALL NOT be merged into chains, and they SHALL NOT change the chains, the chain report or any other part of the health card.

#### Scenario: No layover reaches 45 minutes

- **WHEN** trips run 06:00 to 08:50, 09:00 to 11:50 and 12:00 to 14:50 with layovers of 10 and 10 minutes
- **THEN** exactly one six-hour window exists, starting at 06:00 and spanning 530 minutes with a longest layover of 10.0 minutes, and it is flagged

#### Scenario: A layover of exactly 45 minutes

- **WHEN** trips run 06:00 to 08:50, 09:35 to 12:25 and 12:35 to 15:25 with layovers of 45 and 10 minutes
- **THEN** the six-hour window starting at 06:00 has a longest layover of 45.0 minutes and is not flagged

#### Scenario: A run shorter than six hours

- **WHEN** a run's last trip ends less than 360 minutes after its first trip starts
- **THEN** no six-hour window exists for that run

#### Scenario: Fixture day

- **WHEN** six-hour windows are computed for the analysis fixture on 2026-10-19
- **THEN** there are 7 windows and none is flagged, and the first is TEST-0001's from 06:00 to 13:14 with 6 trips and a longest layover of 56.0 minutes


<!-- @trace
source: 01-rest-windows
updated: 2026-11-02
code:
  - db/migrate/20261101220000_create_route_day_rest_windows.rb
  - docs/data-sources.md
  - analysis/derived_export.sql
  - config/locales/tw.yml
  - .agents/skills/spectra-apply/SKILL.md
  - app/models/route_day.rb
  - spec/factories/layovers.rb
  - app/components/month_card_attribution_component.html.erb
  - app/models/program_version.rb
  - app/models/route_page/month_days.rb
  - app/models/route_card.rb
  - app/models/route_page/schedule_comparison.rb
  - app/components/month_card_cycles_component.rb
  - app/components/month_card_hour_chart_component.html.erb
  - app/models/route_page/layover_distribution.rb
  - spec/factories/route_days.rb
  - analysis/30_layovers.sql
  - app/components/month_card_cycles_component.html.erb
  - app/components/month_card_component.rb
  - .github/skills/spectra-apply/SKILL.md
  - analysis/README.md
  - app/models/route_page/month_card.rb
  - app/components/month_card_history_component.yml
  - app/models/route_page/layover_stats.rb
  - app/models/route_page/card_trend.rb
  - app/components/month_card_chart_component.rb
  - app/components/month_card_distribution_chart_component.html.erb
  - app/components/month_card_history_component.rb
  - spec/factories/route_day_published_departures.rb
  - app/models/route_day_published_headway.rb
  - app/components/month_card_buffer_component.rb
  - app/components/month_card_hour_chart_component.rb
  - app/components/month_card_summary_component.html.erb
  - app/models/route_page/month_findings.rb
  - app/models/route_page/rest_windows.rb
  - spec/factories/route_day_rest_windows.rb
  - spec/factories/trips.rb
  - app/components/month_card_driving_component.yml
  - config/routes.rb
  - app/models/route_page/load_profile.rb
  - analysis/params.sql
  - app/components/month_card_margin_component.rb
  - app/models/route_page/format.rb
  - config/locales/en.yml
  - spec/factories/route_cards.rb
  - app/components/month_card_layovers_component.html.erb
  - app/components/month_card_schedule_component.html.erb
  - app/components/month_card_buffer_component.yml
  - db/migrate/20261102011500_create_route_day_published_schedule.rb
  - db/migrate/20261102030000_create_route_cards.rb
  - app/components/month_card_driving_component.rb
  - app/components/attribution_component.yml
  - app/models/route_card_prepare_command.rb
  - app/components/month_card_margin_component.yml
  - spec/factories/route_day_driving_stretches.rb
  - app/components/month_card_hour_share_chart_component.html.erb
  - spec/factories/route_day_published_headways.rb
  - spec/fixtures/analysis/static/2026-10-23/GetTimeTable.gz
  - app/models/route_day_published_departure.rb
  - app/components/month_card_layovers_component.yml
  - app/components/month_card_attribution_component.rb
  - app/models/route_day_rest_window.rb
  - app/models/route_page/slow_legs.rb
  - spec/fixtures/analysis/static/2026-10-19/GetTimeTable.gz
  - app/components/month_card_hour_share_chart_component.rb
  - app/components/month_card_schedule_component.rb
  - app/components/month_card_run_times_component.rb
  - app/views/route_cards/show.html.erb
  - app/components/month_card_margin_component.html.erb
  - app/components/month_card_attribution_component.yml
  - spec/fixtures/analysis/static/2026-10-23/GetSemiTimeTable.gz
  - app/models/route_page/snapshot_changes.rb
  - app/models/route_day_driving_stretch.rb
  - app/components/month_card_run_times_component.yml
  - app/components/month_card_summary_component.yml
  - spec/fixtures/analysis/README.md
  - lib/tasks/cards.rake
  - app/frontend/stylesheets/application.css
  - db/schema.rb
  - analysis/published_schedule.sql
  - app/components/month_card_buffer_component.html.erb
  - app/models/route_page/layover_hours.rb
  - app/components/month_card_history_component.html.erb
  - app/controllers/route_cards_controller.rb
  - app/components/month_card_driving_component.html.erb
  - app/models/route_day_loader.rb
  - app/components/month_card_run_times_component.html.erb
  - app/components/month_card_distribution_chart_component.yml
  - app/components/month_card_hour_share_chart_component.yml
  - app/models/route_card_coverage.rb
  - bin/health-card
  - app/components/month_card_distribution_chart_component.rb
  - app/components/month_card_cycles_component.yml
  - spec/fixtures/analysis/static/2026-10-19/GetSemiTimeTable.gz
  - app/components/month_card_schedule_component.yml
  - app/components/month_card_layovers_component.rb
  - app/components/month_card_summary_component.rb
  - app/models/route_page/mrt_overlap.rb
tests:
  - spec/analysis/derived_export_spec.rb
  - spec/models/route_day_published_departure_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/route_day_published_headway_spec.rb
  - spec/models/route_card_prepare_command_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/models/program_version_spec.rb
  - spec/models/route_page/schedule_comparison_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_card_spec.rb
  - spec/models/route_page/layover_hours_spec.rb
  - spec/models/route_page/month_card_spec.rb
  - spec/components/month_card_run_times_component_spec.rb
  - spec/components/month_card_margin_component_spec.rb
  - spec/components/month_card_layovers_component_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/components/month_card_buffer_component_spec.rb
  - spec/components/month_card_cycles_component_spec.rb
  - spec/models/route_day_driving_stretch_spec.rb
  - spec/models/route_day_spec.rb
  - spec/system/month_card_print_spec.rb
  - spec/components/month_card_hour_chart_component_spec.rb
  - spec/components/month_card_summary_component_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_day_rest_window_spec.rb
  - spec/models/route_page/month_days_spec.rb
  - spec/models/route_page/month_findings_spec.rb
  - spec/components/month_card_attribution_component_spec.rb
  - spec/models/route_page/slow_legs_spec.rb
  - spec/requests/route_cards_spec.rb
  - spec/components/month_card_history_component_spec.rb
  - spec/components/month_card_driving_component_spec.rb
  - spec/models/route_page/rest_windows_spec.rb
  - spec/models/route_page/card_trend_spec.rb
  - spec/components/month_card_schedule_component_spec.rb
  - spec/analysis/published_schedule_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/models/route_page/snapshot_changes_spec.rb
  - spec/models/route_card_coverage_spec.rb
  - spec/models/derived_load_command_spec.rb
-->

---
### Requirement: Continuous driving stretches

Within the same runs as the requirement "Rest-rule windows and chains", the system SHALL group the trips of each run into continuous driving stretches: the first trip of a run starts a stretch, and so does every trip whose preceding layover is at least the constant `rest_min_minutes` of `analysis/params.sql`, which is 15. A stretch SHALL be reported with its first trip's start time, its last trip's end time and its number of trips.

#### Scenario: A short layover keeps the stretch

- **WHEN** trips run 06:00 to 08:30 and 08:40 to 11:10 with a 10-minute layover
- **THEN** one stretch runs from 06:00 to 11:10 with 2 trips

#### Scenario: A layover of exactly 15 minutes ends the stretch

- **WHEN** trips run 06:00 to 08:30 and 08:45 to 11:15 with a 15-minute layover
- **THEN** two stretches exist, 06:00 to 08:30 and 08:45 to 11:15

#### Scenario: Another route starts a new stretch

- **WHEN** complete trips run 10:20 to 11:08 and 11:20 to 12:08, the vehicle then runs another route, and its next complete trip runs 17:10 to 17:58
- **THEN** one stretch runs from 10:20 to 12:08 with 2 trips and another runs from 17:10 to 17:58 with 1 trip

#### Scenario: Fixture day

- **WHEN** continuous driving stretches are computed for the analysis fixture on 2026-10-19
- **THEN** there are 15 stretches and the longest runs from 06:00 to 11:30 with 5 trips


<!-- @trace
source: 01-rest-windows
updated: 2026-11-02
code:
  - db/migrate/20261101220000_create_route_day_rest_windows.rb
  - docs/data-sources.md
  - analysis/derived_export.sql
  - config/locales/tw.yml
  - .agents/skills/spectra-apply/SKILL.md
  - app/models/route_day.rb
  - spec/factories/layovers.rb
  - app/components/month_card_attribution_component.html.erb
  - app/models/program_version.rb
  - app/models/route_page/month_days.rb
  - app/models/route_card.rb
  - app/models/route_page/schedule_comparison.rb
  - app/components/month_card_cycles_component.rb
  - app/components/month_card_hour_chart_component.html.erb
  - app/models/route_page/layover_distribution.rb
  - spec/factories/route_days.rb
  - analysis/30_layovers.sql
  - app/components/month_card_cycles_component.html.erb
  - app/components/month_card_component.rb
  - .github/skills/spectra-apply/SKILL.md
  - analysis/README.md
  - app/models/route_page/month_card.rb
  - app/components/month_card_history_component.yml
  - app/models/route_page/layover_stats.rb
  - app/models/route_page/card_trend.rb
  - app/components/month_card_chart_component.rb
  - app/components/month_card_distribution_chart_component.html.erb
  - app/components/month_card_history_component.rb
  - spec/factories/route_day_published_departures.rb
  - app/models/route_day_published_headway.rb
  - app/components/month_card_buffer_component.rb
  - app/components/month_card_hour_chart_component.rb
  - app/components/month_card_summary_component.html.erb
  - app/models/route_page/month_findings.rb
  - app/models/route_page/rest_windows.rb
  - spec/factories/route_day_rest_windows.rb
  - spec/factories/trips.rb
  - app/components/month_card_driving_component.yml
  - config/routes.rb
  - app/models/route_page/load_profile.rb
  - analysis/params.sql
  - app/components/month_card_margin_component.rb
  - app/models/route_page/format.rb
  - config/locales/en.yml
  - spec/factories/route_cards.rb
  - app/components/month_card_layovers_component.html.erb
  - app/components/month_card_schedule_component.html.erb
  - app/components/month_card_buffer_component.yml
  - db/migrate/20261102011500_create_route_day_published_schedule.rb
  - db/migrate/20261102030000_create_route_cards.rb
  - app/components/month_card_driving_component.rb
  - app/components/attribution_component.yml
  - app/models/route_card_prepare_command.rb
  - app/components/month_card_margin_component.yml
  - spec/factories/route_day_driving_stretches.rb
  - app/components/month_card_hour_share_chart_component.html.erb
  - spec/factories/route_day_published_headways.rb
  - spec/fixtures/analysis/static/2026-10-23/GetTimeTable.gz
  - app/models/route_day_published_departure.rb
  - app/components/month_card_layovers_component.yml
  - app/components/month_card_attribution_component.rb
  - app/models/route_day_rest_window.rb
  - app/models/route_page/slow_legs.rb
  - spec/fixtures/analysis/static/2026-10-19/GetTimeTable.gz
  - app/components/month_card_hour_share_chart_component.rb
  - app/components/month_card_schedule_component.rb
  - app/components/month_card_run_times_component.rb
  - app/views/route_cards/show.html.erb
  - app/components/month_card_margin_component.html.erb
  - app/components/month_card_attribution_component.yml
  - spec/fixtures/analysis/static/2026-10-23/GetSemiTimeTable.gz
  - app/models/route_page/snapshot_changes.rb
  - app/models/route_day_driving_stretch.rb
  - app/components/month_card_run_times_component.yml
  - app/components/month_card_summary_component.yml
  - spec/fixtures/analysis/README.md
  - lib/tasks/cards.rake
  - app/frontend/stylesheets/application.css
  - db/schema.rb
  - analysis/published_schedule.sql
  - app/components/month_card_buffer_component.html.erb
  - app/models/route_page/layover_hours.rb
  - app/components/month_card_history_component.html.erb
  - app/controllers/route_cards_controller.rb
  - app/components/month_card_driving_component.html.erb
  - app/models/route_day_loader.rb
  - app/components/month_card_run_times_component.html.erb
  - app/components/month_card_distribution_chart_component.yml
  - app/components/month_card_hour_share_chart_component.yml
  - app/models/route_card_coverage.rb
  - bin/health-card
  - app/components/month_card_distribution_chart_component.rb
  - app/components/month_card_cycles_component.yml
  - spec/fixtures/analysis/static/2026-10-19/GetSemiTimeTable.gz
  - app/components/month_card_schedule_component.yml
  - app/components/month_card_layovers_component.rb
  - app/components/month_card_summary_component.rb
  - app/models/route_page/mrt_overlap.rb
tests:
  - spec/analysis/derived_export_spec.rb
  - spec/models/route_day_published_departure_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/route_day_published_headway_spec.rb
  - spec/models/route_card_prepare_command_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/models/program_version_spec.rb
  - spec/models/route_page/schedule_comparison_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_card_spec.rb
  - spec/models/route_page/layover_hours_spec.rb
  - spec/models/route_page/month_card_spec.rb
  - spec/components/month_card_run_times_component_spec.rb
  - spec/components/month_card_margin_component_spec.rb
  - spec/components/month_card_layovers_component_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/components/month_card_buffer_component_spec.rb
  - spec/components/month_card_cycles_component_spec.rb
  - spec/models/route_day_driving_stretch_spec.rb
  - spec/models/route_day_spec.rb
  - spec/system/month_card_print_spec.rb
  - spec/components/month_card_hour_chart_component_spec.rb
  - spec/components/month_card_summary_component_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_day_rest_window_spec.rb
  - spec/models/route_page/month_days_spec.rb
  - spec/models/route_page/month_findings_spec.rb
  - spec/components/month_card_attribution_component_spec.rb
  - spec/models/route_page/slow_legs_spec.rb
  - spec/requests/route_cards_spec.rb
  - spec/components/month_card_history_component_spec.rb
  - spec/components/month_card_driving_component_spec.rb
  - spec/models/route_page/rest_windows_spec.rb
  - spec/models/route_page/card_trend_spec.rb
  - spec/components/month_card_schedule_component_spec.rb
  - spec/analysis/published_schedule_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/models/route_page/snapshot_changes_spec.rb
  - spec/models/route_card_coverage_spec.rb
  - spec/models/derived_load_command_spec.rb
-->

---
### Requirement: Rest window figures over route days

The system SHALL provide the query object `RoutePage::RestWindows`, which reads the stored rest windows and driving stretches of any given set of route days, whether or not the set is ordered. For each of the rules `four_hours` and `six_hours` it SHALL report the number of windows, the number of flagged windows, the flagged share of the windows, the lowest and the highest daily flagged share among the days that have a window of that rule, the number of windows with `over_daily_driving` and the number of flagged windows with `over_daily_driving`. Without a window of a rule, the share and the daily shares SHALL be nil. For the stretches it SHALL report their number, the 50th and 90th percentiles of their minutes to one decimal using linear interpolation, the longest in minutes, and how many exceed 240 and 360 minutes. It SHALL report that the days need loading again when any given route day has `rest_windows_loaded` false. It SHALL NOT return any `BusID` value and SHALL NOT carry any judgement of compliance.

#### Scenario: Shares over two days

- **WHEN** one route day has 4 `four_hours` windows of which 2 are flagged, and another has 2 `four_hours` windows of which 2 are flagged
- **THEN** the rule reports 6 windows, 4 flagged, a share of 4/6, a lowest daily share of 0.5 and a highest daily share of 1.0

#### Scenario: A day without windows

- **WHEN** a route day has `rest_windows_loaded` true and no `six_hours` window, and another has 2 `six_hours` windows of which 1 is flagged
- **THEN** the rule reports 2 windows, 1 flagged, and both daily shares are 0.5

#### Scenario: No windows at all

- **WHEN** no given route day has a `six_hours` window
- **THEN** the rule reports 0 windows, 0 flagged, and its share and daily shares are nil

#### Scenario: Stretch figures

- **WHEN** the stretches last 100, 200, 250 and 400 minutes
- **THEN** the report gives 4 stretches, a p50 of 225.0, a p90 of 355.0, a longest of 400.0, 2 over 240 minutes and 1 over 360 minutes

#### Scenario: A day that was not loaded again

- **WHEN** one given route day has `rest_windows_loaded` false
- **THEN** the query object reports that the days need loading again

#### Scenario: No plates in the figures

- **WHEN** the figures are read for a route day whose vehicle is TEST-0001
- **THEN** no returned value contains TEST-0001

<!-- @trace
source: 01-rest-windows
updated: 2026-11-02
code:
  - db/migrate/20261101220000_create_route_day_rest_windows.rb
  - docs/data-sources.md
  - analysis/derived_export.sql
  - config/locales/tw.yml
  - .agents/skills/spectra-apply/SKILL.md
  - app/models/route_day.rb
  - spec/factories/layovers.rb
  - app/components/month_card_attribution_component.html.erb
  - app/models/program_version.rb
  - app/models/route_page/month_days.rb
  - app/models/route_card.rb
  - app/models/route_page/schedule_comparison.rb
  - app/components/month_card_cycles_component.rb
  - app/components/month_card_hour_chart_component.html.erb
  - app/models/route_page/layover_distribution.rb
  - spec/factories/route_days.rb
  - analysis/30_layovers.sql
  - app/components/month_card_cycles_component.html.erb
  - app/components/month_card_component.rb
  - .github/skills/spectra-apply/SKILL.md
  - analysis/README.md
  - app/models/route_page/month_card.rb
  - app/components/month_card_history_component.yml
  - app/models/route_page/layover_stats.rb
  - app/models/route_page/card_trend.rb
  - app/components/month_card_chart_component.rb
  - app/components/month_card_distribution_chart_component.html.erb
  - app/components/month_card_history_component.rb
  - spec/factories/route_day_published_departures.rb
  - app/models/route_day_published_headway.rb
  - app/components/month_card_buffer_component.rb
  - app/components/month_card_hour_chart_component.rb
  - app/components/month_card_summary_component.html.erb
  - app/models/route_page/month_findings.rb
  - app/models/route_page/rest_windows.rb
  - spec/factories/route_day_rest_windows.rb
  - spec/factories/trips.rb
  - app/components/month_card_driving_component.yml
  - config/routes.rb
  - app/models/route_page/load_profile.rb
  - analysis/params.sql
  - app/components/month_card_margin_component.rb
  - app/models/route_page/format.rb
  - config/locales/en.yml
  - spec/factories/route_cards.rb
  - app/components/month_card_layovers_component.html.erb
  - app/components/month_card_schedule_component.html.erb
  - app/components/month_card_buffer_component.yml
  - db/migrate/20261102011500_create_route_day_published_schedule.rb
  - db/migrate/20261102030000_create_route_cards.rb
  - app/components/month_card_driving_component.rb
  - app/components/attribution_component.yml
  - app/models/route_card_prepare_command.rb
  - app/components/month_card_margin_component.yml
  - spec/factories/route_day_driving_stretches.rb
  - app/components/month_card_hour_share_chart_component.html.erb
  - spec/factories/route_day_published_headways.rb
  - spec/fixtures/analysis/static/2026-10-23/GetTimeTable.gz
  - app/models/route_day_published_departure.rb
  - app/components/month_card_layovers_component.yml
  - app/components/month_card_attribution_component.rb
  - app/models/route_day_rest_window.rb
  - app/models/route_page/slow_legs.rb
  - spec/fixtures/analysis/static/2026-10-19/GetTimeTable.gz
  - app/components/month_card_hour_share_chart_component.rb
  - app/components/month_card_schedule_component.rb
  - app/components/month_card_run_times_component.rb
  - app/views/route_cards/show.html.erb
  - app/components/month_card_margin_component.html.erb
  - app/components/month_card_attribution_component.yml
  - spec/fixtures/analysis/static/2026-10-23/GetSemiTimeTable.gz
  - app/models/route_page/snapshot_changes.rb
  - app/models/route_day_driving_stretch.rb
  - app/components/month_card_run_times_component.yml
  - app/components/month_card_summary_component.yml
  - spec/fixtures/analysis/README.md
  - lib/tasks/cards.rake
  - app/frontend/stylesheets/application.css
  - db/schema.rb
  - analysis/published_schedule.sql
  - app/components/month_card_buffer_component.html.erb
  - app/models/route_page/layover_hours.rb
  - app/components/month_card_history_component.html.erb
  - app/controllers/route_cards_controller.rb
  - app/components/month_card_driving_component.html.erb
  - app/models/route_day_loader.rb
  - app/components/month_card_run_times_component.html.erb
  - app/components/month_card_distribution_chart_component.yml
  - app/components/month_card_hour_share_chart_component.yml
  - app/models/route_card_coverage.rb
  - bin/health-card
  - app/components/month_card_distribution_chart_component.rb
  - app/components/month_card_cycles_component.yml
  - spec/fixtures/analysis/static/2026-10-19/GetSemiTimeTable.gz
  - app/components/month_card_schedule_component.yml
  - app/components/month_card_layovers_component.rb
  - app/components/month_card_summary_component.rb
  - app/models/route_page/mrt_overlap.rb
tests:
  - spec/analysis/derived_export_spec.rb
  - spec/models/route_day_published_departure_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/route_day_published_headway_spec.rb
  - spec/models/route_card_prepare_command_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/models/program_version_spec.rb
  - spec/models/route_page/schedule_comparison_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_card_spec.rb
  - spec/models/route_page/layover_hours_spec.rb
  - spec/models/route_page/month_card_spec.rb
  - spec/components/month_card_run_times_component_spec.rb
  - spec/components/month_card_margin_component_spec.rb
  - spec/components/month_card_layovers_component_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/components/month_card_buffer_component_spec.rb
  - spec/components/month_card_cycles_component_spec.rb
  - spec/models/route_day_driving_stretch_spec.rb
  - spec/models/route_day_spec.rb
  - spec/system/month_card_print_spec.rb
  - spec/components/month_card_hour_chart_component_spec.rb
  - spec/components/month_card_summary_component_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_day_rest_window_spec.rb
  - spec/models/route_page/month_days_spec.rb
  - spec/models/route_page/month_findings_spec.rb
  - spec/components/month_card_attribution_component_spec.rb
  - spec/models/route_page/slow_legs_spec.rb
  - spec/requests/route_cards_spec.rb
  - spec/components/month_card_history_component_spec.rb
  - spec/components/month_card_driving_component_spec.rb
  - spec/models/route_page/rest_windows_spec.rb
  - spec/models/route_page/card_trend_spec.rb
  - spec/components/month_card_schedule_component_spec.rb
  - spec/analysis/published_schedule_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/models/route_page/snapshot_changes_spec.rb
  - spec/models/route_card_coverage_spec.rb
  - spec/models/derived_load_command_spec.rb
-->