## Purpose

The route shape is the line 臺北市公共運輸處 registers for each direction of a route in its static feed `GetBusShape.gz`. This capability stores it per route day and draws it on the route page, so that a reader who does not know the route sees which roads its buses take; it is the registered line, not measured GPS.

## ADDED Requirements

### Requirement: Route shape of a route day

When a day is loaded, the system SHALL read the route shapes file `GetBusShape.gz` of the day's static snapshot and keep, for the route `Id`, the rows whose `SubRouteID` is -1, at most one per direction: the direction, the points of its line in their original order as latitude and longitude rounded to 6 decimal places, and the update time the file gives the row (`utime`, Taipei time). A row SHALL be kept only when it gives an update time that can be read and its geometry is a `LINESTRING` of at least two points whose latitudes all lie between 20 and 27 and whose longitudes all lie between 118 and 123. When the snapshot has no route shapes file, or a direction has no row that can be kept, that direction SHALL have no shape for the day, the load SHALL print one line naming the route, the day, the direction and the reason, and every other part of the day SHALL load as before. When the file has more than one usable row for the same direction, the row with the latest update time SHALL be kept and the load SHALL print one line saying so. Rows of other routes and rows of the route whose `SubRouteID` is not -1 SHALL NOT be kept. Only `derived:load` SHALL read the route shapes file. `bin/health-card` SHALL NOT read it: its five inspection files SHALL NOT change, and its card SHALL change only in the first line of the attribution statement, which the card reproduces from docs/data-sources.md and which names GetBusShape.

#### Scenario: Fixture shapes stored

- **WHEN** the fixture day 2026-10-19 of route 9001 is loaded
- **THEN** two shapes are stored for that route day, one per direction, with the fixture's points and update times, and the rows for route 9100 and for route 9001's sub-route are not stored

##### Example: fixture route 9001

- **GIVEN** the fixture snapshot 2026-10-19 holds, for route 9001 with `SubRouteID` -1, direction 0 `LINESTRING (121.50000012345678 25.04999987654321, 121.5 25.0525, 121.5 25.055, 121.5 25.0575, 121.5 25.06)` updated `2023-12-29 09:46:21`, and direction 1 `LINESTRING (121.5003 25.06, 121.5003 25.0575, 121.5003 25.055, 121.5003 25.0525, 121.5003 25.05)` updated `2023-12-29 09:48:24`
- **WHEN** the day is loaded
- **THEN** direction 0 is stored with 5 points from (25.05, 121.5) to (25.06, 121.5) and the update time 2023-12-29 09:46:21 +08:00, and direction 1 with 5 points from (25.06, 121.5003) to (25.05, 121.5003) and the update time 2023-12-29 09:48:24 +08:00

#### Scenario: Shapes file missing

- **WHEN** the static snapshot of the loaded day has no `GetBusShape.gz`
- **THEN** the day is stored with its trips and layovers and without shapes, and the load prints a line naming the route, the day and the missing file

#### Scenario: Unusable rows left out

- **WHEN** one direction's row of the route cannot be kept
- **THEN** only the other direction's shape is stored, and the load prints a line naming the route, the day, the direction that has no shape and the reason

##### Example: rows that cannot be kept

| Direction 1 row | Stored directions | Reason in the printed line |
| --- | --- | --- |
| absent | 0 | no row for the direction |
| `MULTILINESTRING ((121.5003 25.06, 121.5003 25.05))` | 0 | not a `LINESTRING` |
| `LINESTRING (121.5003 25.06)` | 0 | fewer than two points |
| `LINESTRING (25.06 121.5003, 25.05 121.5003)` | 0 | coordinates outside the range, as when latitude and longitude are swapped |
| `LINESTRING (121.5003 25.06, 121.5003 25.05)` updated `unknown` | 0 | no update time that can be read |

#### Scenario: Health card reads no route shapes

- **WHEN** `bin/health-card` runs on the fixture day 2026-10-19 of route 9001
- **THEN** its five inspection files are the same as before this change, and its card differs only in the first line of the 資料來源與授權 section, which also names GetBusShape

### Requirement: Route map drawn from the latest day with a shape

The route map SHALL be built from the latest covered day that has at least one stored shape, whatever the order in which the covered days are given. It SHALL draw each stored direction of that route day as one line and SHALL mark, for each drawn direction, the first and the last stop of that same route day. It SHALL NOT draw any other stop, any vehicle position or track, any on-board count or any MRT mark. The map data SHALL be in the server response as JSON inside the map container, giving per drawn direction its direction and points, and per drawn direction the names and coordinates of its first and last stop; it SHALL NOT contain any plate number. Below the map, a line SHALL name only its data source, the route shapes of 臺北市公共運輸處, and the latest update date among the drawn directions. When no covered day has a stored shape, there SHALL be no map container, and a sentence SHALL state that the covered days have no route shape.

#### Scenario: Latest day with a shape

- **WHEN** the page covers two days and only the earlier one has stored shapes
- **THEN** the map uses the earlier day's shapes, and the line below the map names their latest update date and no snapshot day

##### Example: the later day without shapes

- **GIVEN** route 9001's covered days are 2026-10-19 and 2026-10-20, given oldest first; 2026-10-19 has both shapes with the static snapshot day 2026-10-19, and 2026-10-20 has none
- **WHEN** the page is rendered
- **THEN** the map data holds 2026-10-19's two lines, and the line below the map names the update date 2023-12-29 and not the snapshot day 2026-10-19

#### Scenario: Map data in the response

- **WHEN** the fixture day 2026-10-19 of route 9001 is shown
- **THEN** the map container holds JSON with two lines of 5 points each, direction 0's first stop 甲站 at (25.05, 121.5) and last stop 戊站 at (25.06, 121.5), direction 1's first stop 戊站對面 and last stop 甲站, and no plate number

#### Scenario: One direction only

- **WHEN** the route day used has a shape for direction 0 only
- **THEN** the map data holds one line and the first and last stop of direction 0 only

#### Scenario: No shape in the covered days

- **WHEN** no covered day has a stored shape
- **THEN** the page has no route map container and states that the covered days have no route shape, and the stop list renders as before

### Requirement: Route map loads on demand and falls back

The route map container SHALL behave as the end map containers do under `turnaround-map` "Map loads on demand and falls back": it SHALL be served with the state `pending`, hidden from assistive technology, holding the map data and a sentence saying the map needs the page's scripts or could not be loaded; the map library and the route map's drawing code SHALL be requested only once at least a quarter of the container is in the viewport; the state SHALL then be `loading`, and `ready` once the map is drawn, at which point the sentence is hidden; when the code cannot be loaded or drawing fails, the state SHALL be `static` and the sentence SHALL stay visible; before Turbo caches the page the container SHALL return to `pending` and release the map; when the visitor prefers reduced motion, zoom, fade and marker animations SHALL be off and the container SHALL say so in a data attribute. The stop sequence list SHALL be complete without the map. Pages without a route map container SHALL NOT request the route map's drawing code.

#### Scenario: Drawn when scrolled into view

- **WHEN** a route page whose covered days have shapes is scrolled until the route map container is at least a quarter visible
- **THEN** the container's state becomes `ready`, the map shows one line per stored direction and a marker for each first and last stop, and the sentence is hidden

#### Scenario: Drawing code blocked

- **WHEN** the route map's drawing code cannot be loaded and the container is scrolled into view
- **THEN** the container's state is `static`, the sentence is visible, and the stop list is complete

#### Scenario: Without scripts

- **WHEN** a route page whose covered days have shapes is fetched without running scripts
- **THEN** the route map container has the state `pending`, holds the sentence and the map data, and the stop list is complete

#### Scenario: Home page requests no route map code

- **WHEN** the home page is opened and scrolled to the end
- **THEN** neither the map library nor the route map's drawing code is requested
