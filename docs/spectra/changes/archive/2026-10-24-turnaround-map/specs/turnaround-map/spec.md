## Purpose

Draw, for each end of a route, a map inside the turnaround facilities block from the derived tables alone: the standstill cells, the located position, the last stop and the next trip's first stop, and the public toilets within range, so that a reader sees where the buses actually stand and what is near. The page stays complete without the map, and no vehicle can be told apart on it.

## ADDED Requirements

### Requirement: Map data in the server response

For each end of a route whose covered days carry end rows as defined by `turnaround-facilities`, the route page response SHALL contain one JSON document for that end's map, computed on the server from the derived tables: the end's direction and nature; the last stop's name and coordinates from the latest covered day; the next trip's first stop, which is the first stop of the other direction on the latest covered day; the location of the latest covered day that carries one, with its source and day, or no location; the toilet places of that located day as defined by `turnaround-facilities`, each named after its nearest toilet with that toilet's category, metres and coordinates and the number of toilets at its address, sorted by metres and then by name; the standstill cells of all covered days with end rows, aggregated per cell corner by summing their standstill reports and counting the days each cell appears on, keeping only cells whose south-west corner lies within 1,000 metres of the last stop and counting the others; the cell size of 0.0002 degrees; and the coverage, which is the sum of the reports of the kept cells, the sum of the end's standstill-report counts over those days, and their ratio, or no ratio when that sum is 0. Vehicle counts of cells SHALL NOT be summed across days and SHALL NOT appear in the response. The response SHALL contain no vehicle identifier. When no covered day carries end rows, the page SHALL contain no map container.

#### Scenario: Cells summed across days

- **WHEN** the covered days are 2026-10-20 with a cell at 25.0604, 121.5002 of 25 reports and 2026-10-21 with the same cell of 15 reports and another cell at 25.0606, 121.5002 of 9 reports, and the end's standstill-report counts are 29 and 31
- **THEN** the map data lists the cell 25.0604, 121.5002 with 40 reports on 2 days and the cell 25.0606, 121.5002 with 9 reports on 1 day, and the coverage is 49 of 60, a ratio of 0.817

#### Scenario: Toilets grouped into places

- **WHEN** the located day of an end stores 戊站公園-男廁 at 251.7 metres and 戊站公園-女廁 at 253.3 metres at the same address, and 戊站加油站-混合廁所 at 451.9 metres at another address
- **THEN** the map data lists two places in that order: 戊站公園-男廁 with 2 toilets at its own coordinates, and 戊站加油站-混合廁所 with 1 toilet

#### Scenario: Cells beyond the extent are counted, not listed

- **WHEN** an end has four cells within 1,000 metres of its last stop and two cells 3,000 metres from it
- **THEN** the map data lists the four cells, states that 2 cells lie beyond the extent, and the coverage counts only the reports of the four

#### Scenario: Next first stop from the other direction

- **WHEN** direction 0 ends at 戊站 and direction 1 starts at 戊站對面
- **THEN** direction 0's map data names 戊站 as the last stop and 戊站對面 as the next trip's first stop

#### Scenario: No standstill report in the covered days

- **WHEN** an end's standstill-report counts over the covered days sum to 0
- **THEN** the map data has no cells and no coverage ratio, and still carries the last stop, the next first stop and, for a located end, the location and toilets

#### Scenario: Rows missing

- **WHEN** every covered day was loaded without end rows
- **THEN** the response contains no map container and no map data

### Requirement: Map drawn per end

When the map of an end is drawn, it SHALL show a basemap, each kept cell as a square of 0.0002 degrees whose south-west corner is the cell's corner, the last stop, the next trip's first stop, the location when its source is `standstill`, and each toilet place at the coordinates of its nearest toilet, with its name, category, metres and number of toilets available on hover or tap. Cells SHALL be shaded in four levels by their share of the largest kept cell's reports on that map: at most 0.25 is level 1, at most 0.5 level 2, at most 0.75 level 3, otherwise level 4; a legend SHALL show the four levels from few to many without numbers. The view SHALL fit the last stop, the next first stop, the location and the kept cells, at a zoom between 15 and the configured maximum. Below the map, outside the hidden map container, the page SHALL state the share of the covered days' standstill reports that the drawn cells cover, rounded to a whole percent, or that there were no standstill reports; when cells lie beyond the extent it SHALL state how many. The map SHALL NOT judge or colour anything by a threshold.

#### Scenario: Shading levels

- **WHEN** an end's kept cells have 40, 20, 11 and 9 reports
- **THEN** their levels are 4, 2, 2 and 1

##### Example: level edges

| Share of the largest cell | Level |
| --- | --- |
| 0.25 | 1 |
| 0.26 | 2 |
| 0.5 | 2 |
| 0.75 | 3 |
| 1.0 | 4 |

#### Scenario: Fixture end with one cell

- **WHEN** the fixture day 2026-10-19 of route 9001 is loaded with both ends configured as stopping ends and the page is drawn with scripts
- **THEN** direction 0's map shows one level-4 cell at 25.0604, 121.5002, the last stop 戊站, the next first stop 戊站對面, the location and two toilet places, and its coverage line says 86%; direction 1's map shows no cell, the last stop 甲站, the location at E and two toilet places, and its coverage line says 0%

#### Scenario: Pass-through end without a location marker

- **WHEN** an end's location source is `end_stop`
- **THEN** its map shows the last stop and no separate location marker

### Requirement: Map loads on demand and falls back

The map container SHALL be served with the state `pending`, hidden from assistive technology, holding the map data and a sentence saying the map needs the page's scripts or could not be loaded; the end's text and numbers above it SHALL be complete without the map. When scripts run, the map library SHALL be requested only once at least a quarter of the container is in the viewport; the state SHALL then be `loading`, and `ready` once the map is drawn, at which point the sentence is hidden. When the library cannot be loaded or drawing fails, the state SHALL be `static` and the sentence SHALL stay visible. Pages without a map container SHALL NOT request the map library. Before Turbo caches the page the container SHALL return to `pending` and release the map. When the visitor prefers reduced motion, zoom, fade and marker animations SHALL be off and the container SHALL say so in a data attribute.

#### Scenario: Drawn when scrolled into view

- **WHEN** a visitor whose browser runs scripts opens a stored day and scrolls until a map container is at least a quarter visible
- **THEN** the map library is requested, the container reaches the state `ready` and shows a map, and the sentence is hidden

#### Scenario: Not requested before it is visible

- **WHEN** a visitor opens a stored day and does not scroll to the facilities block
- **THEN** the map library has not been requested

#### Scenario: Without JavaScript

- **WHEN** the page of a stored day is fetched without running any script
- **THEN** each end's map container is in the state `pending`, contains the sentence and the map data, and the end's text and numbers are present

#### Scenario: Library blocked

- **WHEN** the browser blocks the request for the map library and the container scrolls into view
- **THEN** the container reaches the state `static` and the sentence stays visible, and the rest of the page is unchanged

#### Scenario: Home page requests no map library

- **WHEN** a visitor opens `/`
- **THEN** the map library is not requested

#### Scenario: Reduced motion

- **WHEN** a visitor who prefers reduced motion scrolls a map into view
- **THEN** the map is drawn with zoom, fade and marker animations off and the container carries `data-animations="off"`

### Requirement: Basemap configuration and attribution

The tile address template, its attribution text and the maximum zoom SHALL come from `config/map.yml`; the test environment SHALL use an embedded blank tile as a data URI so that tests never use the network. A missing key SHALL raise an error naming the key. The attribution text SHALL be shown on the map and as a line of the page footer's attribution, and the source and its licence SHALL be recorded in `docs/data-sources.md`. The production source SHALL be chosen by its terms before the map is built: the Taiwan e-Map WMTS of the National Land Surveying and Mapping Center when its terms are the Open Government Data License or require attribution only, otherwise the OpenStreetMap standard tiles under its tile usage policy.

#### Scenario: Blank tile in tests

- **WHEN** the test environment renders a map container
- **THEN** its tile address is a `data:image/png` URI and its attribution names the blank test basemap

#### Scenario: Missing key

- **WHEN** `config/map.yml` lacks the attribution of the current environment
- **THEN** reading the tiles configuration raises an error that names `attribution`

#### Scenario: Attribution shown twice

- **WHEN** a stored day is drawn with scripts
- **THEN** the map's attribution control and the page footer both contain the configured attribution text

### Requirement: Map budget

The chunk that carries the map library and the drawing code SHALL be at most 100 KB after brotli compression, measured on the built file, and SHALL be requested only on route pages and only after a map container is at least a quarter visible. The number and size of tiles each map requests when first drawn SHALL be measured and recorded in the change's design.

#### Scenario: Chunk size

- **WHEN** the frontend is built and the map chunk is compressed with brotli at quality 11
- **THEN** the result is at most 100 KB

##### Example: measured on the fixture page

- **GIVEN** the built chunk of `app/frontend/end_map/runtime.js`
- **WHEN** it is compressed with `brotli -q 11` and `gzip -9`
- **THEN** both sizes are recorded in the design's Risks and the brotli size is at most 100 KB
