## MODIFIED Requirements

### Requirement: Derived export

For an eligible day the system SHALL run `analysis/params.sql`, every numbered stage file in file name order, then `analysis/mrt_overlap.sql` with the newest MRT entrance snapshot by file name date, then `analysis/gps_reports.sql`, then `analysis/turnaround_facilities.sql` with the newest public toilet snapshot by file name date and the natures of the route's two ends from the configuration defined by `turnaround-ends` (or `unknown` for both when the route is not configured), then `analysis/route_shape.sql` with the route shapes file of the day's static snapshot as defined by `route-shape`, then `analysis/depots.sql` with the operators file of the day's static snapshot as defined by the requirement "Depot rows stored with the route day", then `analysis/stop_speeds.sql` as defined by `stop-to-stop-speed`, and then `analysis/derived_export.sql`, which SHALL write eleven CSV files: the route day (route `Id`, name, departure, destination, static snapshot day, the day of the entrance snapshot used, the day of the toilet snapshot used and the member routes' names), the stops of both directions of every route `Id` of the run (direction, sequence number, stop name, latitude, longitude, nearest entrance name and distance as defined by `mrt-overlap`, route `Id`, stop location, and the position along the route shape as defined by `stop-to-stop-speed`), the trips of the day as defined by `trip-reconstruction` together with each trip's time band from `load-profile` and its route `Id`, the layovers as defined by `layover-metrics` with the end time of the trip and the start time of the next trip, the per-stop on-board counts of each trip as defined by `load-profile`, the ends of the route (direction, last stop sequence number, name, latitude and longitude, location source, location latitude and longitude, numbers of layovers, located layovers and standstill reports, and metres from the location to the last stop) as defined by `turnaround-facilities`, the toilets within the radius of each located end (direction, name, category, address, latitude, longitude, metres) as defined by `turnaround-facilities`, the standstill cells of each end (direction, cell latitude, cell longitude, numbers of standstill reports, vehicles and layovers) as defined by `turnaround-facilities`, the route shapes, one row per direction (direction, update time, the points as a JSON array of latitude and longitude pairs, and the reason when the direction has no shape that can be kept or had more than one row) as defined by `route-shape`, the depots of the day's trips as defined by the requirement "Depot rows stored with the route day", and the stop speeds as defined by the requirement "Stop speed rows stored with the route day". `analysis/gps_reports.sql` SHALL keep the GPS reports of every vehicle that has a trip of the day, one per `(BusID, DataTime)`, for `analysis/turnaround_facilities.sql`, `analysis/stop_speeds.sql` and the survey of `end-nature-survey`. The `bus_data` hour files SHALL be read only by `analysis/gps_reports.sql`, over the same read window as the stage files, and the route shapes file only by `analysis/route_shape.sql`, so that `bin/health-card` and its inspection files do not change. Timestamps SHALL be written with the `+08:00` offset. Rows SHALL be sorted so that two runs over the same input produce byte-identical files.

#### Scenario: Stage order shared with the health card

- **WHEN** `bin/health-card` and `derived:load` assemble their SQL
- **THEN** both put the variable settings first, `analysis/params.sql` second and the numbered stage files after it in file name order, and only `derived:load` appends `analysis/mrt_overlap.sql`, `analysis/gps_reports.sql`, `analysis/turnaround_facilities.sql`, `analysis/route_shape.sql`, `analysis/depots.sql`, `analysis/stop_speeds.sql` and `analysis/derived_export.sql` in that order

#### Scenario: Newest snapshot used

- **WHEN** the snapshot folder holds `2026-10-20.csv` and `2026-10-22.csv` and day 2026-10-19 is loaded
- **THEN** the distances come from `2026-10-22.csv` and the stored route day records 2026-10-22 as its entrance snapshot day

#### Scenario: Newest toilet snapshot used

- **WHEN** `external/public-toilets/` holds `2026-10-20.csv` and `2026-10-23.csv` and day 2026-10-19 is loaded
- **THEN** the toilets come from `2026-10-23.csv` and the stored route day records 2026-10-23 as its toilet snapshot day

#### Scenario: Every file written

- **WHEN** the fixture day 2026-10-19 of route 9001 is exported twice
- **THEN** both runs write `route_day.csv`, `stops.csv`, `trips.csv`, `layovers.csv`, `trip_stop_counts.csv`, `ends.csv`, `end_toilets.csv`, `end_cells.csv`, `shapes.csv`, `depots.csv` and `stop_speeds.csv` with identical bytes, and the health card's inspection files are unchanged

#### Scenario: GPS read in one place

- **WHEN** the SQL files of `analysis/` are read and the fixture day 2026-10-19 of route 9001 is exported
- **THEN** only `analysis/gps_reports.sql` passes `bus_data` to `day_files`, and the ends, end toilets and standstill cells written are those of the fixture examples of `turnaround-facilities`

## ADDED Requirements

### Requirement: Stop speed rows stored with the route day

The derived export SHALL write `stop_speeds.csv` with the columns `bus_id, start_time, seq, band, meters, seconds`, ordered by `bus_id`, `start_time` and `seq`, one row per trip and leg as defined by `stop-to-stop-speed`, and `stops.csv` SHALL end with the column `shape_meters`, to one decimal and empty for a stop without a position. The loader SHALL store each stop speed row in `trip_stop_speeds` against the stored trip of the same route day with the same vehicle and start time, keyed uniquely by trip and `seq` and deleted with its trip, and SHALL store `shape_meters` on `route_day_stops`, inside the same transaction as the other tables. A staged stop speed row that finds no trip SHALL fail the day and leave the previously stored day unchanged. `bin/push-derived` SHALL carry `trip_stop_speeds` with the other derived tables.

#### Scenario: Fixture day stop speeds stored

- **WHEN** `derived:load ROUTE=9001 DAY=2026-10-19` runs
- **THEN** `trip_stop_speeds` has one row for that route day, for the trip of TEST-0001 starting 06:00:00, with `seq` 1, band `other`, 200.0 metres and 40 seconds, and the outbound stops 91000 to 91004 of that route day store `shape_meters` 0.0, 278.0, 556.0, 834.0 and 1111.9

#### Scenario: Stop speed rows replaced with the day

- **WHEN** the same route day is loaded again
- **THEN** `trip_stop_speeds` still has exactly one row for that route day, and the counts of trips, layovers and trip stop counts are unchanged

#### Scenario: Row without a trip

- **WHEN** a staged stop speed row names a vehicle and start time that no stored trip of the route day has
- **THEN** the load fails naming `trip_stop_speeds` and the previously stored day is unchanged

#### Scenario: Derived tables pushed

- **WHEN** `bin/push-derived` lists the derived tables
- **THEN** `trip_stop_speeds` is listed after `trip_stop_counts`, among the tables that reference `trips`
