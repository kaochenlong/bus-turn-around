## MODIFIED Requirements

### Requirement: Layover definition

For each vehicle, the system SHALL order its trips by start time and SHALL compute a layover for each pair of consecutive trips as the next trip's start time minus the current trip's end time, only when the current trip observed the last stop of its direction (classified `complete` or `missing_start`), the next trip observed the first stop of its direction (classified `complete` or `missing_end`), both carry the same route `Id`, and the difference is not negative. Pairs that do not qualify SHALL be counted in exactly one of four exclusion categories, taking the first that applies in this order: the current trip did not reach its last stop (`no_last_stop`); the next trip did not leave from its first stop (`no_first_stop`); the next trip is on another route (`other_route`); the difference is negative (`negative`). Excluded pairs SHALL be counted only; their time differences SHALL NOT be reported as layovers. The last trip of a vehicle on the day SHALL have no layover.

#### Scenario: Qualifying pair

- **WHEN** a complete trip ends at 08:30 and the same vehicle's next complete trip on the same route starts at 08:42
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

#### Scenario: Negative difference

- **WHEN** the next trip's start time is earlier than the current trip's end time
- **THEN** no layover is recorded and the negative-pair count increases by one

##### Example: Overlapping trips

- **GIVEN** a complete trip ending at 08:30 and the same vehicle's next complete trip starting at 08:28
- **WHEN** layovers are computed
- **THEN** the pair yields no layover and the negative-pair count is 1

##### Example: Fixture day 2026-10-19

- **GIVEN** the trips of the analysis fixture for 2026-10-19
- **WHEN** layovers are computed
- **THEN** there are 19 layovers, 10 ending an outbound trip and 9 ending an inbound trip, with exclusion counts `no_last_stop` 3, `no_first_stop` 1, `other_route` 0 and `negative` 0
