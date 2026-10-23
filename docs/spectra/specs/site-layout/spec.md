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

Every HTML page SHALL end with one footer that carries, verbatim, the three-line attribution statement for the Taipei bus open data recorded in docs/data-sources.md; one line attributing the MRT entrance coordinates dataset to 臺北大眾捷運股份有限公司 under the same licence; one line attributing the office calendar dataset (data.gov.tw/dataset/14718) to 行政院人事行政總處 under the same licence; one line attributing the national public toilet registry (data.gov.tw/dataset/30794) to 環境部 under the same licence; one line carrying the basemap attribution configured in `config/map.yml` as defined by `turnaround-map`; and one sentence stating that providing the data does not mean the agency recommends, agrees with or approves this project. The footer SHALL be marked with `data-attribution` and `data-license="OGDL-Taiwan-1.0"` and SHALL NOT carry a `data-section` attribute, so that the route page's block order is unchanged.

#### Scenario: Footer on the home page

- **WHEN** `/` is requested
- **THEN** exactly one `footer[data-attribution][data-license="OGDL-Taiwan-1.0"]` is present

#### Scenario: Footer on a route page

- **WHEN** `/routes/9001` is requested and 9001 has no stored days
- **THEN** the response is 200, exactly one `footer[data-attribution][data-license="OGDL-Taiwan-1.0"]` is present, and no element with `data-section` is inside it

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
### Requirement: Site name bar on every page

Every HTML page SHALL begin, before the page's own content, with one bar that carries the site name from the locale file as a link to `/`. The bar SHALL be marked with `data-site-bar` and SHALL NOT carry or contain a `data-section` attribute, so that the block order of every page is unchanged.

#### Scenario: Bar on the home page

- **WHEN** `/` is requested
- **THEN** exactly one `[data-site-bar]` is present before the `main` element, and its link points to `/` with the text 折返點 TurnAround

#### Scenario: Bar on a route page

- **WHEN** `/routes/9001` is requested and 9001 has no stored days
- **THEN** the response is 200, exactly one `[data-site-bar]` is present, and no element with `data-section` is the bar or inside it

<!-- @trace
source: 02-route-page-mobile-first
updated: 2026-10-23
code:
  - spec/fixtures/analysis/external/office-calendar/2026/2026-10-19.csv
  - app/components/route_coverage_component.rb
  - app/models/http_fetcher.rb
  - app/components/load_chart_component.yml
  - analysis/10_load.sql
  - app/components/card_component.rb
  - app/components/layover_chart_component.html.erb
  - spec/fixtures/analysis/bus_event/2026-10-19/14.jsonl
  - app/components/layover_chart_component.yml
  - app/views/routes/show.html.erb
  - app/models/route_day_loader.rb
  - app/views/pages/home.html.erb
  - app/components/route_summary_component.rb
  - app/components/site_bar_component.rb
  - analysis/30_layovers.sql
  - app/components/load_profile_table_component.rb
  - app/components/route_coverage_component.html.erb
  - analysis/params.sql
  - db/migrate/20261022231802_require_day_type_on_route_days.rb
  - app/components/home_hero_component.html.erb
  - analysis/README.md
  - app/components/load_chart_component.html.erb
  - app/components/route_summary_component.yml
  - app/components/route_summary_component.html.erb
  - app/components/buffer_trade_component.yml
  - app/components/data_sources_component.html.erb
  - lib/tasks/external.rake
  - app/components/attribution_component.html.erb
  - app/models/route_page/layover_stats.rb
  - app/components/card_component.html.erb
  - app/components/section_nav_component.html.erb
  - app/components/buffer_trade_component.html.erb
  - app/components/route_coverage_component.yml
  - config/locales/tw.yml
  - app/components/route_list_component.yml
  - app/components/run_time_table_component.yml
  - app/components/route_list_component.html.erb
  - app/components/run_time_table_component.rb
  - db/migrate/20261022230942_add_day_type_to_route_days.rb
  - app/components/site_bar_component.html.erb
  - spec/factories/route_days.rb
  - app/models/route_day.rb
  - app/components/run_time_table_component.html.erb
  - config/locales/en.yml
  - app/components/application_component.rb
  - db/schema.rb
  - app/components/data_limitations_component.html.erb
  - spec/support/duckdb.rb
  - app/components/mrt_overlap_component.rb
  - bin/health-card
  - app/models/office_calendar_snapshot.rb
  - app/frontend/stylesheets/application.css
  - app/models/route_page/coverage.rb
  - spec/fixtures/analysis/README.md
  - app/components/buffer_trade_component.rb
  - app/components/load_profile_table_component.html.erb
  - app/components/mrt_overlap_component.html.erb
  - app/components/layover_table_component.rb
  - app/components/layover_chart_component.rb
  - app/components/load_chart_component.rb
  - docs/data-sources.md
  - app/components/layover_table_component.html.erb
  - app/components/section_nav_component.yml
  - app/components/load_profile_table_component.yml
  - app/components/data_limitations_component.yml
  - analysis/60_export.sql
  - app/models/mrt_exits_snapshot.rb
  - spec/fixtures/analysis/bus_event/2026-10-19/15.jsonl
  - app/components/data_limitations_component.rb
  - app/views/layouts/application.html.erb
  - app/components/section_nav_component.rb
  - app/components/layover_table_component.yml
  - app/components/attribution_component.yml
  - app/components/home_hero_component.rb
tests:
  - spec/models/route_day_loader_spec.rb
  - spec/analysis/card_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/system/route_page_layout_spec.rb
  - spec/models/route_page/run_times_spec.rb
  - spec/components/buffer_trade_component_spec.rb
  - spec/models/http_fetcher_spec.rb
  - spec/models/office_calendar_snapshot_spec.rb
  - spec/requests/routes_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/requests/pages_spec.rb
  - spec/analysis/layovers_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/route_page/coverage_spec.rb
  - spec/components/layover_chart_component_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/run_time_table_component_spec.rb
  - spec/models/route_day_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/analysis/params_spec.rb
  - spec/components/card_component_spec.rb
  - spec/components/load_chart_component_spec.rb
  - spec/models/home_page/route_list_spec.rb
  - spec/components/mrt_overlap_component_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/components/data_limitations_component_spec.rb
  - spec/analysis/load_spec.rb
  - spec/components/layover_table_component_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/analysis/duckdb_helpers_spec.rb
  - spec/components/route_list_component_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/components/route_coverage_component_spec.rb
  - spec/system/home_hero_spec.rb
  - spec/components/load_profile_table_component_spec.rb
  - spec/components/application_component_spec.rb
  - spec/models/route_page/buffer_trade_spec.rb
  - spec/components/route_summary_component_spec.rb
-->