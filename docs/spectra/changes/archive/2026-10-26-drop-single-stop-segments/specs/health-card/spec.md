## MODIFIED Requirements

### Requirement: Data quality section

The 資料品質 section SHALL report: records read and duplicates removed per feed, both counted after filtering to the requested route's sub-routes and over the whole read window; unknown-stop events; the per-sub-route stop sequence check result together with the directions compared; trips total and per completeness class; the number of segments that start on the requested day and observe fewer distinct stops than the constant `min_trip_stops` of `analysis/params.sql`, which are not trips under Segments observing too few stops are not trips, stated together with that constant; the share of trips per `pathAttributeId`; for each direction, the number of complete trips and the number of them whose last stop has a departure event (`CarOnStop` 0 in the deduplicated `bus_event` events of the same `BusID`, route `Id` and `GoBack`) with a `DataTime` no earlier than the trip's end time and no later than 60 minutes after it; for each sub-route, how many of its trips are the vehicle's first trip of the day and how many are its last, where a vehicle's trips of the day are its trips on the requested route that start on the requested day, of any completeness, ordered by start time, and a vehicle's only trip counts as both; the missing-stop rate among complete trips, defined as stops of the direction with no event divided by stops of the direction, summed over complete trips; the distribution of `DutyStatus` values; the share of trips whose last event has `DutyStatus` 2; and the share of `DutyStatus` 2 events that are the last event of a trip.

#### Scenario: Missing-stop rate

- **WHEN** two complete trips on a 5-stop direction observe 5 and 4 distinct stops
- **THEN** the missing-stop rate is 10%

#### Scenario: DutyStatus correspondence

- **WHEN** 10 events carry `DutyStatus` 2 and 7 of them are the last event of their trip
- **THEN** the section reports 70% of `DutyStatus` 2 events as trip-final

#### Scenario: Departure event at the last stop

- **WHEN** direction 1 has two complete trips ending at 10:00 and 12:00, the first followed by a departure event at its last stop at 10:05 and the second followed only by another arrival event at that stop at 12:02
- **THEN** direction 1 reports 2 complete trips and 1 with a departure event at the last stop

#### Scenario: First and last trips per sub-route

- **WHEN** vehicle A has three trips on the day on sub-routes 9002, 9001 and 9001 in start order, and vehicle B has one trip on sub-route 9003
- **THEN** 9002 reports 1 first trip and 0 last trips, 9001 reports 0 first trips and 1 last trip, and 9003 reports 1 first trip and 1 last trip

#### Scenario: Segments that are not trips

- **WHEN** a vehicle's only records of the day are one arrival at the last stop of direction 0 at 06:09 and then a complete direction-1 trip from 06:19 to 07:41
- **THEN** the section reports 1 segment that observes fewer than 2 distinct stops and is not counted as a trip, and the trips per completeness class are 1 complete trip and 0 in every other class

#### Scenario: Fixture day reports no such segment

- **WHEN** the card is generated for the analysis fixture on 2026-10-19
- **THEN** the 資料品質 section contains the line 「觀測到的站少於 2 站、不算趟次的段：0 段」
