## ADDED Requirements

### Requirement: Member routes in the stored rows

For every route `Id` of a run, the stored stops SHALL carry that route `Id` and each stop's `stopLocationId`, keyed uniquely by route day, route `Id`, direction and sequence number. Every stored trip SHALL carry the route `Id` its events were mapped to. Stored trip stop counts SHALL carry the page route's sequence numbers as defined by `load-profile`. The route day SHALL store the names of its member routes keyed by their `Id`. A route day of a route without member routes SHALL store its own `Id` on every stop and trip and an empty name map. Rows stored before this requirement SHALL carry the route day's route `Id` on every stop and trip, and no `stopLocationId`, until the day is loaded again.

#### Scenario: Member day rows

- **WHEN** `derived:load ROUTE=9001 DAY=2026-10-23` runs with the test configuration listing 9050 under 9001's `member_routes`
- **THEN** the route day has 20 stops, 10 with route `Id` 9001 and 10 with 9050, each with its `stopLocationId`; 3 trips, two with route `Id` 9050 and one with 9001; and the member names `{"9050": "測試幹線經己站"}`

#### Scenario: Single route day

- **WHEN** `derived:load ROUTE=9001 DAY=2026-10-19` runs with the same configuration
- **THEN** every stop of 2026-10-19 with route `Id` 9001 and every trip carries route `Id` 9001, the 10 stops of 9050 are stored with route `Id` 9050 and no trips, and the member names are `{"9050": "測試幹線經己站"}`

#### Scenario: Rows loaded before the change

- **WHEN** the migration runs on a database holding route days loaded before it
- **THEN** every stop and trip of those days carries its route day's route `Id`, its `stopLocationId` is empty, and the route day's member names are `{}`

## MODIFIED Requirements

### Requirement: Load task invocation

The system SHALL provide the rake task `derived:load` taking the environment variables `ROUTE` (a route `Id`) and either `DAY` or both `FROM` and `TO` (Taipei days, `YYYY-MM-DD`, `FROM` not after `TO`). `ROUTE` SHALL be a page route, a key of the route list configuration, or a route the configuration does not mention at all; a route `Id` listed under another route's `member_routes` SHALL be a usage error whose message names the page route to use instead. The task SHALL run the analysis with the page route's member route `Id`s. The raw data root SHALL come only from the environment variable `TURNAROUND_DATA`. The task SHALL process the days in ascending order and print one line per day with either the counts written (trips, layovers, trip stop counts) or the reason the day failed.

#### Scenario: Usage error

- **WHEN** the task runs without `ROUTE`, without `TURNAROUND_DATA`, with only one of `FROM` and `TO`, with `FROM` after `TO`, or with a malformed date
- **THEN** it prints the usage, exits with a non-zero status and writes nothing

#### Scenario: Member route given as ROUTE

- **WHEN** the task runs with `ROUTE=9050` and 9050 is listed under route 9001's `member_routes`
- **THEN** it prints that 9050 belongs to the page of 9001 and that `ROUTE=9001` loads it, exits with a non-zero status and writes nothing

#### Scenario: DuckDB missing

- **WHEN** `duckdb` is not on PATH
- **THEN** the task prints that the DuckDB CLI is required together with `brew install duckdb`, exits with a non-zero status and writes nothing

### Requirement: Stored trips match the health card

For the same input files, route, member routes and day, the stored data SHALL reproduce the health card's numbers when aggregated with the route page queries, the card being rendered with the same member routes through `--also-route`: the number of trips and complete trips, for each direction the number of layovers with their p10, p50 and p90 and the share under 15 minutes, and for each direction, band and stop the number of trips with a count, the median and the p90.

#### Scenario: Fixture day agrees with the card

- **WHEN** the fixture route 9001 on 2026-10-19 is both rendered by `bin/health-card` and loaded by `derived:load`
- **THEN** every number listed above computed from the database equals the corresponding number in the card's JSON

#### Scenario: Member day agrees with the card

- **WHEN** the fixture route 9001 with member route 9050 on 2026-10-23 is both rendered by `bin/health-card --route 9001 --also-route 9050 --day 2026-10-23` and loaded by `derived:load ROUTE=9001 DAY=2026-10-23`
- **THEN** every number listed above computed from the database equals the corresponding number in the card's JSON, among them 3 trips, 3 complete trips and one layover of 10.0 minutes in each direction
