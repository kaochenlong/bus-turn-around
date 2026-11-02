# published-schedule Specification

## Purpose

Read the published headways and scheduled departures of each route from the daily static snapshots, and compare them with the departures and vehicles measured from the reconstructed trips. It exists so that a route's published service can be reviewed against what actually ran, without judging why the two differ.

## Requirements

### Requirement: Published schedule read from the static snapshot

The system SHALL read `GetSemiTimeTable.gz` and `GetTimeTable.gz` of the day's static snapshot only in `analysis/published_schedule.sql`, keeping the rows whose `PathAttributeId` belongs to a route `Id` of the run and whose `DateType` is 0. For a headway row, `low_minutes` SHALL be `LongHeadway`, `high_minutes` SHALL be `LowHeadway`, and `start_minute` and `end_minute` SHALL be `StartTime` and `EndTime` as minutes of the day, with 1440 added to `end_minute` when `EndTime` is not later than `StartTime`. For a departure row, `minute` SHALL be `DepartureTime` as a minute of the day. A kept row that cannot be read, or whose `low_minutes` exceeds its `high_minutes`, SHALL fail the day with a message naming the file and the value; rows of other routes SHALL NOT be checked.

#### Scenario: Fixture headways

- **WHEN** the fixture day 2026-10-19 of route 9001 with member route 9050 is exported
- **THEN** the headway rows are 18, from path attributes 9001 and 9002, and none of them comes from path attribute 9100 or has `DateValue` 20260101

#### Scenario: Period ending at midnight

- **WHEN** a kept row has `StartTime` 1700, `EndTime` 0000, `LongHeadway` 30 and `LowHeadway` 30
- **THEN** it is stored with `start_minute` 1020, `end_minute` 1440, `low_minutes` 30 and `high_minutes` 30

#### Scenario: Unreadable row of the route

- **WHEN** a kept row has `LongHeadway` of `abc`
- **THEN** the day fails with a message naming `GetSemiTimeTable.gz` and `abc`

#### Scenario: Unreadable row of another route

- **WHEN** a row of path attribute 9100 has `LongHeadway` of `abc`
- **THEN** the day is exported normally


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
### Requirement: Date value used for a route day

When reading the published schedule of a route day, the system SHALL use one `date_value` chosen from the day and its day type: a weekday on Monday to Friday uses 2 to 6 for Monday to Friday, a holiday on Saturday uses 7, a holiday on Sunday uses 1, a holiday on Monday to Friday uses 1, and a weekday on Saturday or Sunday uses 2.

#### Scenario: Date values

- **WHEN** the date value of a route day is chosen
- **THEN** it follows the table

##### Example: route days

| Day | Weekday | Day type | Date value |
| --- | --- | --- | --- |
| 2026-10-19 | Monday | weekday | 2 |
| 2026-10-23 | Friday | weekday | 6 |
| 2026-10-25 | Sunday | holiday | 1 |
| 2026-10-26 | Monday | holiday | 1 |
| 2026-10-31 | Saturday | holiday | 7 |
| 2026-11-07 | Saturday | weekday | 2 |


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
### Requirement: Schedule comparison over route days

The system SHALL provide the query object `RoutePage::ScheduleComparison`, which reads the stored published rows and the stored trips of any given set of route days of one page route. For the page route it SHALL report one row per published period of the day's date value, deduplicated over the route's path attributes, with the period's start and end, its low and high headway, the published departures per hour as 60 divided by the high and by the low headway, and the measured departures per hour of each direction. The measured departures per hour of a direction SHALL be the number of the route `Id`'s trips of that direction, of any completeness, whose Taipei start time falls in the period, divided by the number of days and by the period's length in hours, unrounded. Only trips whose `route_id` is the page route SHALL count for the page route's rows. It SHALL NOT state whether a departure was missed. It SHALL report that the days need loading again when any given route day has no `published_schedule_day`.

#### Scenario: Measured departures in a period

- **WHEN** a weekday on Monday has the period 06:00 to 08:00 with headways of 5 to 10 minutes, and 6 trips of direction 0 and 3 trips of direction 1 start in it
- **THEN** the row reports 6.0 to 12.0 published departures per hour and 3.0 and 1.5 measured departures per hour

#### Scenario: Two days

- **WHEN** two weekdays have the same period 06:00 to 08:00, and 6 and 2 trips of direction 0 start in it
- **THEN** the row reports 2.0 measured departures per hour for direction 0

#### Scenario: Two path attributes with the same table

- **WHEN** path attributes 157462 and 157463 of a route each carry the period 06:00 to 07:30 with headways of 4 to 6 minutes
- **THEN** one row is reported for that period

#### Scenario: A day without the published rows

- **WHEN** a given route day has no `published_schedule_day`
- **THEN** the query object reports that the days need loading again


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
### Requirement: Vehicles on the road in a period

For each period, the system SHALL report the vehicles on the road: the period SHALL be cut into slices of 30 minutes, and for each day and slice the system SHALL count the distinct vehicles with a trip whose start is before the slice's end and whose end is after the slice's start; the figure SHALL be the mean over all days and slices. A vehicle between two trips SHALL NOT count.

#### Scenario: Two slices

- **WHEN** the period 06:00 to 07:00 has vehicles A and B on trips throughout, and vehicle C on a trip from 06:40 to 08:00
- **THEN** the slices count 2 and 3 and the figure is 2.5

#### Scenario: A trip ending at the slice's start

- **WHEN** a vehicle's trip ends exactly at 06:30 and it has no other trip
- **THEN** it counts for the slice 06:00 to 06:30 and not for the slice 06:30 to 07:00


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
### Requirement: Vehicles needed by the published headway

For each period, the system SHALL report the vehicles needed by the published headway: the all-day 50th percentile of cycles over the given route days as defined by `round-trip-cycle`, divided by the high headway for the low figure and by the low headway for the high figure, rounded to a whole number. Without a cycle both figures SHALL be nil.

#### Scenario: Needed vehicles

- **WHEN** the all-day cycle p50 is 182.2 minutes and the period's headways are 4 to 6 minutes
- **THEN** the period reports 30 to 46 vehicles needed

#### Scenario: No cycle

- **WHEN** the given route days have no cycle
- **THEN** the period reports nil for both figures


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
### Requirement: Published schedule versions within the covered days

The system SHALL group the given route days, in date order, into versions of adjacent days that use the same deduplicated periods and scheduled departures, and SHALL compute each version's figures only from its own days. Days of different date values with identical rows SHALL belong to the same version.

#### Scenario: Headway changed in the middle

- **WHEN** 2026-11-02 and 2026-11-03 use the period 06:00 to 08:00 with headways of 4 to 6 minutes and 2026-11-04 uses it with headways of 8 to 10 minutes
- **THEN** two versions exist, and the first counts only the trips of 2026-11-02 and 2026-11-03

#### Scenario: Monday and Tuesday alike

- **WHEN** a Monday and a Tuesday use date values 2 and 3 with identical rows
- **THEN** they belong to one version


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
### Requirement: Scheduled departures and trips outside the periods

The system SHALL report, for each version, the scheduled departures outside every period and the mean number of trips per day of each direction whose start falls outside every period, together with the vehicles on the road over that time. A route with scheduled departures only SHALL report its whole day this way. The scheduled departures SHALL NOT be matched to trips one by one.

#### Scenario: Scheduled departures after the last period

- **WHEN** a route's last period ends at 21:00, it has scheduled departures at 21:00, 21:30, 22:00 and 23:00, and over 2 days 10 trips of direction 0 start after 21:00
- **THEN** the report lists the 4 departures and 5.0 trips per day for direction 0

#### Scenario: Scheduled departures only

- **WHEN** a route has 37 scheduled departures and no period, and over 7 days its direction 0 has 260 trips
- **THEN** the version has no period rows, and the report lists the 37 departures and about 37.1 trips per day for direction 0


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
### Requirement: Member routes compared on their own

For each member route of the page, the system SHALL report the same figures in a row of its own, using only the trips whose `route_id` is that member route. A member route without published rows SHALL report no row.

#### Scenario: Member with scheduled departures

- **WHEN** page route 9001 has member route 9050 with scheduled departures at 07:00 and 08:30 and 2 trips of `route_id` 9050 on the day
- **THEN** one member row names 9050 with those 2 departures, and those trips do not count in the rows of route 9001


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
### Requirement: Snapshot changes within the covered days

The system SHALL provide the query object `RoutePage::SnapshotChanges`, which compares each given route day with the previous one in date order and reports the days on which the published rows of the page and its member routes differ, the page route's stops of either direction differ in sequence number, name or stop location, or the route shape's update time differs. Published rows SHALL be compared only between days that have a `published_schedule_day`. The first day SHALL NOT count as a change. It SHALL also report the number of days compared and the latest route shape update time.

#### Scenario: Nothing changed

- **WHEN** three route days have identical published rows, stops and shape update times
- **THEN** no change is reported and the number of days is 3

#### Scenario: Headway changed

- **WHEN** the second of three route days has a different high headway in one period
- **THEN** one change is reported for the second day with the kind published schedule, and none for the third unless it differs from the second

#### Scenario: Stop added

- **WHEN** the third of three route days has one more stop in direction 0
- **THEN** one change is reported for the third day with the kind stops

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