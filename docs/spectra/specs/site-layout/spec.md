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

Every HTML page SHALL end with one footer that carries, verbatim, the three-line attribution statement for the Taipei bus open data recorded in docs/data-sources.md, whose first line SHALL name every feed of 臺北市公共運輸處 that the derived tables and the health card are built from; one line attributing the MRT entrance coordinates dataset to 臺北大眾捷運股份有限公司 under the same licence; one line attributing the office calendar dataset (data.gov.tw/dataset/14718) to 行政院人事行政總處 under the same licence; one line attributing the national public toilet registry (data.gov.tw/dataset/30794) to 環境部 under the same licence; one line attributing the 115年第1期臺北市市區公車營運服務指標評鑑總體報告書 to 臺北市公共運輸處 under the open data declaration of its website (政府資料開放授權條款第 1 版); one line carrying the basemap attribution configured in `config/map.yml` as defined by `turnaround-map`; and one sentence stating that providing the data does not mean the agency recommends, agrees with or approves this project. The footer SHALL be marked with `data-attribution` and `data-license="OGDL-Taiwan-1.0"` and SHALL NOT carry a `data-section` attribute, so that the route page's block order is unchanged. The static error pages under `public/`, such as the page of `not-found-page`, are outside this requirement: they are served without the shared layout, show no data from the feeds and carry no footer.

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
| `GetBusShape.gz` | GetBusShape |
| `GetProvider.gz` | GetProvider |

#### Scenario: Office calendar line in the footer

- **WHEN** `/` is requested
- **THEN** the footer contains one line naming 行政院人事行政總處, 中華民國政府行政機關辦公日曆表 and data.gov.tw/dataset/14718

#### Scenario: Public toilet line in the footer

- **WHEN** `/` is requested
- **THEN** the footer contains one line naming 環境部, 全國公廁建檔資料 and data.gov.tw/dataset/30794

#### Scenario: Evaluation report line in the footer

- **WHEN** `/` is requested
- **THEN** the footer contains one line naming 臺北市公共運輸處, 115年第1期臺北市市區公車營運服務指標評鑑總體報告書 and 政府網站資料開放宣告

#### Scenario: Basemap line in the footer

- **WHEN** `/` is requested in the test environment
- **THEN** the footer contains one line that is the basemap attribution of the test environment in `config/map.yml`, 測試用空白底圖


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
### Requirement: Site name bar on every page

Every HTML page SHALL begin, before the page's own content, with one bar that carries: first the site name from the locale file as a link to `/`; then, only on a route page and on a timetable page as defined by `timetable`, a link whose text comes from the locale file (班表 in `tw`) to that route's timetable page without parameters, carrying `aria-current="page"` on the timetable page itself; then a link to the article that introduces the site, `https://kaochenlong.com/bus-turn-around`, whose text comes from the locale file (關於這個網站 in `tw`). The home page SHALL carry exactly two links, a route page and a timetable page exactly three. The article link SHALL open in the same tab: it SHALL NOT carry a `target` attribute. The bar SHALL be marked with `data-site-bar` and SHALL NOT carry or contain a `data-section` attribute, so that the block order of every page is unchanged. The static error pages under `public/`, such as the page of `not-found-page`, are outside this requirement: they are served without the shared layout and carry no bar.

#### Scenario: Bar on the home page

- **WHEN** `/` is requested
- **THEN** exactly one `[data-site-bar]` is present before the `main` element, it contains exactly two links, the first points to `/` with the text 折返點 TurnAround, and the second points to `https://kaochenlong.com/bus-turn-around` with the text 關於這個網站 and has no `target` attribute

#### Scenario: Bar on a route page

- **WHEN** `/routes/9001` is requested and 9001 has no stored days
- **THEN** the response is 200, exactly one `[data-site-bar]` is present, it contains exactly three links, the second points to `/routes/9001/timetable` with the text 班表 and no `aria-current` attribute, the third points to `https://kaochenlong.com/bus-turn-around` with the text 關於這個網站, and no element with `data-section` is the bar or inside it

#### Scenario: Bar on a timetable page

- **WHEN** `/routes/9001/timetable` is requested
- **THEN** the bar contains exactly three links and its second link points to `/routes/9001/timetable` with `aria-current="page"`

<!-- @trace
source: timetable-draft
updated: 2026-10-25
code:
  - app/components/timetable_overrun_table_component.yml
  - app/models/route_page.rb
  - app/components/timetable_limitations_component.rb
  - app/models/route_page/measured_departures.rb
  - app/components/timetable_header_component.rb
  - app/components/timetable_sheet_component.rb
  - app/components/timetable_header_component.html.erb
  - app/views/layouts/application.html.erb
  - config/locales/tw.yml
  - app/components/site_bar_component.rb
  - app/frontend/timetable/layout.js
  - app/components/timetable_overrun_table_component.html.erb
  - app/frontend/timetable/rows.js
  - package.json
  - app/frontend/timetable/rest_windows.js
  - app/components/timetable_sheet_component.yml
  - app/frontend/timetable/edits.js
  - app/frontend/timetable/component.js
  - app/models/route_page/timetable_overruns.rb
  - app/components/timetable_sheet_component.html.erb
  - app/components/buffer_trade_component.html.erb
  - app/controllers/application_controller.rb
  - app/views/timetables/show.html.erb
  - app/models/route_page/planned_run_times.rb
  - app/controllers/timetables_controller.rb
  - app/frontend/timetable/support.js
  - app/controllers/routes_controller.rb
  - app/components/timetable_header_component.yml
  - config/routes.rb
  - app/components/buffer_trade_component.yml
  - app/components/site_bar_component.html.erb
  - docs/use-cases.md
  - config/ci.rb
  - app/frontend/entrypoints/application.js
  - app/components/buffer_trade_component.rb
  - app/frontend/timetable/format.js
  - app/components/timetable_limitations_component.yml
  - app/frontend/stylesheets/application.css
  - app/components/timetable_overrun_table_component.rb
  - app/components/timetable_limitations_component.html.erb
  - app/components/site_bar_component.yml
  - app/models/route_page/timetable.rb
  - config/locales/en.yml
  - README.md
tests:
  - spec/models/route_page/timetable_spec.rb
  - spec/components/timetable_sheet_component_spec.rb
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/timetable_overrun_table_component_spec.rb
  - spec/system/timetable_layout_spec.rb
  - spec/requests/routes_spec.rb
  - spec/system/timetable_print_spec.rb
  - app/frontend/timetable/layout.test.js
  - spec/system/timetable_entry_spec.rb
  - spec/components/timetable_header_component_spec.rb
  - app/frontend/timetable/edits.test.js
  - app/frontend/timetable/rows.test.js
  - app/frontend/timetable/rest_windows.test.js
  - spec/models/route_page/planned_run_times_spec.rb
  - spec/models/route_page/measured_departures_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/format.test.js
  - spec/models/route_page/timetable_overruns_spec.rb
-->