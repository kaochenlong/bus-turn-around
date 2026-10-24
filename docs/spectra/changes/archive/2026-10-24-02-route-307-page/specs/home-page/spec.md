## ADDED Requirements

### Requirement: Route list entry of a page with member routes

An entry of a page route that lists member routes SHALL show the label 路線 Id followed by every route `Id` of the page, the page route first, joined by 「・」, whether or not the route has stored days; SHALL link to `/routes/<page Id>` only when the route has stored days; and the member routes SHALL have no entry of their own.

#### Scenario: Entry with two Ids

- **WHEN** the configuration lists 9001 with 9050 under `member_routes`, and 9001 has a stored day
- **THEN** the list has one entry for them, reading 路線 Id 9001・9050 after the departure and destination and linking to `/routes/9001`, and no entry for 9050

#### Scenario: Entry with two Ids and no data

- **WHEN** the configuration lists 9001 with 9050 under `member_routes`, and 9001 has no stored day
- **THEN** the entry reads 路線 Id 9001・9050, states that the route has no data yet and links nowhere
