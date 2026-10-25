## MODIFIED Requirements

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
| 9100 | 9100 | 0 | 丑站 | 5 | 0 | 0 | 0 | (empty) | (empty) | `undetermined` | `few_layovers` | (empty) | (empty) |
| 9100 | 9100 | 1 | 子站 | 4 | 0 | 0 | 0 | (empty) | (empty) | `undetermined` | `few_layovers` | (empty) | (empty) |

#### Scenario: Summary printed

- **WHEN** the task surveys 2026-10-19 on the fixture data root with the test configuration
- **THEN** it prints 0 ends `stop`, 0 `pass_through` and 4 `undetermined`, all 4 for `few_layovers`; both ends of route 9001 with configured `stop`, inferred `undetermined`, 3 of 4 and 1 of 1 layovers that stood still; no failed route day; and the report path; and it exits with status 0

#### Scenario: Nothing surveyed

- **WHEN** the task surveys 2026-10-19 on the fixture data root with `ROUTES=9999`, and the day's `GetRoute.gz` has no row for 9999
- **THEN** it prints the failure of route 9999 on 2026-10-19, prints that no route day succeeded, writes no `report-2026-10-19_2026-10-19.csv`, and exits with a non-zero status

