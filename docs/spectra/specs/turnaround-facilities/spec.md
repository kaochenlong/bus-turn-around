# turnaround-facilities Specification

## Purpose

Locate each end of a route where buses actually stand still between trips, from the vehicles' GPS reports during measured layovers, and list the public toilets within walking range of that location, so a route page can say where the turnaround point is and what is near it. The toilets come from the national registry, so an end outside Taipei City is covered the same way as one inside it. The nature of each end stays a verified fact in configuration; only the location is derived. The standstill reports are also kept as coarse cells for a later map.

## Requirements

### Requirement: Public toilet snapshot

The system SHALL provide the rake task `external:public_toilets`, which downloads the national public toilet registry of data.gov.tw dataset 30794 through the 環境部 open data API address published on that dataset page, page by page: each request asks for CSV sorted by `number` ascending, with `limit` equal to the page size (1,000 unless a test replaces it) and `offset` starting at 0 and growing by the page size, until a page returns fewer rows than the page size. Every page SHALL be checked before the next one is requested: HTTP status 200, a valid UTF-8 body with any leading byte order mark removed, a header line that is exactly `county,areacode,village,number,name,address,administration,latitude,longitude,grade,type2,type,exec,diaper`, rows that parse as CSV into exactly 14 fields each, at most page-size rows, a non-empty `number` and `name` in every row, and a numeric `latitude` and `longitude` in every row. The assembled rows SHALL number at least one, their `number` values SHALL be strictly increasing in file order, and the number of pages SHALL NOT exceed the page limit (200 unless a test replaces it). Only when every check passes SHALL the task write the rows once, as CSV with the header on the first line, fields quoted by CSV rules, LF line ends and no byte order mark, to `external/public-toilets/<Taipei day>.csv` under the data root given by `TURNAROUND_DATA`, replacing a file of the same day, and report the number of rows written together with how many of them have `county` 63000 (臺北市) and 65000 (新北市). Otherwise the task SHALL print the reason naming the page, exit with a non-zero status, leave every existing snapshot unchanged and leave no partial file behind. The HTTP requests SHALL go through a replaceable fetcher so that tests never use the network.

#### Scenario: Pages assembled into one file

- **WHEN** the page size is 3, the fetcher returns for offset 0 the header and three rows with `county` 63000 and `number` A010000001 to A010000003, and for offset 3 the header and two rows with `county` 65000 and `number` F010000001 and F010000002, one of them with the address `新北市測試區乙路1號, 2樓`
- **THEN** the task requests exactly offsets 0 and 3, writes a file for today's Taipei day whose first line is the header, which holds the five rows in that order with LF line ends and no byte order mark, in which the address with the comma is quoted, and reports 5 rows, 3 in 臺北市 and 2 in 新北市

#### Scenario: Page of exactly the page size followed by an empty page

- **WHEN** the page size is 3, the first page holds three rows and the second page holds the header only
- **THEN** the task requests two pages, writes the three rows and reports 3 rows

#### Scenario: Unexpected page

- **WHEN** the second page returns status 500, or a body that is not valid UTF-8, or a header without `diaper`, or a row with 13 fields, or four rows on a page of size 3, or a row whose `number` is empty, or a row whose `name` is empty, or a row whose `latitude` is `north`, or the first page holds the header only
- **THEN** the task exits with a non-zero status, prints the reason naming the page, writes no file and leaves no `.partial` file

#### Scenario: Repeated or unordered rows

- **WHEN** the first row of the second page has a `number` that is not greater than the last `number` of the first page
- **THEN** the task exits with a non-zero status, says the pages are not in order, and writes no file

#### Scenario: Too many pages

- **WHEN** the page limit is 2 and every page returns page-size rows
- **THEN** the task stops after the second page, exits with a non-zero status, says there are too many pages, and writes no file


<!-- @trace
source: turnaround-facilities
updated: 2026-10-24
code:
  - app/components/cycle_table_component.yml
  - app/frontend/hero/scene.js
  - app/components/turnaround_facilities_component.html.erb
  - app/frontend/hero/runtime.js
  - spec/factories/route_day_ends.rb
  - app/components/section_nav_component.yml
  - spec/factories/route_days.rb
  - app/models/route_page/facilities.rb
  - app/models/public_toilets_snapshot.rb
  - output/branding-v2/a-bus/favicon.ico
  - app/models/route_day_end_toilet.rb
  - app/models/route_page/cycles.rb
  - app/components/turnaround_facilities_component.yml
  - spec/fixtures/analysis/bus_data/2026-10-19/11.jsonl
  - app/models/route_day_end_cell.rb
  - app/models/derived_load_command.rb
  - app/components/site_bar_component.html.erb
  - app/components/cycle_table_component.rb
  - analysis/README.md
  - app/components/attribution_component.yml
  - spec/fixtures/analysis/bus_data/2026-10-19/08.jsonl
  - analysis/derived_export.sql
  - config/environments/production.rb
  - app/frontend/end_map/runtime.js
  - spec/factories/route_day_end_toilets.rb
  - analysis/turnaround_facilities.sql
  - app/components/home_hero_component.yml
  - app/components/home_hero_component.rb
  - app/assets/images/home-hero-wide.webp
  - public/turnaround/icon-16.png
  - config/locales/tw.yml
  - app/assets/images/home-hero-narrow.webp
  - app/models/route_day.rb
  - app/components/section_nav_component.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/12.jsonl
  - Gemfile.lock
  - config/map.yml
  - spec/fixtures/analysis/external/public-toilets/2026-10-19.csv
  - config/database.yml
  - app/components/data_limitations_component.yml
  - app/components/end_map_component.html.erb
  - public/turnaround/og-image-v2.jpg
  - app/components/end_map_component.rb
  - db/schema.rb
  - tools/hero/export.js
  - .kamal/secrets
  - app/frontend/entrypoints/application.js
  - app/models/route_day_end.rb
  - public/turnaround/icon-32.png
  - config/locales/en.yml
  - app/frontend/stylesheets/application.css
  - docs/decisions.md
  - app/views/layouts/application.html.erb
  - .ruby-version
  - tools/hero/index.html
  - app/components/attribution_component.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - analysis/params.sql
  - public/turnaround/favicon.ico
  - app/models/route_page/end_map.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/07.jsonl
  - app/assets/images/home-hero-tall.webp
  - bin/health-card
  - Gemfile
  - app/components/cycle_table_component.html.erb
  - output/branding-v2/a-bus/favicon-preview.png
  - config/deploy.yml
  - package.json
  - app/components/home_hero_component.html.erb
  - app/components/attribution_component.html.erb
  - spec/factories/route_day_end_cells.rb
  - spec/fixtures/analysis/README.md
  - output/branding-v2/a-bus/logo.png
  - app/assets/images/turnaround-logo.webp
  - public/turnaround/apple-touch-icon.png
  - lib/tasks/external.rake
  - Dockerfile
  - spec/support/duckdb.rb
  - app/views/routes/show.html.erb
  - db/migrate/20261023190654_add_turnaround_facilities_to_derived_tables.rb
  - config/credentials/production.yml.enc
  - app/components/turnaround_facilities_component.rb
  - app/models/map_tiles.rb
  - docs/data-sources.md
  - app/components/end_map_component.yml
  - app/models/route_day_loader.rb
tests:
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/assets/home_hero_images_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/route_page/cycles_spec.rb
  - spec/models/map_tiles_spec.rb
  - spec/models/route_day_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/system/end_map_spec.rb
  - spec/components/home_hero_component_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/requests/routes_spec.rb
  - spec/components/cycle_table_component_spec.rb
  - spec/models/route_page/facilities_spec.rb
  - spec/models/route_page/end_map_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/models/public_toilets_snapshot_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/system/home_hero_spec.rb
-->

---
### Requirement: Standstill location of a stopping end

For each end of the route whose nature in the configuration defined by `turnaround-ends` is `stop`, the system SHALL compute a location per Taipei day from the day's layovers ending at that end as defined by `layover-metrics`: the standstill reports are the `bus_data` records of the layover's vehicle whose `DataTime` lies within the layover, from its end time to its next start time inclusive, whose `Speed` converted to a number equals 0, deduplicated on vehicle and `DataTime`, regardless of the record's `RouteID`. The standstill reports SHALL be gathered for the layovers ending at either end; the location of a stopping end uses those ending at that end. Reports with the same latitude and longitude form one standstill point carrying their count. The seed SHALL be the standstill point with the largest sum of counts of standstill points within 50 metres of it, itself included; ties SHALL be broken by the smaller latitude, then the smaller longitude. The location SHALL be the count-weighted mean of the latitude and longitude of the standstill points within 50 metres of the seed, rounded to six decimals. Distances SHALL be haversine distances with an earth radius of 6,371,000 metres, in metres rounded to one decimal. The system SHALL record with the location the number of layovers ending at that end that day, the number of them with at least one standstill report within 150 metres of the location, the total number of standstill reports, and the distance from the location to the direction's last stop, and SHALL mark the location's source as `standstill`. A day without any standstill report at that end SHALL carry no location and no source for that end, with the number of layovers still recorded. The radii 50 and 150 metres SHALL be defined once in `analysis/params.sql`.

#### Scenario: Densest standstill point wins

- **WHEN** one layover has twelve speed-0 reports at coordinate A, three speed-0 reports at coordinate B 20 metres from A, four speed-0 reports at coordinate C 600 metres from A, and six reports at coordinate D 10 metres from A with speed 15
- **THEN** the location is the count-weighted mean of A and B, the standstill reports number 19, and C and D do not move it

##### Example: weighted mean of two points

- **GIVEN** A at latitude 25.060400, longitude 121.500300 with 12 reports and B at latitude 25.060580, longitude 121.500300 with 3 reports
- **WHEN** the location is computed
- **THEN** its latitude is 25.060436 and its longitude is 121.500300

#### Scenario: Located layovers counted

- **WHEN** three layovers end at a stopping end, two of them have a speed-0 report within 150 metres of the location and the third has no `bus_data` record in its window
- **THEN** the end's day records 3 layovers, 2 located layovers, and the standstill reports of the first two

#### Scenario: No standstill report

- **WHEN** no `bus_data` record with speed 0 falls inside any layover window of a stopping end that day
- **THEN** that end's row for the day carries no latitude, longitude or source, records its number of layovers, and lists no toilets

#### Scenario: Tie broken by coordinates

- **WHEN** two standstill points each have a neighbourhood sum of 8 and lie more than 50 metres apart, one at latitude 25.0500 and one at latitude 25.0510
- **THEN** the seed is the point at latitude 25.0500 and two runs over the same input write the same bytes


<!-- @trace
source: turnaround-facilities
updated: 2026-10-24
code:
  - app/components/cycle_table_component.yml
  - app/frontend/hero/scene.js
  - app/components/turnaround_facilities_component.html.erb
  - app/frontend/hero/runtime.js
  - spec/factories/route_day_ends.rb
  - app/components/section_nav_component.yml
  - spec/factories/route_days.rb
  - app/models/route_page/facilities.rb
  - app/models/public_toilets_snapshot.rb
  - output/branding-v2/a-bus/favicon.ico
  - app/models/route_day_end_toilet.rb
  - app/models/route_page/cycles.rb
  - app/components/turnaround_facilities_component.yml
  - spec/fixtures/analysis/bus_data/2026-10-19/11.jsonl
  - app/models/route_day_end_cell.rb
  - app/models/derived_load_command.rb
  - app/components/site_bar_component.html.erb
  - app/components/cycle_table_component.rb
  - analysis/README.md
  - app/components/attribution_component.yml
  - spec/fixtures/analysis/bus_data/2026-10-19/08.jsonl
  - analysis/derived_export.sql
  - config/environments/production.rb
  - app/frontend/end_map/runtime.js
  - spec/factories/route_day_end_toilets.rb
  - analysis/turnaround_facilities.sql
  - app/components/home_hero_component.yml
  - app/components/home_hero_component.rb
  - app/assets/images/home-hero-wide.webp
  - public/turnaround/icon-16.png
  - config/locales/tw.yml
  - app/assets/images/home-hero-narrow.webp
  - app/models/route_day.rb
  - app/components/section_nav_component.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/12.jsonl
  - Gemfile.lock
  - config/map.yml
  - spec/fixtures/analysis/external/public-toilets/2026-10-19.csv
  - config/database.yml
  - app/components/data_limitations_component.yml
  - app/components/end_map_component.html.erb
  - public/turnaround/og-image-v2.jpg
  - app/components/end_map_component.rb
  - db/schema.rb
  - tools/hero/export.js
  - .kamal/secrets
  - app/frontend/entrypoints/application.js
  - app/models/route_day_end.rb
  - public/turnaround/icon-32.png
  - config/locales/en.yml
  - app/frontend/stylesheets/application.css
  - docs/decisions.md
  - app/views/layouts/application.html.erb
  - .ruby-version
  - tools/hero/index.html
  - app/components/attribution_component.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - analysis/params.sql
  - public/turnaround/favicon.ico
  - app/models/route_page/end_map.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/07.jsonl
  - app/assets/images/home-hero-tall.webp
  - bin/health-card
  - Gemfile
  - app/components/cycle_table_component.html.erb
  - output/branding-v2/a-bus/favicon-preview.png
  - config/deploy.yml
  - package.json
  - app/components/home_hero_component.html.erb
  - app/components/attribution_component.html.erb
  - spec/factories/route_day_end_cells.rb
  - spec/fixtures/analysis/README.md
  - output/branding-v2/a-bus/logo.png
  - app/assets/images/turnaround-logo.webp
  - public/turnaround/apple-touch-icon.png
  - lib/tasks/external.rake
  - Dockerfile
  - spec/support/duckdb.rb
  - app/views/routes/show.html.erb
  - db/migrate/20261023190654_add_turnaround_facilities_to_derived_tables.rb
  - config/credentials/production.yml.enc
  - app/components/turnaround_facilities_component.rb
  - app/models/map_tiles.rb
  - docs/data-sources.md
  - app/components/end_map_component.yml
  - app/models/route_day_loader.rb
tests:
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/assets/home_hero_images_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/route_page/cycles_spec.rb
  - spec/models/map_tiles_spec.rb
  - spec/models/route_day_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/system/end_map_spec.rb
  - spec/components/home_hero_component_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/requests/routes_spec.rb
  - spec/components/cycle_table_component_spec.rb
  - spec/models/route_page/facilities_spec.rb
  - spec/models/route_page/end_map_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/models/public_toilets_snapshot_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/system/home_hero_spec.rb
-->

---
### Requirement: Location of a pass-through end

For each end of the route whose configured nature is `pass_through`, the system SHALL set the day's location to the latitude and longitude of the last stop (the largest sequence number) of the direction whose trips end there, mark its source as `end_stop`, record the number of layovers ending at that end and the total number of standstill reports of those layovers as defined in "Standstill location of a stopping end" (the denominator a later map needs for that end's cells), record 0 metres as the distance to the last stop, and record no located-layover count. Both ends of a configured route SHALL have one row per Taipei day regardless of their nature.

#### Scenario: Pass-through end anchored on the last stop

- **WHEN** direction 0 of a route is configured as `pass_through` and its last stop lies at latitude 25.06 and longitude 121.5
- **THEN** the day's row for direction 0 has that latitude and longitude, source `end_stop`, 0.0 metres to the last stop, an empty located-layover count, and the standstill-report count of the layovers ending in direction 0


<!-- @trace
source: turnaround-facilities
updated: 2026-10-24
code:
  - app/components/cycle_table_component.yml
  - app/frontend/hero/scene.js
  - app/components/turnaround_facilities_component.html.erb
  - app/frontend/hero/runtime.js
  - spec/factories/route_day_ends.rb
  - app/components/section_nav_component.yml
  - spec/factories/route_days.rb
  - app/models/route_page/facilities.rb
  - app/models/public_toilets_snapshot.rb
  - output/branding-v2/a-bus/favicon.ico
  - app/models/route_day_end_toilet.rb
  - app/models/route_page/cycles.rb
  - app/components/turnaround_facilities_component.yml
  - spec/fixtures/analysis/bus_data/2026-10-19/11.jsonl
  - app/models/route_day_end_cell.rb
  - app/models/derived_load_command.rb
  - app/components/site_bar_component.html.erb
  - app/components/cycle_table_component.rb
  - analysis/README.md
  - app/components/attribution_component.yml
  - spec/fixtures/analysis/bus_data/2026-10-19/08.jsonl
  - analysis/derived_export.sql
  - config/environments/production.rb
  - app/frontend/end_map/runtime.js
  - spec/factories/route_day_end_toilets.rb
  - analysis/turnaround_facilities.sql
  - app/components/home_hero_component.yml
  - app/components/home_hero_component.rb
  - app/assets/images/home-hero-wide.webp
  - public/turnaround/icon-16.png
  - config/locales/tw.yml
  - app/assets/images/home-hero-narrow.webp
  - app/models/route_day.rb
  - app/components/section_nav_component.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/12.jsonl
  - Gemfile.lock
  - config/map.yml
  - spec/fixtures/analysis/external/public-toilets/2026-10-19.csv
  - config/database.yml
  - app/components/data_limitations_component.yml
  - app/components/end_map_component.html.erb
  - public/turnaround/og-image-v2.jpg
  - app/components/end_map_component.rb
  - db/schema.rb
  - tools/hero/export.js
  - .kamal/secrets
  - app/frontend/entrypoints/application.js
  - app/models/route_day_end.rb
  - public/turnaround/icon-32.png
  - config/locales/en.yml
  - app/frontend/stylesheets/application.css
  - docs/decisions.md
  - app/views/layouts/application.html.erb
  - .ruby-version
  - tools/hero/index.html
  - app/components/attribution_component.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - analysis/params.sql
  - public/turnaround/favicon.ico
  - app/models/route_page/end_map.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/07.jsonl
  - app/assets/images/home-hero-tall.webp
  - bin/health-card
  - Gemfile
  - app/components/cycle_table_component.html.erb
  - output/branding-v2/a-bus/favicon-preview.png
  - config/deploy.yml
  - package.json
  - app/components/home_hero_component.html.erb
  - app/components/attribution_component.html.erb
  - spec/factories/route_day_end_cells.rb
  - spec/fixtures/analysis/README.md
  - output/branding-v2/a-bus/logo.png
  - app/assets/images/turnaround-logo.webp
  - public/turnaround/apple-touch-icon.png
  - lib/tasks/external.rake
  - Dockerfile
  - spec/support/duckdb.rb
  - app/views/routes/show.html.erb
  - db/migrate/20261023190654_add_turnaround_facilities_to_derived_tables.rb
  - config/credentials/production.yml.enc
  - app/components/turnaround_facilities_component.rb
  - app/models/map_tiles.rb
  - docs/data-sources.md
  - app/components/end_map_component.yml
  - app/models/route_day_loader.rb
tests:
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/assets/home_hero_images_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/route_page/cycles_spec.rb
  - spec/models/map_tiles_spec.rb
  - spec/models/route_day_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/system/end_map_spec.rb
  - spec/components/home_hero_component_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/requests/routes_spec.rb
  - spec/components/cycle_table_component_spec.rb
  - spec/models/route_page/facilities_spec.rb
  - spec/models/route_page/end_map_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/models/public_toilets_snapshot_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/system/home_hero_spec.rb
-->

---
### Requirement: Standstill cells of an end

For both ends of a configured route, regardless of their nature, the system SHALL aggregate the day's standstill reports of the layovers ending at that end, as defined in "Standstill location of a stopping end", into cells: a report's cell is its latitude and its longitude each divided by 0.0002 degrees, the quotient rounded to six decimals and then truncated to an integer, multiplied back by 0.0002 and written with four decimals, which is the cell's south-west corner. For each cell the system SHALL record the number of standstill reports, the number of distinct vehicles and the number of distinct layovers. A cell with fewer than 3 distinct vehicles SHALL NOT be exported or stored. The cell size and the vehicle threshold SHALL be defined once in `analysis/params.sql`. The cells SHALL be stored under the end's row of the day, and this capability SHALL NOT show them on the route page. An unconfigured route SHALL have no cells, as it has no end rows.

#### Scenario: Reports aggregated into cells

- **WHEN** vehicle X has 12 speed-0 reports at latitude 25.060400, longitude 121.500300 and 3 at latitude 25.060580, longitude 121.500300 during its layover, vehicle Y has 5 speed-0 reports at the first coordinate during its layover and vehicle Z has 5 there during its layover, all three layovers ending at the same end
- **THEN** one cell at latitude 25.0604, longitude 121.5002 is stored for that end with 25 reports, 3 vehicles and 3 layovers

#### Scenario: Cells of one or two vehicles are not stored

- **WHEN** a cell's standstill reports come from two vehicles only, however many reports there are
- **THEN** that cell is neither exported nor stored, while the end's standstill report count still includes those reports

#### Scenario: Pass-through end keeps its cells

- **WHEN** direction 0 of a route is configured as `pass_through` and three vehicles have speed-0 reports in the same cell during layovers ending in direction 0
- **THEN** that cell is stored for direction 0 even though the end's location is anchored on the last stop

##### Example: cell corners

| Latitude, longitude of the report | Cell latitude, longitude |
| --- | --- |
| 25.060400, 121.500300 | 25.0604, 121.5002 |
| 25.060580, 121.500300 | 25.0604, 121.5002 |
| 25.065800, 121.500300 | 25.0658, 121.5002 |
| 25.049700, 121.500600 | 25.0496, 121.5006 |


<!-- @trace
source: turnaround-facilities
updated: 2026-10-24
code:
  - app/components/cycle_table_component.yml
  - app/frontend/hero/scene.js
  - app/components/turnaround_facilities_component.html.erb
  - app/frontend/hero/runtime.js
  - spec/factories/route_day_ends.rb
  - app/components/section_nav_component.yml
  - spec/factories/route_days.rb
  - app/models/route_page/facilities.rb
  - app/models/public_toilets_snapshot.rb
  - output/branding-v2/a-bus/favicon.ico
  - app/models/route_day_end_toilet.rb
  - app/models/route_page/cycles.rb
  - app/components/turnaround_facilities_component.yml
  - spec/fixtures/analysis/bus_data/2026-10-19/11.jsonl
  - app/models/route_day_end_cell.rb
  - app/models/derived_load_command.rb
  - app/components/site_bar_component.html.erb
  - app/components/cycle_table_component.rb
  - analysis/README.md
  - app/components/attribution_component.yml
  - spec/fixtures/analysis/bus_data/2026-10-19/08.jsonl
  - analysis/derived_export.sql
  - config/environments/production.rb
  - app/frontend/end_map/runtime.js
  - spec/factories/route_day_end_toilets.rb
  - analysis/turnaround_facilities.sql
  - app/components/home_hero_component.yml
  - app/components/home_hero_component.rb
  - app/assets/images/home-hero-wide.webp
  - public/turnaround/icon-16.png
  - config/locales/tw.yml
  - app/assets/images/home-hero-narrow.webp
  - app/models/route_day.rb
  - app/components/section_nav_component.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/12.jsonl
  - Gemfile.lock
  - config/map.yml
  - spec/fixtures/analysis/external/public-toilets/2026-10-19.csv
  - config/database.yml
  - app/components/data_limitations_component.yml
  - app/components/end_map_component.html.erb
  - public/turnaround/og-image-v2.jpg
  - app/components/end_map_component.rb
  - db/schema.rb
  - tools/hero/export.js
  - .kamal/secrets
  - app/frontend/entrypoints/application.js
  - app/models/route_day_end.rb
  - public/turnaround/icon-32.png
  - config/locales/en.yml
  - app/frontend/stylesheets/application.css
  - docs/decisions.md
  - app/views/layouts/application.html.erb
  - .ruby-version
  - tools/hero/index.html
  - app/components/attribution_component.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - analysis/params.sql
  - public/turnaround/favicon.ico
  - app/models/route_page/end_map.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/07.jsonl
  - app/assets/images/home-hero-tall.webp
  - bin/health-card
  - Gemfile
  - app/components/cycle_table_component.html.erb
  - output/branding-v2/a-bus/favicon-preview.png
  - config/deploy.yml
  - package.json
  - app/components/home_hero_component.html.erb
  - app/components/attribution_component.html.erb
  - spec/factories/route_day_end_cells.rb
  - spec/fixtures/analysis/README.md
  - output/branding-v2/a-bus/logo.png
  - app/assets/images/turnaround-logo.webp
  - public/turnaround/apple-touch-icon.png
  - lib/tasks/external.rake
  - Dockerfile
  - spec/support/duckdb.rb
  - app/views/routes/show.html.erb
  - db/migrate/20261023190654_add_turnaround_facilities_to_derived_tables.rb
  - config/credentials/production.yml.enc
  - app/components/turnaround_facilities_component.rb
  - app/models/map_tiles.rb
  - docs/data-sources.md
  - app/components/end_map_component.yml
  - app/models/route_day_loader.rb
tests:
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/assets/home_hero_images_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/route_page/cycles_spec.rb
  - spec/models/map_tiles_spec.rb
  - spec/models/route_day_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/system/end_map_spec.rb
  - spec/components/home_hero_component_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/requests/routes_spec.rb
  - spec/components/cycle_table_component_spec.rb
  - spec/models/route_page/facilities_spec.rb
  - spec/models/route_page/end_map_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/models/public_toilets_snapshot_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/system/home_hero_spec.rb
-->

---
### Requirement: Toilets within the radius

For each end of a Taipei day that has a location, the system SHALL store every row of the snapshot whose haversine distance to the location is at most 500 metres, one stored row per snapshot row (a snapshot row is one toilet, not one place), with its `name`, its `type2` as the category, its `address`, latitude, longitude and distance in metres rounded to one decimal, sorted by distance and then by name. The radius SHALL be defined once in `analysis/params.sql`. When the route page reads the stored rows of an end, it SHALL group them into places by `address`, each row with an empty address forming a place of its own; a place's distance, name, category and coordinates SHALL be those of its nearest row, and the place SHALL carry its number of toilets. The page SHALL count the places within 300 metres as the main number and within 500 metres as the second, both applied when the page is read, SHALL name the nearest place by its nearest toilet with its category, distance and number of toilets, and SHALL list every place within 500 metres with the name of its nearest toilet, its category, address, distance and number of toilets, sorted by distance and then by name.

#### Scenario: Rooms stored, places counted

- **WHEN** the snapshot holds two toilets 250.0 and 251.0 metres from an end's location at the same address, one toilet 450.0 metres from it at another address and one 1,200 metres from it
- **THEN** three rows are stored for that end in the order 250.0, 251.0, 450.0, the page reports 1 place within 300 metres and 2 places within 500 metres, and the nearest place is named after the toilet at 250.0 metres with 2 toilets

#### Scenario: Toilets sorted by distance then name

- **WHEN** two stored toilets at different addresses are both 120.0 metres from the location, named 乙公廁 and 甲公廁
- **THEN** they are stored and listed in the order 乙公廁, 甲公廁

#### Scenario: Empty address counts as its own place

- **WHEN** two stored rows of an end have an empty address, 100.0 and 200.0 metres from the location
- **THEN** the page counts 2 places within 300 metres


<!-- @trace
source: turnaround-facilities
updated: 2026-10-24
code:
  - app/components/cycle_table_component.yml
  - app/frontend/hero/scene.js
  - app/components/turnaround_facilities_component.html.erb
  - app/frontend/hero/runtime.js
  - spec/factories/route_day_ends.rb
  - app/components/section_nav_component.yml
  - spec/factories/route_days.rb
  - app/models/route_page/facilities.rb
  - app/models/public_toilets_snapshot.rb
  - output/branding-v2/a-bus/favicon.ico
  - app/models/route_day_end_toilet.rb
  - app/models/route_page/cycles.rb
  - app/components/turnaround_facilities_component.yml
  - spec/fixtures/analysis/bus_data/2026-10-19/11.jsonl
  - app/models/route_day_end_cell.rb
  - app/models/derived_load_command.rb
  - app/components/site_bar_component.html.erb
  - app/components/cycle_table_component.rb
  - analysis/README.md
  - app/components/attribution_component.yml
  - spec/fixtures/analysis/bus_data/2026-10-19/08.jsonl
  - analysis/derived_export.sql
  - config/environments/production.rb
  - app/frontend/end_map/runtime.js
  - spec/factories/route_day_end_toilets.rb
  - analysis/turnaround_facilities.sql
  - app/components/home_hero_component.yml
  - app/components/home_hero_component.rb
  - app/assets/images/home-hero-wide.webp
  - public/turnaround/icon-16.png
  - config/locales/tw.yml
  - app/assets/images/home-hero-narrow.webp
  - app/models/route_day.rb
  - app/components/section_nav_component.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/12.jsonl
  - Gemfile.lock
  - config/map.yml
  - spec/fixtures/analysis/external/public-toilets/2026-10-19.csv
  - config/database.yml
  - app/components/data_limitations_component.yml
  - app/components/end_map_component.html.erb
  - public/turnaround/og-image-v2.jpg
  - app/components/end_map_component.rb
  - db/schema.rb
  - tools/hero/export.js
  - .kamal/secrets
  - app/frontend/entrypoints/application.js
  - app/models/route_day_end.rb
  - public/turnaround/icon-32.png
  - config/locales/en.yml
  - app/frontend/stylesheets/application.css
  - docs/decisions.md
  - app/views/layouts/application.html.erb
  - .ruby-version
  - tools/hero/index.html
  - app/components/attribution_component.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - analysis/params.sql
  - public/turnaround/favicon.ico
  - app/models/route_page/end_map.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/07.jsonl
  - app/assets/images/home-hero-tall.webp
  - bin/health-card
  - Gemfile
  - app/components/cycle_table_component.html.erb
  - output/branding-v2/a-bus/favicon-preview.png
  - config/deploy.yml
  - package.json
  - app/components/home_hero_component.html.erb
  - app/components/attribution_component.html.erb
  - spec/factories/route_day_end_cells.rb
  - spec/fixtures/analysis/README.md
  - output/branding-v2/a-bus/logo.png
  - app/assets/images/turnaround-logo.webp
  - public/turnaround/apple-touch-icon.png
  - lib/tasks/external.rake
  - Dockerfile
  - spec/support/duckdb.rb
  - app/views/routes/show.html.erb
  - db/migrate/20261023190654_add_turnaround_facilities_to_derived_tables.rb
  - config/credentials/production.yml.enc
  - app/components/turnaround_facilities_component.rb
  - app/models/map_tiles.rb
  - docs/data-sources.md
  - app/components/end_map_component.yml
  - app/models/route_day_loader.rb
tests:
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/assets/home_hero_images_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/route_page/cycles_spec.rb
  - spec/models/map_tiles_spec.rb
  - spec/models/route_day_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/system/end_map_spec.rb
  - spec/components/home_hero_component_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/requests/routes_spec.rb
  - spec/components/cycle_table_component_spec.rb
  - spec/models/route_page/facilities_spec.rb
  - spec/models/route_page/end_map_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/models/public_toilets_snapshot_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/system/home_hero_spec.rb
-->

---
### Requirement: Ends of an unconfigured route

When the route being loaded is not in the route list configuration defined by `turnaround-ends`, the system SHALL load the day without any end rows and without any toilet rows, SHALL report in the load output that the route has no configured ends, and SHALL NOT assume a nature for either end. A route that is in the configuration but whose ends are incomplete or carry an unknown value SHALL fail the day with the configuration error of `turnaround-ends`.

#### Scenario: Unconfigured route loads without ends

- **WHEN** a route absent from the configuration is loaded for a day
- **THEN** the day's trips, layovers, stops and counts are written as before, no end row and no toilet row is written, and the output says the route has no configured ends

#### Scenario: Incomplete configuration fails the day

- **WHEN** the configuration lists the route with only direction 0
- **THEN** the day fails with the configuration error naming the route and the missing direction, and nothing is written for it


<!-- @trace
source: turnaround-facilities
updated: 2026-10-24
code:
  - app/components/cycle_table_component.yml
  - app/frontend/hero/scene.js
  - app/components/turnaround_facilities_component.html.erb
  - app/frontend/hero/runtime.js
  - spec/factories/route_day_ends.rb
  - app/components/section_nav_component.yml
  - spec/factories/route_days.rb
  - app/models/route_page/facilities.rb
  - app/models/public_toilets_snapshot.rb
  - output/branding-v2/a-bus/favicon.ico
  - app/models/route_day_end_toilet.rb
  - app/models/route_page/cycles.rb
  - app/components/turnaround_facilities_component.yml
  - spec/fixtures/analysis/bus_data/2026-10-19/11.jsonl
  - app/models/route_day_end_cell.rb
  - app/models/derived_load_command.rb
  - app/components/site_bar_component.html.erb
  - app/components/cycle_table_component.rb
  - analysis/README.md
  - app/components/attribution_component.yml
  - spec/fixtures/analysis/bus_data/2026-10-19/08.jsonl
  - analysis/derived_export.sql
  - config/environments/production.rb
  - app/frontend/end_map/runtime.js
  - spec/factories/route_day_end_toilets.rb
  - analysis/turnaround_facilities.sql
  - app/components/home_hero_component.yml
  - app/components/home_hero_component.rb
  - app/assets/images/home-hero-wide.webp
  - public/turnaround/icon-16.png
  - config/locales/tw.yml
  - app/assets/images/home-hero-narrow.webp
  - app/models/route_day.rb
  - app/components/section_nav_component.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/12.jsonl
  - Gemfile.lock
  - config/map.yml
  - spec/fixtures/analysis/external/public-toilets/2026-10-19.csv
  - config/database.yml
  - app/components/data_limitations_component.yml
  - app/components/end_map_component.html.erb
  - public/turnaround/og-image-v2.jpg
  - app/components/end_map_component.rb
  - db/schema.rb
  - tools/hero/export.js
  - .kamal/secrets
  - app/frontend/entrypoints/application.js
  - app/models/route_day_end.rb
  - public/turnaround/icon-32.png
  - config/locales/en.yml
  - app/frontend/stylesheets/application.css
  - docs/decisions.md
  - app/views/layouts/application.html.erb
  - .ruby-version
  - tools/hero/index.html
  - app/components/attribution_component.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - analysis/params.sql
  - public/turnaround/favicon.ico
  - app/models/route_page/end_map.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/07.jsonl
  - app/assets/images/home-hero-tall.webp
  - bin/health-card
  - Gemfile
  - app/components/cycle_table_component.html.erb
  - output/branding-v2/a-bus/favicon-preview.png
  - config/deploy.yml
  - package.json
  - app/components/home_hero_component.html.erb
  - app/components/attribution_component.html.erb
  - spec/factories/route_day_end_cells.rb
  - spec/fixtures/analysis/README.md
  - output/branding-v2/a-bus/logo.png
  - app/assets/images/turnaround-logo.webp
  - public/turnaround/apple-touch-icon.png
  - lib/tasks/external.rake
  - Dockerfile
  - spec/support/duckdb.rb
  - app/views/routes/show.html.erb
  - db/migrate/20261023190654_add_turnaround_facilities_to_derived_tables.rb
  - config/credentials/production.yml.enc
  - app/components/turnaround_facilities_component.rb
  - app/models/map_tiles.rb
  - docs/data-sources.md
  - app/components/end_map_component.yml
  - app/models/route_day_loader.rb
tests:
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/assets/home_hero_images_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/route_page/cycles_spec.rb
  - spec/models/map_tiles_spec.rb
  - spec/models/route_day_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/system/end_map_spec.rb
  - spec/components/home_hero_component_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/requests/routes_spec.rb
  - spec/components/cycle_table_component_spec.rb
  - spec/models/route_page/facilities_spec.rb
  - spec/models/route_page/end_map_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/models/public_toilets_snapshot_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/system/home_hero_spec.rb
-->

---
### Requirement: Location shown from the latest located day

For each end, the route page SHALL use the row of the latest covered day that carries a location, name that day and the day of the toilet snapshot that day was loaded with, and state how many covered days have no location for that end. When no covered day carries a location for a stopping end, the page SHALL say the location could not be measured, show the number of layovers of the latest covered day, and show no toilets for that end. When no covered day carries any end row, the page SHALL say the days need to be loaded again instead of showing locations. The page SHALL show the nature of each end as defined by `turnaround-ends`, the location source, the three check numbers of a standstill location, the place counts, the nearest place and the places within 500 metres as defined in "Toilets within the radius", and SHALL NOT judge whether the toilets are enough or mark any threshold.

#### Scenario: Latest located day chosen

- **WHEN** the page covers 2026-10-19, 2026-10-20 and 2026-10-21, direction 1 has a location on 2026-10-19 and 2026-10-20 and none on 2026-10-21
- **THEN** direction 1 shows the location and toilets of 2026-10-20, names 2026-10-20 and the toilet snapshot day of 2026-10-20, and states that 1 covered day has no location

##### Example: snapshot day of the located day

- **GIVEN** 2026-10-19 and 2026-10-20 were loaded with the toilet snapshot of 2026-10-15 and 2026-10-21 with that of 2026-10-21, direction 1 has a location on 2026-10-19 and 2026-10-20 only, and direction 0 on all three days
- **WHEN** the page covers the three days
- **THEN** direction 1 names the toilet snapshot day 2026-10-15 and direction 0 names 2026-10-21

#### Scenario: Stopping end never located

- **WHEN** none of the covered days carries a location for a stopping end
- **THEN** that end says the location could not be measured, shows the number of layovers of the latest covered day, no toilets and no toilet snapshot day, and the other end is shown as usual

#### Scenario: Rows missing

- **WHEN** every covered day was loaded before end rows existed or while the route was unconfigured
- **THEN** the block asks for the days to be loaded again and shows no location

<!-- @trace
source: turnaround-facilities
updated: 2026-10-24
code:
  - app/components/cycle_table_component.yml
  - app/frontend/hero/scene.js
  - app/components/turnaround_facilities_component.html.erb
  - app/frontend/hero/runtime.js
  - spec/factories/route_day_ends.rb
  - app/components/section_nav_component.yml
  - spec/factories/route_days.rb
  - app/models/route_page/facilities.rb
  - app/models/public_toilets_snapshot.rb
  - output/branding-v2/a-bus/favicon.ico
  - app/models/route_day_end_toilet.rb
  - app/models/route_page/cycles.rb
  - app/components/turnaround_facilities_component.yml
  - spec/fixtures/analysis/bus_data/2026-10-19/11.jsonl
  - app/models/route_day_end_cell.rb
  - app/models/derived_load_command.rb
  - app/components/site_bar_component.html.erb
  - app/components/cycle_table_component.rb
  - analysis/README.md
  - app/components/attribution_component.yml
  - spec/fixtures/analysis/bus_data/2026-10-19/08.jsonl
  - analysis/derived_export.sql
  - config/environments/production.rb
  - app/frontend/end_map/runtime.js
  - spec/factories/route_day_end_toilets.rb
  - analysis/turnaround_facilities.sql
  - app/components/home_hero_component.yml
  - app/components/home_hero_component.rb
  - app/assets/images/home-hero-wide.webp
  - public/turnaround/icon-16.png
  - config/locales/tw.yml
  - app/assets/images/home-hero-narrow.webp
  - app/models/route_day.rb
  - app/components/section_nav_component.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/12.jsonl
  - Gemfile.lock
  - config/map.yml
  - spec/fixtures/analysis/external/public-toilets/2026-10-19.csv
  - config/database.yml
  - app/components/data_limitations_component.yml
  - app/components/end_map_component.html.erb
  - public/turnaround/og-image-v2.jpg
  - app/components/end_map_component.rb
  - db/schema.rb
  - tools/hero/export.js
  - .kamal/secrets
  - app/frontend/entrypoints/application.js
  - app/models/route_day_end.rb
  - public/turnaround/icon-32.png
  - config/locales/en.yml
  - app/frontend/stylesheets/application.css
  - docs/decisions.md
  - app/views/layouts/application.html.erb
  - .ruby-version
  - tools/hero/index.html
  - app/components/attribution_component.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - analysis/params.sql
  - public/turnaround/favicon.ico
  - app/models/route_page/end_map.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/07.jsonl
  - app/assets/images/home-hero-tall.webp
  - bin/health-card
  - Gemfile
  - app/components/cycle_table_component.html.erb
  - output/branding-v2/a-bus/favicon-preview.png
  - config/deploy.yml
  - package.json
  - app/components/home_hero_component.html.erb
  - app/components/attribution_component.html.erb
  - spec/factories/route_day_end_cells.rb
  - spec/fixtures/analysis/README.md
  - output/branding-v2/a-bus/logo.png
  - app/assets/images/turnaround-logo.webp
  - public/turnaround/apple-touch-icon.png
  - lib/tasks/external.rake
  - Dockerfile
  - spec/support/duckdb.rb
  - app/views/routes/show.html.erb
  - db/migrate/20261023190654_add_turnaround_facilities_to_derived_tables.rb
  - config/credentials/production.yml.enc
  - app/components/turnaround_facilities_component.rb
  - app/models/map_tiles.rb
  - docs/data-sources.md
  - app/components/end_map_component.yml
  - app/models/route_day_loader.rb
tests:
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/assets/home_hero_images_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/route_page/cycles_spec.rb
  - spec/models/map_tiles_spec.rb
  - spec/models/route_day_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/system/end_map_spec.rb
  - spec/components/home_hero_component_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/requests/routes_spec.rb
  - spec/components/cycle_table_component_spec.rb
  - spec/models/route_page/facilities_spec.rb
  - spec/models/route_page/end_map_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/models/public_toilets_snapshot_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/system/home_hero_spec.rb
-->

---
### Requirement: Depots of the day's vehicles

For each route day the system SHALL record the depots of the vehicles that ran the route that day: each trip's depot SHALL be the `StationID` that occurs most often among the trip's `bus_event` records, the smaller `StationID` on a tie, and for each depot the system SHALL store the number of distinct vehicles and the number of trips. The depot's operator name and station name SHALL come from the row of the day's `GetProvider.gz` whose `stationId` equals it (`nameZn` and `stationNameZn`); when the day's static snapshot has no `GetProvider.gz`, the rows SHALL still be stored with empty names and the load SHALL print one line saying the day's depots have no names.

#### Scenario: One depot on the fixture day

- **WHEN** route 9001 is loaded for 2026-10-19, every event of TEST-0001 to TEST-0004 carrying `StationID` 19001, and `GetProvider.gz` lists `stationId` 19001 as 測試客運 測試站
- **THEN** the route day has one depot row: 測試客運, 測試站, 4 vehicles and as many trips as the day has

#### Scenario: Snapshot without GetProvider.gz

- **WHEN** the day's static snapshot has no `GetProvider.gz`
- **THEN** the depot rows are stored with empty operator and station names and the load prints one line about the missing names

#### Scenario: Majority vote per trip

- **WHEN** a trip has five events with `StationID` 19001 and one with `StationID` 19002
- **THEN** the trip counts under depot 19001


<!-- @trace
source: 03-depot-inspection-scores
updated: 2026-10-24
code:
  - db/migrate/20261024050200_backfill_route_id_on_derived_rows.rb
  - spec/factories/route_day_end_toilets.rb
  - app/frontend/entrypoints/application.js
  - app/components/data_limitations_component.rb
  - db/migrate/20261024050300_require_route_id_on_derived_rows.rb
  - app/models/route_page/depot_inspections.rb
  - app/components/buffer_trade_component.yml
  - app/components/stop_sequence_component.yml
  - docs/data-sources.md
  - docs/background.md
  - config/route_page.yml
  - spec/support/duckdb.rb
  - README.md
  - app/models/route_page/mrt_overlap.rb
  - app/views/routes/show.html.erb
  - spec/factories/route_day_ends.rb
  - spec/fixtures/analysis/bus_event/2026-10-23/09.jsonl
  - lib/tasks/external.rake
  - spec/fixtures/analysis/bus_data/2026-10-23/07.jsonl
  - analysis/10_load.sql
  - app/models/route_page/summary.rb
  - analysis/derived_export.sql
  - analysis/route_shape.sql
  - app/components/route_map_component.html.erb
  - db/migrate/20261024062215_create_route_day_depots.rb
  - spec/fixtures/analysis/bus_event/2026-10-23/08.jsonl
  - spec/fixtures/analysis/README.md
  - spec/fixtures/analysis/static/2026-10-19/GetStop.gz
  - app/models/derived_load_command.rb
  - analysis/50_quality.sql
  - app/components/route_list_component.rb
  - analysis/README.md
  - spec/fixtures/analysis/bus_event/2026-10-23/07.jsonl
  - app/models/route_day_loader.rb
  - db/schema.rb
  - app/components/end_map_component.html.erb
  - spec/factories/route_days.rb
  - spec/fixtures/analysis/static/2026-10-19/GetProvider.gz
  - spec/fixtures/analysis/bus_seat_event/2026-10-23/07.jsonl
  - app/models/tdx_s2s_travel_time_snapshot.rb
  - app/components/route_map_component.rb
  - analysis/turnaround_facilities.sql
  - analysis/60_export.sql
  - app/components/attribution_component.html.erb
  - app/components/route_list_component.html.erb
  - app/frontend/end_map/runtime.js
  - spec/fixtures/analysis/static/2026-10-23/GetRoute.gz
  - app/models/route_page/route_shape.rb
  - app/frontend/route_map/runtime.js
  - config/locales/en.yml
  - app/models/route_day_stop.rb
  - app/components/turnaround_facilities_component.yml
  - spec/fixtures/analysis/static/2026-10-23/GetProvider.gz
  - bin/health-card
  - app/components/buffer_trade_component.html.erb
  - spec/factories/route_day_shapes.rb
  - spec/fixtures/analysis/static/2026-10-23/GetStop.gz
  - app/models/route_day.rb
  - spec/fixtures/analysis/static/2026-10-23/GetPathDetail.gz
  - app/components/data_limitations_component.html.erb
  - analysis/params.sql
  - config/locales/tw.yml
  - app/components/stop_sequence_component.rb
  - analysis/depots.sql
  - app/models/route_page/depots.rb
  - app/components/route_coverage_component.rb
  - config/depot_inspections.yml
  - app/models/route_page/stop_sequence.rb
  - analysis/40_load_profile.sql
  - spec/fixtures/analysis/static/2026-10-19/GetBusShape.gz
  - app/components/stop_sequence_component.html.erb
  - app/models/route_page.rb
  - app/models/route_page/layover_stats.rb
  - lib/analysis_run.rb
  - app/components/route_coverage_component.html.erb
  - app/components/application_component.rb
  - app/components/data_limitations_component.yml
  - app/frontend/stylesheets/application.css
  - app/frontend/maps/base_map.js
  - spec/fixtures/analysis/bus_seat_event/2026-10-23/08.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-23/09.jsonl
  - analysis/mrt_overlap.sql
  - app/models/route_page/load_profile.rb
  - spec/factories/route_day_end_cells.rb
  - db/migrate/20261024050100_add_member_route_columns_to_derived_tables.rb
  - app/models/route_day_shape.rb
  - app/models/trip.rb
  - spec/fixtures/analysis/bus_event/2026-10-24/01.jsonl
  - app/models/route_day_depot.rb
  - spec/fixtures/analysis/static/2026-10-23/GetBusShape.gz
  - app/components/attribution_component.yml
  - app/components/route_map_component.yml
  - docs/decisions.md
  - app/components/turnaround_facilities_component.html.erb
  - db/migrate/20261024035750_create_route_day_shapes.rb
  - app/components/turnaround_facilities_component.rb
  - app/models/pto_assessment_snapshot.rb
  - spec/fixtures/analysis/static/2026-10-19/GetPathDetail.gz
  - spec/fixtures/analysis/static/2026-10-19/GetRoute.gz
  - spec/factories/route_day_depots.rb
tests:
  - spec/analysis/params_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/requests/routes_spec.rb
  - spec/components/route_map_component_spec.rb
  - spec/analysis/layovers_spec.rb
  - spec/analysis/load_spec.rb
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/migrations/member_route_columns_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/route_page/summary_spec.rb
  - spec/models/route_page/depot_inspections_spec.rb
  - spec/components/data_limitations_component_spec.rb
  - spec/models/route_page/depots_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/analysis/mrt_overlap_spec.rb
  - spec/system/route_map_spec.rb
  - spec/components/stop_sequence_component_spec.rb
  - spec/analysis/quality_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/profile_spec.rb
  - spec/components/attribution_component_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/analysis/trips_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/analysis/card_spec.rb
  - spec/components/route_list_component_spec.rb
  - spec/models/route_page/ends_spec.rb
  - spec/models/route_page/stop_sequence_spec.rb
  - spec/requests/pages_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/analysis/depots_spec.rb
  - spec/components/route_coverage_component_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_page/route_shape_spec.rb
  - spec/models/tdx_s2s_travel_time_snapshot_spec.rb
  - spec/models/pto_assessment_snapshot_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/system/end_map_spec.rb
  - spec/analysis/analysis_run_spec.rb
  - spec/analysis/route_shape_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/requests/site_layout_spec.rb
-->

---
### Requirement: Depot inspection scores on the page

The turnaround facilities block SHALL show, after the two ends, a part listing the depots of the latest covered day in descending order of vehicles, each with its operator name, station name, number of vehicles and number of trips, or with 營業站 Id and the `StationID` when the names are empty. The part SHALL open with a sentence stating that a depot is the station the vehicles belong to and drivers report at, not necessarily the turnaround point, and that the scores are what 臺北市公共運輸處 recorded when it inspected the station for the 115年第1期 evaluation, copied from the report's appendix. For a depot listed with scores in `config/depot_inspections.yml`, the part SHALL show the nine configured items with both printed columns, written once when the two columns are equal and as 「a／b」 when they differ, together with the printed inspection date, the printed appendix page and a link to the report's announcement page. For a depot listed under `not_in_appendix` the part SHALL state that it is not in the inspection list of that term. For a depot in neither list the part SHALL state that it has not been checked against the list. The part SHALL NOT colour, rank or judge any score. When no covered day has depot rows the part SHALL say the days need to be loaded again.

#### Scenario: Depot with scores

- **WHEN** the latest covered day has the depot 測試客運 測試站 with 4 vehicles and 7 trips, and the test configuration lists it with 調度室環境 `[8, 9]`, 休憩室空間及環境 `[7, 7]`, 休憩室設施 `[6, 6]`, 盥洗室環境 `[5, 4]`, 禁菸環境 `[5, 5]`, 停車場使用情形 `[5, 5]`, 男女專用廁所或性別友善廁所 `[2, 2]`, 男女性專用休息室 `[2, 2]`, 總分 `[98, 97]`, inspected on 12月2日 at page A-99
- **THEN** the part shows 測試客運 測試站・4 輛・7 趟, the score of 調度室環境 as 8／9, of 休憩室空間及環境 as 7, of 盥洗室環境 as 5／4, of 總分 as 98／97, the words 檢查日期 12月2日 and 附錄 A-99, and a link to the announcement page

#### Scenario: Depot not in the appendix

- **WHEN** the latest covered day has the depot 測試客運 測試二站 and the test configuration lists it under `not_in_appendix`
- **THEN** the part shows that 測試二站 is not in the inspection list of 115 年第 1 期, with no scores

#### Scenario: Depot not yet checked

- **WHEN** the latest covered day has the depot 測試客運 測試三站, which the configuration mentions nowhere
- **THEN** the part shows that 測試三站 has not been checked against the inspection list

##### Example: three depots on one day

| Depot row of the latest day | In `depots` | In `not_in_appendix` | Status shown |
| --- | --- | --- | --- |
| 測試客運 測試站, 4 vehicles | yes | no | nine scores, 檢查日期 12月2日, 附錄 A-99 |
| 測試客運 測試二站, 2 vehicles | no | yes | 不在 115 年第 1 期的查核名單 |
| 測試客運 測試三站, 1 vehicle | no | no | 這個調度站還沒對過查核名單 |

#### Scenario: Names missing

- **WHEN** a depot row has `station_id` 19005 and empty names
- **THEN** the part names it 營業站 Id 19005

#### Scenario: Days loaded before depots existed

- **WHEN** no covered day has depot rows
- **THEN** the part says the days need to be loaded again, as the toilets part does

##### Example: a day stored before the table existed

- **GIVEN** route 9001's only covered day 2026-10-19 was loaded before `route_day_depots` existed, so it has end rows and toilets but no depot rows
- **WHEN** the page is rendered
- **THEN** the toilets of both ends show as before, and the depot part consists of the one sentence that the days need to be loaded again with `bin/rails derived:load`

<!-- @trace
source: 03-depot-inspection-scores
updated: 2026-10-24
code:
  - db/migrate/20261024050200_backfill_route_id_on_derived_rows.rb
  - spec/factories/route_day_end_toilets.rb
  - app/frontend/entrypoints/application.js
  - app/components/data_limitations_component.rb
  - db/migrate/20261024050300_require_route_id_on_derived_rows.rb
  - app/models/route_page/depot_inspections.rb
  - app/components/buffer_trade_component.yml
  - app/components/stop_sequence_component.yml
  - docs/data-sources.md
  - docs/background.md
  - config/route_page.yml
  - spec/support/duckdb.rb
  - README.md
  - app/models/route_page/mrt_overlap.rb
  - app/views/routes/show.html.erb
  - spec/factories/route_day_ends.rb
  - spec/fixtures/analysis/bus_event/2026-10-23/09.jsonl
  - lib/tasks/external.rake
  - spec/fixtures/analysis/bus_data/2026-10-23/07.jsonl
  - analysis/10_load.sql
  - app/models/route_page/summary.rb
  - analysis/derived_export.sql
  - analysis/route_shape.sql
  - app/components/route_map_component.html.erb
  - db/migrate/20261024062215_create_route_day_depots.rb
  - spec/fixtures/analysis/bus_event/2026-10-23/08.jsonl
  - spec/fixtures/analysis/README.md
  - spec/fixtures/analysis/static/2026-10-19/GetStop.gz
  - app/models/derived_load_command.rb
  - analysis/50_quality.sql
  - app/components/route_list_component.rb
  - analysis/README.md
  - spec/fixtures/analysis/bus_event/2026-10-23/07.jsonl
  - app/models/route_day_loader.rb
  - db/schema.rb
  - app/components/end_map_component.html.erb
  - spec/factories/route_days.rb
  - spec/fixtures/analysis/static/2026-10-19/GetProvider.gz
  - spec/fixtures/analysis/bus_seat_event/2026-10-23/07.jsonl
  - app/models/tdx_s2s_travel_time_snapshot.rb
  - app/components/route_map_component.rb
  - analysis/turnaround_facilities.sql
  - analysis/60_export.sql
  - app/components/attribution_component.html.erb
  - app/components/route_list_component.html.erb
  - app/frontend/end_map/runtime.js
  - spec/fixtures/analysis/static/2026-10-23/GetRoute.gz
  - app/models/route_page/route_shape.rb
  - app/frontend/route_map/runtime.js
  - config/locales/en.yml
  - app/models/route_day_stop.rb
  - app/components/turnaround_facilities_component.yml
  - spec/fixtures/analysis/static/2026-10-23/GetProvider.gz
  - bin/health-card
  - app/components/buffer_trade_component.html.erb
  - spec/factories/route_day_shapes.rb
  - spec/fixtures/analysis/static/2026-10-23/GetStop.gz
  - app/models/route_day.rb
  - spec/fixtures/analysis/static/2026-10-23/GetPathDetail.gz
  - app/components/data_limitations_component.html.erb
  - analysis/params.sql
  - config/locales/tw.yml
  - app/components/stop_sequence_component.rb
  - analysis/depots.sql
  - app/models/route_page/depots.rb
  - app/components/route_coverage_component.rb
  - config/depot_inspections.yml
  - app/models/route_page/stop_sequence.rb
  - analysis/40_load_profile.sql
  - spec/fixtures/analysis/static/2026-10-19/GetBusShape.gz
  - app/components/stop_sequence_component.html.erb
  - app/models/route_page.rb
  - app/models/route_page/layover_stats.rb
  - lib/analysis_run.rb
  - app/components/route_coverage_component.html.erb
  - app/components/application_component.rb
  - app/components/data_limitations_component.yml
  - app/frontend/stylesheets/application.css
  - app/frontend/maps/base_map.js
  - spec/fixtures/analysis/bus_seat_event/2026-10-23/08.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-23/09.jsonl
  - analysis/mrt_overlap.sql
  - app/models/route_page/load_profile.rb
  - spec/factories/route_day_end_cells.rb
  - db/migrate/20261024050100_add_member_route_columns_to_derived_tables.rb
  - app/models/route_day_shape.rb
  - app/models/trip.rb
  - spec/fixtures/analysis/bus_event/2026-10-24/01.jsonl
  - app/models/route_day_depot.rb
  - spec/fixtures/analysis/static/2026-10-23/GetBusShape.gz
  - app/components/attribution_component.yml
  - app/components/route_map_component.yml
  - docs/decisions.md
  - app/components/turnaround_facilities_component.html.erb
  - db/migrate/20261024035750_create_route_day_shapes.rb
  - app/components/turnaround_facilities_component.rb
  - app/models/pto_assessment_snapshot.rb
  - spec/fixtures/analysis/static/2026-10-19/GetPathDetail.gz
  - spec/fixtures/analysis/static/2026-10-19/GetRoute.gz
  - spec/factories/route_day_depots.rb
tests:
  - spec/analysis/params_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/requests/routes_spec.rb
  - spec/components/route_map_component_spec.rb
  - spec/analysis/layovers_spec.rb
  - spec/analysis/load_spec.rb
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/migrations/member_route_columns_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/route_page/summary_spec.rb
  - spec/models/route_page/depot_inspections_spec.rb
  - spec/components/data_limitations_component_spec.rb
  - spec/models/route_page/depots_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/analysis/mrt_overlap_spec.rb
  - spec/system/route_map_spec.rb
  - spec/components/stop_sequence_component_spec.rb
  - spec/analysis/quality_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/profile_spec.rb
  - spec/components/attribution_component_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/analysis/trips_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/analysis/card_spec.rb
  - spec/components/route_list_component_spec.rb
  - spec/models/route_page/ends_spec.rb
  - spec/models/route_page/stop_sequence_spec.rb
  - spec/requests/pages_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/analysis/depots_spec.rb
  - spec/components/route_coverage_component_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_page/route_shape_spec.rb
  - spec/models/tdx_s2s_travel_time_snapshot_spec.rb
  - spec/models/pto_assessment_snapshot_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/system/end_map_spec.rb
  - spec/analysis/analysis_run_spec.rb
  - spec/analysis/route_shape_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/requests/site_layout_spec.rb
-->