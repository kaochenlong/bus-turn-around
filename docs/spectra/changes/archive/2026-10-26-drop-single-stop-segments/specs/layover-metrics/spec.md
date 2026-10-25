## MODIFIED Requirements

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
