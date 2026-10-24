## MODIFIED Requirements

### Requirement: Sub-route to route and direction mapping

A run SHALL work on a set of route `Id`s: the page route's `Id` followed by the `Id`s of its member routes, given as the SQL variable `member_route_ids` and defaulting to the page route alone. The system SHALL map each event's `RouteID` to one of those route `Id`s using the distinct `(Id, pathAttributeId)` pairs of the `GetRoute.gz` snapshot. Rows of the snapshot that agree on `Id`, `pathAttributeId`, `nameZh`, `pathAttributeName`, `departureZh` and `destinationZh` SHALL count as one sub-route however many such rows the snapshot holds, so that every event of that sub-route is mapped exactly once. The system SHALL map each event's `StopID` to a sequence number using the `GetStop.gz` rows whose `routeId` equals the event's route `Id` and whose `goBack` equals the event's `GoBack`. Trips SHALL be segmented per vehicle and route `Id`, so that a member route's events form trips of the member route judged against the member route's own stop list. Events whose `StopID` is not in that direction's stop list of their route `Id` SHALL be excluded from trips and counted as unknown-stop events. A route `Id` of the set that has no row in the day's `GetRoute.gz` SHALL fail the run with a message naming that `Id`.

#### Scenario: Half-path events merge into the route

- **WHEN** events carry `RouteID` 9002 and `GetRoute.gz` lists `pathAttributeId` 9002 under `Id` 9001
- **THEN** those events are segmented together with `RouteID` 9001 events under route 9001

#### Scenario: Duplicate rows of one sub-route

- **WHEN** `GetRoute.gz` lists `pathAttributeId` 9002 under `Id` 9001 in two rows that differ only in `providerId` and `providerName`
- **THEN** route 9001 has the sub-routes 9001, 9002 and 9003 once each, and every deduplicated `bus_event` record with `RouteID` 9002 is either one stop event or one unknown-stop event, never two

#### Scenario: Member route events keep their own Id and stop list

- **WHEN** the run is for route 9001 with member route 9050 on 2026-10-23, and vehicle TEST-0005 has events with `RouteID` 9050 and events with `RouteID` 9001
- **THEN** the `RouteID` 9050 events form trips of route 9050 whose sequence numbers come from route 9050's stop list, and the `RouteID` 9001 events form a trip of route 9001

##### Example: TEST-0005 on the member day

- **GIVEN** TEST-0005 departs 95000 at 07:00, is observed at 95001, 95002 and 95003, arrives at 95004 at 07:50, departs 91005 at 08:00, arrives at 91009 at 08:50, then repeats the 9050 trip from 09:00 to 09:50
- **WHEN** trips are segmented
- **THEN** there are three complete trips: two of route 9050 in direction 0 with first sequence 0 and last sequence 4, and one of route 9001 in direction 1 with first sequence 5 and last sequence 9

#### Scenario: Member route missing from the snapshot

- **WHEN** the run is for route 9001 with member route 9050 and the day's `GetRoute.gz` has no row with `Id` 9050
- **THEN** the run fails and the message names 9050

#### Scenario: Stop outside the direction's list

- **WHEN** an event with `GoBack` 0 carries a `StopID` that exists only in the `goBack` 1 stop list
- **THEN** the event is not part of any trip and the unknown-stop count increases by one

### Requirement: Sub-route stop sequence check

For every `pathAttributeId` mapped to any route `Id` of the run, the system SHALL take its `stopId` sequence from `GetPathDetail.gz` ordered by `sequenceNo`, and SHALL determine the directions compared as the set of `goBack` values of the rows of `GetStop.gz` of the route `Id` that `pathAttributeId` belongs to whose `Id` appears in that sequence. The system SHALL compare the sequence with that route `Id`'s stop list ordered by `seqNo`, restricted to the compared directions: one direction's list when the set has one value, the full list when it has both. Only the order of stops SHALL be compared, not the `sequenceNo` values, because `sequenceNo` starts at 0 for every sub-route. The system SHALL report, per sub-route, its route `Id`, whether the two sequences are identical and which directions were compared. A sub-route none of whose stops appear in its route `Id`'s stop list SHALL be reported as not identical with no direction compared.

#### Scenario: Identical sequences

- **WHEN** sub-route 9002's `GetPathDetail.gz` stops equal the route's `goBack` 0 stop list in order
- **THEN** the report marks sub-route 9002 as identical, compared with direction 0

#### Scenario: Different sequences

- **WHEN** sub-route 9003's `GetPathDetail.gz` stops omit one stop of the route's `goBack` 1 list
- **THEN** the report marks sub-route 9003 as not identical, compared with direction 1

#### Scenario: Sub-route spanning both directions

- **WHEN** sub-route 9001's `GetPathDetail.gz` stops equal the route's `goBack` 0 stop list followed by its `goBack` 1 stop list
- **THEN** the report marks sub-route 9001 as identical, compared with both directions

#### Scenario: Member route compared with its own stop list

- **WHEN** the run is for route 9001 with member route 9050, and sub-route 9050's `GetPathDetail.gz` stops equal route 9050's `goBack` 0 list followed by its `goBack` 1 list
- **THEN** the report marks sub-route 9050 as identical under route 9050, compared with both directions, even though 己站 is not in route 9001's stop list
