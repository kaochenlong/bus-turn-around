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

Every HTML page SHALL end with one footer that carries, verbatim, the three-line attribution statement for the Taipei bus open data recorded in docs/data-sources.md; one line attributing the MRT entrance coordinates dataset to 臺北大眾捷運股份有限公司 under the same licence; one line attributing the office calendar dataset (data.gov.tw/dataset/14718) to 行政院人事行政總處 under the same licence; and one sentence stating that providing the data does not mean the agency recommends, agrees with or approves this project. The footer SHALL be marked with `data-attribution` and `data-license="OGDL-Taiwan-1.0"` and SHALL NOT carry a `data-section` attribute, so that the route page's block order is unchanged.

#### Scenario: Footer on the home page

- **WHEN** `/` is requested
- **THEN** exactly one `footer[data-attribution][data-license="OGDL-Taiwan-1.0"]` is present

#### Scenario: Footer on a route page

- **WHEN** `/routes/9001` is requested and 9001 has no stored days
- **THEN** the response is 200, exactly one `footer[data-attribution][data-license="OGDL-Taiwan-1.0"]` is present, and no element with `data-section` is inside it

#### Scenario: Office calendar line in the footer

- **WHEN** `/` is requested
- **THEN** the footer contains one line naming 行政院人事行政總處, 中華民國政府行政機關辦公日曆表 and data.gov.tw/dataset/14718

<!-- @trace
source: day-types
updated: 2026-10-23
code:
  - lib/tasks/external.rake
  - app/models/office_calendar_snapshot.rb
  - docs/data-sources.md
  - config/locales/tw.yml
  - app/models/route_day_loader.rb
  - app/components/data_limitations_component.yml
  - app/components/route_coverage_component.rb
  - app/components/route_coverage_component.yml
  - app/models/mrt_exits_snapshot.rb
  - app/components/route_coverage_component.html.erb
  - db/schema.rb
  - app/components/route_list_component.html.erb
  - db/migrate/20261022230942_add_day_type_to_route_days.rb
  - spec/factories/route_days.rb
  - app/components/attribution_component.html.erb
  - app/components/attribution_component.yml
  - config/locales/en.yml
  - spec/fixtures/analysis/README.md
  - app/models/route_page/coverage.rb
  - app/components/application_component.rb
  - app/components/route_list_component.yml
  - app/models/http_fetcher.rb
  - spec/fixtures/analysis/external/office-calendar/2026/2026-10-19.csv
  - app/models/route_day.rb
  - db/migrate/20261022231802_require_day_type_on_route_days.rb
tests:
  - spec/components/mrt_overlap_component_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/components/route_summary_component_spec.rb
  - spec/models/route_page/buffer_trade_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/components/load_profile_table_component_spec.rb
  - spec/components/run_time_table_component_spec.rb
  - spec/system/home_hero_spec.rb
  - spec/models/http_fetcher_spec.rb
  - spec/models/route_day_spec.rb
  - spec/components/buffer_trade_component_spec.rb
  - spec/components/layover_chart_component_spec.rb
  - spec/components/load_chart_component_spec.rb
  - spec/components/application_component_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/route_page/coverage_spec.rb
  - spec/components/layover_table_component_spec.rb
  - spec/components/route_list_component_spec.rb
  - spec/models/home_page/route_list_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/models/office_calendar_snapshot_spec.rb
  - spec/requests/pages_spec.rb
  - spec/requests/routes_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/models/route_page/run_times_spec.rb
  - spec/components/route_coverage_component_spec.rb
-->