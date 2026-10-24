## ADDED Requirements

### Requirement: Depot rows stored with the route day

The derived export SHALL write `depots.csv` with the columns `station_id, provider_name, station_name, n_buses, n_trips`, ordered by `n_buses` descending then `station_id` ascending, and the loader SHALL store its rows in `route_day_depots`, keyed uniquely by route day and `station_id` and deleted with the route day. `GetProvider.gz` SHALL NOT be required for a day to be eligible: without it the rows carry empty names.

#### Scenario: Fixture day depots

- **WHEN** `derived:load ROUTE=9001 DAY=2026-10-19` runs
- **THEN** `route_day_depots` has one row for that route day with `station_id` 19001, 測試客運, 測試站, `n_buses` 4 and `n_trips` equal to the day's number of trips

#### Scenario: Depot rows replaced with the day

- **WHEN** the same route day is loaded again
- **THEN** its previous depot rows are gone and the new ones are present, inside the same transaction as the other tables

##### Example: reload of the fixture day

- **GIVEN** route 9001's 2026-10-19 is stored with one depot row for `station_id` 19001
- **WHEN** `derived:load ROUTE=9001 DAY=2026-10-19` runs again
- **THEN** `route_day_depots` still has exactly one row for that route day, its `id` differs from the previous row's, and the counts of trips, layovers and trip stop counts are unchanged

#### Scenario: Eligible without GetProvider.gz

- **WHEN** the day's static snapshot holds `GetRoute.gz`, `GetStop.gz` and `GetPathDetail.gz` but no `GetProvider.gz`
- **THEN** the day is loaded and its depot rows have empty names
