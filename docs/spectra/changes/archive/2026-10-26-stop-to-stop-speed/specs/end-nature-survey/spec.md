## MODIFIED Requirements

### Requirement: Routes surveyed

For each requested day the task SHALL survey the route `Id`s of that day's `GetRoute.gz`, or only the `Id`s given in `ROUTES`, except `Id`s listed under a configured route's `member_routes`, which SHALL be surveyed together with their page route as `derived:load` runs them. Each route day SHALL run `analysis/params.sql`, every numbered stage file in file name order, `analysis/mrt_overlap.sql`, `analysis/gps_reports.sql` as defined by `derived-tables`, `analysis/turnaround_facilities.sql` with both end natures `unknown`, `analysis/end_nature_evidence.sql` and `analysis/end_nature_export.sql`, and SHALL place its two files in `<OUT>/evidence/<day>/<route Id>/` only when the whole run succeeded, together with a fingerprint of the analysis: the text of the SQL files run and the route `Id`s of the run. When that folder already holds the same fingerprint, the route day SHALL be reused without running DuckDB; when it holds a different one, the route day SHALL run again and its folder SHALL be replaced. A route day whose run fails SHALL be reported with its route `Id`, its day and the first line of the DuckDB message, SHALL leave no folder behind, and SHALL NOT stop the survey. The task SHALL print one line per day with the numbers of routes run, reused and failed.

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

