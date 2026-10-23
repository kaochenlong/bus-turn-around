# day-types Specification

## Purpose

Classify every Taipei day as a weekday or a holiday from the office calendar of 行政院人事行政總處 (data.gov.tw dataset 14718), so that no metric pools the two. The bus feeds only distinguish days of the week, so without the calendar a substitute holiday such as Monday 2026-10-26 would count as a weekday.

## Requirements

### Requirement: Office calendar snapshot

The system SHALL provide the rake task `external:office_calendar`, which takes the environment variable `YEAR` (four digits, defaulting to the year of today's Taipei day), downloads that year's office calendar CSV from the URL configured for that year, and writes it to `external/office-calendar/<YEAR>/<Taipei day>.csv` under the data root given by `TURNAROUND_DATA`, replacing a file of the same day. After a leading byte order mark is removed, the content SHALL be valid UTF-8, and the file SHALL be written only when all of these hold: the first line is exactly `西元日期,星期,是否放假,備註`; the number of data rows equals the number of days in `YEAR`; every row splits on commas into exactly four fields; the n-th row's date is the n-th day of `YEAR` written as `YYYYMMDD`; its weekday field is that date's weekday as one of 日, 一, 二, 三, 四, 五 and 六; and its 是否放假 field is `0` or `2`. The written file SHALL keep every row unchanged, without the byte order mark and with LF line ends. On success the task SHALL print the file path, the number of days and the number of holidays. When `TURNAROUND_DATA` is missing, `YEAR` is malformed or has no configured URL, the HTTP status is not 200, or any check fails, the task SHALL print the reason, exit with a non-zero status and leave every existing snapshot unchanged; a year without a URL SHALL be reported together with the years that have one, without any request. The HTTP request SHALL go through a replaceable fetcher so that tests never use the network.

#### Scenario: Calendar written without the byte order mark and CRLF

- **WHEN** the fetcher returns the 2026 calendar with status 200, a byte order mark and CRLF line ends
- **THEN** the task writes the year's snapshot with the same rows, no byte order mark and LF line ends, and reports the days and holidays

##### Example: the 2026 calendar

- **GIVEN** the body is the fixture snapshot `spec/fixtures/analysis/external/office-calendar/2026/2026-10-19.csv` with a byte order mark added and every LF replaced by CRLF
- **WHEN** the task runs with `YEAR=2026` on the Taipei day 2026-10-23
- **THEN** `external/office-calendar/2026/2026-10-23.csv` is byte-identical to the fixture snapshot and the output reports 365 days and 120 holidays

#### Scenario: Unusable calendar

- **WHEN** the response or the body fails any check of this requirement
- **THEN** the task exits with a non-zero status, prints the reason and writes no file, and an existing snapshot of the same year is unchanged

##### Example: failing responses for 2026

| Response | Why it fails |
| --- | --- |
| status 500 | the HTTP status is not 200 |
| the bytes `FF FE` followed by the 2026 rows | not UTF-8 |
| header `日期,星期,是否放假,備註` | header differs |
| the first 364 rows of 2026 | 364 rows for a year of 365 days |
| a row `20260101,四,2` | three fields |
| the row for 20260102 replaced by `20260103,六,2,` | the date skips a day |
| the row `20260101,五,2,開國紀念日` | 2026-01-01 is a Thursday (四) |
| the row `20260101,四,1,開國紀念日` | 是否放假 is neither 0 nor 2 |

#### Scenario: Year without a URL

- **WHEN** the task runs with `YEAR=2025` and only 2026 and 2027 have a configured URL
- **THEN** it exits with a non-zero status, names 2026 and 2027, makes no request and writes no file

#### Scenario: Usage without a data root

- **WHEN** the task runs without `TURNAROUND_DATA`
- **THEN** it prints the usage naming `TURNAROUND_DATA`, exits with a non-zero status and makes no request


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

---
### Requirement: Day type of a Taipei day

The day type of a Taipei day SHALL be read from the snapshot with the latest file name date in the folder of that day's year: the day is a weekday when its row's 是否放假 is `0` and a holiday when it is `2`, and its note is the row's 備註 when that is not empty. A make-up workday is therefore a weekday and a substitute holiday is a holiday. Days off for typhoons or other natural disasters are not in the calendar and SHALL take the type the calendar gives them. A trip SHALL take the day type of the Taipei day it belongs to under `trip-reconstruction`, which is the day it departs. When the folder of the day's year holds no snapshot, the lookup SHALL fail with a message naming `bin/rails external:office_calendar YEAR=<year>`; when the snapshot has no row for the day, it SHALL fail with a message naming the file and the day.

#### Scenario: Days around a substitute holiday

- **WHEN** the 2026 snapshot is read for the days from 2026-10-23 to 2026-10-26
- **THEN** each day gets the type and note of its row

##### Example: the Retrocession Day weekend

| Day | Row in the 2026 calendar | Day type | Note |
| --- | --- | --- | --- |
| 2026-10-23 | `20261023,五,0,` | weekday | none |
| 2026-10-24 | `20261024,六,2,` | holiday | none |
| 2026-10-25 | `20261025,日,2,臺灣光復暨金門古寧頭大捷紀念日` | holiday | 臺灣光復暨金門古寧頭大捷紀念日 |
| 2026-10-26 | `20261026,一,2,補假` | holiday | 補假 |

#### Scenario: Newest snapshot of the year used

- **WHEN** the 2026 folder holds `2026-10-20.csv`, in which 2026-10-19 is a weekday, and `2026-10-23.csv`, in which it is a holiday, and 2026-10-19 is read
- **THEN** the day is a holiday and its snapshot day is 2026-10-23

#### Scenario: No snapshot for the year

- **WHEN** 2027-01-04 is read and the data root has no file under `external/office-calendar/2027/`
- **THEN** the lookup fails with a message naming `bin/rails external:office_calendar YEAR=2027`

#### Scenario: Snapshot without the day

- **WHEN** a 2026 snapshot that has no row for 2026-10-19 is the newest one and 2026-10-19 is read
- **THEN** the lookup fails with a message naming that file and 2026-10-19

#### Scenario: Trip across midnight takes the departure day's type

- **WHEN** the fixture day 2026-10-19 of route 9001 is loaded with a calendar snapshot in which 2026-10-19 is a holiday and 2026-10-20 is a weekday
- **THEN** the trip of TEST-0002 that departs 2026-10-19 23:40 and arrives 2026-10-20 00:50 is stored under the 2026-10-19 route day, whose day type is holiday

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