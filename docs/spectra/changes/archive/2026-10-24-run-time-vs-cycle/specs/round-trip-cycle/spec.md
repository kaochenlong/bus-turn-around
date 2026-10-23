## Purpose

The round trip and the cycle of a vehicle on a route: how long one loop from the stopping end and back takes, and how long the operation actually gives a vehicle between two returns to that end. Both are computed at read time from the stored trips and layovers, so the gap that drivers absorb by hurrying or by skipping rest is visible per route and departure hour.

## ADDED Requirements

### Requirement: Lead direction

For a route whose end natures are defined by `turnaround-ends`, the system SHALL compute round trips and cycles from a lead direction: direction 0, unless direction 0's trips end at a stopping end and direction 1's trips end at a pass-through end, in which case the lead direction SHALL be 1. The back direction SHALL be the other direction. The lead direction's trips are the ones that leave the stopping end; a route with two stopping ends or two pass-through ends SHALL use direction 0.

#### Scenario: Pass-through end in direction 0

- **WHEN** a route is configured with direction 0 as `pass_through` and direction 1 as `stop`
- **THEN** the lead direction is 0 and the back direction is 1

#### Scenario: Pass-through end in direction 1

- **WHEN** a route is configured with direction 0 as `stop` and direction 1 as `pass_through`
- **THEN** the lead direction is 1 and the back direction is 0

#### Scenario: Both ends stopping

- **WHEN** route 9001 is configured with both ends as `stop`
- **THEN** the lead direction is 0

### Requirement: Round trip

A round trip SHALL be the minutes from the `start_time` of a lead-direction trip to the `end_time` of the back-direction trip that follows it on the same vehicle and stored day. The pair SHALL qualify only when the lead trip is complete and its start is an observed departure (`start_from_arrival` false), when a stored layover of the lead direction has that lead trip's `end_time` as its `end_time` and the back trip's `start_time` as its `next_start_time` for the same vehicle and stored day, and when the back trip is complete and its end is an observed arrival (`end_from_departure` false). A round trip includes the time spent at the far end between the two trips. A lead trip without such a layover, or whose following trip is not in the back direction, SHALL NOT yield a round trip.

#### Scenario: Qualifying pair

- **WHEN** vehicle A has a complete lead trip from 06:00 to 06:50 with an observed departure, a stored layover of the lead direction from 06:50 to 07:00, and a complete back trip from 07:00 to 08:30 with an observed arrival
- **THEN** one round trip of 150.0 minutes is counted in hour 6

#### Scenario: Lead trip starting from an arrival

- **WHEN** the lead trip of an otherwise qualifying pair has `start_from_arrival` true
- **THEN** the pair yields no round trip

#### Scenario: Back trip ending with a departure

- **WHEN** the back trip of an otherwise qualifying pair has `end_from_departure` true
- **THEN** the pair yields no round trip

#### Scenario: No stored layover between the trips

- **WHEN** vehicle A has a complete lead trip ending at 07:23 and a back trip starting at 07:40, and no stored layover of the lead direction has `end_time` 07:23 and `next_start_time` 07:40 for vehicle A
- **THEN** the pair yields no round trip

#### Scenario: Following trip in the lead direction again

- **WHEN** vehicle A has a complete lead trip ending at 07:53, a stored layover of the lead direction from 07:53 to 08:08, and the trip starting at 08:08 is again in the lead direction
- **THEN** the lead trip ending at 07:53 yields no round trip

##### Example: fixture day

- **GIVEN** the fixture day 2026-10-19 of route 9001 written by the loader, with both ends `stop`
- **WHEN** the round trips are read over that day
- **THEN** there are 7 round trips of 150, 109, 153, 125, 108, 113 and 108 minutes, starting in hours 6, 8, 10, 13, 17, 11 and 7, and the trip of TEST-0002 starting at 10:20 with `start_from_arrival` true yields none

### Requirement: Cycle

A cycle SHALL be the minutes from the `end_time` of a back-direction trip to the `end_time` of the next back-direction trip of the same vehicle and stored day, with exactly one lead-direction trip between them. The chain SHALL qualify only when a stored layover of the back direction has the earlier back trip's `end_time` as its `end_time` and the lead trip's `start_time` as its `next_start_time`, when a stored layover of the lead direction has the lead trip's `end_time` as its `end_time` and the later back trip's `start_time` as its `next_start_time`, when the earlier back trip's end is an observed arrival (`end_from_departure` false), and when the later back trip is complete and its end is an observed arrival. The lead trip's completeness and `start_from_arrival` SHALL NOT affect the cycle. The cycle SHALL be counted in the Taipei hour of the lead trip's `start_time`. For one chain, the cycle SHALL equal the stored layover at the stopping end plus the round trip of the same lead and later back trips.

#### Scenario: Qualifying chain

- **WHEN** vehicle A has a back trip ending at 08:30 with an observed arrival, a stored layover of the back direction from 08:30 to 08:42, a lead trip from 08:42 to 09:30, a stored layover of the lead direction from 09:30 to 09:43, and a complete back trip from 09:43 to 10:31 with an observed arrival
- **THEN** one cycle of 121.0 minutes is counted in hour 8, equal to the layover of 12.0 minutes plus the round trip of 109.0 minutes

#### Scenario: First loop of the vehicle's day

- **WHEN** a vehicle's first trip of a stored day is a lead trip
- **THEN** that lead trip and the back trip after it yield a round trip and no cycle

##### Example: fixture vehicle TEST-0001

- **GIVEN** the fixture day 2026-10-19 of route 9001, where TEST-0001's first trip is the lead trip from 06:00 to 06:50 followed by the back trip from 07:00 to 08:30
- **WHEN** the round trips and cycles are read over that day
- **THEN** hour 6 has one round trip of 150.0 minutes and no cycle, and TEST-0001's first cycle is the one of 121.0 minutes in hour 8

#### Scenario: Earlier back trip ending with a departure

- **WHEN** the earlier back trip of an otherwise qualifying chain has `end_from_departure` true
- **THEN** the chain yields no cycle

#### Scenario: Later back trip incomplete

- **WHEN** the later back trip of an otherwise qualifying chain has completeness `missing_end`
- **THEN** the chain yields no cycle

#### Scenario: Lead trip starting from an arrival

- **WHEN** the lead trip of an otherwise qualifying chain has `start_from_arrival` true and completeness `complete`
- **THEN** the chain yields a cycle and the same trips yield no round trip

#### Scenario: Earlier back trip missing its start

- **WHEN** the earlier back trip of an otherwise qualifying chain has completeness `missing_start` and `end_from_departure` false
- **THEN** the chain yields a cycle

##### Example: fixture day

- **GIVEN** the fixture day 2026-10-19 of route 9001 written by the loader
- **WHEN** the cycles are read over that day
- **THEN** there are 5 cycles of 121, 163, 146, 136 and 125 minutes, counted in hours 8, 10, 13, 11 and 7, and the cycle of 136 minutes starts from TEST-0003's back trip of completeness `missing_start` ending at 10:52

### Requirement: Summary by departure hour

The system SHALL summarise the round trips and cycles of the covered days per Taipei hour of the lead trip's departure, each hour giving the number of round trips with their p50 and p85, and the number of cycles with their p10 and p50, and SHALL add one all-day row that pools every hour. Percentiles SHALL interpolate linearly between order statistics and SHALL be rounded to one decimal; a measure with no value in a row SHALL report nil percentiles and a count of 0. A measure with fewer than 5 values in a row SHALL be marked as a small sample. Values SHALL be pooled over all covered days, not combined from daily values.

#### Scenario: Hour with round trips but no cycle

- **WHEN** hour 6 has one round trip of 150 minutes and no cycle
- **THEN** the row of hour 6 reports 1 round trip with p50 150.0 and p85 150.0, marked as a small sample, and 0 cycles with nil percentiles

#### Scenario: Linear interpolation

- **WHEN** the covered days have round trips of 108, 108, 109, 113, 125, 150 and 153 minutes and cycles of 121, 125, 136, 146 and 163 minutes
- **THEN** the all-day row reports 7 round trips with p50 113.0 and p85 150.3, and 5 cycles with p10 122.6 and p50 136.0

#### Scenario: Two days pooled

- **WHEN** day one has round trips of 100 and 110 minutes in hour 7 and day two has one of 120 minutes in hour 7, and the page covers both days
- **THEN** the row of hour 7 reports 3 round trips with p50 110.0

#### Scenario: Small sample

- **WHEN** hour 7 has 4 round trips and 6 cycles
- **THEN** the row of hour 7 marks the round trips as a small sample and the cycles not

##### Example: fixture day

- **GIVEN** the fixture day 2026-10-19 of route 9001 written by the loader
- **WHEN** the summary is read over that day
- **THEN** the all-day row reports 7 round trips with p50 113.0 and p85 150.3 and 5 cycles with p10 122.6 and p50 136.0, and every hourly row is a small sample
