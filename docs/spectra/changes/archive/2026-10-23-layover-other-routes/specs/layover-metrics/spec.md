## ADDED Requirements

### Requirement: Runs on other routes between trips

The system SHALL read, from the same `bus_event` hourly files of the read window, the records of every vehicle that has an event on the route, whose `RouteID` is neither 0 nor one of the route's `pathAttributeId`s, deduplicated by `(BusID, DataTime)`. A vehicle SHALL be taken to have run another route between two of its consecutive trips when those records with a `DataTime` later than the current trip's end time and earlier than the next trip's start time cover at least the number of distinct `StopID`s given by the constant `other_route_min_stops` of `analysis/params.sql`, which is 3. Records with `RouteID` 0 SHALL never count, because they mark non-revenue states such as the end of duty at a terminal, and a return to the depot belongs to the layover. Records of another route covering fewer distinct stops than the threshold SHALL NOT count, because they come from a route code set at a terminal, not from a run.

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

#### Scenario: Records outside the gap

- **WHEN** all of a vehicle's records on another route lie after the end of its last trip of the day
- **THEN** none of its pairs of consecutive trips counts as having run another route

##### Example: Control route after the last trip

- **GIVEN** TEST-0004's trips of the analysis fixture on 2026-10-19 end at 06:58, 08:03 and 09:03, and its 20 records on route 9100 lie between 13:10 and 22:50
- **WHEN** layovers are computed
- **THEN** TEST-0004's layovers are 17.0 and 12.0 minutes and neither of its two pairs ran another route

## MODIFIED Requirements

### Requirement: Layover definition

For each vehicle, the system SHALL order its trips by start time and SHALL compute a layover for each pair of consecutive trips as the next trip's start time minus the current trip's end time, only when the current trip observed the last stop of its direction (classified `complete` or `missing_start`), the next trip observed the first stop of its direction (classified `complete` or `missing_end`), the vehicle did not run another route between the two trips as defined by Runs on other routes between trips, and the difference is not negative. Pairs that do not qualify SHALL be counted in exactly one of four exclusion categories, taking the first that applies in this order: the current trip did not reach its last stop (`no_last_stop`); the next trip did not leave from its first stop (`no_first_stop`); the vehicle ran another route between the two trips (`other_route`); the difference is negative (`negative`). Excluded pairs SHALL be counted only; their time differences SHALL NOT be reported as layovers. The last trip of a vehicle on the day SHALL have no layover.

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

#### Scenario: Fixture day

- **WHEN** layovers are computed for the analysis fixture on 2026-10-19
- **THEN** the layovers and exclusion counts equal the values hand-computed in `spec/fixtures/analysis/README.md`

##### Example: Fixture day 2026-10-19

- **GIVEN** the trips of the analysis fixture for 2026-10-19, where TEST-0002 has records on route 9100 at three distinct stops between its trip ending at 12:08 and its trip starting at 17:10, and TEST-0001 has records on route 9100 at two distinct stops between its trip ending at 15:40 and its trip starting at 17:05
- **WHEN** layovers are computed
- **THEN** there are 18 layovers, 10 ending an outbound trip and 8 ending an inbound trip, TEST-0001's 85.0-minute layover after 15:40 is among them, and the exclusion counts are `no_last_stop` 3, `no_first_stop` 1, `other_route` 1 and `negative` 0

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
