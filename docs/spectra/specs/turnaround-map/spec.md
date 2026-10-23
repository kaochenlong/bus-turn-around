# turnaround-map Specification

## Purpose

Draw, for each end of a route, a map inside the turnaround facilities block from the derived tables alone: the standstill cells, the located position, the last stop and the next trip's first stop, and the public toilets within range, so that a reader sees where the buses actually stand and what is near. The page stays complete without the map, and no vehicle can be told apart on it.

## Requirements

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


<!-- @trace
source: turnaround-map
updated: 2026-10-24
code:
  - app/models/route_day_end_toilet.rb
  - app/components/attribution_component.html.erb
  - app/components/data_limitations_component.yml
  - app/views/routes/show.html.erb
  - analysis/params.sql
  - app/components/attribution_component.rb
  - analysis/derived_export.sql
  - app/components/section_nav_component.yml
  - output/branding-v2/a-bus/favicon-preview.png
  - app/components/home_hero_component.yml
  - output/branding-v2/a-bus/favicon.ico
  - app/components/turnaround_facilities_component.rb
  - .ruby-version
  - .kamal/secrets
  - app/components/attribution_component.yml
  - app/components/home_hero_component.html.erb
  - app/components/end_map_component.yml
  - public/turnaround/og-image-v2.jpg
  - app/components/end_map_component.rb
  - spec/support/duckdb.rb
  - app/assets/images/home-hero-wide.webp
  - app/components/section_nav_component.rb
  - app/models/route_day.rb
  - app/components/cycle_table_component.html.erb
  - config/environments/production.rb
  - app/models/route_page/facilities.rb
  - app/components/end_map_component.html.erb
  - config/map.yml
  - public/turnaround/icon-32.png
  - tools/hero/index.html
  - config/locales/en.yml
  - app/components/site_bar_component.html.erb
  - db/migrate/20261023190654_add_turnaround_facilities_to_derived_tables.rb
  - app/components/home_hero_component.rb
  - lib/tasks/external.rake
  - spec/factories/route_day_end_toilets.rb
  - app/models/map_tiles.rb
  - app/views/layouts/application.html.erb
  - app/frontend/hero/runtime.js
  - bin/health-card
  - app/frontend/stylesheets/application.css
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - app/assets/images/home-hero-narrow.webp
  - docs/data-sources.md
  - spec/fixtures/analysis/bus_data/2026-10-19/11.jsonl
  - public/turnaround/icon-16.png
  - app/components/turnaround_facilities_component.yml
  - app/assets/images/home-hero-tall.webp
  - app/assets/images/turnaround-logo.webp
  - public/turnaround/apple-touch-icon.png
  - output/branding-v2/a-bus/logo.png
  - config/deploy.yml
  - app/models/route_page/cycles.rb
  - app/models/route_page/end_map.rb
  - config/database.yml
  - spec/fixtures/analysis/bus_data/2026-10-19/12.jsonl
  - docs/decisions.md
  - package.json
  - spec/fixtures/analysis/README.md
  - spec/factories/route_day_end_cells.rb
  - app/components/cycle_table_component.yml
  - spec/factories/route_day_ends.rb
  - Dockerfile
  - analysis/turnaround_facilities.sql
  - config/credentials/production.yml.enc
  - spec/fixtures/analysis/bus_data/2026-10-19/07.jsonl
  - app/components/turnaround_facilities_component.html.erb
  - app/models/derived_load_command.rb
  - app/frontend/entrypoints/application.js
  - app/frontend/hero/scene.js
  - tools/hero/export.js
  - spec/fixtures/analysis/external/public-toilets/2026-10-19.csv
  - config/locales/tw.yml
  - app/models/route_day_end.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/08.jsonl
  - app/models/route_day_end_cell.rb
  - app/models/route_day_loader.rb
  - Gemfile.lock
  - app/frontend/end_map/runtime.js
  - app/models/public_toilets_snapshot.rb
  - public/turnaround/favicon.ico
  - Gemfile
  - db/schema.rb
  - analysis/README.md
  - app/components/cycle_table_component.rb
  - spec/factories/route_days.rb
tests:
  - spec/models/map_tiles_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/system/end_map_spec.rb
  - spec/models/route_page/cycles_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/cycle_table_component_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/models/route_page/facilities_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/models/route_page/end_map_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/assets/home_hero_images_spec.rb
  - spec/requests/routes_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/public_toilets_snapshot_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/components/home_hero_component_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/system/home_hero_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/analysis/fixtures_spec.rb
-->

---
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


<!-- @trace
source: turnaround-map
updated: 2026-10-24
code:
  - app/models/route_day_end_toilet.rb
  - app/components/attribution_component.html.erb
  - app/components/data_limitations_component.yml
  - app/views/routes/show.html.erb
  - analysis/params.sql
  - app/components/attribution_component.rb
  - analysis/derived_export.sql
  - app/components/section_nav_component.yml
  - output/branding-v2/a-bus/favicon-preview.png
  - app/components/home_hero_component.yml
  - output/branding-v2/a-bus/favicon.ico
  - app/components/turnaround_facilities_component.rb
  - .ruby-version
  - .kamal/secrets
  - app/components/attribution_component.yml
  - app/components/home_hero_component.html.erb
  - app/components/end_map_component.yml
  - public/turnaround/og-image-v2.jpg
  - app/components/end_map_component.rb
  - spec/support/duckdb.rb
  - app/assets/images/home-hero-wide.webp
  - app/components/section_nav_component.rb
  - app/models/route_day.rb
  - app/components/cycle_table_component.html.erb
  - config/environments/production.rb
  - app/models/route_page/facilities.rb
  - app/components/end_map_component.html.erb
  - config/map.yml
  - public/turnaround/icon-32.png
  - tools/hero/index.html
  - config/locales/en.yml
  - app/components/site_bar_component.html.erb
  - db/migrate/20261023190654_add_turnaround_facilities_to_derived_tables.rb
  - app/components/home_hero_component.rb
  - lib/tasks/external.rake
  - spec/factories/route_day_end_toilets.rb
  - app/models/map_tiles.rb
  - app/views/layouts/application.html.erb
  - app/frontend/hero/runtime.js
  - bin/health-card
  - app/frontend/stylesheets/application.css
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - app/assets/images/home-hero-narrow.webp
  - docs/data-sources.md
  - spec/fixtures/analysis/bus_data/2026-10-19/11.jsonl
  - public/turnaround/icon-16.png
  - app/components/turnaround_facilities_component.yml
  - app/assets/images/home-hero-tall.webp
  - app/assets/images/turnaround-logo.webp
  - public/turnaround/apple-touch-icon.png
  - output/branding-v2/a-bus/logo.png
  - config/deploy.yml
  - app/models/route_page/cycles.rb
  - app/models/route_page/end_map.rb
  - config/database.yml
  - spec/fixtures/analysis/bus_data/2026-10-19/12.jsonl
  - docs/decisions.md
  - package.json
  - spec/fixtures/analysis/README.md
  - spec/factories/route_day_end_cells.rb
  - app/components/cycle_table_component.yml
  - spec/factories/route_day_ends.rb
  - Dockerfile
  - analysis/turnaround_facilities.sql
  - config/credentials/production.yml.enc
  - spec/fixtures/analysis/bus_data/2026-10-19/07.jsonl
  - app/components/turnaround_facilities_component.html.erb
  - app/models/derived_load_command.rb
  - app/frontend/entrypoints/application.js
  - app/frontend/hero/scene.js
  - tools/hero/export.js
  - spec/fixtures/analysis/external/public-toilets/2026-10-19.csv
  - config/locales/tw.yml
  - app/models/route_day_end.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/08.jsonl
  - app/models/route_day_end_cell.rb
  - app/models/route_day_loader.rb
  - Gemfile.lock
  - app/frontend/end_map/runtime.js
  - app/models/public_toilets_snapshot.rb
  - public/turnaround/favicon.ico
  - Gemfile
  - db/schema.rb
  - analysis/README.md
  - app/components/cycle_table_component.rb
  - spec/factories/route_days.rb
tests:
  - spec/models/map_tiles_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/system/end_map_spec.rb
  - spec/models/route_page/cycles_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/cycle_table_component_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/models/route_page/facilities_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/models/route_page/end_map_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/assets/home_hero_images_spec.rb
  - spec/requests/routes_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/public_toilets_snapshot_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/components/home_hero_component_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/system/home_hero_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/analysis/fixtures_spec.rb
-->

---
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


<!-- @trace
source: turnaround-map
updated: 2026-10-24
code:
  - app/models/route_day_end_toilet.rb
  - app/components/attribution_component.html.erb
  - app/components/data_limitations_component.yml
  - app/views/routes/show.html.erb
  - analysis/params.sql
  - app/components/attribution_component.rb
  - analysis/derived_export.sql
  - app/components/section_nav_component.yml
  - output/branding-v2/a-bus/favicon-preview.png
  - app/components/home_hero_component.yml
  - output/branding-v2/a-bus/favicon.ico
  - app/components/turnaround_facilities_component.rb
  - .ruby-version
  - .kamal/secrets
  - app/components/attribution_component.yml
  - app/components/home_hero_component.html.erb
  - app/components/end_map_component.yml
  - public/turnaround/og-image-v2.jpg
  - app/components/end_map_component.rb
  - spec/support/duckdb.rb
  - app/assets/images/home-hero-wide.webp
  - app/components/section_nav_component.rb
  - app/models/route_day.rb
  - app/components/cycle_table_component.html.erb
  - config/environments/production.rb
  - app/models/route_page/facilities.rb
  - app/components/end_map_component.html.erb
  - config/map.yml
  - public/turnaround/icon-32.png
  - tools/hero/index.html
  - config/locales/en.yml
  - app/components/site_bar_component.html.erb
  - db/migrate/20261023190654_add_turnaround_facilities_to_derived_tables.rb
  - app/components/home_hero_component.rb
  - lib/tasks/external.rake
  - spec/factories/route_day_end_toilets.rb
  - app/models/map_tiles.rb
  - app/views/layouts/application.html.erb
  - app/frontend/hero/runtime.js
  - bin/health-card
  - app/frontend/stylesheets/application.css
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - app/assets/images/home-hero-narrow.webp
  - docs/data-sources.md
  - spec/fixtures/analysis/bus_data/2026-10-19/11.jsonl
  - public/turnaround/icon-16.png
  - app/components/turnaround_facilities_component.yml
  - app/assets/images/home-hero-tall.webp
  - app/assets/images/turnaround-logo.webp
  - public/turnaround/apple-touch-icon.png
  - output/branding-v2/a-bus/logo.png
  - config/deploy.yml
  - app/models/route_page/cycles.rb
  - app/models/route_page/end_map.rb
  - config/database.yml
  - spec/fixtures/analysis/bus_data/2026-10-19/12.jsonl
  - docs/decisions.md
  - package.json
  - spec/fixtures/analysis/README.md
  - spec/factories/route_day_end_cells.rb
  - app/components/cycle_table_component.yml
  - spec/factories/route_day_ends.rb
  - Dockerfile
  - analysis/turnaround_facilities.sql
  - config/credentials/production.yml.enc
  - spec/fixtures/analysis/bus_data/2026-10-19/07.jsonl
  - app/components/turnaround_facilities_component.html.erb
  - app/models/derived_load_command.rb
  - app/frontend/entrypoints/application.js
  - app/frontend/hero/scene.js
  - tools/hero/export.js
  - spec/fixtures/analysis/external/public-toilets/2026-10-19.csv
  - config/locales/tw.yml
  - app/models/route_day_end.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/08.jsonl
  - app/models/route_day_end_cell.rb
  - app/models/route_day_loader.rb
  - Gemfile.lock
  - app/frontend/end_map/runtime.js
  - app/models/public_toilets_snapshot.rb
  - public/turnaround/favicon.ico
  - Gemfile
  - db/schema.rb
  - analysis/README.md
  - app/components/cycle_table_component.rb
  - spec/factories/route_days.rb
tests:
  - spec/models/map_tiles_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/system/end_map_spec.rb
  - spec/models/route_page/cycles_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/cycle_table_component_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/models/route_page/facilities_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/models/route_page/end_map_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/assets/home_hero_images_spec.rb
  - spec/requests/routes_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/public_toilets_snapshot_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/components/home_hero_component_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/system/home_hero_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/analysis/fixtures_spec.rb
-->

---
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


<!-- @trace
source: turnaround-map
updated: 2026-10-24
code:
  - app/models/route_day_end_toilet.rb
  - app/components/attribution_component.html.erb
  - app/components/data_limitations_component.yml
  - app/views/routes/show.html.erb
  - analysis/params.sql
  - app/components/attribution_component.rb
  - analysis/derived_export.sql
  - app/components/section_nav_component.yml
  - output/branding-v2/a-bus/favicon-preview.png
  - app/components/home_hero_component.yml
  - output/branding-v2/a-bus/favicon.ico
  - app/components/turnaround_facilities_component.rb
  - .ruby-version
  - .kamal/secrets
  - app/components/attribution_component.yml
  - app/components/home_hero_component.html.erb
  - app/components/end_map_component.yml
  - public/turnaround/og-image-v2.jpg
  - app/components/end_map_component.rb
  - spec/support/duckdb.rb
  - app/assets/images/home-hero-wide.webp
  - app/components/section_nav_component.rb
  - app/models/route_day.rb
  - app/components/cycle_table_component.html.erb
  - config/environments/production.rb
  - app/models/route_page/facilities.rb
  - app/components/end_map_component.html.erb
  - config/map.yml
  - public/turnaround/icon-32.png
  - tools/hero/index.html
  - config/locales/en.yml
  - app/components/site_bar_component.html.erb
  - db/migrate/20261023190654_add_turnaround_facilities_to_derived_tables.rb
  - app/components/home_hero_component.rb
  - lib/tasks/external.rake
  - spec/factories/route_day_end_toilets.rb
  - app/models/map_tiles.rb
  - app/views/layouts/application.html.erb
  - app/frontend/hero/runtime.js
  - bin/health-card
  - app/frontend/stylesheets/application.css
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - app/assets/images/home-hero-narrow.webp
  - docs/data-sources.md
  - spec/fixtures/analysis/bus_data/2026-10-19/11.jsonl
  - public/turnaround/icon-16.png
  - app/components/turnaround_facilities_component.yml
  - app/assets/images/home-hero-tall.webp
  - app/assets/images/turnaround-logo.webp
  - public/turnaround/apple-touch-icon.png
  - output/branding-v2/a-bus/logo.png
  - config/deploy.yml
  - app/models/route_page/cycles.rb
  - app/models/route_page/end_map.rb
  - config/database.yml
  - spec/fixtures/analysis/bus_data/2026-10-19/12.jsonl
  - docs/decisions.md
  - package.json
  - spec/fixtures/analysis/README.md
  - spec/factories/route_day_end_cells.rb
  - app/components/cycle_table_component.yml
  - spec/factories/route_day_ends.rb
  - Dockerfile
  - analysis/turnaround_facilities.sql
  - config/credentials/production.yml.enc
  - spec/fixtures/analysis/bus_data/2026-10-19/07.jsonl
  - app/components/turnaround_facilities_component.html.erb
  - app/models/derived_load_command.rb
  - app/frontend/entrypoints/application.js
  - app/frontend/hero/scene.js
  - tools/hero/export.js
  - spec/fixtures/analysis/external/public-toilets/2026-10-19.csv
  - config/locales/tw.yml
  - app/models/route_day_end.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/08.jsonl
  - app/models/route_day_end_cell.rb
  - app/models/route_day_loader.rb
  - Gemfile.lock
  - app/frontend/end_map/runtime.js
  - app/models/public_toilets_snapshot.rb
  - public/turnaround/favicon.ico
  - Gemfile
  - db/schema.rb
  - analysis/README.md
  - app/components/cycle_table_component.rb
  - spec/factories/route_days.rb
tests:
  - spec/models/map_tiles_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/system/end_map_spec.rb
  - spec/models/route_page/cycles_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/cycle_table_component_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/models/route_page/facilities_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/models/route_page/end_map_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/assets/home_hero_images_spec.rb
  - spec/requests/routes_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/public_toilets_snapshot_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/components/home_hero_component_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/system/home_hero_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/analysis/fixtures_spec.rb
-->

---
### Requirement: Map budget

The chunk that carries the map library and the drawing code SHALL be at most 100 KB after brotli compression, measured on the built file, and SHALL be requested only on route pages and only after a map container is at least a quarter visible. The number and size of tiles each map requests when first drawn SHALL be measured and recorded in the change's design.

#### Scenario: Chunk size

- **WHEN** the frontend is built and the map chunk is compressed with brotli at quality 11
- **THEN** the result is at most 100 KB

##### Example: measured on the fixture page

- **GIVEN** the built chunk of `app/frontend/end_map/runtime.js`
- **WHEN** it is compressed with `brotli -q 11` and `gzip -9`
- **THEN** both sizes are recorded in the design's Risks and the brotli size is at most 100 KB

<!-- @trace
source: turnaround-map
updated: 2026-10-24
code:
  - app/models/route_day_end_toilet.rb
  - app/components/attribution_component.html.erb
  - app/components/data_limitations_component.yml
  - app/views/routes/show.html.erb
  - analysis/params.sql
  - app/components/attribution_component.rb
  - analysis/derived_export.sql
  - app/components/section_nav_component.yml
  - output/branding-v2/a-bus/favicon-preview.png
  - app/components/home_hero_component.yml
  - output/branding-v2/a-bus/favicon.ico
  - app/components/turnaround_facilities_component.rb
  - .ruby-version
  - .kamal/secrets
  - app/components/attribution_component.yml
  - app/components/home_hero_component.html.erb
  - app/components/end_map_component.yml
  - public/turnaround/og-image-v2.jpg
  - app/components/end_map_component.rb
  - spec/support/duckdb.rb
  - app/assets/images/home-hero-wide.webp
  - app/components/section_nav_component.rb
  - app/models/route_day.rb
  - app/components/cycle_table_component.html.erb
  - config/environments/production.rb
  - app/models/route_page/facilities.rb
  - app/components/end_map_component.html.erb
  - config/map.yml
  - public/turnaround/icon-32.png
  - tools/hero/index.html
  - config/locales/en.yml
  - app/components/site_bar_component.html.erb
  - db/migrate/20261023190654_add_turnaround_facilities_to_derived_tables.rb
  - app/components/home_hero_component.rb
  - lib/tasks/external.rake
  - spec/factories/route_day_end_toilets.rb
  - app/models/map_tiles.rb
  - app/views/layouts/application.html.erb
  - app/frontend/hero/runtime.js
  - bin/health-card
  - app/frontend/stylesheets/application.css
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - app/assets/images/home-hero-narrow.webp
  - docs/data-sources.md
  - spec/fixtures/analysis/bus_data/2026-10-19/11.jsonl
  - public/turnaround/icon-16.png
  - app/components/turnaround_facilities_component.yml
  - app/assets/images/home-hero-tall.webp
  - app/assets/images/turnaround-logo.webp
  - public/turnaround/apple-touch-icon.png
  - output/branding-v2/a-bus/logo.png
  - config/deploy.yml
  - app/models/route_page/cycles.rb
  - app/models/route_page/end_map.rb
  - config/database.yml
  - spec/fixtures/analysis/bus_data/2026-10-19/12.jsonl
  - docs/decisions.md
  - package.json
  - spec/fixtures/analysis/README.md
  - spec/factories/route_day_end_cells.rb
  - app/components/cycle_table_component.yml
  - spec/factories/route_day_ends.rb
  - Dockerfile
  - analysis/turnaround_facilities.sql
  - config/credentials/production.yml.enc
  - spec/fixtures/analysis/bus_data/2026-10-19/07.jsonl
  - app/components/turnaround_facilities_component.html.erb
  - app/models/derived_load_command.rb
  - app/frontend/entrypoints/application.js
  - app/frontend/hero/scene.js
  - tools/hero/export.js
  - spec/fixtures/analysis/external/public-toilets/2026-10-19.csv
  - config/locales/tw.yml
  - app/models/route_day_end.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/08.jsonl
  - app/models/route_day_end_cell.rb
  - app/models/route_day_loader.rb
  - Gemfile.lock
  - app/frontend/end_map/runtime.js
  - app/models/public_toilets_snapshot.rb
  - public/turnaround/favicon.ico
  - Gemfile
  - db/schema.rb
  - analysis/README.md
  - app/components/cycle_table_component.rb
  - spec/factories/route_days.rb
tests:
  - spec/models/map_tiles_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/system/end_map_spec.rb
  - spec/models/route_page/cycles_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/cycle_table_component_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/models/route_page/facilities_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/models/route_page/end_map_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/assets/home_hero_images_spec.rb
  - spec/requests/routes_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/public_toilets_snapshot_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/components/home_hero_component_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/system/home_hero_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/analysis/fixtures_spec.rb
-->