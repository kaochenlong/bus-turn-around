# monthly-card Specification

## Purpose

A printable health card for one route and one month: which days it covers, its figures on driver rest and on the published schedule, and how they compare with earlier months. It exists so that a route's month can be read, printed and cited as one document, and so that the history the feeds do not keep has a place to accumulate.

## Requirements

### Requirement: Route card row for a month

The system SHALL store a route card as one row of `route_cards`, keyed uniquely by `route_id`, `month` (the first day of the month) and `version` (1 by default), carrying the month's coverage. The table SHALL NOT reference `route_days`, so that `bin/push-derived` does not treat it as a derived table.

#### Scenario: Not a derived table

- **WHEN** `bin/push-derived` lists the derived tables
- **THEN** `route_cards` is not among them

#### Scenario: One row per version

- **WHEN** a second row is created with the same `route_id`, `month` and `version`
- **THEN** the database refuses it


<!-- @trace
source: 03-monthly-card
updated: 2026-11-02
code:
  - app/components/month_card_driving_component.yml
  - spec/fixtures/analysis/README.md
  - lib/tasks/cards.rake
  - app/components/month_card_component.rb
  - spec/factories/route_day_rest_windows.rb
  - app/components/month_card_hour_chart_component.rb
  - spec/fixtures/analysis/static/2026-10-19/GetSemiTimeTable.gz
  - app/components/month_card_margin_component.rb
  - spec/factories/route_day_published_departures.rb
  - app/components/month_card_attribution_component.rb
  - app/models/route_card.rb
  - app/models/route_page/slow_legs.rb
  - app/components/month_card_distribution_chart_component.yml
  - app/models/route_page/schedule_comparison.rb
  - app/models/route_day_published_headway.rb
  - app/components/month_card_buffer_component.rb
  - app/components/month_card_cycles_component.rb
  - app/components/month_card_layovers_component.rb
  - app/controllers/route_cards_controller.rb
  - db/schema.rb
  - app/components/month_card_history_component.rb
  - db/migrate/20261102011500_create_route_day_published_schedule.rb
  - .agents/skills/spectra-apply/SKILL.md
  - app/components/month_card_hour_share_chart_component.rb
  - app/components/attribution_component.yml
  - app/components/month_card_layovers_component.yml
  - analysis/README.md
  - app/components/month_card_attribution_component.yml
  - app/components/month_card_history_component.html.erb
  - app/components/month_card_summary_component.html.erb
  - app/models/route_card_prepare_command.rb
  - app/components/month_card_margin_component.yml
  - config/routes.rb
  - spec/factories/route_cards.rb
  - app/components/month_card_run_times_component.rb
  - app/components/month_card_cycles_component.html.erb
  - app/components/month_card_schedule_component.yml
  - app/models/route_page/layover_hours.rb
  - spec/factories/route_day_driving_stretches.rb
  - app/models/route_page/load_profile.rb
  - config/locales/en.yml
  - spec/factories/route_days.rb
  - app/models/route_day_driving_stretch.rb
  - app/models/route_page/card_trend.rb
  - app/models/route_page/mrt_overlap.rb
  - app/components/month_card_driving_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetSemiTimeTable.gz
  - app/components/month_card_buffer_component.yml
  - spec/fixtures/analysis/static/2026-10-19/GetTimeTable.gz
  - app/components/month_card_margin_component.html.erb
  - app/components/month_card_distribution_chart_component.rb
  - app/models/route_page/format.rb
  - app/models/route_page/layover_distribution.rb
  - db/migrate/20261102030000_create_route_cards.rb
  - app/views/route_cards/show.html.erb
  - app/components/month_card_attribution_component.html.erb
  - app/components/month_card_hour_share_chart_component.html.erb
  - analysis/published_schedule.sql
  - app/components/month_card_chart_component.rb
  - app/components/month_card_driving_component.rb
  - db/migrate/20261101220000_create_route_day_rest_windows.rb
  - app/models/route_page/month_days.rb
  - app/components/month_card_hour_chart_component.html.erb
  - app/components/month_card_run_times_component.yml
  - app/components/month_card_summary_component.rb
  - app/models/route_day_loader.rb
  - app/components/month_card_run_times_component.html.erb
  - app/components/month_card_layovers_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetTimeTable.gz
  - app/components/month_card_cycles_component.yml
  - app/models/route_day_published_departure.rb
  - app/models/route_page/month_card.rb
  - app/components/month_card_history_component.yml
  - analysis/30_layovers.sql
  - config/locales/tw.yml
  - analysis/params.sql
  - docs/data-sources.md
  - analysis/derived_export.sql
  - spec/factories/route_day_published_headways.rb
  - app/components/month_card_distribution_chart_component.html.erb
  - app/components/month_card_hour_share_chart_component.yml
  - app/frontend/stylesheets/application.css
  - app/models/program_version.rb
  - app/models/route_page/snapshot_changes.rb
  - spec/factories/layovers.rb
  - spec/factories/trips.rb
  - .github/skills/spectra-apply/SKILL.md
  - app/components/month_card_buffer_component.html.erb
  - app/models/route_day_rest_window.rb
  - app/models/route_card_coverage.rb
  - app/models/route_page/layover_stats.rb
  - app/models/route_page/rest_windows.rb
  - app/components/month_card_summary_component.yml
  - bin/health-card
  - app/components/month_card_schedule_component.rb
  - app/models/route_day.rb
  - app/components/month_card_schedule_component.html.erb
  - app/models/route_page/month_findings.rb
tests:
  - spec/system/month_card_print_spec.rb
  - spec/analysis/published_schedule_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/route_page/schedule_comparison_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/models/route_card_prepare_command_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_page/card_trend_spec.rb
  - spec/components/month_card_history_component_spec.rb
  - spec/components/month_card_summary_component_spec.rb
  - spec/models/route_page/snapshot_changes_spec.rb
  - spec/models/route_card_coverage_spec.rb
  - spec/models/route_day_published_departure_spec.rb
  - spec/components/month_card_buffer_component_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/route_page/month_findings_spec.rb
  - spec/models/route_day_rest_window_spec.rb
  - spec/models/route_page/layover_hours_spec.rb
  - spec/components/month_card_driving_component_spec.rb
  - spec/components/month_card_attribution_component_spec.rb
  - spec/models/program_version_spec.rb
  - spec/models/route_page/slow_legs_spec.rb
  - spec/analysis/params_spec.rb
  - spec/components/month_card_run_times_component_spec.rb
  - spec/components/month_card_margin_component_spec.rb
  - spec/models/route_day_published_headway_spec.rb
  - spec/components/month_card_hour_chart_component_spec.rb
  - spec/components/month_card_cycles_component_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/components/month_card_schedule_component_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/models/route_page/rest_windows_spec.rb
  - spec/models/route_page/month_card_spec.rb
  - spec/models/route_page/month_days_spec.rb
  - spec/requests/route_cards_spec.rb
  - spec/components/month_card_layovers_component_spec.rb
  - spec/models/route_card_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/models/route_day_driving_stretch_spec.rb
-->

---
### Requirement: Coverage of a month

The system SHALL classify every day of the month for a route as loaded when the route day is stored; missing with the reason 還沒開始收資料 when it is before `first_day` of `config/derived_days.yml`; missing with the configured reason when it is in `skipped_days`; missing with the reason 原始檔不齊 when its read window has ended and `RawDayCheck` fails for it; and waiting in every other case. The coverage SHALL be ready when no day is waiting. It SHALL report the month's weekdays and holidays according to the office calendar, the loaded weekdays and holidays, and the missing days with adjacent days of the same reason merged. A month SHALL be partial when its loaded weekdays are fewer than 90% of its calendar weekdays.

#### Scenario: A month with every kind of missing day

- **WHEN** the coverage of route 15373 for 2026-10 is computed with `first_day` 2026-10-19, 2026-10-23 and 2026-10-24 skipped, 2026-10-30 failing `RawDayCheck`, and every other day from 2026-10-19 to 2026-10-31 stored
- **THEN** it is ready and partial, with 20 calendar weekdays, 11 calendar holidays, 7 loaded weekdays and 3 loaded holidays, and the missing entries are 2026-10-01 to 2026-10-18 還沒開始收資料, 2026-10-23 to 2026-10-24 with the configured reason, and 2026-10-30 原始檔不齊

#### Scenario: Raw files fine but the day not stored

- **WHEN** a past day of the month passes `RawDayCheck`, is not skipped and has no stored route day
- **THEN** the day is waiting and the coverage is not ready

#### Scenario: A day whose read window has not ended

- **WHEN** the month's last day is 2026-11-30 and the current Taipei time is 2026-12-01 01:30
- **THEN** 2026-11-30 is waiting and the coverage is not ready

##### Example: Partial or not

| Calendar weekdays | Loaded weekdays | Partial |
| --- | --- | --- |
| 21 | 20 | no |
| 20 | 18 | no |
| 21 | 18 | yes |
| 20 | 7 | yes |


<!-- @trace
source: 03-monthly-card
updated: 2026-11-02
code:
  - app/components/month_card_driving_component.yml
  - spec/fixtures/analysis/README.md
  - lib/tasks/cards.rake
  - app/components/month_card_component.rb
  - spec/factories/route_day_rest_windows.rb
  - app/components/month_card_hour_chart_component.rb
  - spec/fixtures/analysis/static/2026-10-19/GetSemiTimeTable.gz
  - app/components/month_card_margin_component.rb
  - spec/factories/route_day_published_departures.rb
  - app/components/month_card_attribution_component.rb
  - app/models/route_card.rb
  - app/models/route_page/slow_legs.rb
  - app/components/month_card_distribution_chart_component.yml
  - app/models/route_page/schedule_comparison.rb
  - app/models/route_day_published_headway.rb
  - app/components/month_card_buffer_component.rb
  - app/components/month_card_cycles_component.rb
  - app/components/month_card_layovers_component.rb
  - app/controllers/route_cards_controller.rb
  - db/schema.rb
  - app/components/month_card_history_component.rb
  - db/migrate/20261102011500_create_route_day_published_schedule.rb
  - .agents/skills/spectra-apply/SKILL.md
  - app/components/month_card_hour_share_chart_component.rb
  - app/components/attribution_component.yml
  - app/components/month_card_layovers_component.yml
  - analysis/README.md
  - app/components/month_card_attribution_component.yml
  - app/components/month_card_history_component.html.erb
  - app/components/month_card_summary_component.html.erb
  - app/models/route_card_prepare_command.rb
  - app/components/month_card_margin_component.yml
  - config/routes.rb
  - spec/factories/route_cards.rb
  - app/components/month_card_run_times_component.rb
  - app/components/month_card_cycles_component.html.erb
  - app/components/month_card_schedule_component.yml
  - app/models/route_page/layover_hours.rb
  - spec/factories/route_day_driving_stretches.rb
  - app/models/route_page/load_profile.rb
  - config/locales/en.yml
  - spec/factories/route_days.rb
  - app/models/route_day_driving_stretch.rb
  - app/models/route_page/card_trend.rb
  - app/models/route_page/mrt_overlap.rb
  - app/components/month_card_driving_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetSemiTimeTable.gz
  - app/components/month_card_buffer_component.yml
  - spec/fixtures/analysis/static/2026-10-19/GetTimeTable.gz
  - app/components/month_card_margin_component.html.erb
  - app/components/month_card_distribution_chart_component.rb
  - app/models/route_page/format.rb
  - app/models/route_page/layover_distribution.rb
  - db/migrate/20261102030000_create_route_cards.rb
  - app/views/route_cards/show.html.erb
  - app/components/month_card_attribution_component.html.erb
  - app/components/month_card_hour_share_chart_component.html.erb
  - analysis/published_schedule.sql
  - app/components/month_card_chart_component.rb
  - app/components/month_card_driving_component.rb
  - db/migrate/20261101220000_create_route_day_rest_windows.rb
  - app/models/route_page/month_days.rb
  - app/components/month_card_hour_chart_component.html.erb
  - app/components/month_card_run_times_component.yml
  - app/components/month_card_summary_component.rb
  - app/models/route_day_loader.rb
  - app/components/month_card_run_times_component.html.erb
  - app/components/month_card_layovers_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetTimeTable.gz
  - app/components/month_card_cycles_component.yml
  - app/models/route_day_published_departure.rb
  - app/models/route_page/month_card.rb
  - app/components/month_card_history_component.yml
  - analysis/30_layovers.sql
  - config/locales/tw.yml
  - analysis/params.sql
  - docs/data-sources.md
  - analysis/derived_export.sql
  - spec/factories/route_day_published_headways.rb
  - app/components/month_card_distribution_chart_component.html.erb
  - app/components/month_card_hour_share_chart_component.yml
  - app/frontend/stylesheets/application.css
  - app/models/program_version.rb
  - app/models/route_page/snapshot_changes.rb
  - spec/factories/layovers.rb
  - spec/factories/trips.rb
  - .github/skills/spectra-apply/SKILL.md
  - app/components/month_card_buffer_component.html.erb
  - app/models/route_day_rest_window.rb
  - app/models/route_card_coverage.rb
  - app/models/route_page/layover_stats.rb
  - app/models/route_page/rest_windows.rb
  - app/components/month_card_summary_component.yml
  - bin/health-card
  - app/components/month_card_schedule_component.rb
  - app/models/route_day.rb
  - app/components/month_card_schedule_component.html.erb
  - app/models/route_page/month_findings.rb
tests:
  - spec/system/month_card_print_spec.rb
  - spec/analysis/published_schedule_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/route_page/schedule_comparison_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/models/route_card_prepare_command_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_page/card_trend_spec.rb
  - spec/components/month_card_history_component_spec.rb
  - spec/components/month_card_summary_component_spec.rb
  - spec/models/route_page/snapshot_changes_spec.rb
  - spec/models/route_card_coverage_spec.rb
  - spec/models/route_day_published_departure_spec.rb
  - spec/components/month_card_buffer_component_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/route_page/month_findings_spec.rb
  - spec/models/route_day_rest_window_spec.rb
  - spec/models/route_page/layover_hours_spec.rb
  - spec/components/month_card_driving_component_spec.rb
  - spec/components/month_card_attribution_component_spec.rb
  - spec/models/program_version_spec.rb
  - spec/models/route_page/slow_legs_spec.rb
  - spec/analysis/params_spec.rb
  - spec/components/month_card_run_times_component_spec.rb
  - spec/components/month_card_margin_component_spec.rb
  - spec/models/route_day_published_headway_spec.rb
  - spec/components/month_card_hour_chart_component_spec.rb
  - spec/components/month_card_cycles_component_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/components/month_card_schedule_component_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/models/route_page/rest_windows_spec.rb
  - spec/models/route_page/month_card_spec.rb
  - spec/models/route_page/month_days_spec.rb
  - spec/requests/route_cards_spec.rb
  - spec/components/month_card_layovers_component_spec.rb
  - spec/models/route_card_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/models/route_day_driving_stretch_spec.rb
-->

---
### Requirement: Preparing a route card

The system SHALL provide the rake task `cards:prepare` taking `ROUTE` (a page route `Id`) and `MONTH` (`YYYY-MM`), with the raw data root from `TURNAROUND_DATA`. It SHALL print the month's coverage. When the coverage is ready it SHALL create version 1 of the route card or update that version's coverage, and exit with status 0. When a day is waiting it SHALL name the waiting days, write nothing and exit with a non-zero status. A `ROUTE` that is a member route or not a page route, a malformed `MONTH`, or a missing `TURNAROUND_DATA` SHALL print the usage and exit with a non-zero status. A month with a version printed as defined by `monthly-card-pdf` SHALL be refused: the task SHALL say so, point to `--revise`, write nothing and exit with a non-zero status.

#### Scenario: Ready month

- **WHEN** `cards:prepare ROUTE=9001 MONTH=2026-10` runs and no day is waiting
- **THEN** version 1 of the route card exists with that coverage and the exit status is 0

#### Scenario: Waiting days

- **WHEN** a day of the month is waiting
- **THEN** the output names that day, no row is written and the exit status is non-zero

#### Scenario: Member route

- **WHEN** `ROUTE` is listed under another route's `member_routes`
- **THEN** the usage names the page route and the exit status is non-zero

#### Scenario: Preparing a printed month

- **WHEN** `cards:prepare ROUTE=15373 MONTH=2026-11` runs and version 1 of that month is printed
- **THEN** the output says the month is printed and points to `--revise`, the row is unchanged and the exit status is non-zero


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
### Requirement: Month card page

The system SHALL serve the month card of a page route and month at `/routes/<Id>/cards/<YYYY-MM>`, using the highest version of its route card, with a `main[data-month-card]` that holds the blocks marked by `data-card-section` in this order: `summary`, `layovers`, `driving`, `schedule`, `cycles`, `run-times`, `buffer`, `history`, `attribution`. The response SHALL be 404 when the route is not a page route, when the month has no route card, or when the month is malformed. The document title SHALL be 路線名 健檢卡 YYYY 年 M 月 followed by the site name after the separator ｜, and the page SHALL carry a `robots` meta of `noindex`. The page SHALL carry a `turnaround-card` meta holding the route `Id`, the month and the version joined by `/`, a `turnaround-program-version` meta holding the short commit of the running program, and a `turnaround-card-summary` meta holding, as JSON, what the route card stores as its summary. The page SHALL NOT contain any `BusID` value and SHALL NOT state that anything complies or fails to comply with a rule. When rest windows or the published schedule of a covered day need loading again, the page SHALL say at its top, in an element marked `data-card-incomplete`, that those figures are incomplete.

#### Scenario: Blocks in order

- **WHEN** `/routes/9001/cards/2026-10` is requested and the route card exists
- **THEN** the response is 200 and the `data-card-section` values appear in the listed order, each exactly once

#### Scenario: Which card the page is

- **WHEN** `/routes/9001/cards/2026-10` is requested and the highest version of that month's route card is 2
- **THEN** the `turnaround-card` meta is 9001/2026-10/2, and the `turnaround-card-summary` meta parses to the month card's summary

#### Scenario: No route card

- **WHEN** `/routes/9001/cards/2026-11` is requested and that month has no route card
- **THEN** the response is 404

#### Scenario: Route without a page

- **WHEN** `/routes/19108/cards/2026-10` is requested and 19108 is a member route
- **THEN** the response is 404

#### Scenario: Malformed month

- **WHEN** `/routes/9001/cards/2026-13` is requested
- **THEN** the response is 404

#### Scenario: Plates and verdicts

- **WHEN** the page of a route whose vehicles include TEST-0001 is requested
- **THEN** `main[data-month-card]` does not contain TEST-0001, 不合規 or 違規

#### Scenario: Days not loaded again

- **WHEN** one covered route day has `rest_windows_loaded` false
- **THEN** the page says at its top, in an element marked `data-card-incomplete`, that the figures are incomplete


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
### Requirement: Month card printing

When the page is printed, each page SHALL be A4 in portrait, the site name bar and the layout's attribution footer SHALL NOT appear, and the page margin SHALL carry the route name, the month and, for a partial month, 部分月份, together with the page number and the number of pages.

#### Scenario: Print media

- **WHEN** the page is shown with the print media type
- **THEN** `[data-site-bar]` and the layout's `footer[data-attribution]` are not displayed and `[data-card-section="attribution"]` is displayed

#### Scenario: Paper

- **WHEN** the page is printed with the page size the page itself asks for
- **THEN** the first page of the result is A4 in portrait


<!-- @trace
source: 03-monthly-card
updated: 2026-11-02
code:
  - app/components/month_card_driving_component.yml
  - spec/fixtures/analysis/README.md
  - lib/tasks/cards.rake
  - app/components/month_card_component.rb
  - spec/factories/route_day_rest_windows.rb
  - app/components/month_card_hour_chart_component.rb
  - spec/fixtures/analysis/static/2026-10-19/GetSemiTimeTable.gz
  - app/components/month_card_margin_component.rb
  - spec/factories/route_day_published_departures.rb
  - app/components/month_card_attribution_component.rb
  - app/models/route_card.rb
  - app/models/route_page/slow_legs.rb
  - app/components/month_card_distribution_chart_component.yml
  - app/models/route_page/schedule_comparison.rb
  - app/models/route_day_published_headway.rb
  - app/components/month_card_buffer_component.rb
  - app/components/month_card_cycles_component.rb
  - app/components/month_card_layovers_component.rb
  - app/controllers/route_cards_controller.rb
  - db/schema.rb
  - app/components/month_card_history_component.rb
  - db/migrate/20261102011500_create_route_day_published_schedule.rb
  - .agents/skills/spectra-apply/SKILL.md
  - app/components/month_card_hour_share_chart_component.rb
  - app/components/attribution_component.yml
  - app/components/month_card_layovers_component.yml
  - analysis/README.md
  - app/components/month_card_attribution_component.yml
  - app/components/month_card_history_component.html.erb
  - app/components/month_card_summary_component.html.erb
  - app/models/route_card_prepare_command.rb
  - app/components/month_card_margin_component.yml
  - config/routes.rb
  - spec/factories/route_cards.rb
  - app/components/month_card_run_times_component.rb
  - app/components/month_card_cycles_component.html.erb
  - app/components/month_card_schedule_component.yml
  - app/models/route_page/layover_hours.rb
  - spec/factories/route_day_driving_stretches.rb
  - app/models/route_page/load_profile.rb
  - config/locales/en.yml
  - spec/factories/route_days.rb
  - app/models/route_day_driving_stretch.rb
  - app/models/route_page/card_trend.rb
  - app/models/route_page/mrt_overlap.rb
  - app/components/month_card_driving_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetSemiTimeTable.gz
  - app/components/month_card_buffer_component.yml
  - spec/fixtures/analysis/static/2026-10-19/GetTimeTable.gz
  - app/components/month_card_margin_component.html.erb
  - app/components/month_card_distribution_chart_component.rb
  - app/models/route_page/format.rb
  - app/models/route_page/layover_distribution.rb
  - db/migrate/20261102030000_create_route_cards.rb
  - app/views/route_cards/show.html.erb
  - app/components/month_card_attribution_component.html.erb
  - app/components/month_card_hour_share_chart_component.html.erb
  - analysis/published_schedule.sql
  - app/components/month_card_chart_component.rb
  - app/components/month_card_driving_component.rb
  - db/migrate/20261101220000_create_route_day_rest_windows.rb
  - app/models/route_page/month_days.rb
  - app/components/month_card_hour_chart_component.html.erb
  - app/components/month_card_run_times_component.yml
  - app/components/month_card_summary_component.rb
  - app/models/route_day_loader.rb
  - app/components/month_card_run_times_component.html.erb
  - app/components/month_card_layovers_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetTimeTable.gz
  - app/components/month_card_cycles_component.yml
  - app/models/route_day_published_departure.rb
  - app/models/route_page/month_card.rb
  - app/components/month_card_history_component.yml
  - analysis/30_layovers.sql
  - config/locales/tw.yml
  - analysis/params.sql
  - docs/data-sources.md
  - analysis/derived_export.sql
  - spec/factories/route_day_published_headways.rb
  - app/components/month_card_distribution_chart_component.html.erb
  - app/components/month_card_hour_share_chart_component.yml
  - app/frontend/stylesheets/application.css
  - app/models/program_version.rb
  - app/models/route_page/snapshot_changes.rb
  - spec/factories/layovers.rb
  - spec/factories/trips.rb
  - .github/skills/spectra-apply/SKILL.md
  - app/components/month_card_buffer_component.html.erb
  - app/models/route_day_rest_window.rb
  - app/models/route_card_coverage.rb
  - app/models/route_page/layover_stats.rb
  - app/models/route_page/rest_windows.rb
  - app/components/month_card_summary_component.yml
  - bin/health-card
  - app/components/month_card_schedule_component.rb
  - app/models/route_day.rb
  - app/components/month_card_schedule_component.html.erb
  - app/models/route_page/month_findings.rb
tests:
  - spec/system/month_card_print_spec.rb
  - spec/analysis/published_schedule_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/route_page/schedule_comparison_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/models/route_card_prepare_command_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_page/card_trend_spec.rb
  - spec/components/month_card_history_component_spec.rb
  - spec/components/month_card_summary_component_spec.rb
  - spec/models/route_page/snapshot_changes_spec.rb
  - spec/models/route_card_coverage_spec.rb
  - spec/models/route_day_published_departure_spec.rb
  - spec/components/month_card_buffer_component_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/route_page/month_findings_spec.rb
  - spec/models/route_day_rest_window_spec.rb
  - spec/models/route_page/layover_hours_spec.rb
  - spec/components/month_card_driving_component_spec.rb
  - spec/components/month_card_attribution_component_spec.rb
  - spec/models/program_version_spec.rb
  - spec/models/route_page/slow_legs_spec.rb
  - spec/analysis/params_spec.rb
  - spec/components/month_card_run_times_component_spec.rb
  - spec/components/month_card_margin_component_spec.rb
  - spec/models/route_day_published_headway_spec.rb
  - spec/components/month_card_hour_chart_component_spec.rb
  - spec/components/month_card_cycles_component_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/components/month_card_schedule_component_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/models/route_page/rest_windows_spec.rb
  - spec/models/route_page/month_card_spec.rb
  - spec/models/route_page/month_days_spec.rb
  - spec/requests/route_cards_spec.rb
  - spec/components/month_card_layovers_component_spec.rb
  - spec/models/route_card_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/models/route_day_driving_stretch_spec.rb
-->

---
### Requirement: Summary block

The `summary` block SHALL show the route name, its departure and destination, the route `Id`s, the operators of the latest covered day, the month, the coverage with its missing days and reasons, the generation day and the program version. Its table SHALL have the columns weekdays, holidays and last month's weekdays, and for each stopping end the share of layovers under 15 minutes, its daily range, and p10 and p50; for each rest rule the share of flagged windows with its numerator and denominator; for the periods with the smallest low headway, the published headway, the measured departures per hour of each direction, the vehicles on the road and the vehicles needed; and the round trip p50 and the cycle p10. A figure with no data, and last month's column when that month has no route card, SHALL show —.

#### Scenario: Coverage sentence

- **WHEN** the card of 2026-10 has the coverage of the scenario "A month with every kind of missing day"
- **THEN** the block says 涵蓋 7 個平日（這個月有 20 個）、3 個假日（這個月有 11 個） and names 10-01 到 10-18 還沒開始收資料 and 10-30 原始檔不齊

#### Scenario: Two stopping ends

- **WHEN** both ends of the route are stopping ends
- **THEN** the table has one layover group per stopping end, each named after its last stop

#### Scenario: Last month's column

- **WHEN** the previous month has a route card with a weekday short share of 40.0%
- **THEN** the last-month column of that row shows 40.0%

#### Scenario: A month without holidays stored

- **WHEN** no holiday of the month is stored
- **THEN** every figure in the holiday column shows —


<!-- @trace
source: 03-monthly-card
updated: 2026-11-02
code:
  - app/components/month_card_driving_component.yml
  - spec/fixtures/analysis/README.md
  - lib/tasks/cards.rake
  - app/components/month_card_component.rb
  - spec/factories/route_day_rest_windows.rb
  - app/components/month_card_hour_chart_component.rb
  - spec/fixtures/analysis/static/2026-10-19/GetSemiTimeTable.gz
  - app/components/month_card_margin_component.rb
  - spec/factories/route_day_published_departures.rb
  - app/components/month_card_attribution_component.rb
  - app/models/route_card.rb
  - app/models/route_page/slow_legs.rb
  - app/components/month_card_distribution_chart_component.yml
  - app/models/route_page/schedule_comparison.rb
  - app/models/route_day_published_headway.rb
  - app/components/month_card_buffer_component.rb
  - app/components/month_card_cycles_component.rb
  - app/components/month_card_layovers_component.rb
  - app/controllers/route_cards_controller.rb
  - db/schema.rb
  - app/components/month_card_history_component.rb
  - db/migrate/20261102011500_create_route_day_published_schedule.rb
  - .agents/skills/spectra-apply/SKILL.md
  - app/components/month_card_hour_share_chart_component.rb
  - app/components/attribution_component.yml
  - app/components/month_card_layovers_component.yml
  - analysis/README.md
  - app/components/month_card_attribution_component.yml
  - app/components/month_card_history_component.html.erb
  - app/components/month_card_summary_component.html.erb
  - app/models/route_card_prepare_command.rb
  - app/components/month_card_margin_component.yml
  - config/routes.rb
  - spec/factories/route_cards.rb
  - app/components/month_card_run_times_component.rb
  - app/components/month_card_cycles_component.html.erb
  - app/components/month_card_schedule_component.yml
  - app/models/route_page/layover_hours.rb
  - spec/factories/route_day_driving_stretches.rb
  - app/models/route_page/load_profile.rb
  - config/locales/en.yml
  - spec/factories/route_days.rb
  - app/models/route_day_driving_stretch.rb
  - app/models/route_page/card_trend.rb
  - app/models/route_page/mrt_overlap.rb
  - app/components/month_card_driving_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetSemiTimeTable.gz
  - app/components/month_card_buffer_component.yml
  - spec/fixtures/analysis/static/2026-10-19/GetTimeTable.gz
  - app/components/month_card_margin_component.html.erb
  - app/components/month_card_distribution_chart_component.rb
  - app/models/route_page/format.rb
  - app/models/route_page/layover_distribution.rb
  - db/migrate/20261102030000_create_route_cards.rb
  - app/views/route_cards/show.html.erb
  - app/components/month_card_attribution_component.html.erb
  - app/components/month_card_hour_share_chart_component.html.erb
  - analysis/published_schedule.sql
  - app/components/month_card_chart_component.rb
  - app/components/month_card_driving_component.rb
  - db/migrate/20261101220000_create_route_day_rest_windows.rb
  - app/models/route_page/month_days.rb
  - app/components/month_card_hour_chart_component.html.erb
  - app/components/month_card_run_times_component.yml
  - app/components/month_card_summary_component.rb
  - app/models/route_day_loader.rb
  - app/components/month_card_run_times_component.html.erb
  - app/components/month_card_layovers_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetTimeTable.gz
  - app/components/month_card_cycles_component.yml
  - app/models/route_day_published_departure.rb
  - app/models/route_page/month_card.rb
  - app/components/month_card_history_component.yml
  - analysis/30_layovers.sql
  - config/locales/tw.yml
  - analysis/params.sql
  - docs/data-sources.md
  - analysis/derived_export.sql
  - spec/factories/route_day_published_headways.rb
  - app/components/month_card_distribution_chart_component.html.erb
  - app/components/month_card_hour_share_chart_component.yml
  - app/frontend/stylesheets/application.css
  - app/models/program_version.rb
  - app/models/route_page/snapshot_changes.rb
  - spec/factories/layovers.rb
  - spec/factories/trips.rb
  - .github/skills/spectra-apply/SKILL.md
  - app/components/month_card_buffer_component.html.erb
  - app/models/route_day_rest_window.rb
  - app/models/route_card_coverage.rb
  - app/models/route_page/layover_stats.rb
  - app/models/route_page/rest_windows.rb
  - app/components/month_card_summary_component.yml
  - bin/health-card
  - app/components/month_card_schedule_component.rb
  - app/models/route_day.rb
  - app/components/month_card_schedule_component.html.erb
  - app/models/route_page/month_findings.rb
tests:
  - spec/system/month_card_print_spec.rb
  - spec/analysis/published_schedule_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/route_page/schedule_comparison_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/models/route_card_prepare_command_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_page/card_trend_spec.rb
  - spec/components/month_card_history_component_spec.rb
  - spec/components/month_card_summary_component_spec.rb
  - spec/models/route_page/snapshot_changes_spec.rb
  - spec/models/route_card_coverage_spec.rb
  - spec/models/route_day_published_departure_spec.rb
  - spec/components/month_card_buffer_component_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/route_page/month_findings_spec.rb
  - spec/models/route_day_rest_window_spec.rb
  - spec/models/route_page/layover_hours_spec.rb
  - spec/components/month_card_driving_component_spec.rb
  - spec/components/month_card_attribution_component_spec.rb
  - spec/models/program_version_spec.rb
  - spec/models/route_page/slow_legs_spec.rb
  - spec/analysis/params_spec.rb
  - spec/components/month_card_run_times_component_spec.rb
  - spec/components/month_card_margin_component_spec.rb
  - spec/models/route_day_published_headway_spec.rb
  - spec/components/month_card_hour_chart_component_spec.rb
  - spec/components/month_card_cycles_component_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/components/month_card_schedule_component_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/models/route_page/rest_windows_spec.rb
  - spec/models/route_page/month_card_spec.rb
  - spec/models/route_page/month_days_spec.rb
  - spec/requests/route_cards_spec.rb
  - spec/components/month_card_layovers_component_spec.rb
  - spec/models/route_card_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/models/route_day_driving_stretch_spec.rb
-->

---
### Requirement: Findings sentences

The `summary` block SHALL carry sentences built by rules from the figures of the weekdays, each left out when its condition does not hold, and SHALL NOT draw any conclusion beyond them. The first sentence, one per stopping end, SHALL give the short share; the hours with at least 10 layovers and a short share of at least 60%, with adjacent hours merged; and the hour with at least 10 layovers and the lowest short share. The second SHALL name the starting hours with at least 5 round trips and 5 cycles whose cycle p10 and round trip p50 differ by less than 4 minutes. The third SHALL give the flagged share of the four-hour windows and the share of those windows on vehicles over the daily driving limit. The fourth SHALL give, for the periods with the smallest low headway, the published headway, the vehicles needed and the vehicles on the road, then the same for the other periods starting from 08:00 and before 20:00, and SHALL say that public data does not show the reason for the difference; a route with scheduled departures only SHALL instead give the number of departures and the trips per direction.

#### Scenario: Hours gathered

- **WHEN** the stopping end's hours are as in the example
- **THEN** the first sentence reads 停車端的折返停留有 43% 不到 15 分鐘，集中在 08 時（80%）與 17 到 19 時（62% 到 83%）回來的車；12 時回來的車只有 5%。

##### Example: Hours of a stopping end

| Hour | Layovers | Short share |
| --- | --- | --- |
| 08 | 10 | 80% |
| 12 | 20 | 5% |
| 17 | 12 | 83% |
| 18 | 16 | 62% |
| 19 | 27 | 78% |
| 23 | 6 | 100% |

#### Scenario: No hour reaches the threshold

- **WHEN** no hour with at least 10 layovers has a short share of at least 60%
- **THEN** the first sentence gives only the share and the lowest hour

#### Scenario: No tight hour

- **WHEN** no starting hour qualifies for the second sentence
- **THEN** the second sentence does not appear

#### Scenario: Scheduled departures only

- **WHEN** the route has 37 scheduled departures, no period and about 37.1 trips per day in each direction
- **THEN** the fourth sentence reads 定時班次一天 37 班，量到每個方向約 37 趟。


<!-- @trace
source: 03-monthly-card
updated: 2026-11-02
code:
  - app/components/month_card_driving_component.yml
  - spec/fixtures/analysis/README.md
  - lib/tasks/cards.rake
  - app/components/month_card_component.rb
  - spec/factories/route_day_rest_windows.rb
  - app/components/month_card_hour_chart_component.rb
  - spec/fixtures/analysis/static/2026-10-19/GetSemiTimeTable.gz
  - app/components/month_card_margin_component.rb
  - spec/factories/route_day_published_departures.rb
  - app/components/month_card_attribution_component.rb
  - app/models/route_card.rb
  - app/models/route_page/slow_legs.rb
  - app/components/month_card_distribution_chart_component.yml
  - app/models/route_page/schedule_comparison.rb
  - app/models/route_day_published_headway.rb
  - app/components/month_card_buffer_component.rb
  - app/components/month_card_cycles_component.rb
  - app/components/month_card_layovers_component.rb
  - app/controllers/route_cards_controller.rb
  - db/schema.rb
  - app/components/month_card_history_component.rb
  - db/migrate/20261102011500_create_route_day_published_schedule.rb
  - .agents/skills/spectra-apply/SKILL.md
  - app/components/month_card_hour_share_chart_component.rb
  - app/components/attribution_component.yml
  - app/components/month_card_layovers_component.yml
  - analysis/README.md
  - app/components/month_card_attribution_component.yml
  - app/components/month_card_history_component.html.erb
  - app/components/month_card_summary_component.html.erb
  - app/models/route_card_prepare_command.rb
  - app/components/month_card_margin_component.yml
  - config/routes.rb
  - spec/factories/route_cards.rb
  - app/components/month_card_run_times_component.rb
  - app/components/month_card_cycles_component.html.erb
  - app/components/month_card_schedule_component.yml
  - app/models/route_page/layover_hours.rb
  - spec/factories/route_day_driving_stretches.rb
  - app/models/route_page/load_profile.rb
  - config/locales/en.yml
  - spec/factories/route_days.rb
  - app/models/route_day_driving_stretch.rb
  - app/models/route_page/card_trend.rb
  - app/models/route_page/mrt_overlap.rb
  - app/components/month_card_driving_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetSemiTimeTable.gz
  - app/components/month_card_buffer_component.yml
  - spec/fixtures/analysis/static/2026-10-19/GetTimeTable.gz
  - app/components/month_card_margin_component.html.erb
  - app/components/month_card_distribution_chart_component.rb
  - app/models/route_page/format.rb
  - app/models/route_page/layover_distribution.rb
  - db/migrate/20261102030000_create_route_cards.rb
  - app/views/route_cards/show.html.erb
  - app/components/month_card_attribution_component.html.erb
  - app/components/month_card_hour_share_chart_component.html.erb
  - analysis/published_schedule.sql
  - app/components/month_card_chart_component.rb
  - app/components/month_card_driving_component.rb
  - db/migrate/20261101220000_create_route_day_rest_windows.rb
  - app/models/route_page/month_days.rb
  - app/components/month_card_hour_chart_component.html.erb
  - app/components/month_card_run_times_component.yml
  - app/components/month_card_summary_component.rb
  - app/models/route_day_loader.rb
  - app/components/month_card_run_times_component.html.erb
  - app/components/month_card_layovers_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetTimeTable.gz
  - app/components/month_card_cycles_component.yml
  - app/models/route_day_published_departure.rb
  - app/models/route_page/month_card.rb
  - app/components/month_card_history_component.yml
  - analysis/30_layovers.sql
  - config/locales/tw.yml
  - analysis/params.sql
  - docs/data-sources.md
  - analysis/derived_export.sql
  - spec/factories/route_day_published_headways.rb
  - app/components/month_card_distribution_chart_component.html.erb
  - app/components/month_card_hour_share_chart_component.yml
  - app/frontend/stylesheets/application.css
  - app/models/program_version.rb
  - app/models/route_page/snapshot_changes.rb
  - spec/factories/layovers.rb
  - spec/factories/trips.rb
  - .github/skills/spectra-apply/SKILL.md
  - app/components/month_card_buffer_component.html.erb
  - app/models/route_day_rest_window.rb
  - app/models/route_card_coverage.rb
  - app/models/route_page/layover_stats.rb
  - app/models/route_page/rest_windows.rb
  - app/components/month_card_summary_component.yml
  - bin/health-card
  - app/components/month_card_schedule_component.rb
  - app/models/route_day.rb
  - app/components/month_card_schedule_component.html.erb
  - app/models/route_page/month_findings.rb
tests:
  - spec/system/month_card_print_spec.rb
  - spec/analysis/published_schedule_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/route_page/schedule_comparison_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/models/route_card_prepare_command_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_page/card_trend_spec.rb
  - spec/components/month_card_history_component_spec.rb
  - spec/components/month_card_summary_component_spec.rb
  - spec/models/route_page/snapshot_changes_spec.rb
  - spec/models/route_card_coverage_spec.rb
  - spec/models/route_day_published_departure_spec.rb
  - spec/components/month_card_buffer_component_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/route_page/month_findings_spec.rb
  - spec/models/route_day_rest_window_spec.rb
  - spec/models/route_page/layover_hours_spec.rb
  - spec/components/month_card_driving_component_spec.rb
  - spec/components/month_card_attribution_component_spec.rb
  - spec/models/program_version_spec.rb
  - spec/models/route_page/slow_legs_spec.rb
  - spec/analysis/params_spec.rb
  - spec/components/month_card_run_times_component_spec.rb
  - spec/components/month_card_margin_component_spec.rb
  - spec/models/route_day_published_headway_spec.rb
  - spec/components/month_card_hour_chart_component_spec.rb
  - spec/components/month_card_cycles_component_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/components/month_card_schedule_component_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/models/route_page/rest_windows_spec.rb
  - spec/models/route_page/month_card_spec.rb
  - spec/models/route_page/month_days_spec.rb
  - spec/requests/route_cards_spec.rb
  - spec/components/month_card_layovers_component_spec.rb
  - spec/models/route_card_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/models/route_day_driving_stretch_spec.rb
-->

---
### Requirement: Layovers block

The `layovers` block SHALL show, for weekdays and holidays and for both ends, the end's direction, last stop and nature, the number of layovers, p10, p50, p90 and the share under 15 minutes; a sentence saying that layovers at a pass-through end are not rest; and, for each stopping end, the weekday distribution in the bins of `layover-metrics` with the 15-minute boundary marked, and the share under 15 minutes per Taipei hour of the end time with each hour's share and count printed. An hour with fewer than 10 layovers SHALL be drawn apart from the others.

#### Scenario: Hour rows

- **WHEN** a stopping end has 10 layovers ending in hour 08, of which 8 are under 15 minutes, and 6 ending in hour 23, all under 15 minutes
- **THEN** the block prints 80 and 10 for hour 08 and 100 and 6 for hour 23, and hour 23 is drawn apart


<!-- @trace
source: 03-monthly-card
updated: 2026-11-02
code:
  - app/components/month_card_driving_component.yml
  - spec/fixtures/analysis/README.md
  - lib/tasks/cards.rake
  - app/components/month_card_component.rb
  - spec/factories/route_day_rest_windows.rb
  - app/components/month_card_hour_chart_component.rb
  - spec/fixtures/analysis/static/2026-10-19/GetSemiTimeTable.gz
  - app/components/month_card_margin_component.rb
  - spec/factories/route_day_published_departures.rb
  - app/components/month_card_attribution_component.rb
  - app/models/route_card.rb
  - app/models/route_page/slow_legs.rb
  - app/components/month_card_distribution_chart_component.yml
  - app/models/route_page/schedule_comparison.rb
  - app/models/route_day_published_headway.rb
  - app/components/month_card_buffer_component.rb
  - app/components/month_card_cycles_component.rb
  - app/components/month_card_layovers_component.rb
  - app/controllers/route_cards_controller.rb
  - db/schema.rb
  - app/components/month_card_history_component.rb
  - db/migrate/20261102011500_create_route_day_published_schedule.rb
  - .agents/skills/spectra-apply/SKILL.md
  - app/components/month_card_hour_share_chart_component.rb
  - app/components/attribution_component.yml
  - app/components/month_card_layovers_component.yml
  - analysis/README.md
  - app/components/month_card_attribution_component.yml
  - app/components/month_card_history_component.html.erb
  - app/components/month_card_summary_component.html.erb
  - app/models/route_card_prepare_command.rb
  - app/components/month_card_margin_component.yml
  - config/routes.rb
  - spec/factories/route_cards.rb
  - app/components/month_card_run_times_component.rb
  - app/components/month_card_cycles_component.html.erb
  - app/components/month_card_schedule_component.yml
  - app/models/route_page/layover_hours.rb
  - spec/factories/route_day_driving_stretches.rb
  - app/models/route_page/load_profile.rb
  - config/locales/en.yml
  - spec/factories/route_days.rb
  - app/models/route_day_driving_stretch.rb
  - app/models/route_page/card_trend.rb
  - app/models/route_page/mrt_overlap.rb
  - app/components/month_card_driving_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetSemiTimeTable.gz
  - app/components/month_card_buffer_component.yml
  - spec/fixtures/analysis/static/2026-10-19/GetTimeTable.gz
  - app/components/month_card_margin_component.html.erb
  - app/components/month_card_distribution_chart_component.rb
  - app/models/route_page/format.rb
  - app/models/route_page/layover_distribution.rb
  - db/migrate/20261102030000_create_route_cards.rb
  - app/views/route_cards/show.html.erb
  - app/components/month_card_attribution_component.html.erb
  - app/components/month_card_hour_share_chart_component.html.erb
  - analysis/published_schedule.sql
  - app/components/month_card_chart_component.rb
  - app/components/month_card_driving_component.rb
  - db/migrate/20261101220000_create_route_day_rest_windows.rb
  - app/models/route_page/month_days.rb
  - app/components/month_card_hour_chart_component.html.erb
  - app/components/month_card_run_times_component.yml
  - app/components/month_card_summary_component.rb
  - app/models/route_day_loader.rb
  - app/components/month_card_run_times_component.html.erb
  - app/components/month_card_layovers_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetTimeTable.gz
  - app/components/month_card_cycles_component.yml
  - app/models/route_day_published_departure.rb
  - app/models/route_page/month_card.rb
  - app/components/month_card_history_component.yml
  - analysis/30_layovers.sql
  - config/locales/tw.yml
  - analysis/params.sql
  - docs/data-sources.md
  - analysis/derived_export.sql
  - spec/factories/route_day_published_headways.rb
  - app/components/month_card_distribution_chart_component.html.erb
  - app/components/month_card_hour_share_chart_component.yml
  - app/frontend/stylesheets/application.css
  - app/models/program_version.rb
  - app/models/route_page/snapshot_changes.rb
  - spec/factories/layovers.rb
  - spec/factories/trips.rb
  - .github/skills/spectra-apply/SKILL.md
  - app/components/month_card_buffer_component.html.erb
  - app/models/route_day_rest_window.rb
  - app/models/route_card_coverage.rb
  - app/models/route_page/layover_stats.rb
  - app/models/route_page/rest_windows.rb
  - app/components/month_card_summary_component.yml
  - bin/health-card
  - app/components/month_card_schedule_component.rb
  - app/models/route_day.rb
  - app/components/month_card_schedule_component.html.erb
  - app/models/route_page/month_findings.rb
tests:
  - spec/system/month_card_print_spec.rb
  - spec/analysis/published_schedule_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/route_page/schedule_comparison_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/models/route_card_prepare_command_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_page/card_trend_spec.rb
  - spec/components/month_card_history_component_spec.rb
  - spec/components/month_card_summary_component_spec.rb
  - spec/models/route_page/snapshot_changes_spec.rb
  - spec/models/route_card_coverage_spec.rb
  - spec/models/route_day_published_departure_spec.rb
  - spec/components/month_card_buffer_component_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/route_page/month_findings_spec.rb
  - spec/models/route_day_rest_window_spec.rb
  - spec/models/route_page/layover_hours_spec.rb
  - spec/components/month_card_driving_component_spec.rb
  - spec/components/month_card_attribution_component_spec.rb
  - spec/models/program_version_spec.rb
  - spec/models/route_page/slow_legs_spec.rb
  - spec/analysis/params_spec.rb
  - spec/components/month_card_run_times_component_spec.rb
  - spec/components/month_card_margin_component_spec.rb
  - spec/models/route_day_published_headway_spec.rb
  - spec/components/month_card_hour_chart_component_spec.rb
  - spec/components/month_card_cycles_component_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/components/month_card_schedule_component_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/models/route_page/rest_windows_spec.rb
  - spec/models/route_page/month_card_spec.rb
  - spec/models/route_page/month_days_spec.rb
  - spec/requests/route_cards_spec.rb
  - spec/components/month_card_layovers_component_spec.rb
  - spec/models/route_card_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/models/route_day_driving_stretch_spec.rb
-->

---
### Requirement: Continuous driving block

The `driving` block SHALL state the rest rule of 汽車運輸業管理規則第 19 條之 2 with its six-hour exception and that the figures are numbers only, without a verdict, because the data sees vehicles and not drivers. It SHALL show, for weekdays and holidays and for both rules of `layover-metrics`, the windows that can be judged, the windows meeting the condition, their share and the daily range, followed by how many weekday four-hour windows are on vehicles over the daily driving limit and the distribution of the weekday driving stretches.

#### Scenario: Rule row

- **WHEN** the weekdays have 281 `four_hours` windows of which 142 are flagged, with daily shares from 43% to 59%
- **THEN** the row shows 281, 142, 50.5% and 43%–59%


<!-- @trace
source: 03-monthly-card
updated: 2026-11-02
code:
  - app/components/month_card_driving_component.yml
  - spec/fixtures/analysis/README.md
  - lib/tasks/cards.rake
  - app/components/month_card_component.rb
  - spec/factories/route_day_rest_windows.rb
  - app/components/month_card_hour_chart_component.rb
  - spec/fixtures/analysis/static/2026-10-19/GetSemiTimeTable.gz
  - app/components/month_card_margin_component.rb
  - spec/factories/route_day_published_departures.rb
  - app/components/month_card_attribution_component.rb
  - app/models/route_card.rb
  - app/models/route_page/slow_legs.rb
  - app/components/month_card_distribution_chart_component.yml
  - app/models/route_page/schedule_comparison.rb
  - app/models/route_day_published_headway.rb
  - app/components/month_card_buffer_component.rb
  - app/components/month_card_cycles_component.rb
  - app/components/month_card_layovers_component.rb
  - app/controllers/route_cards_controller.rb
  - db/schema.rb
  - app/components/month_card_history_component.rb
  - db/migrate/20261102011500_create_route_day_published_schedule.rb
  - .agents/skills/spectra-apply/SKILL.md
  - app/components/month_card_hour_share_chart_component.rb
  - app/components/attribution_component.yml
  - app/components/month_card_layovers_component.yml
  - analysis/README.md
  - app/components/month_card_attribution_component.yml
  - app/components/month_card_history_component.html.erb
  - app/components/month_card_summary_component.html.erb
  - app/models/route_card_prepare_command.rb
  - app/components/month_card_margin_component.yml
  - config/routes.rb
  - spec/factories/route_cards.rb
  - app/components/month_card_run_times_component.rb
  - app/components/month_card_cycles_component.html.erb
  - app/components/month_card_schedule_component.yml
  - app/models/route_page/layover_hours.rb
  - spec/factories/route_day_driving_stretches.rb
  - app/models/route_page/load_profile.rb
  - config/locales/en.yml
  - spec/factories/route_days.rb
  - app/models/route_day_driving_stretch.rb
  - app/models/route_page/card_trend.rb
  - app/models/route_page/mrt_overlap.rb
  - app/components/month_card_driving_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetSemiTimeTable.gz
  - app/components/month_card_buffer_component.yml
  - spec/fixtures/analysis/static/2026-10-19/GetTimeTable.gz
  - app/components/month_card_margin_component.html.erb
  - app/components/month_card_distribution_chart_component.rb
  - app/models/route_page/format.rb
  - app/models/route_page/layover_distribution.rb
  - db/migrate/20261102030000_create_route_cards.rb
  - app/views/route_cards/show.html.erb
  - app/components/month_card_attribution_component.html.erb
  - app/components/month_card_hour_share_chart_component.html.erb
  - analysis/published_schedule.sql
  - app/components/month_card_chart_component.rb
  - app/components/month_card_driving_component.rb
  - db/migrate/20261101220000_create_route_day_rest_windows.rb
  - app/models/route_page/month_days.rb
  - app/components/month_card_hour_chart_component.html.erb
  - app/components/month_card_run_times_component.yml
  - app/components/month_card_summary_component.rb
  - app/models/route_day_loader.rb
  - app/components/month_card_run_times_component.html.erb
  - app/components/month_card_layovers_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetTimeTable.gz
  - app/components/month_card_cycles_component.yml
  - app/models/route_day_published_departure.rb
  - app/models/route_page/month_card.rb
  - app/components/month_card_history_component.yml
  - analysis/30_layovers.sql
  - config/locales/tw.yml
  - analysis/params.sql
  - docs/data-sources.md
  - analysis/derived_export.sql
  - spec/factories/route_day_published_headways.rb
  - app/components/month_card_distribution_chart_component.html.erb
  - app/components/month_card_hour_share_chart_component.yml
  - app/frontend/stylesheets/application.css
  - app/models/program_version.rb
  - app/models/route_page/snapshot_changes.rb
  - spec/factories/layovers.rb
  - spec/factories/trips.rb
  - .github/skills/spectra-apply/SKILL.md
  - app/components/month_card_buffer_component.html.erb
  - app/models/route_day_rest_window.rb
  - app/models/route_card_coverage.rb
  - app/models/route_page/layover_stats.rb
  - app/models/route_page/rest_windows.rb
  - app/components/month_card_summary_component.yml
  - bin/health-card
  - app/components/month_card_schedule_component.rb
  - app/models/route_day.rb
  - app/components/month_card_schedule_component.html.erb
  - app/models/route_page/month_findings.rb
tests:
  - spec/system/month_card_print_spec.rb
  - spec/analysis/published_schedule_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/route_page/schedule_comparison_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/models/route_card_prepare_command_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_page/card_trend_spec.rb
  - spec/components/month_card_history_component_spec.rb
  - spec/components/month_card_summary_component_spec.rb
  - spec/models/route_page/snapshot_changes_spec.rb
  - spec/models/route_card_coverage_spec.rb
  - spec/models/route_day_published_departure_spec.rb
  - spec/components/month_card_buffer_component_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/route_page/month_findings_spec.rb
  - spec/models/route_day_rest_window_spec.rb
  - spec/models/route_page/layover_hours_spec.rb
  - spec/components/month_card_driving_component_spec.rb
  - spec/components/month_card_attribution_component_spec.rb
  - spec/models/program_version_spec.rb
  - spec/models/route_page/slow_legs_spec.rb
  - spec/analysis/params_spec.rb
  - spec/components/month_card_run_times_component_spec.rb
  - spec/components/month_card_margin_component_spec.rb
  - spec/models/route_day_published_headway_spec.rb
  - spec/components/month_card_hour_chart_component_spec.rb
  - spec/components/month_card_cycles_component_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/components/month_card_schedule_component_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/models/route_page/rest_windows_spec.rb
  - spec/models/route_page/month_card_spec.rb
  - spec/models/route_page/month_days_spec.rb
  - spec/requests/route_cards_spec.rb
  - spec/components/month_card_layovers_component_spec.rb
  - spec/models/route_card_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/models/route_day_driving_stretch_spec.rb
-->

---
### Requirement: Schedule block

The `schedule` block SHALL state which comparisons public data allows and which it does not: no planned run time, no approved trips or vehicle numbers, so no statement on how long the timetable gives or on missed departures. It SHALL show two charts over the weekday hours, the measured departures of each direction against the published departures per hour, and the vehicles on the road against the vehicles needed, and a table with, for each version of `published-schedule`, one row per period, the row of scheduled departures and trips outside the periods, the member routes' rows and the holiday rows. The periods with the smallest low headway SHALL be set apart.

#### Scenario: Period row

- **WHEN** a period runs 06:30 to 08:00 with headways of 4 to 6 minutes, 5.5 and 2.5 measured departures per hour, 10 vehicles on the road and 30 to 46 vehicles needed
- **THEN** its row shows 06:30–08:00, 4–6 分, 10–15, 5.5, 2.5, 10 and 30–46

#### Scenario: Two versions in the month

- **WHEN** the published headways changed within the month
- **THEN** the block shows one table per version, each naming its days

#### Scenario: Member route

- **WHEN** the page has a member route with 37 scheduled departures
- **THEN** the table has a row naming that member route with its 37 departures


<!-- @trace
source: 03-monthly-card
updated: 2026-11-02
code:
  - app/components/month_card_driving_component.yml
  - spec/fixtures/analysis/README.md
  - lib/tasks/cards.rake
  - app/components/month_card_component.rb
  - spec/factories/route_day_rest_windows.rb
  - app/components/month_card_hour_chart_component.rb
  - spec/fixtures/analysis/static/2026-10-19/GetSemiTimeTable.gz
  - app/components/month_card_margin_component.rb
  - spec/factories/route_day_published_departures.rb
  - app/components/month_card_attribution_component.rb
  - app/models/route_card.rb
  - app/models/route_page/slow_legs.rb
  - app/components/month_card_distribution_chart_component.yml
  - app/models/route_page/schedule_comparison.rb
  - app/models/route_day_published_headway.rb
  - app/components/month_card_buffer_component.rb
  - app/components/month_card_cycles_component.rb
  - app/components/month_card_layovers_component.rb
  - app/controllers/route_cards_controller.rb
  - db/schema.rb
  - app/components/month_card_history_component.rb
  - db/migrate/20261102011500_create_route_day_published_schedule.rb
  - .agents/skills/spectra-apply/SKILL.md
  - app/components/month_card_hour_share_chart_component.rb
  - app/components/attribution_component.yml
  - app/components/month_card_layovers_component.yml
  - analysis/README.md
  - app/components/month_card_attribution_component.yml
  - app/components/month_card_history_component.html.erb
  - app/components/month_card_summary_component.html.erb
  - app/models/route_card_prepare_command.rb
  - app/components/month_card_margin_component.yml
  - config/routes.rb
  - spec/factories/route_cards.rb
  - app/components/month_card_run_times_component.rb
  - app/components/month_card_cycles_component.html.erb
  - app/components/month_card_schedule_component.yml
  - app/models/route_page/layover_hours.rb
  - spec/factories/route_day_driving_stretches.rb
  - app/models/route_page/load_profile.rb
  - config/locales/en.yml
  - spec/factories/route_days.rb
  - app/models/route_day_driving_stretch.rb
  - app/models/route_page/card_trend.rb
  - app/models/route_page/mrt_overlap.rb
  - app/components/month_card_driving_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetSemiTimeTable.gz
  - app/components/month_card_buffer_component.yml
  - spec/fixtures/analysis/static/2026-10-19/GetTimeTable.gz
  - app/components/month_card_margin_component.html.erb
  - app/components/month_card_distribution_chart_component.rb
  - app/models/route_page/format.rb
  - app/models/route_page/layover_distribution.rb
  - db/migrate/20261102030000_create_route_cards.rb
  - app/views/route_cards/show.html.erb
  - app/components/month_card_attribution_component.html.erb
  - app/components/month_card_hour_share_chart_component.html.erb
  - analysis/published_schedule.sql
  - app/components/month_card_chart_component.rb
  - app/components/month_card_driving_component.rb
  - db/migrate/20261101220000_create_route_day_rest_windows.rb
  - app/models/route_page/month_days.rb
  - app/components/month_card_hour_chart_component.html.erb
  - app/components/month_card_run_times_component.yml
  - app/components/month_card_summary_component.rb
  - app/models/route_day_loader.rb
  - app/components/month_card_run_times_component.html.erb
  - app/components/month_card_layovers_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetTimeTable.gz
  - app/components/month_card_cycles_component.yml
  - app/models/route_day_published_departure.rb
  - app/models/route_page/month_card.rb
  - app/components/month_card_history_component.yml
  - analysis/30_layovers.sql
  - config/locales/tw.yml
  - analysis/params.sql
  - docs/data-sources.md
  - analysis/derived_export.sql
  - spec/factories/route_day_published_headways.rb
  - app/components/month_card_distribution_chart_component.html.erb
  - app/components/month_card_hour_share_chart_component.yml
  - app/frontend/stylesheets/application.css
  - app/models/program_version.rb
  - app/models/route_page/snapshot_changes.rb
  - spec/factories/layovers.rb
  - spec/factories/trips.rb
  - .github/skills/spectra-apply/SKILL.md
  - app/components/month_card_buffer_component.html.erb
  - app/models/route_day_rest_window.rb
  - app/models/route_card_coverage.rb
  - app/models/route_page/layover_stats.rb
  - app/models/route_page/rest_windows.rb
  - app/components/month_card_summary_component.yml
  - bin/health-card
  - app/components/month_card_schedule_component.rb
  - app/models/route_day.rb
  - app/components/month_card_schedule_component.html.erb
  - app/models/route_page/month_findings.rb
tests:
  - spec/system/month_card_print_spec.rb
  - spec/analysis/published_schedule_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/route_page/schedule_comparison_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/models/route_card_prepare_command_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_page/card_trend_spec.rb
  - spec/components/month_card_history_component_spec.rb
  - spec/components/month_card_summary_component_spec.rb
  - spec/models/route_page/snapshot_changes_spec.rb
  - spec/models/route_card_coverage_spec.rb
  - spec/models/route_day_published_departure_spec.rb
  - spec/components/month_card_buffer_component_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/route_page/month_findings_spec.rb
  - spec/models/route_day_rest_window_spec.rb
  - spec/models/route_page/layover_hours_spec.rb
  - spec/components/month_card_driving_component_spec.rb
  - spec/components/month_card_attribution_component_spec.rb
  - spec/models/program_version_spec.rb
  - spec/models/route_page/slow_legs_spec.rb
  - spec/analysis/params_spec.rb
  - spec/components/month_card_run_times_component_spec.rb
  - spec/components/month_card_margin_component_spec.rb
  - spec/models/route_day_published_headway_spec.rb
  - spec/components/month_card_hour_chart_component_spec.rb
  - spec/components/month_card_cycles_component_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/components/month_card_schedule_component_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/models/route_page/rest_windows_spec.rb
  - spec/models/route_page/month_card_spec.rb
  - spec/models/route_page/month_days_spec.rb
  - spec/requests/route_cards_spec.rb
  - spec/components/month_card_layovers_component_spec.rb
  - spec/models/route_card_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/models/route_day_driving_stretch_spec.rb
-->

---
### Requirement: Cycles and run times blocks

The `cycles` block SHALL explain round trips and cycles and draw, per starting hour of the weekdays with at least 5 values, the round trip p50 and the cycle p10, marking the hours where they differ by less than 4 minutes. The `run-times` block SHALL state which trips are left out and their numbers per direction, and SHALL show per starting hour of the weekdays the trips, p50 and p85 of each direction, the round trips with p50 and p85 and the cycles with p10 and p50, a row for the whole day, values with fewer than 5 trips set apart, and the 4 slowest stretches between stops in the morning and evening peaks of at least 200 metres, none of them a small sample, as defined by `stop-to-stop-speed`.

#### Scenario: Slowest stretches

- **WHEN** the weekday stop speeds hold five peak stretches of at least 200 metres at 4.2, 4.9, 5.5, 5.6 and 5.8 km/h and a stretch of 150 metres at 3.0 km/h
- **THEN** the block lists the four at 4.2 to 5.6 km/h in that order and not the 150-metre stretch

#### Scenario: Left-out trips

- **WHEN** 199 trips of direction 0 and 7 of direction 1 are left out of run times
- **THEN** the block names 199 and 7


<!-- @trace
source: 03-monthly-card
updated: 2026-11-02
code:
  - app/components/month_card_driving_component.yml
  - spec/fixtures/analysis/README.md
  - lib/tasks/cards.rake
  - app/components/month_card_component.rb
  - spec/factories/route_day_rest_windows.rb
  - app/components/month_card_hour_chart_component.rb
  - spec/fixtures/analysis/static/2026-10-19/GetSemiTimeTable.gz
  - app/components/month_card_margin_component.rb
  - spec/factories/route_day_published_departures.rb
  - app/components/month_card_attribution_component.rb
  - app/models/route_card.rb
  - app/models/route_page/slow_legs.rb
  - app/components/month_card_distribution_chart_component.yml
  - app/models/route_page/schedule_comparison.rb
  - app/models/route_day_published_headway.rb
  - app/components/month_card_buffer_component.rb
  - app/components/month_card_cycles_component.rb
  - app/components/month_card_layovers_component.rb
  - app/controllers/route_cards_controller.rb
  - db/schema.rb
  - app/components/month_card_history_component.rb
  - db/migrate/20261102011500_create_route_day_published_schedule.rb
  - .agents/skills/spectra-apply/SKILL.md
  - app/components/month_card_hour_share_chart_component.rb
  - app/components/attribution_component.yml
  - app/components/month_card_layovers_component.yml
  - analysis/README.md
  - app/components/month_card_attribution_component.yml
  - app/components/month_card_history_component.html.erb
  - app/components/month_card_summary_component.html.erb
  - app/models/route_card_prepare_command.rb
  - app/components/month_card_margin_component.yml
  - config/routes.rb
  - spec/factories/route_cards.rb
  - app/components/month_card_run_times_component.rb
  - app/components/month_card_cycles_component.html.erb
  - app/components/month_card_schedule_component.yml
  - app/models/route_page/layover_hours.rb
  - spec/factories/route_day_driving_stretches.rb
  - app/models/route_page/load_profile.rb
  - config/locales/en.yml
  - spec/factories/route_days.rb
  - app/models/route_day_driving_stretch.rb
  - app/models/route_page/card_trend.rb
  - app/models/route_page/mrt_overlap.rb
  - app/components/month_card_driving_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetSemiTimeTable.gz
  - app/components/month_card_buffer_component.yml
  - spec/fixtures/analysis/static/2026-10-19/GetTimeTable.gz
  - app/components/month_card_margin_component.html.erb
  - app/components/month_card_distribution_chart_component.rb
  - app/models/route_page/format.rb
  - app/models/route_page/layover_distribution.rb
  - db/migrate/20261102030000_create_route_cards.rb
  - app/views/route_cards/show.html.erb
  - app/components/month_card_attribution_component.html.erb
  - app/components/month_card_hour_share_chart_component.html.erb
  - analysis/published_schedule.sql
  - app/components/month_card_chart_component.rb
  - app/components/month_card_driving_component.rb
  - db/migrate/20261101220000_create_route_day_rest_windows.rb
  - app/models/route_page/month_days.rb
  - app/components/month_card_hour_chart_component.html.erb
  - app/components/month_card_run_times_component.yml
  - app/components/month_card_summary_component.rb
  - app/models/route_day_loader.rb
  - app/components/month_card_run_times_component.html.erb
  - app/components/month_card_layovers_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetTimeTable.gz
  - app/components/month_card_cycles_component.yml
  - app/models/route_day_published_departure.rb
  - app/models/route_page/month_card.rb
  - app/components/month_card_history_component.yml
  - analysis/30_layovers.sql
  - config/locales/tw.yml
  - analysis/params.sql
  - docs/data-sources.md
  - analysis/derived_export.sql
  - spec/factories/route_day_published_headways.rb
  - app/components/month_card_distribution_chart_component.html.erb
  - app/components/month_card_hour_share_chart_component.yml
  - app/frontend/stylesheets/application.css
  - app/models/program_version.rb
  - app/models/route_page/snapshot_changes.rb
  - spec/factories/layovers.rb
  - spec/factories/trips.rb
  - .github/skills/spectra-apply/SKILL.md
  - app/components/month_card_buffer_component.html.erb
  - app/models/route_day_rest_window.rb
  - app/models/route_card_coverage.rb
  - app/models/route_page/layover_stats.rb
  - app/models/route_page/rest_windows.rb
  - app/components/month_card_summary_component.yml
  - bin/health-card
  - app/components/month_card_schedule_component.rb
  - app/models/route_day.rb
  - app/components/month_card_schedule_component.html.erb
  - app/models/route_page/month_findings.rb
tests:
  - spec/system/month_card_print_spec.rb
  - spec/analysis/published_schedule_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/route_page/schedule_comparison_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/models/route_card_prepare_command_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_page/card_trend_spec.rb
  - spec/components/month_card_history_component_spec.rb
  - spec/components/month_card_summary_component_spec.rb
  - spec/models/route_page/snapshot_changes_spec.rb
  - spec/models/route_card_coverage_spec.rb
  - spec/models/route_day_published_departure_spec.rb
  - spec/components/month_card_buffer_component_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/route_page/month_findings_spec.rb
  - spec/models/route_day_rest_window_spec.rb
  - spec/models/route_page/layover_hours_spec.rb
  - spec/components/month_card_driving_component_spec.rb
  - spec/components/month_card_attribution_component_spec.rb
  - spec/models/program_version_spec.rb
  - spec/models/route_page/slow_legs_spec.rb
  - spec/analysis/params_spec.rb
  - spec/components/month_card_run_times_component_spec.rb
  - spec/components/month_card_margin_component_spec.rb
  - spec/models/route_day_published_headway_spec.rb
  - spec/components/month_card_hour_chart_component_spec.rb
  - spec/components/month_card_cycles_component_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/components/month_card_schedule_component_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/models/route_page/rest_windows_spec.rb
  - spec/models/route_page/month_card_spec.rb
  - spec/models/route_page/month_days_spec.rb
  - spec/requests/route_cards_spec.rb
  - spec/components/month_card_layovers_component_spec.rb
  - spec/models/route_card_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/models/route_day_driving_stretch_spec.rb
-->

---
### Requirement: Buffer block

The `buffer` block SHALL show, for 10, 15 and 20 minutes to hold at the stopping ends of the weekdays, the share of layovers already reaching it, the added vehicle-hours per day of the lower and of the upper bound, and the added vehicles in the busiest hour, as defined by `buffer-trade`, and SHALL state the numbers of trips and of measured layovers it rests on and that it counts vehicles, not drivers' hours. It SHALL NOT recommend an action.

#### Scenario: Fifteen minutes

- **WHEN** holding 15 minutes reports 57% already reaching it, 2.0 and 9.9 vehicle-hours per day and 0.3 to 1.0 vehicles in hour 19
- **THEN** that row shows 57%, 2.0, 9.9 and 0.3–1.0 台（19 時）


<!-- @trace
source: 03-monthly-card
updated: 2026-11-02
code:
  - app/components/month_card_driving_component.yml
  - spec/fixtures/analysis/README.md
  - lib/tasks/cards.rake
  - app/components/month_card_component.rb
  - spec/factories/route_day_rest_windows.rb
  - app/components/month_card_hour_chart_component.rb
  - spec/fixtures/analysis/static/2026-10-19/GetSemiTimeTable.gz
  - app/components/month_card_margin_component.rb
  - spec/factories/route_day_published_departures.rb
  - app/components/month_card_attribution_component.rb
  - app/models/route_card.rb
  - app/models/route_page/slow_legs.rb
  - app/components/month_card_distribution_chart_component.yml
  - app/models/route_page/schedule_comparison.rb
  - app/models/route_day_published_headway.rb
  - app/components/month_card_buffer_component.rb
  - app/components/month_card_cycles_component.rb
  - app/components/month_card_layovers_component.rb
  - app/controllers/route_cards_controller.rb
  - db/schema.rb
  - app/components/month_card_history_component.rb
  - db/migrate/20261102011500_create_route_day_published_schedule.rb
  - .agents/skills/spectra-apply/SKILL.md
  - app/components/month_card_hour_share_chart_component.rb
  - app/components/attribution_component.yml
  - app/components/month_card_layovers_component.yml
  - analysis/README.md
  - app/components/month_card_attribution_component.yml
  - app/components/month_card_history_component.html.erb
  - app/components/month_card_summary_component.html.erb
  - app/models/route_card_prepare_command.rb
  - app/components/month_card_margin_component.yml
  - config/routes.rb
  - spec/factories/route_cards.rb
  - app/components/month_card_run_times_component.rb
  - app/components/month_card_cycles_component.html.erb
  - app/components/month_card_schedule_component.yml
  - app/models/route_page/layover_hours.rb
  - spec/factories/route_day_driving_stretches.rb
  - app/models/route_page/load_profile.rb
  - config/locales/en.yml
  - spec/factories/route_days.rb
  - app/models/route_day_driving_stretch.rb
  - app/models/route_page/card_trend.rb
  - app/models/route_page/mrt_overlap.rb
  - app/components/month_card_driving_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetSemiTimeTable.gz
  - app/components/month_card_buffer_component.yml
  - spec/fixtures/analysis/static/2026-10-19/GetTimeTable.gz
  - app/components/month_card_margin_component.html.erb
  - app/components/month_card_distribution_chart_component.rb
  - app/models/route_page/format.rb
  - app/models/route_page/layover_distribution.rb
  - db/migrate/20261102030000_create_route_cards.rb
  - app/views/route_cards/show.html.erb
  - app/components/month_card_attribution_component.html.erb
  - app/components/month_card_hour_share_chart_component.html.erb
  - analysis/published_schedule.sql
  - app/components/month_card_chart_component.rb
  - app/components/month_card_driving_component.rb
  - db/migrate/20261101220000_create_route_day_rest_windows.rb
  - app/models/route_page/month_days.rb
  - app/components/month_card_hour_chart_component.html.erb
  - app/components/month_card_run_times_component.yml
  - app/components/month_card_summary_component.rb
  - app/models/route_day_loader.rb
  - app/components/month_card_run_times_component.html.erb
  - app/components/month_card_layovers_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetTimeTable.gz
  - app/components/month_card_cycles_component.yml
  - app/models/route_day_published_departure.rb
  - app/models/route_page/month_card.rb
  - app/components/month_card_history_component.yml
  - analysis/30_layovers.sql
  - config/locales/tw.yml
  - analysis/params.sql
  - docs/data-sources.md
  - analysis/derived_export.sql
  - spec/factories/route_day_published_headways.rb
  - app/components/month_card_distribution_chart_component.html.erb
  - app/components/month_card_hour_share_chart_component.yml
  - app/frontend/stylesheets/application.css
  - app/models/program_version.rb
  - app/models/route_page/snapshot_changes.rb
  - spec/factories/layovers.rb
  - spec/factories/trips.rb
  - .github/skills/spectra-apply/SKILL.md
  - app/components/month_card_buffer_component.html.erb
  - app/models/route_day_rest_window.rb
  - app/models/route_card_coverage.rb
  - app/models/route_page/layover_stats.rb
  - app/models/route_page/rest_windows.rb
  - app/components/month_card_summary_component.yml
  - bin/health-card
  - app/components/month_card_schedule_component.rb
  - app/models/route_day.rb
  - app/components/month_card_schedule_component.html.erb
  - app/models/route_page/month_findings.rb
tests:
  - spec/system/month_card_print_spec.rb
  - spec/analysis/published_schedule_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/route_page/schedule_comparison_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/models/route_card_prepare_command_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_page/card_trend_spec.rb
  - spec/components/month_card_history_component_spec.rb
  - spec/components/month_card_summary_component_spec.rb
  - spec/models/route_page/snapshot_changes_spec.rb
  - spec/models/route_card_coverage_spec.rb
  - spec/models/route_day_published_departure_spec.rb
  - spec/components/month_card_buffer_component_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/route_page/month_findings_spec.rb
  - spec/models/route_day_rest_window_spec.rb
  - spec/models/route_page/layover_hours_spec.rb
  - spec/components/month_card_driving_component_spec.rb
  - spec/components/month_card_attribution_component_spec.rb
  - spec/models/program_version_spec.rb
  - spec/models/route_page/slow_legs_spec.rb
  - spec/analysis/params_spec.rb
  - spec/components/month_card_run_times_component_spec.rb
  - spec/components/month_card_margin_component_spec.rb
  - spec/models/route_day_published_headway_spec.rb
  - spec/components/month_card_hour_chart_component_spec.rb
  - spec/components/month_card_cycles_component_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/components/month_card_schedule_component_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/models/route_page/rest_windows_spec.rb
  - spec/models/route_page/month_card_spec.rb
  - spec/models/route_page/month_days_spec.rb
  - spec/requests/route_cards_spec.rb
  - spec/components/month_card_layovers_component_spec.rb
  - spec/models/route_card_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/models/route_day_driving_stretch_spec.rb
-->

---
### Requirement: History block

The `history` block SHALL show one row per month of the route that has a route card up to this month, recomputed with the current definitions: the weekdays covered, for each stopping end the short share with its daily range and p10, the flagged shares of both rules, and the vehicles on the road in the morning period with the smallest low headway, with 部分月份 beside a partial month. When an earlier month's stored `summary` differs from its recomputed figures, the block SHALL name that month and say that its figures differ from the printed card. On the first card it SHALL say that there is no earlier month to compare. It SHALL show the changes reported by `RoutePage::SnapshotChanges`, and one row per day of the month from the first loaded day on, with its weekday, day type, trips, share of complete trips, missing-stop rate, vehicles, stopping-end layovers, short share and four-hour flagged share, and for a missing day its reason instead.

#### Scenario: First card

- **WHEN** the route has no route card for an earlier month
- **THEN** the table has one row and the block says 這是第一份，還沒有上個月可以比

#### Scenario: Definition changed

- **WHEN** the stored `summary` of 2026-11 gives a short share of 40.0% and recomputing gives 38.0%
- **THEN** the block says that the figures of 2026 年 11 月 differ from the printed card

#### Scenario: Nothing changed in the snapshots

- **WHEN** `RoutePage::SnapshotChanges` reports no change over 10 days and a shape update time on 2024-11-29
- **THEN** the block says that the published schedule and stops did not change over those 10 days and names 2024-11-29

#### Scenario: Missing day in the daily rows

- **WHEN** 2026-10-30 is missing with the reason 原始檔不齊
- **THEN** its row shows 10-30（五）and 原始檔不齊 and no figures


<!-- @trace
source: 03-monthly-card
updated: 2026-11-02
code:
  - app/components/month_card_driving_component.yml
  - spec/fixtures/analysis/README.md
  - lib/tasks/cards.rake
  - app/components/month_card_component.rb
  - spec/factories/route_day_rest_windows.rb
  - app/components/month_card_hour_chart_component.rb
  - spec/fixtures/analysis/static/2026-10-19/GetSemiTimeTable.gz
  - app/components/month_card_margin_component.rb
  - spec/factories/route_day_published_departures.rb
  - app/components/month_card_attribution_component.rb
  - app/models/route_card.rb
  - app/models/route_page/slow_legs.rb
  - app/components/month_card_distribution_chart_component.yml
  - app/models/route_page/schedule_comparison.rb
  - app/models/route_day_published_headway.rb
  - app/components/month_card_buffer_component.rb
  - app/components/month_card_cycles_component.rb
  - app/components/month_card_layovers_component.rb
  - app/controllers/route_cards_controller.rb
  - db/schema.rb
  - app/components/month_card_history_component.rb
  - db/migrate/20261102011500_create_route_day_published_schedule.rb
  - .agents/skills/spectra-apply/SKILL.md
  - app/components/month_card_hour_share_chart_component.rb
  - app/components/attribution_component.yml
  - app/components/month_card_layovers_component.yml
  - analysis/README.md
  - app/components/month_card_attribution_component.yml
  - app/components/month_card_history_component.html.erb
  - app/components/month_card_summary_component.html.erb
  - app/models/route_card_prepare_command.rb
  - app/components/month_card_margin_component.yml
  - config/routes.rb
  - spec/factories/route_cards.rb
  - app/components/month_card_run_times_component.rb
  - app/components/month_card_cycles_component.html.erb
  - app/components/month_card_schedule_component.yml
  - app/models/route_page/layover_hours.rb
  - spec/factories/route_day_driving_stretches.rb
  - app/models/route_page/load_profile.rb
  - config/locales/en.yml
  - spec/factories/route_days.rb
  - app/models/route_day_driving_stretch.rb
  - app/models/route_page/card_trend.rb
  - app/models/route_page/mrt_overlap.rb
  - app/components/month_card_driving_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetSemiTimeTable.gz
  - app/components/month_card_buffer_component.yml
  - spec/fixtures/analysis/static/2026-10-19/GetTimeTable.gz
  - app/components/month_card_margin_component.html.erb
  - app/components/month_card_distribution_chart_component.rb
  - app/models/route_page/format.rb
  - app/models/route_page/layover_distribution.rb
  - db/migrate/20261102030000_create_route_cards.rb
  - app/views/route_cards/show.html.erb
  - app/components/month_card_attribution_component.html.erb
  - app/components/month_card_hour_share_chart_component.html.erb
  - analysis/published_schedule.sql
  - app/components/month_card_chart_component.rb
  - app/components/month_card_driving_component.rb
  - db/migrate/20261101220000_create_route_day_rest_windows.rb
  - app/models/route_page/month_days.rb
  - app/components/month_card_hour_chart_component.html.erb
  - app/components/month_card_run_times_component.yml
  - app/components/month_card_summary_component.rb
  - app/models/route_day_loader.rb
  - app/components/month_card_run_times_component.html.erb
  - app/components/month_card_layovers_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetTimeTable.gz
  - app/components/month_card_cycles_component.yml
  - app/models/route_day_published_departure.rb
  - app/models/route_page/month_card.rb
  - app/components/month_card_history_component.yml
  - analysis/30_layovers.sql
  - config/locales/tw.yml
  - analysis/params.sql
  - docs/data-sources.md
  - analysis/derived_export.sql
  - spec/factories/route_day_published_headways.rb
  - app/components/month_card_distribution_chart_component.html.erb
  - app/components/month_card_hour_share_chart_component.yml
  - app/frontend/stylesheets/application.css
  - app/models/program_version.rb
  - app/models/route_page/snapshot_changes.rb
  - spec/factories/layovers.rb
  - spec/factories/trips.rb
  - .github/skills/spectra-apply/SKILL.md
  - app/components/month_card_buffer_component.html.erb
  - app/models/route_day_rest_window.rb
  - app/models/route_card_coverage.rb
  - app/models/route_page/layover_stats.rb
  - app/models/route_page/rest_windows.rb
  - app/components/month_card_summary_component.yml
  - bin/health-card
  - app/components/month_card_schedule_component.rb
  - app/models/route_day.rb
  - app/components/month_card_schedule_component.html.erb
  - app/models/route_page/month_findings.rb
tests:
  - spec/system/month_card_print_spec.rb
  - spec/analysis/published_schedule_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/route_page/schedule_comparison_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/models/route_card_prepare_command_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_page/card_trend_spec.rb
  - spec/components/month_card_history_component_spec.rb
  - spec/components/month_card_summary_component_spec.rb
  - spec/models/route_page/snapshot_changes_spec.rb
  - spec/models/route_card_coverage_spec.rb
  - spec/models/route_day_published_departure_spec.rb
  - spec/components/month_card_buffer_component_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/route_page/month_findings_spec.rb
  - spec/models/route_day_rest_window_spec.rb
  - spec/models/route_page/layover_hours_spec.rb
  - spec/components/month_card_driving_component_spec.rb
  - spec/components/month_card_attribution_component_spec.rb
  - spec/models/program_version_spec.rb
  - spec/models/route_page/slow_legs_spec.rb
  - spec/analysis/params_spec.rb
  - spec/components/month_card_run_times_component_spec.rb
  - spec/components/month_card_margin_component_spec.rb
  - spec/models/route_day_published_headway_spec.rb
  - spec/components/month_card_hour_chart_component_spec.rb
  - spec/components/month_card_cycles_component_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/components/month_card_schedule_component_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/models/route_page/rest_windows_spec.rb
  - spec/models/route_page/month_card_spec.rb
  - spec/models/route_page/month_days_spec.rb
  - spec/requests/route_cards_spec.rb
  - spec/components/month_card_layovers_component_spec.rb
  - spec/models/route_card_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/models/route_day_driving_stretch_spec.rb
-->

---
### Requirement: Attribution block

The `attribution` block SHALL name the feeds of 臺北市公共運輸處 this card uses by their codes, GetBusData, GetBusEvent, GetRoute, GetStop, GetPathDetail, GetBusShape, GetProvider, GetSemiTimeTable and GetTimeTable, with the second and third paragraphs of the 授權 section of docs/data-sources.md verbatim; the office calendar line of `site-layout`; the source of the regulation; the sentence that providing the data does not mean the agency recommends, agrees with or approves this project; and the repository address with the program version.

#### Scenario: Licence paragraphs

- **WHEN** the block is rendered
- **THEN** it contains 政府資料開放授權條款：https://data.gov.tw/license and 提供資料不代表該機關推薦、同意或核准本專案。

#### Scenario: Sources not used

- **WHEN** the block is rendered
- **THEN** it does not name BusSeatEvent, 捷運車站出入口座標, 全國公廁建檔資料 or 營運服務指標評鑑


<!-- @trace
source: 03-monthly-card
updated: 2026-11-02
code:
  - app/components/month_card_driving_component.yml
  - spec/fixtures/analysis/README.md
  - lib/tasks/cards.rake
  - app/components/month_card_component.rb
  - spec/factories/route_day_rest_windows.rb
  - app/components/month_card_hour_chart_component.rb
  - spec/fixtures/analysis/static/2026-10-19/GetSemiTimeTable.gz
  - app/components/month_card_margin_component.rb
  - spec/factories/route_day_published_departures.rb
  - app/components/month_card_attribution_component.rb
  - app/models/route_card.rb
  - app/models/route_page/slow_legs.rb
  - app/components/month_card_distribution_chart_component.yml
  - app/models/route_page/schedule_comparison.rb
  - app/models/route_day_published_headway.rb
  - app/components/month_card_buffer_component.rb
  - app/components/month_card_cycles_component.rb
  - app/components/month_card_layovers_component.rb
  - app/controllers/route_cards_controller.rb
  - db/schema.rb
  - app/components/month_card_history_component.rb
  - db/migrate/20261102011500_create_route_day_published_schedule.rb
  - .agents/skills/spectra-apply/SKILL.md
  - app/components/month_card_hour_share_chart_component.rb
  - app/components/attribution_component.yml
  - app/components/month_card_layovers_component.yml
  - analysis/README.md
  - app/components/month_card_attribution_component.yml
  - app/components/month_card_history_component.html.erb
  - app/components/month_card_summary_component.html.erb
  - app/models/route_card_prepare_command.rb
  - app/components/month_card_margin_component.yml
  - config/routes.rb
  - spec/factories/route_cards.rb
  - app/components/month_card_run_times_component.rb
  - app/components/month_card_cycles_component.html.erb
  - app/components/month_card_schedule_component.yml
  - app/models/route_page/layover_hours.rb
  - spec/factories/route_day_driving_stretches.rb
  - app/models/route_page/load_profile.rb
  - config/locales/en.yml
  - spec/factories/route_days.rb
  - app/models/route_day_driving_stretch.rb
  - app/models/route_page/card_trend.rb
  - app/models/route_page/mrt_overlap.rb
  - app/components/month_card_driving_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetSemiTimeTable.gz
  - app/components/month_card_buffer_component.yml
  - spec/fixtures/analysis/static/2026-10-19/GetTimeTable.gz
  - app/components/month_card_margin_component.html.erb
  - app/components/month_card_distribution_chart_component.rb
  - app/models/route_page/format.rb
  - app/models/route_page/layover_distribution.rb
  - db/migrate/20261102030000_create_route_cards.rb
  - app/views/route_cards/show.html.erb
  - app/components/month_card_attribution_component.html.erb
  - app/components/month_card_hour_share_chart_component.html.erb
  - analysis/published_schedule.sql
  - app/components/month_card_chart_component.rb
  - app/components/month_card_driving_component.rb
  - db/migrate/20261101220000_create_route_day_rest_windows.rb
  - app/models/route_page/month_days.rb
  - app/components/month_card_hour_chart_component.html.erb
  - app/components/month_card_run_times_component.yml
  - app/components/month_card_summary_component.rb
  - app/models/route_day_loader.rb
  - app/components/month_card_run_times_component.html.erb
  - app/components/month_card_layovers_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetTimeTable.gz
  - app/components/month_card_cycles_component.yml
  - app/models/route_day_published_departure.rb
  - app/models/route_page/month_card.rb
  - app/components/month_card_history_component.yml
  - analysis/30_layovers.sql
  - config/locales/tw.yml
  - analysis/params.sql
  - docs/data-sources.md
  - analysis/derived_export.sql
  - spec/factories/route_day_published_headways.rb
  - app/components/month_card_distribution_chart_component.html.erb
  - app/components/month_card_hour_share_chart_component.yml
  - app/frontend/stylesheets/application.css
  - app/models/program_version.rb
  - app/models/route_page/snapshot_changes.rb
  - spec/factories/layovers.rb
  - spec/factories/trips.rb
  - .github/skills/spectra-apply/SKILL.md
  - app/components/month_card_buffer_component.html.erb
  - app/models/route_day_rest_window.rb
  - app/models/route_card_coverage.rb
  - app/models/route_page/layover_stats.rb
  - app/models/route_page/rest_windows.rb
  - app/components/month_card_summary_component.yml
  - bin/health-card
  - app/components/month_card_schedule_component.rb
  - app/models/route_day.rb
  - app/components/month_card_schedule_component.html.erb
  - app/models/route_page/month_findings.rb
tests:
  - spec/system/month_card_print_spec.rb
  - spec/analysis/published_schedule_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/route_page/schedule_comparison_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/models/route_card_prepare_command_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_page/card_trend_spec.rb
  - spec/components/month_card_history_component_spec.rb
  - spec/components/month_card_summary_component_spec.rb
  - spec/models/route_page/snapshot_changes_spec.rb
  - spec/models/route_card_coverage_spec.rb
  - spec/models/route_day_published_departure_spec.rb
  - spec/components/month_card_buffer_component_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/route_page/month_findings_spec.rb
  - spec/models/route_day_rest_window_spec.rb
  - spec/models/route_page/layover_hours_spec.rb
  - spec/components/month_card_driving_component_spec.rb
  - spec/components/month_card_attribution_component_spec.rb
  - spec/models/program_version_spec.rb
  - spec/models/route_page/slow_legs_spec.rb
  - spec/analysis/params_spec.rb
  - spec/components/month_card_run_times_component_spec.rb
  - spec/components/month_card_margin_component_spec.rb
  - spec/models/route_day_published_headway_spec.rb
  - spec/components/month_card_hour_chart_component_spec.rb
  - spec/components/month_card_cycles_component_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/components/month_card_schedule_component_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/models/route_page/rest_windows_spec.rb
  - spec/models/route_page/month_card_spec.rb
  - spec/models/route_page/month_days_spec.rb
  - spec/requests/route_cards_spec.rb
  - spec/components/month_card_layovers_component_spec.rb
  - spec/models/route_card_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/models/route_day_driving_stretch_spec.rb
-->

---
### Requirement: Blocks left out of the month card

The month card SHALL NOT contain turnaround facilities, depot inspection scores, MRT overlap, on-board counts, load profiles, maps or a block of its own for data limitations. Those remain on the route page. The limits that matter to each block SHALL be stated in that block's own text.

#### Scenario: Left out

- **WHEN** the page is requested for a route whose route days hold end toilets, depots, MRT distances and on-board counts
- **THEN** `main[data-month-card]` does not contain 公廁, 調度站, 捷運 or 車上人數, and no `data-card-section` is named `limits`

<!-- @trace
source: 03-monthly-card
updated: 2026-11-02
code:
  - app/components/month_card_driving_component.yml
  - spec/fixtures/analysis/README.md
  - lib/tasks/cards.rake
  - app/components/month_card_component.rb
  - spec/factories/route_day_rest_windows.rb
  - app/components/month_card_hour_chart_component.rb
  - spec/fixtures/analysis/static/2026-10-19/GetSemiTimeTable.gz
  - app/components/month_card_margin_component.rb
  - spec/factories/route_day_published_departures.rb
  - app/components/month_card_attribution_component.rb
  - app/models/route_card.rb
  - app/models/route_page/slow_legs.rb
  - app/components/month_card_distribution_chart_component.yml
  - app/models/route_page/schedule_comparison.rb
  - app/models/route_day_published_headway.rb
  - app/components/month_card_buffer_component.rb
  - app/components/month_card_cycles_component.rb
  - app/components/month_card_layovers_component.rb
  - app/controllers/route_cards_controller.rb
  - db/schema.rb
  - app/components/month_card_history_component.rb
  - db/migrate/20261102011500_create_route_day_published_schedule.rb
  - .agents/skills/spectra-apply/SKILL.md
  - app/components/month_card_hour_share_chart_component.rb
  - app/components/attribution_component.yml
  - app/components/month_card_layovers_component.yml
  - analysis/README.md
  - app/components/month_card_attribution_component.yml
  - app/components/month_card_history_component.html.erb
  - app/components/month_card_summary_component.html.erb
  - app/models/route_card_prepare_command.rb
  - app/components/month_card_margin_component.yml
  - config/routes.rb
  - spec/factories/route_cards.rb
  - app/components/month_card_run_times_component.rb
  - app/components/month_card_cycles_component.html.erb
  - app/components/month_card_schedule_component.yml
  - app/models/route_page/layover_hours.rb
  - spec/factories/route_day_driving_stretches.rb
  - app/models/route_page/load_profile.rb
  - config/locales/en.yml
  - spec/factories/route_days.rb
  - app/models/route_day_driving_stretch.rb
  - app/models/route_page/card_trend.rb
  - app/models/route_page/mrt_overlap.rb
  - app/components/month_card_driving_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetSemiTimeTable.gz
  - app/components/month_card_buffer_component.yml
  - spec/fixtures/analysis/static/2026-10-19/GetTimeTable.gz
  - app/components/month_card_margin_component.html.erb
  - app/components/month_card_distribution_chart_component.rb
  - app/models/route_page/format.rb
  - app/models/route_page/layover_distribution.rb
  - db/migrate/20261102030000_create_route_cards.rb
  - app/views/route_cards/show.html.erb
  - app/components/month_card_attribution_component.html.erb
  - app/components/month_card_hour_share_chart_component.html.erb
  - analysis/published_schedule.sql
  - app/components/month_card_chart_component.rb
  - app/components/month_card_driving_component.rb
  - db/migrate/20261101220000_create_route_day_rest_windows.rb
  - app/models/route_page/month_days.rb
  - app/components/month_card_hour_chart_component.html.erb
  - app/components/month_card_run_times_component.yml
  - app/components/month_card_summary_component.rb
  - app/models/route_day_loader.rb
  - app/components/month_card_run_times_component.html.erb
  - app/components/month_card_layovers_component.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetTimeTable.gz
  - app/components/month_card_cycles_component.yml
  - app/models/route_day_published_departure.rb
  - app/models/route_page/month_card.rb
  - app/components/month_card_history_component.yml
  - analysis/30_layovers.sql
  - config/locales/tw.yml
  - analysis/params.sql
  - docs/data-sources.md
  - analysis/derived_export.sql
  - spec/factories/route_day_published_headways.rb
  - app/components/month_card_distribution_chart_component.html.erb
  - app/components/month_card_hour_share_chart_component.yml
  - app/frontend/stylesheets/application.css
  - app/models/program_version.rb
  - app/models/route_page/snapshot_changes.rb
  - spec/factories/layovers.rb
  - spec/factories/trips.rb
  - .github/skills/spectra-apply/SKILL.md
  - app/components/month_card_buffer_component.html.erb
  - app/models/route_day_rest_window.rb
  - app/models/route_card_coverage.rb
  - app/models/route_page/layover_stats.rb
  - app/models/route_page/rest_windows.rb
  - app/components/month_card_summary_component.yml
  - bin/health-card
  - app/components/month_card_schedule_component.rb
  - app/models/route_day.rb
  - app/components/month_card_schedule_component.html.erb
  - app/models/route_page/month_findings.rb
tests:
  - spec/system/month_card_print_spec.rb
  - spec/analysis/published_schedule_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/route_page/schedule_comparison_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/models/route_card_prepare_command_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_page/card_trend_spec.rb
  - spec/components/month_card_history_component_spec.rb
  - spec/components/month_card_summary_component_spec.rb
  - spec/models/route_page/snapshot_changes_spec.rb
  - spec/models/route_card_coverage_spec.rb
  - spec/models/route_day_published_departure_spec.rb
  - spec/components/month_card_buffer_component_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/route_page/month_findings_spec.rb
  - spec/models/route_day_rest_window_spec.rb
  - spec/models/route_page/layover_hours_spec.rb
  - spec/components/month_card_driving_component_spec.rb
  - spec/components/month_card_attribution_component_spec.rb
  - spec/models/program_version_spec.rb
  - spec/models/route_page/slow_legs_spec.rb
  - spec/analysis/params_spec.rb
  - spec/components/month_card_run_times_component_spec.rb
  - spec/components/month_card_margin_component_spec.rb
  - spec/models/route_day_published_headway_spec.rb
  - spec/components/month_card_hour_chart_component_spec.rb
  - spec/components/month_card_cycles_component_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/components/month_card_schedule_component_spec.rb
  - spec/models/derived_push_command_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/models/route_page/rest_windows_spec.rb
  - spec/models/route_page/month_card_spec.rb
  - spec/models/route_page/month_days_spec.rb
  - spec/requests/route_cards_spec.rb
  - spec/components/month_card_layovers_component_spec.rb
  - spec/models/route_card_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/models/route_day_driving_stretch_spec.rb
-->