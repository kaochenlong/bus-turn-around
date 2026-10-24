## ADDED Requirements

### Requirement: Layovers across member routes

A pair of consecutive trips of one vehicle SHALL qualify as a layover under the same conditions whichever route `Id` of the run each of the two trips belongs to, so that a vehicle switching between the page route and a member route at a terminal keeps its layover. The layover's direction SHALL be the direction of the trip that ended.

#### Scenario: Member route trip followed by a page route trip

- **WHEN** on 2026-10-23 TEST-0005's trip of route 9050 in direction 0 arrives at 07:50 and its trip of route 9001 in direction 1 departs at 08:00
- **THEN** the pair is a layover of 10.0 minutes in direction 0

#### Scenario: Page route trip followed by a member route trip

- **WHEN** TEST-0005's trip of route 9001 in direction 1 arrives at 08:50 and its trip of route 9050 in direction 0 departs at 09:00
- **THEN** the pair is a layover of 10.0 minutes in direction 1

## MODIFIED Requirements

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
