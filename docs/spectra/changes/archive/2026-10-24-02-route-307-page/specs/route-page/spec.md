## ADDED Requirements

### Requirement: Route Ids of a page with member routes

When the page route lists member routes in the route list configuration, the line under the heading SHALL give the departure and destination of the latest covered day followed by the label 路線 Id and every route `Id` of the page, the page route first, joined by 「・」. The page SHALL stay at `/routes/<page Id>`, and a member route's `Id` SHALL NOT have a page of its own.

#### Scenario: Two Ids in the header

- **WHEN** route 9001 lists 9050 under `member_routes` and its latest covered day has departure 甲站 and destination 戊站
- **THEN** the line under the heading reads 甲站－戊站 followed by 路線 Id 9001・9050

#### Scenario: Member route address

- **WHEN** a visitor requests `/routes/9050` and 9050 is listed only under route 9001's `member_routes`
- **THEN** the response is 404 and its body is the content of `public/404.html`

#### Scenario: Single route unchanged

- **WHEN** route 10712 lists no member routes
- **THEN** the line under the heading ends with 路線 Id 10712

### Requirement: Member route note in the stop sequence block

For each direction, after the page route's stops and before the turnaround row, the block SHALL state, for every member route whose stops of that direction differ from the page route's on the latest covered day, the member route's name and `Id`, the page route's stops of that direction the member does not serve in sequence order, and the stops the member serves instead in the member's sequence order, the comparison being made by `stopLocationId`. A member route whose stops of a direction equal the page route's SHALL get no such line in that direction, and a page without member routes SHALL have none.

#### Scenario: Member differs in one stop

- **WHEN** on the latest covered day route 9001's direction 0 is 甲站、乙站、丙站、丁站、戊站 and member route 9050's direction 0 is 甲站、乙站、己站、丁站、戊站 with the same `stopLocationId` except at the third stop
- **THEN** direction 0 carries the line 測試幹線經己站（路線 Id 9050）在這個方向不停 丙站，改停 己站。 and direction 1 carries the line 測試幹線經己站（路線 Id 9050）在這個方向不停 丙站對面，改停 己站對面。

#### Scenario: No member routes

- **WHEN** route 10712 lists no member routes
- **THEN** no direction of its stop sequence block carries such a line

### Requirement: Data limitation of a page with member routes

When the page route lists member routes, the data limitations block SHALL add one item stating which route `Id`s the page counts as one route; that trips, run times, layovers, round trips, cycles and the rest estimate pool their vehicles; that the load chart, the MRT overlap and the stop sequence use the page route's stops, with the member routes' on-board counts pooled at the stops both serve and the stops only a member serves left out; and the number of trips of each route `Id` over the covered days. A page without member routes SHALL NOT show this item.

#### Scenario: Trip counts per Id

- **WHEN** the page of route 9001 with member route 9050 covers 2026-10-23, whose stored trips are one of 9001 and two of 9050
- **THEN** the data limitations block has an item that names 9001 and 9050 and contains 9001 1 趟、9050 2 趟

#### Scenario: Absent without member routes

- **WHEN** the page of route 10712 is shown
- **THEN** the data limitations block has no item about counting route `Id`s as one route
