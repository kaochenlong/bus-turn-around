# mrt-overlap Specification

## Purpose

Measure how much of a bus route runs near the Taipei MRT and how many riders are on board along those stretches, with a transparent definition that can be recomputed: each stop's straight-line distance to the nearest MRT entrance. The official method for the review rule's overlap figure is not published, so the definition is stated in full and shown under several distance thresholds.

## Requirements

### Requirement: MRT entrance snapshot

The system SHALL provide the rake task `external:mrt_exits`, which downloads the Taipei MRT entrance coordinates CSV of data.gov.tw dataset 128428, converts it from Big5 to UTF-8, and writes it to `external/taipei-mrt-exits/<Taipei day>.csv` under the data root given by `TURNAROUND_DATA`, replacing a file of the same day. The file SHALL be written only when the header is exactly `項次,出入口名稱,出入口編號,經度,緯度,是否為無障礙用`, there is at least one data row, and every longitude and latitude is a number. Otherwise the task SHALL print the reason, exit with a non-zero status and leave every existing snapshot unchanged. The HTTP request SHALL go through a replaceable fetcher so that tests never use the network.

#### Scenario: Big5 snapshot written as UTF-8

- **WHEN** the fetcher returns a Big5 body with the expected header and two entrances `頂埔站出口1` and `頂埔站出口2`
- **THEN** the task writes a UTF-8 file for today's Taipei day containing both names and reports 2 entrances

#### Scenario: Unexpected file

- **WHEN** the fetcher returns status 500, or a body whose header differs, or a header with no rows, or a row whose latitude is not a number
- **THEN** the task exits with a non-zero status, prints the reason and writes no file


<!-- @trace
source: zhongshan-mrt-overlap
updated: 2026-10-22
code:
  - lib/tasks/external.rake
  - analysis/mrt_overlap.sql
  - docs/data-sources.md
  - app/components/mrt_overlap_component.yml
  - db/migrate/20261021193708_add_mrt_overlap_to_derived_tables.rb
  - app/components/data_limitations_component.yml
  - analysis/10_load.sql
  - app/models/route_page/mrt_overlap.rb
  - app/models/route_day.rb
  - analysis/derived_export.sql
  - spec/fixtures/analysis/README.md
  - app/models/route_day_loader.rb
  - app/models/mrt_exits_snapshot.rb
  - spec/fixtures/analysis/static/2026-10-19/GetStop.gz
  - app/components/mrt_overlap_component.rb
  - app/models/route_day_stop.rb
  - db/schema.rb
  - app/components/mrt_overlap_component.html.erb
  - analysis/README.md
  - app/views/routes/show.html.erb
  - spec/fixtures/analysis/external/taipei-mrt-exits/2026-10-19.csv
tests:
  - spec/analysis/fixtures_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/models/route_day_spec.rb
  - spec/requests/routes_spec.rb
  - spec/analysis/mrt_overlap_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/components/mrt_overlap_component_spec.rb
  - spec/models/mrt_exits_snapshot_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/analysis/derived_export_spec.rb
-->

---
### Requirement: Nearest entrance of each stop

For each stop of the route the system SHALL compute the haversine distance in metres, with an earth radius of 6,371,000 metres, to every entrance of the snapshot, and SHALL keep the smallest distance rounded to one decimal together with that entrance's name.

#### Scenario: Nearest entrance chosen

- **WHEN** a stop lies about 111 metres from entrance A and about 334 metres from entrance B
- **THEN** the stop's nearest entrance is A with a distance of about 111 metres


<!-- @trace
source: zhongshan-mrt-overlap
updated: 2026-10-22
code:
  - lib/tasks/external.rake
  - analysis/mrt_overlap.sql
  - docs/data-sources.md
  - app/components/mrt_overlap_component.yml
  - db/migrate/20261021193708_add_mrt_overlap_to_derived_tables.rb
  - app/components/data_limitations_component.yml
  - analysis/10_load.sql
  - app/models/route_page/mrt_overlap.rb
  - app/models/route_day.rb
  - analysis/derived_export.sql
  - spec/fixtures/analysis/README.md
  - app/models/route_day_loader.rb
  - app/models/mrt_exits_snapshot.rb
  - spec/fixtures/analysis/static/2026-10-19/GetStop.gz
  - app/components/mrt_overlap_component.rb
  - app/models/route_day_stop.rb
  - db/schema.rb
  - app/components/mrt_overlap_component.html.erb
  - analysis/README.md
  - app/views/routes/show.html.erb
  - spec/fixtures/analysis/external/taipei-mrt-exits/2026-10-19.csv
tests:
  - spec/analysis/fixtures_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/models/route_day_spec.rb
  - spec/requests/routes_spec.rb
  - spec/analysis/mrt_overlap_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/components/mrt_overlap_component_spec.rb
  - spec/models/mrt_exits_snapshot_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/analysis/derived_export_spec.rb
-->

---
### Requirement: Overlap share and overlap stretches

A stop SHALL count as near the MRT at a threshold when its nearest-entrance distance is at most that threshold. For each direction and for each of the thresholds 300, 500 and 800 metres, the overlap share SHALL be the number of the direction's stops near the MRT divided by the number of the direction's stops. At 500 metres, consecutive stops of one direction (adjacent sequence numbers) that are all near the MRT SHALL form an overlap stretch when there are at least two of them; a single near stop forms no stretch but still counts toward the share.

#### Scenario: Shares and stretches of one direction

- **WHEN** the five stops of direction 0 have nearest-entrance distances 900, 400, 250, 450 and 700 metres at sequence numbers 0 to 4
- **THEN** the shares are 20% at 300 metres, 60% at 500 metres and 80% at 800 metres, and the only stretch at 500 metres runs from sequence 1 to 3

#### Scenario: Single near stop

- **WHEN** only sequence 4 of a direction is within 500 metres
- **THEN** that direction has no stretch and an overlap share above zero


<!-- @trace
source: zhongshan-mrt-overlap
updated: 2026-10-22
code:
  - lib/tasks/external.rake
  - analysis/mrt_overlap.sql
  - docs/data-sources.md
  - app/components/mrt_overlap_component.yml
  - db/migrate/20261021193708_add_mrt_overlap_to_derived_tables.rb
  - app/components/data_limitations_component.yml
  - analysis/10_load.sql
  - app/models/route_page/mrt_overlap.rb
  - app/models/route_day.rb
  - analysis/derived_export.sql
  - spec/fixtures/analysis/README.md
  - app/models/route_day_loader.rb
  - app/models/mrt_exits_snapshot.rb
  - spec/fixtures/analysis/static/2026-10-19/GetStop.gz
  - app/components/mrt_overlap_component.rb
  - app/models/route_day_stop.rb
  - db/schema.rb
  - app/components/mrt_overlap_component.html.erb
  - analysis/README.md
  - app/views/routes/show.html.erb
  - spec/fixtures/analysis/external/taipei-mrt-exits/2026-10-19.csv
tests:
  - spec/analysis/fixtures_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/models/route_day_spec.rb
  - spec/requests/routes_spec.rb
  - spec/analysis/mrt_overlap_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/components/mrt_overlap_component_spec.rb
  - spec/models/mrt_exits_snapshot_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/analysis/derived_export_spec.rb
-->

---
### Requirement: On-board counts along a stretch

For each overlap stretch and time band, the system SHALL pool the on-board counts of every trip at every stop of the stretch, as stored in the derived tables under `load-profile`, and SHALL report the median and the 90th percentile interpolated linearly and rounded to one decimal, and the number of trips with at least one count in the stretch.

#### Scenario: Pooled counts

- **WHEN** one morning-peak trip has counts 10 and 20 at the two stops of a stretch and another has 30 at the first stop only
- **THEN** the stretch's morning-peak row reports 2 trips, a median of 20.0 and a p90 of 28.0

<!-- @trace
source: zhongshan-mrt-overlap
updated: 2026-10-22
code:
  - lib/tasks/external.rake
  - analysis/mrt_overlap.sql
  - docs/data-sources.md
  - app/components/mrt_overlap_component.yml
  - db/migrate/20261021193708_add_mrt_overlap_to_derived_tables.rb
  - app/components/data_limitations_component.yml
  - analysis/10_load.sql
  - app/models/route_page/mrt_overlap.rb
  - app/models/route_day.rb
  - analysis/derived_export.sql
  - spec/fixtures/analysis/README.md
  - app/models/route_day_loader.rb
  - app/models/mrt_exits_snapshot.rb
  - spec/fixtures/analysis/static/2026-10-19/GetStop.gz
  - app/components/mrt_overlap_component.rb
  - app/models/route_day_stop.rb
  - db/schema.rb
  - app/components/mrt_overlap_component.html.erb
  - analysis/README.md
  - app/views/routes/show.html.erb
  - spec/fixtures/analysis/external/taipei-mrt-exits/2026-10-19.csv
tests:
  - spec/analysis/fixtures_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/models/route_day_spec.rb
  - spec/requests/routes_spec.rb
  - spec/analysis/mrt_overlap_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/components/mrt_overlap_component_spec.rb
  - spec/models/mrt_exits_snapshot_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/analysis/derived_export_spec.rb
-->

---
### Requirement: Member routes' stops stay out of the overlap

The nearest-entrance distance SHALL be computed and stored for the stops of every route `Id` of the run, but the overlap share, the overlap stretches and the on-board counts along a stretch SHALL use only the page route's stops. Counts of member route trips attributed to page route stops as defined by `load-profile` SHALL take part in the on-board counts along a stretch.

#### Scenario: Member route stop stored but not counted

- **WHEN** the run is for route 9001 with member route 9050 on 2026-10-23
- **THEN** 己站 has a stored nearest-entrance distance, direction 0's overlap share at 500 metres is 3 of 5 stops as it is without members, and the stretch of direction 0 runs from 乙站 to 丁站

#### Scenario: Member route counts along a stretch

- **WHEN** TEST-0005's 9050 trips carry 5 and 4 at 乙站 and 6 and 5 at 丁站
- **THEN** the morning-peak row of direction 0's stretch counts those trips at 乙站 and 丁站

<!-- @trace
source: 02-route-307-page
updated: 2026-10-24
code:
  - db/migrate/20261024050300_require_route_id_on_derived_rows.rb
  - app/components/turnaround_facilities_component.rb
  - analysis/10_load.sql
  - bin/health-card
  - spec/fixtures/analysis/README.md
  - analysis/params.sql
  - spec/fixtures/analysis/bus_event/2026-10-23/07.jsonl
  - app/components/turnaround_facilities_component.yml
  - analysis/60_export.sql
  - docs/background.md
  - app/models/route_day.rb
  - analysis/50_quality.sql
  - app/components/data_limitations_component.yml
  - spec/factories/route_day_ends.rb
  - spec/fixtures/analysis/static/2026-10-19/GetPathDetail.gz
  - README.md
  - app/components/data_limitations_component.rb
  - db/migrate/20261024035750_create_route_day_shapes.rb
  - spec/fixtures/analysis/static/2026-10-23/GetProvider.gz
  - analysis/depots.sql
  - spec/fixtures/analysis/static/2026-10-19/GetBusShape.gz
  - app/components/stop_sequence_component.yml
  - spec/fixtures/analysis/bus_data/2026-10-23/07.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-23/07.jsonl
  - app/components/attribution_component.html.erb
  - app/models/trip.rb
  - app/frontend/maps/base_map.js
  - app/models/route_page/route_shape.rb
  - app/models/route_page/stop_sequence.rb
  - config/depot_inspections.yml
  - analysis/40_load_profile.sql
  - analysis/route_shape.sql
  - spec/factories/route_day_shapes.rb
  - db/schema.rb
  - app/models/route_page/depots.rb
  - spec/fixtures/analysis/static/2026-10-23/GetBusShape.gz
  - app/models/route_page/depot_inspections.rb
  - db/migrate/20261024062215_create_route_day_depots.rb
  - app/models/route_day_depot.rb
  - spec/fixtures/analysis/static/2026-10-19/GetRoute.gz
  - app/components/end_map_component.html.erb
  - app/models/route_day_loader.rb
  - config/locales/en.yml
  - analysis/README.md
  - spec/fixtures/analysis/bus_event/2026-10-23/08.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-23/09.jsonl
  - app/components/route_map_component.html.erb
  - spec/factories/route_day_depots.rb
  - spec/factories/route_day_end_cells.rb
  - app/components/attribution_component.yml
  - spec/fixtures/analysis/static/2026-10-23/GetRoute.gz
  - app/models/route_page/load_profile.rb
  - app/frontend/route_map/runtime.js
  - spec/fixtures/analysis/static/2026-10-19/GetStop.gz
  - app/components/route_map_component.rb
  - app/models/route_page/layover_stats.rb
  - app/models/derived_load_command.rb
  - spec/fixtures/analysis/bus_seat_event/2026-10-23/08.jsonl
  - db/migrate/20261024050200_backfill_route_id_on_derived_rows.rb
  - app/frontend/entrypoints/application.js
  - app/models/route_day_shape.rb
  - analysis/turnaround_facilities.sql
  - app/models/pto_assessment_snapshot.rb
  - docs/data-sources.md
  - app/frontend/stylesheets/application.css
  - app/components/application_component.rb
  - analysis/derived_export.sql
  - spec/fixtures/analysis/static/2026-10-19/GetProvider.gz
  - app/components/route_list_component.rb
  - analysis/mrt_overlap.sql
  - app/models/route_page/mrt_overlap.rb
  - app/models/route_page/summary.rb
  - config/route_page.yml
  - lib/tasks/external.rake
  - spec/factories/route_day_end_toilets.rb
  - spec/factories/route_days.rb
  - spec/fixtures/analysis/static/2026-10-23/GetStop.gz
  - app/components/route_map_component.yml
  - spec/fixtures/analysis/bus_event/2026-10-23/09.jsonl
  - app/models/tdx_s2s_travel_time_snapshot.rb
  - app/components/turnaround_facilities_component.html.erb
  - app/components/buffer_trade_component.yml
  - app/views/routes/show.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetPathDetail.gz
  - db/migrate/20261024050100_add_member_route_columns_to_derived_tables.rb
  - app/frontend/end_map/runtime.js
  - app/models/route_day_stop.rb
  - app/components/route_coverage_component.html.erb
  - app/models/route_page.rb
  - spec/fixtures/analysis/bus_event/2026-10-24/01.jsonl
  - app/components/route_list_component.html.erb
  - spec/support/duckdb.rb
  - app/components/data_limitations_component.html.erb
  - app/components/route_coverage_component.rb
  - app/components/stop_sequence_component.html.erb
  - config/locales/tw.yml
  - lib/analysis_run.rb
  - app/components/buffer_trade_component.html.erb
  - app/components/stop_sequence_component.rb
  - docs/decisions.md
tests:
  - spec/models/route_day_spec.rb
  - spec/migrations/member_route_columns_spec.rb
  - spec/analysis/depots_spec.rb
  - spec/models/route_page/route_shape_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/components/data_limitations_component_spec.rb
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/load_spec.rb
  - spec/models/route_page/depots_spec.rb
  - spec/models/route_page/summary_spec.rb
  - spec/analysis/card_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/analysis/trips_spec.rb
  - spec/models/pto_assessment_snapshot_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/tdx_s2s_travel_time_snapshot_spec.rb
  - spec/requests/routes_spec.rb
  - spec/requests/pages_spec.rb
  - spec/models/route_page/stop_sequence_spec.rb
  - spec/components/attribution_component_spec.rb
  - spec/system/route_map_spec.rb
  - spec/components/route_coverage_component_spec.rb
  - spec/analysis/profile_spec.rb
  - spec/analysis/mrt_overlap_spec.rb
  - spec/analysis/quality_spec.rb
  - spec/components/route_list_component_spec.rb
  - spec/analysis/route_shape_spec.rb
  - spec/models/route_page/depot_inspections_spec.rb
  - spec/analysis/layovers_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/analysis/analysis_run_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/components/route_map_component_spec.rb
  - spec/models/route_page/ends_spec.rb
  - spec/system/end_map_spec.rb
  - spec/analysis/params_spec.rb
  - spec/components/stop_sequence_component_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/analysis/cli_spec.rb
-->