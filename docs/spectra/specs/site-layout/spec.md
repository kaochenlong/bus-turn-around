# site-layout Specification

## Purpose

What every page receives from the shared layout: a document title that carries the site name, and the attribution footer that the open data licence requires on everything built from the Taipei bus feeds. It exists so that no page can ship without the attribution.

## Requirements

### Requirement: Document title carries the site name

Every page SHALL have a document title. When a page sets no title of its own, the title SHALL be the site name 折返點 TurnAround from the locale file, and the `application-name` meta SHALL carry the same site name.

#### Scenario: Home page title

- **WHEN** `/` is requested
- **THEN** the document title is 折返點 TurnAround and the `application-name` meta is 折返點 TurnAround

#### Scenario: Route page title

- **WHEN** `/routes/9001` is requested and 9001 has no stored days
- **THEN** the response is 200 and the document title is 折返點 TurnAround


<!-- @trace
source: home-page
updated: 2026-10-23
code:
  - app/assets/images/home-hero-tall.webp
  - app/components/route_coverage_component.rb
  - app/components/route_list_component.yml
  - app/controllers/pages_controller.rb
  - app/assets/images/home-hero-wide.webp
  - app/components/data_limitations_component.rb
  - config/locales/en.yml
  - config/locales/tw.yml
  - app/frontend/hero/scene.js
  - app/components/route_list_component.html.erb
  - app/components/attribution_component.yml
  - app/components/data_limitations_component.html.erb
  - app/frontend/hero/runtime.js
  - .dockerignore
  - app/frontend/entrypoints/application.js
  - app/views/pages/home.html.erb
  - spec/support/system.rb
  - package.json
  - tools/hero/export.js
  - app/frontend/stylesheets/application.css
  - tools/hero/index.html
  - app/components/home_hero_component.yml
  - app/components/route_list_component.rb
  - app/components/attribution_component.rb
  - app/components/attribution_component.html.erb
  - app/components/data_sources_component.yml
  - app/components/home_hero_component.html.erb
  - app/components/data_limitations_component.yml
  - .rubocop.yml
  - app/models/home_page/route_list.rb
  - app/components/data_sources_component.html.erb
  - app/views/layouts/application.html.erb
  - app/components/application_component.rb
  - app/components/data_sources_component.rb
  - app/components/home_hero_component.rb
tests:
  - spec/requests/site_layout_spec.rb
  - spec/components/home_hero_component_spec.rb
  - spec/components/data_sources_component_spec.rb
  - spec/requests/pages_spec.rb
  - spec/system/home_hero_spec.rb
  - spec/components/data_limitations_component_spec.rb
  - spec/models/home_page/route_list_spec.rb
  - spec/assets/home_hero_images_spec.rb
  - spec/components/route_list_component_spec.rb
-->

---
### Requirement: Attribution footer on every page

Every HTML page SHALL end with one footer that carries, verbatim, the three-line attribution statement for the Taipei bus open data recorded in docs/data-sources.md, whose first line SHALL name every feed of 臺北市公共運輸處 that the derived tables and the health card are built from; one line attributing the MRT entrance coordinates dataset to 臺北大眾捷運股份有限公司 under the same licence; one line attributing the office calendar dataset (data.gov.tw/dataset/14718) to 行政院人事行政總處 under the same licence; one line attributing the national public toilet registry (data.gov.tw/dataset/30794) to 環境部 under the same licence; one line carrying the basemap attribution configured in `config/map.yml` as defined by `turnaround-map`; and one sentence stating that providing the data does not mean the agency recommends, agrees with or approves this project. The footer SHALL be marked with `data-attribution` and `data-license="OGDL-Taiwan-1.0"` and SHALL NOT carry a `data-section` attribute, so that the route page's block order is unchanged.

#### Scenario: Footer on the home page

- **WHEN** `/` is requested
- **THEN** exactly one `footer[data-attribution][data-license="OGDL-Taiwan-1.0"]` is present

#### Scenario: Footer on a route page

- **WHEN** `/routes/9001` is requested and 9001 has no stored days
- **THEN** the response is 200, exactly one `footer[data-attribution][data-license="OGDL-Taiwan-1.0"]` is present, and no element with `data-section` is inside it

#### Scenario: Statement as recorded

- **WHEN** `/` is requested
- **THEN** the footer's three statement lines are, in order and character for character, the three quoted paragraphs of the 授權 section of docs/data-sources.md

#### Scenario: Every bus feed named

- **WHEN** the site's code reads a feed of 臺北市公共運輸處, either as a folder of hourly files passed to `day_files` in `analysis/` or as a snapshot file whose name starts with `Get` and ends with `.gz`
- **THEN** the first line of the statement names that feed by its code

##### Example: feeds read today

| Read by the code | Named in the first line |
| --- | --- |
| `bus_event` hourly files | GetBusEvent |
| `bus_seat_event` hourly files | BusSeatEvent |
| `bus_data` hourly files | GetBusData |
| `GetRoute.gz` | GetRoute |
| `GetStop.gz` | GetStop |
| `GetPathDetail.gz` | GetPathDetail |

#### Scenario: Office calendar line in the footer

- **WHEN** `/` is requested
- **THEN** the footer contains one line naming 行政院人事行政總處, 中華民國政府行政機關辦公日曆表 and data.gov.tw/dataset/14718

#### Scenario: Public toilet line in the footer

- **WHEN** `/` is requested
- **THEN** the footer contains one line naming 環境部, 全國公廁建檔資料 and data.gov.tw/dataset/30794

#### Scenario: Basemap line in the footer

- **WHEN** `/` is requested in the test environment
- **THEN** the footer contains one line that is the basemap attribution of the test environment in `config/map.yml`, 測試用空白底圖


<!-- @trace
source: 01-bus-feeds-attribution
updated: 2026-10-24
code:
  - docs/data-sources.md
  - bin/health-card
  - app/components/attribution_component.yml
tests:
  - spec/analysis/attribution_spec.rb
  - spec/requests/site_layout_spec.rb
-->

---
### Requirement: Site name bar on every page

Every HTML page SHALL begin, before the page's own content, with one bar that carries the site name from the locale file as a link to `/`. The bar SHALL be marked with `data-site-bar` and SHALL NOT carry or contain a `data-section` attribute, so that the block order of every page is unchanged. The static error pages under `public/`, such as the page of `not-found-page`, are outside this requirement: they are served without the shared layout and carry no bar.

#### Scenario: Bar on the home page

- **WHEN** `/` is requested
- **THEN** exactly one `[data-site-bar]` is present before the `main` element, and its link points to `/` with the text 折返點 TurnAround

#### Scenario: Bar on a route page

- **WHEN** `/routes/9001` is requested and 9001 has no stored days
- **THEN** the response is 200, exactly one `[data-site-bar]` is present, and no element with `data-section` is the bar or inside it

<!-- @trace
source: site-easter-eggs
updated: 2026-10-24
code:
  - config/locales/tw.yml
  - app/components/attribution_component.html.erb
  - config/locales/en.yml
  - app/models/route_day.rb
  - config/map.yml
  - spec/support/duckdb.rb
  - app/models/route_page/cycles.rb
  - app/components/end_map_component.yml
  - analysis/turnaround_facilities.sql
  - app/components/cycle_table_component.yml
  - app/components/home_hero_component.yml
  - spec/fixtures/analysis/README.md
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - public/turnaround/favicon.ico
  - spec/fixtures/analysis/bus_data/2026-10-19/12.jsonl
  - docs/data-sources.md
  - bin/health-card
  - analysis/params.sql
  - app/assets/images/turnaround-logo.webp
  - spec/factories/route_day_end_toilets.rb
  - public/turnaround/icon-16.png
  - app/components/load_chart_component.rb
  - app/components/turnaround_facilities_component.rb
  - spec/fixtures/analysis/external/public-toilets/2026-10-19.csv
  - Gemfile
  - app/components/turnaround_facilities_component.yml
  - app/frontend/stylesheets/application.css
  - spec/factories/route_day_ends.rb
  - app/frontend/end_map/runtime.js
  - app/frontend/hero/scene.js
  - app/components/home_hero_component.html.erb
  - lib/tasks/external.rake
  - spec/fixtures/analysis/bus_data/2026-10-19/11.jsonl
  - app/assets/images/home-hero-wide.webp
  - app/models/route_day_end.rb
  - app/models/map_tiles.rb
  - app/models/route_day_loader.rb
  - config/initializers/mime_types.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/08.jsonl
  - app/views/layouts/application.html.erb
  - app/models/route_page/end_map.rb
  - app/components/attribution_component.yml
  - app/frontend/rest_command.js
  - analysis/derived_export.sql
  - app/components/turnaround_facilities_component.html.erb
  - db/migrate/20261023190654_add_turnaround_facilities_to_derived_tables.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/07.jsonl
  - app/models/public_toilets_snapshot.rb
  - app/components/cycle_table_component.rb
  - public/turnaround/apple-touch-icon.png
  - app/models/route_day_end_cell.rb
  - spec/factories/route_days.rb
  - spec/factories/route_day_end_cells.rb
  - config/deploy.yml
  - app/models/route_day_end_toilet.rb
  - app/components/section_nav_component.yml
  - Dockerfile
  - public/turnaround/icon-32.png
  - app/components/end_map_component.rb
  - app/views/routes/show.html.erb
  - app/components/site_bar_component.html.erb
  - app/models/derived_load_command.rb
  - app/components/load_chart_component.html.erb
  - package.json
  - app/components/attribution_component.rb
  - app/components/section_nav_component.rb
  - app/models/route_page/facilities.rb
  - app/frontend/hero/runtime.js
  - app/frontend/entrypoints/application.js
  - app/components/cycle_table_component.html.erb
  - .ruby-version
  - analysis/README.md
  - public/turnaround/og-image-v2.jpg
  - db/schema.rb
  - app/assets/images/home-hero-narrow.webp
  - app/components/end_map_component.html.erb
  - app/components/data_limitations_component.yml
  - Gemfile.lock
tests:
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_page/end_map_spec.rb
  - spec/requests/easter_eggs_spec.rb
  - spec/system/load_chart_hover_spec.rb
  - spec/models/route_day_spec.rb
  - spec/analysis/params_spec.rb
  - spec/system/rest_command_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/requests/routes_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/components/cycle_table_component_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/models/route_page/facilities_spec.rb
  - spec/models/map_tiles_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/components/load_chart_component_spec.rb
  - spec/requests/not_found_page_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/models/public_toilets_snapshot_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/system/end_map_spec.rb
  - spec/models/route_page/cycles_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/requests/route_page_fixture_spec.rb
-->