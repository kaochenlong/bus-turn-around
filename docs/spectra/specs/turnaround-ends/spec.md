# turnaround-ends Specification

## Purpose

Record, for each route that has a route page, whether buses stop at each end of the route or drive straight on to the first stop of the next trip (the nature of the 折返點), as a fact verified route by route and kept in configuration rather than derived from the data, and define how layovers ending at a pass-through end are treated: they are measured, but they are not rest opportunities.

## Requirements

### Requirement: Verified end nature per route

Every route in the route list configuration SHALL carry the nature of both of its ends, keyed by the direction (`go_back` 0 and 1) of the trips that end there: `stop` when buses stop at that end before the next trip, `pass_through` when they drive on to the first stop of the next trip without stopping. The nature SHALL be a fact verified on the route's own data and written into the configuration together with the date and the evidence of the verification, and it SHALL NOT be derived from the stored layovers or vehicle positions when the page is read. The route Ids of the configuration SHALL remain the list of routes that have a route page.

#### Scenario: Both ends of 中山幹線

- **WHEN** the ends of route 15373 are read
- **THEN** direction 0, whose trips end at 青年公園(馬場町), is `pass_through`, and direction 1, whose trips end at 職能發展學院二, is `stop`

#### Scenario: Both ends of 251

- **WHEN** the ends of route 10712 are read
- **THEN** direction 0, whose trips end at 臺北車站(開封), is `pass_through`, and direction 1, whose trips end at 福安居一, is `stop`

#### Scenario: Both ends of 251區

- **WHEN** the ends of route 11764 are read
- **THEN** direction 0, whose trips end at 捷運公館站, is `pass_through`, and direction 1, whose trips end at 福安居一, is `stop`

#### Scenario: Route list is the set of configured routes

- **WHEN** the configuration holds routes 15373, 10712, 11764 and 9001 and nothing else
- **THEN** the routes that have a route page are exactly 15373, 10712, 11764 and 9001


<!-- @trace
source: route-251-pages
updated: 2026-10-23
code:
  - app/components/card_component.rb
  - app/components/route_summary_component.html.erb
  - docs/use-cases.md
  - app/components/buffer_trade_component.rb
  - docs/100-days.md
  - app/components/mrt_overlap_component.rb
  - app/models/route_page/coverage.rb
  - app/models/route_page/layover_stats.rb
  - app/components/section_nav_component.rb
  - config/locales/tw.yml
  - spec/fixtures/analysis/bus_event/2026-10-19/15.jsonl
  - app/components/load_profile_table_component.rb
  - app/views/pages/home.html.erb
  - app/components/data_limitations_component.yml
  - app/components/route_list_component.html.erb
  - app/models/office_calendar_snapshot.rb
  - app/views/routes/show.html.erb
  - db/schema.rb
  - docs/data-sources.md
  - analysis/params.sql
  - spec/fixtures/analysis/README.md
  - spec/fixtures/analysis/bus_event/2026-10-19/14.jsonl
  - app/components/layover_chart_component.html.erb
  - app/components/data_limitations_component.html.erb
  - analysis/10_load.sql
  - spec/support/duckdb.rb
  - app/components/layover_table_component.rb
  - app/components/run_time_table_component.rb
  - analysis/README.md
  - app/components/load_profile_table_component.yml
  - app/components/mrt_overlap_component.html.erb
  - bin/health-card
  - app/components/application_component.rb
  - app/components/load_chart_component.yml
  - app/views/layouts/application.html.erb
  - docs/decisions.md
  - app/components/route_coverage_component.rb
  - app/components/layover_table_component.yml
  - app/components/data_sources_component.yml
  - app/components/layover_chart_component.yml
  - app/models/mrt_exits_snapshot.rb
  - app/components/site_bar_component.html.erb
  - app/components/data_limitations_component.rb
  - app/components/layover_table_component.html.erb
  - app/components/route_list_component.yml
  - app/components/route_summary_component.yml
  - app/components/home_hero_component.yml
  - app/components/site_bar_component.rb
  - config/locales/en.yml
  - config/route_page.yml
  - docs/background.md
  - lib/tasks/external.rake
  - app/components/section_nav_component.yml
  - app/frontend/stylesheets/application.css
  - app/components/home_hero_component.rb
  - db/migrate/20261022230942_add_day_type_to_route_days.rb
  - spec/factories/route_days.rb
  - README.md
  - app/components/data_sources_component.html.erb
  - app/components/attribution_component.html.erb
  - app/components/mrt_overlap_component.yml
  - app/components/section_nav_component.html.erb
  - app/components/run_time_table_component.html.erb
  - app/components/load_profile_table_component.html.erb
  - app/components/layover_chart_component.rb
  - spec/fixtures/analysis/external/office-calendar/2026/2026-10-19.csv
  - app/components/attribution_component.yml
  - app/components/home_hero_component.html.erb
  - app/components/load_chart_component.rb
  - app/models/http_fetcher.rb
  - app/components/load_chart_component.html.erb
  - analysis/30_layovers.sql
  - app/models/route_day.rb
  - app/components/card_component.html.erb
  - analysis/60_export.sql
  - app/components/buffer_trade_component.yml
  - app/components/route_coverage_component.html.erb
  - app/models/route_day_loader.rb
  - app/components/route_summary_component.rb
  - app/components/run_time_table_component.yml
  - app/components/route_coverage_component.yml
  - app/components/buffer_trade_component.html.erb
  - db/migrate/20261022231802_require_day_type_on_route_days.rb
tests:
  - spec/analysis/cli_spec.rb
  - spec/components/route_coverage_component_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/analysis/layovers_spec.rb
  - spec/models/home_page/route_list_spec.rb
  - spec/requests/pages_spec.rb
  - spec/system/route_page_layout_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/components/load_profile_table_component_spec.rb
  - spec/components/mrt_overlap_component_spec.rb
  - spec/models/office_calendar_snapshot_spec.rb
  - spec/analysis/card_spec.rb
  - spec/components/buffer_trade_component_spec.rb
  - spec/models/route_page/ends_spec.rb
  - spec/models/route_page/coverage_spec.rb
  - spec/analysis/load_spec.rb
  - spec/components/layover_chart_component_spec.rb
  - spec/system/home_hero_spec.rb
  - spec/requests/routes_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/components/route_list_component_spec.rb
  - spec/components/load_chart_component_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/models/http_fetcher_spec.rb
  - spec/components/application_component_spec.rb
  - spec/analysis/chains_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/analysis/duckdb_helpers_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/models/route_day_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/models/route_page/run_times_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/components/data_limitations_component_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/components/run_time_table_component_spec.rb
  - spec/components/layover_table_component_spec.rb
  - spec/components/route_summary_component_spec.rb
  - spec/models/route_page/buffer_trade_spec.rb
  - spec/components/card_component_spec.rb
-->

---
### Requirement: Missing or unknown end nature is an error

When a configured route lacks the nature of either direction, or carries a value other than `stop` or `pass_through`, reading that route's ends SHALL fail with an error that names the route Id and the direction, and SHALL NOT assume a nature for it.

#### Scenario: One direction missing

- **WHEN** route 9001 is configured with direction 0 as `stop` and no entry for direction 1
- **THEN** reading its ends fails with an error that names 9001 and direction 1

#### Scenario: Unknown value

- **WHEN** direction 1 of route 9001 carries the value `depot`
- **THEN** reading its ends fails with an error that names 9001, direction 1 and the value `depot`


<!-- @trace
source: zhongshan-turnaround-ends
updated: 2026-10-22
code:
  - config/route_page.yml
  - app/components/layover_chart_component.rb
  - app/components/layover_chart_component.yml
  - app/components/layover_chart_component.html.erb
  - app/controllers/routes_controller.rb
  - app/components/buffer_trade_component.html.erb
  - app/components/layover_table_component.html.erb
  - app/components/buffer_trade_component.rb
  - app/components/buffer_trade_component.yml
  - app/components/layover_table_component.yml
  - app/models/route_page/buffer_trade.rb
  - app/components/layover_table_component.rb
  - app/components/data_limitations_component.yml
  - app/models/route_page/ends.rb
  - app/views/routes/show.html.erb
  - app/models/route_page.rb
tests:
  - spec/models/route_page/buffer_trade_spec.rb
  - spec/components/buffer_trade_component_spec.rb
  - spec/components/layover_chart_component_spec.rb
  - spec/components/layover_table_component_spec.rb
  - spec/requests/routes_spec.rb
  - spec/models/route_page/ends_spec.rb
-->

---
### Requirement: Layovers at a pass-through end are not rest opportunities

A layover whose ending trip's direction is a `pass_through` end SHALL remain a measured layover as defined by `layover-metrics`, and SHALL NOT count as a rest opportunity: the buffer estimate of `buffer-trade` SHALL exclude it from its base and report it separately, and the route page SHALL label that end as pass-through wherever it shows that end's layovers. The layover definition, its distribution and the rest-rule chains of `layover-metrics` SHALL NOT change.

#### Scenario: Pass-through end excluded from the estimate

- **WHEN** a route's direction 0 is `pass_through` and direction 1 is `stop`, and the covered days hold 3 layovers ending in direction 0 and 2 ending in direction 1
- **THEN** the buffer estimate's base is the 2 layovers ending in direction 1, and it reports 3 layovers at the pass-through end as not counted

#### Scenario: Pass-through end labelled on the page

- **WHEN** the layovers of a route whose direction 0 is `pass_through` and direction 1 is `stop` are shown
- **THEN** direction 0's layovers are labelled as ending at a pass-through end and direction 1's as ending at a stopping end, and the counts and percentiles of both directions are the ones of `layover-metrics`

<!-- @trace
source: zhongshan-turnaround-ends
updated: 2026-10-22
code:
  - config/route_page.yml
  - app/components/layover_chart_component.rb
  - app/components/layover_chart_component.yml
  - app/components/layover_chart_component.html.erb
  - app/controllers/routes_controller.rb
  - app/components/buffer_trade_component.html.erb
  - app/components/layover_table_component.html.erb
  - app/components/buffer_trade_component.rb
  - app/components/buffer_trade_component.yml
  - app/components/layover_table_component.yml
  - app/models/route_page/buffer_trade.rb
  - app/components/layover_table_component.rb
  - app/components/data_limitations_component.yml
  - app/models/route_page/ends.rb
  - app/views/routes/show.html.erb
  - app/models/route_page.rb
tests:
  - spec/models/route_page/buffer_trade_spec.rb
  - spec/components/buffer_trade_component_spec.rb
  - spec/components/layover_chart_component_spec.rb
  - spec/components/layover_table_component_spec.rb
  - spec/requests/routes_spec.rb
  - spec/models/route_page/ends_spec.rb
-->