# not-found-page Specification

## Purpose

The page a visitor gets when the site has nothing at the requested address: a static page in the shape of a bus stop sign that says this stop is not served and links back to the home page. It exists so that a mistyped address, or a link to a route that has been taken off the route list, ends on a page of this site instead of a blank page or the framework's English default.

## Requirements

### Requirement: Not-found page

The site SHALL have one not-found page, the static file `public/404.html`, and SHALL serve it with status 404 for every path the site does not route and, as `route-page` requires, for every route `Id` outside the route list. The page SHALL be in Traditional Chinese (`lang="zh-Hant-TW"`), SHALL have the document title 這一站沒有停靠｜折返點 TurnAround with no emoticon, SHALL show a bus stop sign whose stop name 這一站沒有停靠 is the page's only `h1`, and SHALL carry exactly one `a` element, linking to `/`, whose text names the route 404 and the destination 往 首頁. The page SHALL keep `<meta name="robots" content="noindex, nofollow">`. The page SHALL be served without the shared layout: it SHALL have no site name bar, no attribution footer and no `script` element, because it shows no data from the feeds.

#### Scenario: Unknown path

- **WHEN** a visitor requests `/no-such-page` with detailed exception pages turned off, as in production
- **THEN** the response is 404 and its body is the content of `public/404.html`

#### Scenario: Page content

- **WHEN** `public/404.html` is parsed
- **THEN** its title is 這一站沒有停靠｜折返點 TurnAround, its only `h1` reads 這一站沒有停靠, it has exactly one `a` element, which points to `/` and whose text contains 404 and 往 首頁, its robots meta is `noindex, nofollow`, and it has no `script` element, no `[data-site-bar]` and no `footer[data-attribution]`

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