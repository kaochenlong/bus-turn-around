# site-layout Specification

## Purpose

What every page receives from the shared layout: a document title that carries the site name, and the attribution footer that the open data licence requires on everything built from the Taipei bus feeds. It exists so that no page can ship without the attribution.

## Requirements

### Requirement: Document title carries the site name

Every page SHALL have a document title that carries the site name 折返點 TurnAround from the locale file. When a page sets no title of its own, the title SHALL be the site name alone. A page that sets its own title SHALL end it with the site name after the separator ｜, as `route-page` does with 路線名｜折返點 TurnAround. The `application-name` meta SHALL carry the site name on every page. The `og:title` and `twitter:title` metas SHALL equal the document title.

#### Scenario: Home page title

- **WHEN** `/` is requested
- **THEN** the document title is 折返點 TurnAround, the `application-name` meta is 折返點 TurnAround, and the `og:title` and `twitter:title` metas are 折返點 TurnAround

#### Scenario: Route page title

- **WHEN** `/routes/9001` is requested and 9001 has no stored days
- **THEN** the response is 200 and the document title is 折返點 TurnAround

#### Scenario: Share title follows the document title

- **WHEN** `/routes/9001` is requested and 9001's latest covered day has the route name 測試幹線
- **THEN** the document title, the `og:title` meta and the `twitter:title` meta are all 測試幹線｜折返點 TurnAround


<!-- @trace
source: share-preview-home-figure
updated: 2026-10-25
code:
  - app/models/route_page/format.rb
  - app/models/route_page/share_preview.rb
  - config/locales/tw.yml
  - app/models/home_page/stop_end_figures.rb
  - app/components/route_list_component.yml
  - app/components/application_component.rb
  - app/controllers/pages_controller.rb
  - config/locales/en.yml
  - app/views/routes/show.html.erb
  - app/components/route_list_component.rb
  - app/models/home_page/route_list.rb
  - app/views/layouts/application.html.erb
  - app/components/route_list_component.html.erb
  - app/models/route_page/layover_stats.rb
tests:
  - spec/requests/routes_spec.rb
  - spec/models/route_page/format_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/route_list_component_spec.rb
  - spec/models/home_page/stop_end_figures_spec.rb
  - spec/requests/pages_spec.rb
  - spec/models/route_page/share_preview_spec.rb
  - spec/models/home_page/route_list_spec.rb
-->

---
### Requirement: Attribution footer on every page

Every HTML page SHALL end with one footer that carries, verbatim, the three-line attribution statement for the Taipei bus open data recorded in docs/data-sources.md, whose first line SHALL name every feed of 臺北市公共運輸處 that the derived tables and the health card are built from; one line attributing the MRT entrance coordinates dataset to 臺北大眾捷運股份有限公司 under the same licence; one line attributing the office calendar dataset (data.gov.tw/dataset/14718) to 行政院人事行政總處 under the same licence; one line attributing the national public toilet registry (data.gov.tw/dataset/30794) to 環境部 under the same licence; one line attributing the township boundary dataset 鄉鎮市區界線(TWD97經緯度) (data.gov.tw/dataset/7441) to 內政部國土測繪中心 under the same licence; one line attributing the 115年第1期臺北市市區公車營運服務指標評鑑總體報告書 to 臺北市公共運輸處 under the open data declaration of its website (政府資料開放授權條款第 1 版); one line carrying the basemap attribution configured in `config/map.yml` as defined by `turnaround-map`; and one sentence stating that providing the data does not mean the agency recommends, agrees with or approves this project. The footer SHALL be marked with `data-attribution` and `data-license="OGDL-Taiwan-1.0"` and SHALL NOT carry a `data-section` attribute, so that the route page's block order is unchanged. The static error pages under `public/`, such as the page of `not-found-page`, are outside this requirement: they are served without the shared layout, show no data from the feeds and carry no footer.

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
| `GetSemiTimeTable.gz` | GetSemiTimeTable |
| `GetTimeTable.gz` | GetTimeTable |

#### Scenario: Office calendar line in the footer

- **WHEN** `/` is requested
- **THEN** the footer contains one line naming 行政院人事行政總處, 中華民國政府行政機關辦公日曆表 and data.gov.tw/dataset/14718

#### Scenario: Public toilet line in the footer

- **WHEN** `/` is requested
- **THEN** the footer contains one line naming 環境部, 全國公廁建檔資料 and data.gov.tw/dataset/30794

#### Scenario: Township boundary line in the footer

- **WHEN** `/` is requested
- **THEN** the footer contains one line naming 內政部國土測繪中心, 鄉鎮市區界線(TWD97經緯度) and data.gov.tw/dataset/7441

#### Scenario: Evaluation report line in the footer

- **WHEN** `/` is requested
- **THEN** the footer contains one line naming 臺北市公共運輸處, 115年第1期臺北市市區公車營運服務指標評鑑總體報告書 and 政府網站資料開放宣告

#### Scenario: Basemap line in the footer

- **WHEN** `/` is requested in the test environment
- **THEN** the footer contains one line that is the basemap attribution of the test environment in `config/map.yml`, 測試用空白底圖


<!-- @trace
source: 02-published-schedule
updated: 2026-11-02
code:
  - app/components/month_card_run_times_component.yml
  - app/models/route_page/month_card.rb
  - analysis/30_layovers.sql
  - app/components/month_card_cycles_component.html.erb
  - app/views/route_cards/show.html.erb
  - app/components/month_card_attribution_component.rb
  - app/components/month_card_buffer_component.rb
  - spec/factories/layovers.rb
  - spec/factories/route_cards.rb
  - spec/fixtures/analysis/README.md
  - app/models/route_day_published_departure.rb
  - app/models/route_page/month_days.rb
  - config/routes.rb
  - app/frontend/stylesheets/application.css
  - db/migrate/20261102030000_create_route_cards.rb
  - spec/factories/route_day_published_departures.rb
  - app/models/route_page/mrt_overlap.rb
  - spec/factories/route_day_rest_windows.rb
  - app/models/route_page/layover_hours.rb
  - analysis/published_schedule.sql
  - spec/factories/trips.rb
  - spec/factories/route_day_driving_stretches.rb
  - app/components/month_card_schedule_component.html.erb
  - app/models/route_page/format.rb
  - db/migrate/20261102011500_create_route_day_published_schedule.rb
  - app/models/route_page/load_profile.rb
  - bin/health-card
  - app/components/month_card_summary_component.yml
  - app/models/route_page/card_trend.rb
  - app/models/route_day_published_headway.rb
  - app/components/month_card_run_times_component.html.erb
  - app/models/route_card.rb
  - config/locales/tw.yml
  - app/components/month_card_run_times_component.rb
  - analysis/derived_export.sql
  - app/components/month_card_cycles_component.yml
  - app/components/month_card_hour_share_chart_component.yml
  - .agents/skills/spectra-apply/SKILL.md
  - app/controllers/route_cards_controller.rb
  - spec/fixtures/analysis/static/2026-10-19/GetSemiTimeTable.gz
  - app/components/month_card_hour_share_chart_component.html.erb
  - app/components/month_card_hour_chart_component.rb
  - app/components/month_card_driving_component.yml
  - app/components/month_card_hour_share_chart_component.rb
  - app/models/route_page/rest_windows.rb
  - app/models/route_page/layover_distribution.rb
  - docs/data-sources.md
  - app/components/month_card_margin_component.html.erb
  - app/components/attribution_component.yml
  - app/models/route_page/layover_stats.rb
  - app/models/route_day_driving_stretch.rb
  - app/components/month_card_attribution_component.yml
  - app/models/route_day_rest_window.rb
  - app/models/route_page/snapshot_changes.rb
  - app/components/month_card_schedule_component.rb
  - app/components/month_card_history_component.yml
  - app/components/month_card_schedule_component.yml
  - app/models/program_version.rb
  - app/models/route_page/month_findings.rb
  - app/components/month_card_layovers_component.html.erb
  - app/components/month_card_summary_component.html.erb
  - db/schema.rb
  - spec/factories/route_days.rb
  - app/components/month_card_chart_component.rb
  - app/components/month_card_hour_chart_component.html.erb
  - config/locales/en.yml
  - spec/fixtures/analysis/static/2026-10-23/GetSemiTimeTable.gz
  - analysis/README.md
  - app/components/month_card_driving_component.html.erb
  - app/components/month_card_margin_component.yml
  - app/components/month_card_component.rb
  - app/components/month_card_buffer_component.html.erb
  - lib/tasks/cards.rake
  - app/models/route_page/slow_legs.rb
  - app/components/month_card_buffer_component.yml
  - app/components/month_card_history_component.html.erb
  - app/components/month_card_summary_component.rb
  - app/components/month_card_distribution_chart_component.yml
  - app/models/route_day.rb
  - app/components/month_card_distribution_chart_component.html.erb
  - app/components/month_card_layovers_component.rb
  - spec/fixtures/analysis/static/2026-10-23/GetTimeTable.gz
  - .github/skills/spectra-apply/SKILL.md
  - app/components/month_card_history_component.rb
  - app/components/month_card_cycles_component.rb
  - app/components/month_card_layovers_component.yml
  - app/models/route_page/schedule_comparison.rb
  - app/components/month_card_distribution_chart_component.rb
  - app/models/route_card_coverage.rb
  - app/components/month_card_attribution_component.html.erb
  - app/models/route_day_loader.rb
  - app/components/month_card_margin_component.rb
  - app/models/route_card_prepare_command.rb
  - db/migrate/20261101220000_create_route_day_rest_windows.rb
  - spec/fixtures/analysis/static/2026-10-19/GetTimeTable.gz
  - app/components/month_card_driving_component.rb
  - spec/factories/route_day_published_headways.rb
  - analysis/params.sql
tests:
  - spec/models/route_day_driving_stretch_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/components/month_card_history_component_spec.rb
  - spec/components/month_card_summary_component_spec.rb
  - spec/models/route_page/month_findings_spec.rb
  - spec/system/month_card_print_spec.rb
  - spec/models/route_day_published_headway_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/route_day_rest_window_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/components/month_card_buffer_component_spec.rb
  - spec/components/month_card_attribution_component_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/route_page/slow_legs_spec.rb
  - spec/models/route_page/layover_hours_spec.rb
  - spec/requests/route_cards_spec.rb
  - spec/models/route_card_coverage_spec.rb
  - spec/models/route_page/month_card_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/components/month_card_run_times_component_spec.rb
  - spec/components/month_card_margin_component_spec.rb
  - spec/models/program_version_spec.rb
  - spec/models/route_page/snapshot_changes_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_page/rest_windows_spec.rb
  - spec/components/month_card_schedule_component_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_card_prepare_command_spec.rb
  - spec/analysis/published_schedule_spec.rb
  - spec/components/month_card_cycles_component_spec.rb
  - spec/components/month_card_driving_component_spec.rb
  - spec/models/route_card_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/components/month_card_layovers_component_spec.rb
  - spec/models/route_page/month_days_spec.rb
  - spec/models/route_page/schedule_comparison_spec.rb
  - spec/models/route_day_published_departure_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/components/month_card_hour_chart_component_spec.rb
  - spec/models/route_page/card_trend_spec.rb
  - spec/analysis/attribution_spec.rb
-->

---
### Requirement: Site name bar on every page

Every HTML page SHALL begin, before the page's own content, with one bar that carries, in this order: first the site name from the locale file as a link to `/`; then, only on a route page, a timetable page as defined by `timetable`, a day dispatch page as defined by `day-dispatch`, a month card page as defined by `monthly-card` and a month card list as defined by `monthly-card-pdf`, a link whose text comes from the locale file (班表 in `tw`) to that route's timetable page without parameters, carrying `aria-current="page"` on the timetable page itself, followed by a link whose text comes from the locale file (當天調度 in `tw`) to that route's day dispatch page `/routes/<Id>/dispatch`, carrying `aria-current="page"` on the day dispatch page itself, followed by a link whose text comes from the locale file (健檢卡 in `tw`) to that route's month card list `/routes/<Id>/cards`, carrying `aria-current="page"` on the month card list and on a month card page; then a link to the site's source repository, `https://github.com/kaochenlong/bus-turn-around`, shown as the GitHub mark, whose text comes from the locale file (GitHub in `tw`) and is read by assistive technology only; then a link to the article that introduces the site, `https://kaochenlong.com/bus-turn-around`, whose text comes from the locale file (關於這個網站 in `tw`). The repository link and the article link SHALL sit together at the right end of the bar, apart from the site name and the route links. At every screen width the article link SHALL show only the first part of its text (關於 in `tw`) while its text stays whole for assistive technology. On a screen narrower than 640 px the repository link SHALL NOT be displayed. The home page SHALL carry exactly three links; a route page, a timetable page, a day dispatch page, a month card page and a month card list exactly six. On a screen 360 px wide the bar SHALL fit without horizontal scrolling. The repository link and the article link SHALL open in a new tab: each SHALL carry `target="_blank"` and `rel="noopener"` and SHALL be described to assistive technology as opening in a new tab, in words from the locale file (另開新分頁 in `tw`). The bar SHALL be marked with `data-site-bar` and SHALL NOT carry or contain a `data-section` attribute, so that the block order of every page is unchanged. The static error pages under `public/`, such as the page of `not-found-page`, are outside this requirement: they are served without the shared layout and carry no bar.

#### Scenario: Bar on the home page

- **WHEN** `/` is requested
- **THEN** exactly one `[data-site-bar]` is present before the `main` element, it contains exactly three links, the first points to `/` with the text 折返點 TurnAround, the second points to `https://github.com/kaochenlong/bus-turn-around` with the text GitHub and `target="_blank"`, and the third points to `https://kaochenlong.com/bus-turn-around` with the text 關於這個網站 and `target="_blank"`

#### Scenario: Bar on a route page

- **WHEN** `/routes/9001` is requested and 9001 has no stored days
- **THEN** the response is 200, exactly one `[data-site-bar]` is present, it contains exactly six links, the second points to `/routes/9001/timetable` with the text 班表 and no `aria-current` attribute, the third points to `/routes/9001/dispatch` with the text 當天調度 and no `aria-current` attribute, the fourth points to `/routes/9001/cards` with the text 健檢卡 and no `aria-current` attribute, the fifth points to `https://github.com/kaochenlong/bus-turn-around` with the text GitHub, the sixth points to `https://kaochenlong.com/bus-turn-around` with the text 關於這個網站, and no element with `data-section` is the bar or inside it

#### Scenario: Bar on a timetable page

- **WHEN** `/routes/9001/timetable` is requested
- **THEN** the bar contains exactly six links, its second link points to `/routes/9001/timetable` with `aria-current="page"`, its third link points to `/routes/9001/dispatch` without `aria-current`, and its fourth link points to `/routes/9001/cards` without `aria-current`

#### Scenario: Bar on a day dispatch page

- **WHEN** `/routes/9001/dispatch` is requested
- **THEN** the bar contains exactly six links, its second link points to `/routes/9001/timetable` without `aria-current`, its third link points to `/routes/9001/dispatch` with `aria-current="page"`, and its fourth link points to `/routes/9001/cards` without `aria-current`

#### Scenario: Bar on a month card list

- **WHEN** `/routes/9001/cards` is requested
- **THEN** the bar contains exactly six links and its fourth link points to `/routes/9001/cards` with `aria-current="page"`

#### Scenario: Bar on a month card page

- **WHEN** `/routes/9001/cards/2026-10` is requested and the route card exists
- **THEN** the bar contains exactly six links and its fourth link points to `/routes/9001/cards` with `aria-current="page"`

#### Scenario: Bar on small phones

- **WHEN** a route page is shown on a phone screen 390 px wide, and again on one 360 px wide
- **THEN** the page has no horizontal scrolling and all four route links and the article link are displayed

#### Scenario: Repository link on a phone

- **WHEN** a route page is shown on a phone screen 390 px wide, and again on a screen 1400 px wide
- **THEN** the repository link in the bar is not displayed on the phone screen and is displayed on the 1400 px screen


<!-- @trace
source: 04-monthly-card-pdf
updated: 2026-11-02
code:
  - app/models/route_day_driving_stretch.rb
  - app/components/month_card_history_component.rb
  - app/models/route_page/layover_hours.rb
  - .agents/skills/spectra-apply/SKILL.md
  - AGENTS.md
  - app/components/month_card_layovers_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetTimeTable.gz
  - app/models/route_page/month_card.rb
  - spec/fixtures/analysis/static/2026-10-19/GetSemiTimeTable.gz
  - spec/factories/route_days.rb
  - spec/factories/route_cards.rb
  - app/components/month_card_layovers_component.yml
  - app/models/route_card_local_copy.rb
  - app/components/month_card_hour_share_chart_component.yml
  - app/models/monthly_cards_command.rb
  - app/models/route_day_loader.rb
  - app/models/route_page/rest_windows.rb
  - app/models/route_day_published_departure.rb
  - app/models/route_page/layover_stats.rb
  - app/components/month_card_schedule_component.html.erb
  - app/components/month_card_history_component.yml
  - app/components/month_card_buffer_component.rb
  - app/frontend/stylesheets/application.css
  - app/components/month_card_layovers_component.rb
  - app/models/route_day_published_headway.rb
  - app/views/route_cards/index.html.erb
  - app/components/month_card_list_component.html.erb
  - app/components/month_card_schedule_component.yml
  - app/components/month_card_margin_component.rb
  - app/components/site_bar_component.html.erb
  - analysis/derived_export.sql
  - app/components/month_card_component.rb
  - spec/fixtures/analysis/static/2026-10-23/GetSemiTimeTable.gz
  - app/models/route_page/slow_legs.rb
  - app/components/month_card_cycles_component.html.erb
  - app/components/month_card_summary_component.yml
  - spec/fixtures/analysis/static/2026-10-19/GetTimeTable.gz
  - app/models/route_card_prepare_command.rb
  - app/models/route_page/schedule_comparison.rb
  - app/components/month_card_list_component.yml
  - app/components/month_card_hour_share_chart_component.html.erb
  - app/models/nightly_load_command.rb
  - app/models/route_page/load_profile.rb
  - app/components/month_card_driving_component.html.erb
  - app/components/month_card_distribution_chart_component.rb
  - app/models/route_page/month_days.rb
  - spec/fixtures/analysis/README.md
  - app/components/month_card_run_times_component.rb
  - config/locales/en.yml
  - db/migrate/20261102011500_create_route_day_published_schedule.rb
  - app/components/month_card_schedule_component.rb
  - app/components/month_card_margin_component.html.erb
  - spec/factories/route_day_published_departures.rb
  - app/models/card_months.rb
  - spec/factories/route_day_rest_windows.rb
  - app/components/month_card_attribution_component.rb
  - app/components/month_card_history_component.html.erb
  - app/components/attribution_component.yml
  - app/components/month_card_chart_component.rb
  - app/models/route_page/month_findings.rb
  - app/components/month_card_driving_component.yml
  - config/routes.rb
  - app/components/month_card_run_times_component.yml
  - app/components/month_card_driving_component.rb
  - app/components/month_card_run_times_component.html.erb
  - app/components/month_card_buffer_component.html.erb
  - app/models/route_page/snapshot_changes.rb
  - db/migrate/20261102054500_add_printed_card_to_route_cards.rb
  - app/components/month_card_cycles_component.rb
  - spec/factories/trips.rb
  - app/components/month_card_cycles_component.yml
  - app/components/month_card_hour_chart_component.rb
  - app/models/route_card_coverage.rb
  - docs/data-sources.md
  - db/migrate/20261102030000_create_route_cards.rb
  - app/components/site_bar_component.rb
  - app/views/layouts/application.html.erb
  - db/migrate/20261101220000_create_route_day_rest_windows.rb
  - app/components/site_bar_component.yml
  - app/models/route_page/mrt_overlap.rb
  - app/components/month_card_attribution_component.html.erb
  - app/components/month_card_summary_component.rb
  - app/components/month_card_margin_component.yml
  - docs/decisions.md
  - app/models/route_card_pdf.rb
  - app/models/production_session.rb
  - analysis/30_layovers.sql
  - app/components/month_card_hour_chart_component.html.erb
  - app/models/program_version.rb
  - .github/skills/spectra-apply/SKILL.md
  - spec/factories/route_day_published_headways.rb
  - app/models/route_page/format.rb
  - app/components/month_card_attribution_component.yml
  - app/models/route_page/card_trend.rb
  - app/models/route_page/layover_distribution.rb
  - app/views/route_cards/show.html.erb
  - spec/factories/route_day_driving_stretches.rb
  - db/schema.rb
  - bin/health-card
  - analysis/README.md
  - app/components/month_card_buffer_component.yml
  - app/components/month_card_distribution_chart_component.html.erb
  - app/components/month_card_distribution_chart_component.yml
  - app/models/route_card.rb
  - analysis/published_schedule.sql
  - app/components/month_card_summary_component.html.erb
  - app/models/route_day.rb
  - app/models/route_day_rest_window.rb
  - config/locales/tw.yml
  - app/components/month_card_hour_share_chart_component.rb
  - lib/tasks/cards.rake
  - config/route_cards.yml
  - spec/factories/layovers.rb
  - analysis/params.sql
  - app/models/card_printer.rb
  - bin/monthly-cards
  - app/components/month_card_list_component.rb
  - app/controllers/route_cards_controller.rb
tests:
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_card_prepare_command_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/models/route_page/month_days_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/models/route_day_rest_window_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/analysis/params_spec.rb
  - spec/components/month_card_buffer_component_spec.rb
  - spec/models/route_day_published_headway_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/models/route_page/slow_legs_spec.rb
  - spec/system/month_card_print_spec.rb
  - spec/models/production_session_spec.rb
  - spec/models/route_page/month_findings_spec.rb
  - spec/components/month_card_margin_component_spec.rb
  - spec/components/month_card_hour_chart_component_spec.rb
  - spec/models/nightly_load_command_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/models/route_page/rest_windows_spec.rb
  - spec/components/month_card_summary_component_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/components/month_card_driving_component_spec.rb
  - spec/models/route_page/month_card_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/models/card_printer_spec.rb
  - spec/models/route_card_local_copy_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/models/route_page/schedule_comparison_spec.rb
  - spec/models/program_version_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/route_day_published_departure_spec.rb
  - spec/models/route_day_driving_stretch_spec.rb
  - spec/analysis/published_schedule_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/requests/route_cards_spec.rb
  - spec/components/month_card_layovers_component_spec.rb
  - spec/models/monthly_cards_command_spec.rb
  - spec/components/month_card_run_times_component_spec.rb
  - spec/models/route_card_coverage_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/route_page/snapshot_changes_spec.rb
  - spec/components/month_card_cycles_component_spec.rb
  - spec/models/route_day_spec.rb
  - spec/components/month_card_history_component_spec.rb
  - spec/models/card_months_spec.rb
  - spec/components/month_card_attribution_component_spec.rb
  - spec/components/month_card_schedule_component_spec.rb
  - spec/models/route_card_spec.rb
  - spec/models/route_page/card_trend_spec.rb
  - spec/components/month_card_list_component_spec.rb
  - spec/models/route_page/layover_hours_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
-->

---
### Requirement: Share description follows the page

Every page SHALL carry three description metas, `description`, `og:description` and `twitter:description`, with the same content: the page's own description when the page sets one, otherwise the site description from the locale file. On every page the `og:url` meta SHALL be the requested URL, the `og:site_name` meta the site name, and the `og:image` meta the site's share image. The static error pages under `public/` are outside this requirement, as they are served without the shared layout.

#### Scenario: Home page descriptions

- **WHEN** `/` is requested
- **THEN** the `description`, `og:description` and `twitter:description` metas are all the site description from the locale file

#### Scenario: Route page without stored days

- **WHEN** `/routes/9001` is requested and 9001 has no stored days
- **THEN** the response is 200 and the three description metas are all the site description from the locale file

#### Scenario: Route page with data

- **WHEN** `/routes/9001` is requested and the selected day is stored
- **THEN** the three description metas are all the share text that `route-page` defines for that page, and none of them is the site description

<!-- @trace
source: share-preview-home-figure
updated: 2026-10-25
code:
  - app/models/route_page/format.rb
  - app/models/route_page/share_preview.rb
  - config/locales/tw.yml
  - app/models/home_page/stop_end_figures.rb
  - app/components/route_list_component.yml
  - app/components/application_component.rb
  - app/controllers/pages_controller.rb
  - config/locales/en.yml
  - app/views/routes/show.html.erb
  - app/components/route_list_component.rb
  - app/models/home_page/route_list.rb
  - app/views/layouts/application.html.erb
  - app/components/route_list_component.html.erb
  - app/models/route_page/layover_stats.rb
tests:
  - spec/requests/routes_spec.rb
  - spec/models/route_page/format_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/components/route_list_component_spec.rb
  - spec/models/home_page/stop_end_figures_spec.rb
  - spec/requests/pages_spec.rb
  - spec/models/route_page/share_preview_spec.rb
  - spec/models/home_page/route_list_spec.rb
-->