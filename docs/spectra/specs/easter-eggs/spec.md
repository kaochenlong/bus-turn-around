# easter-eggs Specification

## Purpose

Three small touches for visitors who look under the hood, each about the rest a bus driver is owed: a comment in `robots.txt`, a bus drawn in the page source, and a `休息()` command in the browser console. They change nothing that a crawler obeys or that an ordinary visitor sees on the page.

## Requirements

### Requirement: Comment in robots.txt

`/robots.txt` SHALL contain the comment line `# 機器人也一樣，連續工作 4 小時至少休息 30 分鐘（汽車運輸業管理規則第 19 條之 2）`. Every line of the file SHALL be a comment or blank, so that the file gives crawlers no rule and every path stays allowed. The file SHALL be served with the content type `text/plain; charset=utf-8`, so that browsers decode the comment as UTF-8.

#### Scenario: Requesting robots.txt

- **WHEN** `/robots.txt` is requested
- **THEN** the response is 200 with the content type `text/plain; charset=utf-8`, the body contains the comment line, and every non-blank line of the body starts with `#`


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

---
### Requirement: Bus drawing in the page source

Every page rendered with the shared layout SHALL carry, right after `<!DOCTYPE html>` and before the `html` element, one HTML comment that holds a drawing of a bus with the word `TurnAround` on its side. The comment SHALL contain only printable ASCII characters, spaces and line breaks, so that it lines up in any monospace view of the source, and SHALL NOT contain `--` between its opening and closing marks.

#### Scenario: Home page source

- **WHEN** `/` is requested
- **THEN** the body starts with `<!DOCTYPE html>`, a line break and an HTML comment that closes before `<html`, contains `TurnAround`, holds only printable ASCII characters, spaces and line breaks, and has no `--` between its opening and closing marks

#### Scenario: Route page source

- **WHEN** `/routes/9001` is requested and 9001 has no stored days
- **THEN** the response is 200 and the body starts with the same doctype and comment as the home page


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

---
### Requirement: Rest command in the console

On every full page load of a page rendered with the shared layout, the site's script SHALL write the line 輸入 休息() 試試看 to the browser console once and SHALL define the global function `休息` on `window`. Calling `休息()` SHALL write the line 駕駛連續開車 4 小時，至少要休息 30 分鐘（汽車運輸業管理規則第 19 條之 2） to the console. A Turbo visit to another page SHALL NOT write the hint again.

#### Scenario: Hint on a full load

- **WHEN** a browser with JavaScript opens `/`
- **THEN** the console has received 輸入 休息() 試試看 exactly once, and `window.休息` is a function

#### Scenario: Calling the command

- **WHEN** a browser with JavaScript opens `/` and `休息()` is called
- **THEN** the console receives 駕駛連續開車 4 小時，至少要休息 30 分鐘（汽車運輸業管理規則第 19 條之 2）

#### Scenario: Turbo visit

- **WHEN** a browser with JavaScript opens `/routes/9001` and follows the site name bar's link to `/`
- **THEN** the console has received 輸入 休息() 試試看 exactly once

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