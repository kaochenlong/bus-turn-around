## ADDED Requirements

### Requirement: Rest window rows stored with the route day

The derived export SHALL also write `rest_windows.csv` with the columns `bus_id, rule, start_time, end_time, n_trips, credit_minutes, longest_layover_minutes, flagged, over_daily_driving`, one row per window as defined by the requirements "Rest-rule windows and chains" (rule `four_hours`) and "Six-hour rest windows" (rule `six_hours`) of `layover-metrics`, ordered by `rule`, `bus_id` and `start_time`, and `driving_stretches.csv` with the columns `bus_id, start_time, end_time, n_trips`, one row per stretch as defined by "Continuous driving stretches", ordered by `bus_id` and `start_time`. `over_daily_driving` SHALL be true when the run times of all the vehicle's trips of the day, of any completeness and of every route `Id` of the run, add up to more than the constant `daily_driving_limit_minutes` of `analysis/params.sql`, which is 600. The loader SHALL store the rows in `route_day_rest_windows`, keyed uniquely by route day, `rule`, `bus_id` and `start_time`, and in `route_day_driving_stretches`, keyed uniquely by route day, `bus_id` and `start_time`, both deleted with the route day and written inside the same transaction as the other tables, and SHALL set `rest_windows_loaded` of the route day to true. A route day stored before this requirement SHALL read `rest_windows_loaded` false until it is loaded again. `bin/push-derived` SHALL carry both tables with the other derived tables.

#### Scenario: Fixture day rows stored

- **WHEN** `derived:load ROUTE=9001 DAY=2026-10-19` runs
- **THEN** `route_day_rest_windows` has 9 `four_hours` rows of which 2 are flagged, the ones of TEST-0001 starting 06:00 and 07:00, and 7 `six_hours` rows of which none is flagged; `route_day_driving_stretches` has 15 rows; every row has `over_daily_driving` false, the most any vehicle drove being 483.0 minutes; and the route day has `rest_windows_loaded` true

#### Scenario: Rows replaced with the day

- **WHEN** the same route day is loaded again
- **THEN** both tables have the same number of rows for that route day as after the first load, and the counts of trips, layovers and trip stop counts are unchanged

##### Example: reload of the fixture day

- **GIVEN** route 9001's 2026-10-19 is stored with 16 rows in `route_day_rest_windows` and 15 rows in `route_day_driving_stretches`
- **WHEN** `derived:load ROUTE=9001 DAY=2026-10-19` runs again
- **THEN** the two tables still have 16 and 15 rows for that route day

#### Scenario: Same bytes on two runs

- **WHEN** the fixture day 2026-10-19 of route 9001 is exported twice
- **THEN** both runs write `rest_windows.csv` and `driving_stretches.csv` with identical bytes

#### Scenario: Over the daily driving limit

- **WHEN** a vehicle's trips of the day add up to 601 minutes, and another vehicle's add up to exactly 600 minutes
- **THEN** the first vehicle's windows have `over_daily_driving` true and the second vehicle's have it false

#### Scenario: Day stored before this requirement

- **WHEN** a route day exists that has not been loaded since the column was added
- **THEN** it has `rest_windows_loaded` false and no rows in either table

#### Scenario: Derived tables pushed

- **WHEN** `bin/push-derived` lists the derived tables
- **THEN** `route_day_rest_windows` and `route_day_driving_stretches` are listed among the tables that reference `route_days`
