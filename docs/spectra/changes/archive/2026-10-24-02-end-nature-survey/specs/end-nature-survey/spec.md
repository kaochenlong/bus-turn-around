## Purpose

Survey every route of the network over a range of Taipei days and record, for each end, the GPS evidence of whether buses wait there between trips, together with the end nature a fixed rule infers from that evidence. It exists so that whether end natures can be inferred from data is decided on measurements of the whole network instead of the few routes verified by hand. The survey writes files only: it never writes the derived tables, the configuration or any route page.

## ADDED Requirements

### Requirement: Survey task invocation

The system SHALL provide the rake task `survey:end_natures` taking the environment variables `FROM` and `TO` (Taipei days, `YYYY-MM-DD`, `FROM` not after `TO`), optionally `ROUTES` (route `Id`s separated by commas) and optionally `OUT` (the output folder, `tmp/end-natures` under the repository root when absent). The raw data root SHALL come only from the environment variable `TURNAROUND_DATA`. Before any route is analysed, the task SHALL check that the DuckDB CLI is on the `PATH`, SHALL check every requested day with the day eligibility rules that `derived:load` applies (defined by `derived-tables`), and SHALL look up the newest MRT entrance snapshot and the newest public toilet snapshot the way `derived:load` does. A route `Id` in `ROUTES` that is listed under a configured route's `member_routes` SHALL be a usage error whose message names the page route to use instead. Any of these failures SHALL print the reason, exit with a non-zero status and leave `OUT` untouched. The task SHALL NOT write to the database and SHALL NOT change the route list configuration.

#### Scenario: Usage error

- **WHEN** the task runs with `FROM=2026-10-19` and without `TO`
- **THEN** it prints the reason and the usage, exits with a non-zero status, and `OUT` does not exist afterwards

#### Scenario: Day whose read window is not over

- **WHEN** the task runs on the fixture data root with `FROM=2026-10-19` and `TO=2026-10-20`, and the data root has no `bus_event/2026-10-21/01.jsonl` or `01.jsonl.gz`
- **THEN** it prints that the read window of 2026-10-20 is not over, exits with a non-zero status, and no route day of 2026-10-19 is analysed either

#### Scenario: Member route given

- **WHEN** the test configuration lists 9050 under route 9001's `member_routes` and the task runs with `ROUTES=9050`
- **THEN** it prints a usage error that names 9001 and exits with a non-zero status

#### Scenario: DuckDB missing

- **WHEN** the `PATH` holds no `duckdb` executable
- **THEN** the task prints how to install DuckDB and exits with a non-zero status

#### Scenario: Database untouched

- **WHEN** the task surveys the fixture day 2026-10-19
- **THEN** the numbers of rows in `route_days` and every table linked to it are the same before and after

### Requirement: Routes surveyed

For each requested day the task SHALL survey the route `Id`s of that day's `GetRoute.gz`, or only the `Id`s given in `ROUTES`, except `Id`s listed under a configured route's `member_routes`, which SHALL be surveyed together with their page route as `derived:load` runs them. Each route day SHALL run `analysis/params.sql`, every numbered stage file in file name order, `analysis/mrt_overlap.sql`, `analysis/turnaround_facilities.sql` with both end natures `unknown`, `analysis/end_nature_evidence.sql` and `analysis/end_nature_export.sql`, and SHALL place its two files in `<OUT>/evidence/<day>/<route Id>/` only when the whole run succeeded, together with a fingerprint of the analysis: the text of the SQL files run and the route `Id`s of the run. When that folder already holds the same fingerprint, the route day SHALL be reused without running DuckDB; when it holds a different one, the route day SHALL run again and its folder SHALL be replaced. A route day whose run fails SHALL be reported with its route `Id`, its day and the first line of the DuckDB message, SHALL leave no folder behind, and SHALL NOT stop the survey. The task SHALL print one line per day with the numbers of routes run, reused and failed.

#### Scenario: Fixture day

- **WHEN** the task surveys 2026-10-19 on the fixture data root with the test configuration, where route 9001 lists 9050 under `member_routes`
- **THEN** it writes the folders of route 9001, run with route `Id`s 9001 and 9050, and of route 9100, writes no folder for 9050, and the day line reports 2 routes run, 0 reused and 0 failed

#### Scenario: Second run reuses the route days

- **WHEN** the same survey runs a second time with nothing changed
- **THEN** the day line reports 0 routes run, 2 reused and 0 failed, and DuckDB is not invoked for any route day

#### Scenario: Changed analysis runs again

- **WHEN** the fingerprint stored in route 9100's folder differs from the current one and the survey runs again
- **THEN** route 9100 runs again and its folder is replaced, and route 9001 is reused

#### Scenario: Failing route day

- **WHEN** the task surveys 2026-10-19 with `ROUTES=9001,9999` and the day's `GetRoute.gz` has no row for 9999
- **THEN** the day line reports 1 route run and 1 failed, the failure names route 9999 and the message that `GetRoute.gz` has no row for it, no folder exists for 9999, and the report is still written from route 9001

### Requirement: Layover evidence

For every layover of a route day, as defined by `layover-metrics` and paired across member routes, the evidence SHALL hold the direction of the trip that ended, which is the end, and the layover's minutes, together with:

- **Stop pair**: the last stop of the ended trip's route `Id` and direction, and the first stop of the next trip's route `Id` and direction.
- **Stop gap**: the straight-line distance in metres between the two stops of the pair, by the haversine formula with an Earth radius of 6,371,000 metres, with one decimal.
- **GPS reports**: the reports of the layover's vehicle from the end of its trip to the start of the next, both included, one per vehicle and report time as `turnaround-facilities` reads them, whatever their `RouteID`, leaving out reports without a numeric position; the evidence SHALL hold their number.
- **Farthest distance**: the largest distance, over those reports, from a report to the nearer stop of the pair, in metres with one decimal.
- **Longest standstill**: in minutes with one decimal. Speed-0 reports in time order form runs: a speed-0 report continues the run of the report just before it when that report also has speed 0 and lies within `standstill_radius_meters` (50 metres) of it, and starts a new run otherwise. A run lasts from its first report to its last. A layover whose reports include no speed-0 report has a longest standstill of 0.0; a layover without reports has neither a farthest distance nor a longest standstill.

For every direction of the page route, the evidence SHALL also count the trip pairs ending in that direction by the categories of `layover-metrics`: layovers, `no_last_stop`, `no_first_stop`, `other_route` and `negative`.

#### Scenario: Stopping end of the fixture day

- **WHEN** the evidence of route 9001 on 2026-10-19 is computed
- **THEN** direction 0, whose trips end at 戊站, has 10 layovers, of which the 4 below have GPS reports and the other 6 have none

##### Example: layovers with GPS reports at 戊站

| Vehicle | Layover | Minutes | Next trip starts at | Stop gap | Reports | Longest standstill | Farthest |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TEST-0001 | 06:50:00 to 07:00:00 | 10.0 | 戊站對面 | 30.2 | 21 | 2.0 | 64.5 |
| TEST-0003 | 07:53:00 to 08:08:00 | 15.0 | 甲站 (direction 0) | 1111.9 | 5 | 8.0 | 53.8 |
| TEST-0004 | 08:03:00 to 08:15:00 | 12.0 | 戊站對面 | 30.2 | 5 | 8.0 | 44.5 |
| TEST-0001 | 11:30:00 to 12:26:00 | 56.0 | 戊站對面 | 30.2 | 4 | 35.0 | 644.9 |

#### Scenario: Other end of the fixture day

- **WHEN** the evidence of route 9001 on 2026-10-19 is computed
- **THEN** direction 1, whose trips end at 甲站, has 8 layovers, and only TEST-0001's from 08:30:00 to 08:42:00 has GPS reports: 12.0 minutes, next trip from 甲站 of direction 0, stop gap 30.2, 8 reports, longest standstill 7.0, farthest 45.0

#### Scenario: Moving reports split a standstill

- **WHEN** TEST-0001's layover from 06:50:00 to 07:00:00 is evaluated, whose speed-0 reports run from 06:50:00 to 06:51:30 and from 06:58:00 to 07:00:00 with speed-15 reports between them
- **THEN** its longest standstill is 2.0 minutes, the later run, not the 10 minutes from the first speed-0 report to the last

#### Scenario: A jump beyond the radius splits a standstill

- **WHEN** a layover from 06:50:00 to 07:00:00 has speed-0 reports at (25.0604, 121.5003) at 06:51:00 and 06:52:00 and at (25.06094, 121.5003), 60.0 metres away, at 06:53:00 and 06:56:00
- **THEN** its longest standstill is 3.0 minutes

#### Scenario: Trip pairs counted per end

- **WHEN** the evidence of route 9001 on 2026-10-19 is computed
- **THEN** direction 0 has 12 trip pairs: 10 layovers, 1 `no_last_stop` and 1 `no_first_stop`; direction 1 has 11: 8 layovers, 2 `no_last_stop` and 1 `other_route`

### Requirement: Inferred end nature

The survey SHALL pool, for each page route and direction, the layover evidence of every surveyed day, and SHALL infer the nature of that end with constants defined only in `analysis/params.sql`. A layover with GPS reports SHALL count as having stood still when its longest standstill is longer than `nature_still_minutes` (2 minutes). The stood-still share is the number of layovers that stood still divided by the number of layovers with GPS reports. The end SHALL be `undetermined` with reason `few_layovers` when fewer than `nature_min_layovers` (20) layovers have GPS reports. Otherwise it SHALL be `pass_through` when the share is at most `nature_pass_through_max_share` (0.05), `stop` when the share is at least `nature_stop_min_share` (0.5), and `undetermined` with reason `between` in every other case. The rule SHALL NOT read the configured natures.

#### Scenario: Shares against the thresholds

- **WHEN** an end's pooled evidence is classified
- **THEN** the nature and reason follow the table below

##### Example: one end, pooled over the surveyed days

| Layovers with GPS reports | Longest standstills | Share | Nature | Reason |
| --- | --- | --- | --- | --- |
| 20 | all 1.5 | 0.000 | `pass_through` | (none) |
| 20 | all exactly 2.0 | 0.000 | `pass_through` | (none) |
| 20 | one 3.0, the rest 1.5 | 0.050 | `pass_through` | (none) |
| 20 | two 3.0, the rest 1.5 | 0.100 | `undetermined` | `between` |
| 20 | ten 3.0, the rest 1.5 | 0.500 | `stop` | (none) |
| 19 | all 30.0 | 1.000 | `undetermined` | `few_layovers` |

#### Scenario: Days pooled

- **WHEN** an end has 10 layovers with GPS reports on each of two surveyed days, every one with a longest standstill of 30.0 minutes
- **THEN** the end is `stop` with 20 layovers with GPS reports and a share of 1.000

#### Scenario: Layovers without reports left out

- **WHEN** an end has 25 layovers, 19 of them with GPS reports and every one of those with a longest standstill of 30.0 minutes
- **THEN** the end is `undetermined` with reason `few_layovers`

### Requirement: Survey report

After the route days, the task SHALL write `<OUT>/report-<FROM>_<TO>.csv` with a header line and one row per surveyed page route and direction, sorted by route `Id` and then direction, with these columns in this order: route `Id`; the route `Id`s of the run joined by `・`; route name; direction; last stop name; number of days with at least one layover at that end; numbers of trip pairs, layovers, `other_route` pairs, layovers with GPS reports and layovers that stood still; layover p10, p50 and p90 in minutes; median stop gap in metres; median and largest longest standstill in minutes; the stood-still share with three decimals; farthest distance p50, p90 and largest in metres; inferred nature; reason; configured nature; agreement. Percentiles SHALL interpolate linearly between order statistics; minutes and metres SHALL keep one decimal; a value with nothing to compute from SHALL be empty. The route name and the last stop name SHALL be those of the latest surveyed day. The configured nature SHALL come from the route list configuration defined by `turnaround-ends` and be empty for a route that is not configured. Agreement SHALL be `true` when the inferred nature equals the configured one, `false` when they differ, `undetermined` included, and empty when the route is not configured. The task SHALL then print the numbers of ends inferred `stop`, `pass_through` and `undetermined`, the last split by reason; every configured end with its configured nature, its inferred nature and its layovers that stood still out of its layovers with GPS reports; every failed route day; and the path of the report. It SHALL exit with status 0 when the report is written and at least one route day has evidence, and with a non-zero status otherwise.

#### Scenario: Fixture report

- **WHEN** the task surveys 2026-10-19 on the fixture data root with the test configuration
- **THEN** `report-2026-10-19_2026-10-19.csv` has four rows, and each row has the values in the table below

##### Example: rows of the fixture report

| Route | Run Ids | Direction | Last stop | Layovers | `other_route` | With GPS | Stood still | Share | Largest farthest | Nature | Reason | Configured | Agreement |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 9001 | 9001・9050 | 0 | 戊站 | 10 | 0 | 4 | 3 | 0.750 | 644.9 | `undetermined` | `few_layovers` | `stop` | `false` |
| 9001 | 9001・9050 | 1 | 甲站 | 8 | 1 | 1 | 1 | 1.000 | 45.0 | `undetermined` | `few_layovers` | `stop` | `false` |
| 9100 | 9100 | 0 | 丑站 | 6 | 0 | 0 | 0 | (empty) | (empty) | `undetermined` | `few_layovers` | (empty) | (empty) |
| 9100 | 9100 | 1 | 子站 | 4 | 0 | 0 | 0 | (empty) | (empty) | `undetermined` | `few_layovers` | (empty) | (empty) |

#### Scenario: Summary printed

- **WHEN** the task surveys 2026-10-19 on the fixture data root with the test configuration
- **THEN** it prints 0 ends `stop`, 0 `pass_through` and 4 `undetermined`, all 4 for `few_layovers`; both ends of route 9001 with configured `stop`, inferred `undetermined`, 3 of 4 and 1 of 1 layovers that stood still; no failed route day; and the report path; and it exits with status 0

#### Scenario: Nothing surveyed

- **WHEN** the task surveys 2026-10-19 on the fixture data root with `ROUTES=9999`, and the day's `GetRoute.gz` has no row for 9999
- **THEN** it prints the failure of route 9999 on 2026-10-19, prints that no route day succeeded, writes no `report-2026-10-19_2026-10-19.csv`, and exits with a non-zero status
