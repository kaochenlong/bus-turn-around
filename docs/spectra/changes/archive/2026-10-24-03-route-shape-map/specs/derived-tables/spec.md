## MODIFIED Requirements

### Requirement: Derived export

For an eligible day the system SHALL run `analysis/params.sql`, every numbered stage file in file name order, then `analysis/mrt_overlap.sql` with the newest MRT entrance snapshot by file name date, then `analysis/turnaround_facilities.sql` with the newest public toilet snapshot by file name date and the natures of the route's two ends from the configuration defined by `turnaround-ends` (or `unknown` for both when the route is not configured), then `analysis/route_shape.sql` with the route shapes file of the day's static snapshot as defined by `route-shape`, and then `analysis/derived_export.sql`, which SHALL write nine CSV files: the route day (route `Id`, name, departure, destination, static snapshot day, the day of the entrance snapshot used and the day of the toilet snapshot used), the stops of both directions (direction, sequence number, stop name, latitude, longitude, nearest entrance name and distance as defined by `mrt-overlap`), the trips of the day as defined by `trip-reconstruction` together with each trip's time band from `load-profile`, the layovers as defined by `layover-metrics` with the end time of the trip and the start time of the next trip, the per-stop on-board counts of each trip as defined by `load-profile`, the ends of the route (direction, last stop sequence number, name, latitude and longitude, location source, location latitude and longitude, numbers of layovers, located layovers and standstill reports, and metres from the location to the last stop) as defined by `turnaround-facilities`, the toilets within the radius of each located end (direction, name, category, address, latitude, longitude, metres) as defined by `turnaround-facilities`, the standstill cells of each end (direction, cell latitude, cell longitude, numbers of standstill reports, vehicles and layovers) as defined by `turnaround-facilities`, and the route shapes, one row per direction (direction, update time, the points as a JSON array of latitude and longitude pairs, and the reason when the direction has no shape that can be kept or had more than one row) as defined by `route-shape`. The `bus_data` hour files SHALL be read only by `analysis/turnaround_facilities.sql`, over the same read window as the stage files, and the route shapes file only by `analysis/route_shape.sql`, so that `bin/health-card` and its inspection files do not change. Timestamps SHALL be written with the `+08:00` offset. Rows SHALL be sorted so that two runs over the same input produce byte-identical files.

#### Scenario: Stage order shared with the health card

- **WHEN** `bin/health-card` and `derived:load` assemble their SQL
- **THEN** both put the variable settings first, `analysis/params.sql` second and the numbered stage files after it in file name order, and only `derived:load` appends `analysis/mrt_overlap.sql`, `analysis/turnaround_facilities.sql`, `analysis/route_shape.sql` and `analysis/derived_export.sql` in that order

#### Scenario: Newest snapshot used

- **WHEN** the snapshot folder holds `2026-10-20.csv` and `2026-10-22.csv` and day 2026-10-19 is loaded
- **THEN** the distances come from `2026-10-22.csv` and the stored route day records 2026-10-22 as its entrance snapshot day

#### Scenario: Newest toilet snapshot used

- **WHEN** `external/public-toilets/` holds `2026-10-20.csv` and `2026-10-23.csv` and day 2026-10-19 is loaded
- **THEN** the toilets come from `2026-10-23.csv` and the stored route day records 2026-10-23 as its toilet snapshot day

#### Scenario: Nine files written

- **WHEN** the fixture day 2026-10-19 of route 9001 is exported twice
- **THEN** both runs write `route_day.csv`, `stops.csv`, `trips.csv`, `layovers.csv`, `trip_stop_counts.csv`, `ends.csv`, `end_toilets.csv`, `end_cells.csv` and `shapes.csv` with identical bytes, and the health card's inspection files are unchanged

### Requirement: Replace one route day atomically

Writing a day SHALL happen in one database transaction that first deletes the existing route day of the same route `Id` and Taipei day, together with all its stops, trips, layovers, trip stop counts, ends, end toilets, end cells and shapes, and then inserts the nine files, taking from the route shapes file only the rows that have points. A failure at any step SHALL leave the previously stored data of that day unchanged. Loading the same day twice from the same input SHALL leave the same rows.

#### Scenario: Reload is idempotent

- **WHEN** the fixture day 2026-10-19 of route 9001 is loaded twice
- **THEN** the number of trips, layovers, trip stop counts, ends, end toilets, end cells and shapes stored for that day equals the number after the first load

#### Scenario: Failure keeps the old day

- **WHEN** a day is already stored and a later load of the same day fails while inserting
- **THEN** the stored trips of that day are the ones from the earlier load
