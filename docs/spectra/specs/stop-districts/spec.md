# stop-districts Specification

## Purpose

Assign every stop location to the county and township it lies in, using the township boundary dataset of 內政部國土測繪中心, so that the derived tables carry the district of each stop and the share of a route's stop locations in each district, from which the home page offers a district filter.

## Requirements

### Requirement: Stop district snapshot

The system SHALL provide the rake task `external:stop_districts`, which downloads the township boundary archive of data.gov.tw dataset 7441 from the address recorded in the snapshot class, extracts from it only the members whose names match `TOWN_MOI_<version>.shp`, `.shx`, `.dbf` and `.prj` (and `.cpg` when present) into a temporary folder, reads the `GetStop.gz` of the static snapshot with the latest day name under the data root, and, with the DuckDB spatial extension loaded on the machine running the task, assigns every stop location (`stopLocationId`) to the boundary polygon that contains the point of its stop with the smallest stop `Id`. The task SHALL write `external/stop-districts/<today's Taipei day>.csv` under the data root: UTF-8 without a byte order mark, LF line ends, the header `stop_location_id,county,town`, one row per stop location that lies inside a polygon, ordered by `stop_location_id` ascending, and no row for a location outside every polygon. Before the file is given its name the task SHALL check it: the exact header, three fields in every row, an integer `stop_location_id` strictly increasing down the file, a non-empty `county` and `town` in every row, and at least one row. The task SHALL print the path, the number of stop locations read, the number assigned and the number not assigned, together with the version in the member names, and exit 0. A download that is not HTTP 200, an archive without the four members, a data root without any `static/<day>/GetStop.gz`, a failure to load the spatial extension, or a file that fails the check SHALL make the task exit with a non-zero status, print the reason, write no snapshot and leave no `.partial` file; the extension failure SHALL name the command `duckdb -c "INSTALL spatial"`.

#### Scenario: Snapshot written from the boundary archive and the newest stop list

- **WHEN** the fetcher returns an archive holding the fixture boundary members `TOWN_MOI_TEST.shp`, `.shx`, `.dbf` and `.prj`, whose two polygons are 臺北市 測試區 around the stop locations 81000 to 81008, 82000 to 82003 of the comparison route 9100 and 85002, and 新北市 甲區 around 81009, and the data root holds the fixture static snapshots 2026-10-19 and 2026-10-23
- **THEN** the task reads `static/2026-10-23/GetStop.gz`, writes the file for today's Taipei day with the header and the rows 81000 to 81008 as 臺北市,測試區, 81009 as 新北市,甲區, 82000 to 82003 as 臺北市,測試區 and 85002 as 臺北市,測試區, leaves out 85007, which lies outside both polygons, prints 16 stop locations read, 15 assigned and 1 not assigned, and exits 0

##### Example: rows of the fixture snapshot

| stop_location_id | county | town |
| --- | --- | --- |
| 81000 | 臺北市 | 測試區 |
| 81008 | 臺北市 | 測試區 |
| 81009 | 新北市 | 甲區 |
| 82000 | 臺北市 | 測試區 |
| 85002 | 臺北市 | 測試區 |

#### Scenario: Members chosen by name

- **WHEN** the archive also holds a member whose name is not valid UTF-8 and a member `readme.xlsx`
- **THEN** only the four boundary members are extracted and the snapshot is written as in the previous scenario

#### Scenario: Spatial extension missing

- **WHEN** loading the spatial extension fails on the machine running the task
- **THEN** the task exits with a non-zero status, prints a reason naming `duckdb -c "INSTALL spatial"`, and writes neither the snapshot nor a `.partial` file

#### Scenario: Unusable input

- **WHEN** the download returns status 404, or the archive has no `TOWN_MOI_*.shp` member, or the data root has no `static/<day>/GetStop.gz`, or the written file has a row whose `town` is empty
- **THEN** the task exits with a non-zero status, prints the reason, writes no snapshot and leaves no `.partial` file, and an existing snapshot stays as it was


<!-- @trace
source: home-district-filter
updated: 2026-11-02
code:
  - app/components/route_list_component.rb
  - app/components/attribution_component.html.erb
  - app/frontend/route_list/district_filter.js
  - app/components/route_list_component.html.erb
  - Gemfile.lock
  - spec/factories/route_day_districts.rb
  - analysis/derived_export.sql
  - spec/factories/route_days.rb
  - db/schema.rb
  - spec/fixtures/analysis/external/stop-districts/2026-10-19.csv
  - spec/fixtures/analysis/external/town-boundaries/TOWN_MOI_TEST.shp
  - app/frontend/entrypoints/application.js
  - app/models/home_page/route_districts.rb
  - app/models/route_day_district.rb
  - analysis/stop_district_snapshot.sql
  - spec/fixtures/analysis/README.md
  - spec/fixtures/analysis/external/town-boundaries/TOWN_MOI_TEST.prj
  - app/components/attribution_component.yml
  - spec/fixtures/analysis/external/town-boundaries/TOWN_MOI_TEST.dbf
  - README.md
  - analysis/README.md
  - app/models/home_page/route_list.rb
  - spec/fixtures/analysis/external/town-boundaries/TOWN_MOI_TEST.cpg
  - .agents/skills/spectra-apply/SKILL.md
  - app/models/route_day_loader.rb
  - .github/skills/spectra-apply/SKILL.md
  - app/models/stop_districts_snapshot.rb
  - config/route_page.yml
  - analysis/stop_districts.sql
  - spec/fixtures/analysis/external/town-boundaries/TOWN_MOI_TEST.shx
  - docs/data-sources.md
  - analysis/params.sql
  - db/migrate/20261101172102_create_route_day_districts.rb
  - app/models/route_day_stop.rb
  - Gemfile
  - lib/tasks/external.rake
  - app/models/route_day.rb
  - app/components/route_list_component.yml
tests:
  - spec/models/derived_load_command_spec.rb
  - spec/components/route_list_component_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/stop_district_snapshot_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/models/stop_districts_snapshot_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/home_page/route_districts_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/nightly_load_command_spec.rb
  - spec/models/route_day_loader_spec.rb
  - app/frontend/route_list/district_filter.test.js
  - spec/analysis/stop_districts_spec.rb
  - spec/models/home_page/route_list_spec.rb
  - spec/system/home_district_filter_spec.rb
  - spec/requests/pages_spec.rb
  - spec/models/route_page/ends_spec.rb
-->

---
### Requirement: District of each stop

For every route Id of a load run, each stop SHALL carry the district of its stop location read from the newest stop district snapshot: the county and the town joined without a separator, such as 臺北市大安區. A stop without a stop location, or whose stop location has no row in the snapshot, SHALL carry no district.

#### Scenario: Stops of the fixture day

- **WHEN** route 9001 is loaded for 2026-10-19 with the fixture snapshot `external/stop-districts/2026-10-19.csv`
- **THEN** the stops at the locations 81000 to 81008 carry 臺北市測試區, the stop at 81009 carries 新北市甲區, and the member route 9050's stop at 85007 carries no district


<!-- @trace
source: home-district-filter
updated: 2026-11-02
code:
  - app/components/route_list_component.rb
  - app/components/attribution_component.html.erb
  - app/frontend/route_list/district_filter.js
  - app/components/route_list_component.html.erb
  - Gemfile.lock
  - spec/factories/route_day_districts.rb
  - analysis/derived_export.sql
  - spec/factories/route_days.rb
  - db/schema.rb
  - spec/fixtures/analysis/external/stop-districts/2026-10-19.csv
  - spec/fixtures/analysis/external/town-boundaries/TOWN_MOI_TEST.shp
  - app/frontend/entrypoints/application.js
  - app/models/home_page/route_districts.rb
  - app/models/route_day_district.rb
  - analysis/stop_district_snapshot.sql
  - spec/fixtures/analysis/README.md
  - spec/fixtures/analysis/external/town-boundaries/TOWN_MOI_TEST.prj
  - app/components/attribution_component.yml
  - spec/fixtures/analysis/external/town-boundaries/TOWN_MOI_TEST.dbf
  - README.md
  - analysis/README.md
  - app/models/home_page/route_list.rb
  - spec/fixtures/analysis/external/town-boundaries/TOWN_MOI_TEST.cpg
  - .agents/skills/spectra-apply/SKILL.md
  - app/models/route_day_loader.rb
  - .github/skills/spectra-apply/SKILL.md
  - app/models/stop_districts_snapshot.rb
  - config/route_page.yml
  - analysis/stop_districts.sql
  - spec/fixtures/analysis/external/town-boundaries/TOWN_MOI_TEST.shx
  - docs/data-sources.md
  - analysis/params.sql
  - db/migrate/20261101172102_create_route_day_districts.rb
  - app/models/route_day_stop.rb
  - Gemfile
  - lib/tasks/external.rake
  - app/models/route_day.rb
  - app/components/route_list_component.yml
tests:
  - spec/models/derived_load_command_spec.rb
  - spec/components/route_list_component_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/stop_district_snapshot_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/models/stop_districts_snapshot_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/home_page/route_districts_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/nightly_load_command_spec.rb
  - spec/models/route_day_loader_spec.rb
  - app/frontend/route_list/district_filter.test.js
  - spec/analysis/stop_districts_spec.rb
  - spec/models/home_page/route_list_spec.rb
  - spec/system/home_district_filter_spec.rb
  - spec/requests/pages_spec.rb
  - spec/models/route_page/ends_spec.rb
-->

---
### Requirement: District shares of a route day

For the page route of a load run the system SHALL compute, per district, the number of its distinct stop locations in that district over both directions (`n_locations`), against the number of its distinct stop locations with a stop location Id over both directions (`n_total`), the share `n_locations / n_total` to three decimals, and whether the district qualifies: `n_locations * 100 >= n_total * district_min_share_percent`, with `district_min_share_percent` set to 10 in `analysis/params.sql`, so that the comparison is exact. The stops of member routes SHALL NOT count in either number. A stop location without a district SHALL count in `n_total` and in no district.

#### Scenario: Shares of the fixture day

- **WHEN** route 9001 is loaded for 2026-10-19 with the fixture snapshot
- **THEN** the route day has two district rows: 臺北市 測試區 with 9 locations, share 0.900, qualifying, and 新北市 甲區 with 1 location, share 0.100, qualifying, both against 10 locations

##### Example: threshold at the boundary

| n_locations | n_total | threshold percent | qualifies |
| --- | --- | --- | --- |
| 1 | 10 | 10 | yes |
| 1 | 10 | 20 | no |
| 7 | 70 | 10 | yes |
| 6 | 70 | 10 | no |

#### Scenario: Member route stops stay out of the shares

- **WHEN** route 9001 is loaded with its member route 9050 for 2026-10-23
- **THEN** 9050's stop locations 85002 and 85007 are in neither `n_locations` nor `n_total` of any district row

#### Scenario: Location without a district counts in the total only

- **WHEN** a snapshot without the row for 81009 is used
- **THEN** 臺北市 測試區 has 9 locations against 10, share 0.900, and no row exists for 新北市 甲區

<!-- @trace
source: home-district-filter
updated: 2026-11-02
code:
  - app/components/route_list_component.rb
  - app/components/attribution_component.html.erb
  - app/frontend/route_list/district_filter.js
  - app/components/route_list_component.html.erb
  - Gemfile.lock
  - spec/factories/route_day_districts.rb
  - analysis/derived_export.sql
  - spec/factories/route_days.rb
  - db/schema.rb
  - spec/fixtures/analysis/external/stop-districts/2026-10-19.csv
  - spec/fixtures/analysis/external/town-boundaries/TOWN_MOI_TEST.shp
  - app/frontend/entrypoints/application.js
  - app/models/home_page/route_districts.rb
  - app/models/route_day_district.rb
  - analysis/stop_district_snapshot.sql
  - spec/fixtures/analysis/README.md
  - spec/fixtures/analysis/external/town-boundaries/TOWN_MOI_TEST.prj
  - app/components/attribution_component.yml
  - spec/fixtures/analysis/external/town-boundaries/TOWN_MOI_TEST.dbf
  - README.md
  - analysis/README.md
  - app/models/home_page/route_list.rb
  - spec/fixtures/analysis/external/town-boundaries/TOWN_MOI_TEST.cpg
  - .agents/skills/spectra-apply/SKILL.md
  - app/models/route_day_loader.rb
  - .github/skills/spectra-apply/SKILL.md
  - app/models/stop_districts_snapshot.rb
  - config/route_page.yml
  - analysis/stop_districts.sql
  - spec/fixtures/analysis/external/town-boundaries/TOWN_MOI_TEST.shx
  - docs/data-sources.md
  - analysis/params.sql
  - db/migrate/20261101172102_create_route_day_districts.rb
  - app/models/route_day_stop.rb
  - Gemfile
  - lib/tasks/external.rake
  - app/models/route_day.rb
  - app/components/route_list_component.yml
tests:
  - spec/models/derived_load_command_spec.rb
  - spec/components/route_list_component_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/stop_district_snapshot_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/models/stop_districts_snapshot_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/home_page/route_districts_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/nightly_load_command_spec.rb
  - spec/models/route_day_loader_spec.rb
  - app/frontend/route_list/district_filter.test.js
  - spec/analysis/stop_districts_spec.rb
  - spec/models/home_page/route_list_spec.rb
  - spec/system/home_district_filter_spec.rb
  - spec/requests/pages_spec.rb
  - spec/models/route_page/ends_spec.rb
-->