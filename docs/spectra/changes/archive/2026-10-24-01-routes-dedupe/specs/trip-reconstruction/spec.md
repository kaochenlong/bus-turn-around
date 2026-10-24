## MODIFIED Requirements

### Requirement: Sub-route to route and direction mapping

The system SHALL map each event's `RouteID` to a route `Id` using the distinct `(Id, pathAttributeId)` pairs of the `GetRoute.gz` snapshot. Rows of the snapshot that agree on `Id`, `pathAttributeId`, `nameZh`, `pathAttributeName`, `departureZh` and `destinationZh` SHALL count as one sub-route however many such rows the snapshot holds, so that every event of that sub-route is mapped exactly once. The system SHALL map each event's `StopID` to a sequence number using the `GetStop.gz` rows whose `routeId` equals that route `Id` and whose `goBack` equals the event's `GoBack`. Events whose `StopID` is not in that direction's stop list SHALL be excluded from trips and counted as unknown-stop events.

#### Scenario: Half-path events merge into the route

- **WHEN** events carry `RouteID` 9002 and `GetRoute.gz` lists `pathAttributeId` 9002 under `Id` 9001
- **THEN** those events are segmented together with `RouteID` 9001 events under route 9001

#### Scenario: Duplicate rows of one sub-route

- **WHEN** `GetRoute.gz` lists `pathAttributeId` 9002 under `Id` 9001 in two rows that differ only in `providerId` and `providerName`
- **THEN** route 9001 has the sub-routes 9001, 9002 and 9003 once each, and every deduplicated `bus_event` record with `RouteID` 9002 is either one stop event or one unknown-stop event, never two

##### Example: fixture snapshot of 2026-10-19

- **GIVEN** the fixture `GetRoute.gz` whose rows are (`Id` 9001, `pathAttributeId` 9001), (9001, 9002) twice with `providerId` 9999 and 9998, (9001, 9003) and (9100, 9100)
- **WHEN** stage 10 builds the routes table for route 9001
- **THEN** the routes table has three rows, one per `pathAttributeId` 9001, 9002 and 9003, and the number of stop events plus unknown-stop events equals the number of deduplicated `bus_event` records of those three sub-routes

#### Scenario: Stop outside the direction's list

- **WHEN** an event with `GoBack` 0 carries a `StopID` that exists only in the `goBack` 1 stop list
- **THEN** the event is not part of any trip and the unknown-stop count increases by one
