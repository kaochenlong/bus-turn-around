-- Derived export: the per-trip results of one route and one Taipei day, for
-- the PostgreSQL derived tables. It runs after params.sql, every numbered
-- stage, mrt_overlap.sql and turnaround_facilities.sql; its name does not
-- start with a digit, so bin/health-card never runs it.
--
-- Reads routes and stops from stage 10, trips from stage 20, layovers from
-- stage 30, trip_bands and trip_stop_counts from stage 40, stop_mrt_distances
-- from mrt_overlap.sql, turnaround_ends, end_toilets and standstill_cells from
-- turnaround_facilities.sql, and the variables route_id, day, static_day,
-- mrt_exits_day, public_toilets_day and derived_dir. Writes to derived_dir:
--   route_day.csv         the route's name and terminals, one row
--   stops.csv             the stops of both directions, with the nearest MRT
--                         entrance
--   trips.csv             the day's trips with their time band
--   layovers.csv          the end of each trip and the start of the next
--   trip_stop_counts.csv  the on-board count per counted stop of each trip
--   ends.csv              both ends: last stop, location and check numbers
--   end_toilets.csv       the toilets within the radius of each located end
--   end_cells.csv         the standstill cells of each end
-- Timestamps carry the Taipei offset, and every file has a fixed column order
-- and row order, so two runs over the same input give the same bytes.

CREATE OR REPLACE MACRO taipei_text(ts) AS strftime(ts, '%Y-%m-%d %H:%M:%S') || '+08:00';

-- The route's own pathAttributeId names the route; another sub-route is used
-- only when the route has none.
COPY (
    SELECT route_id,
           strftime(getvariable('day'), '%Y-%m-%d') AS day,
           route_name,
           departure,
           destination,
           strftime(getvariable('static_day'), '%Y-%m-%d') AS static_day,
           strftime(getvariable('mrt_exits_day'), '%Y-%m-%d') AS mrt_exits_day,
           strftime(getvariable('public_toilets_day'), '%Y-%m-%d') AS public_toilets_day
    FROM routes
    ORDER BY path_attribute_id <> route_id, path_attribute_id
    LIMIT 1
) TO (getvariable('derived_dir') || '/route_day.csv') (HEADER);

COPY (
    SELECT s.go_back, s.seq, s.stop_name, d.latitude, d.longitude, d.nearest_exit_name, d.nearest_exit_meters
    FROM stops s
    LEFT JOIN stop_mrt_distances d USING (go_back, seq)
    ORDER BY s.go_back, s.seq
) TO (getvariable('derived_dir') || '/stops.csv') (HEADER);

COPY (
    SELECT t.bus_id, t.path_attribute_id, t.go_back, b.band,
           taipei_text(t.start_time) AS start_time, taipei_text(t.end_time) AS end_time,
           t.first_seq, t.last_seq, t.n_events, t.n_stops_observed, t.completeness,
           t.start_from_arrival, t.end_from_departure
    FROM trips t
    JOIN trip_bands b USING (trip_id)
    ORDER BY t.bus_id, t.start_time, t.trip_id
) TO (getvariable('derived_dir') || '/trips.csv') (HEADER);

COPY (
    SELECT bus_id, go_back, taipei_text(end_time) AS end_time, taipei_text(next_start_time) AS next_start_time
    FROM layovers
    ORDER BY bus_id, end_time
) TO (getvariable('derived_dir') || '/layovers.csv') (HEADER);

-- A trip is named by its vehicle and start time, the key the loader uses to
-- find it again in PostgreSQL.
COPY (
    SELECT t.bus_id, taipei_text(t.start_time) AS start_time, c.seq, c.on_board
    FROM trip_stop_counts c
    JOIN trips t USING (trip_id)
    ORDER BY t.bus_id, t.start_time, c.seq
) TO (getvariable('derived_dir') || '/trip_stop_counts.csv') (HEADER);

COPY (
    SELECT go_back, end_seq, end_stop_name, end_latitude, end_longitude, location_source, latitude, longitude,
           n_layovers, n_located_layovers, n_standstill_records, end_stop_meters
    FROM turnaround_ends
    ORDER BY go_back
) TO (getvariable('derived_dir') || '/ends.csv') (HEADER);

-- The loader finds the end of a toilet or a cell again by its direction.
COPY (
    SELECT go_back, name, category, address, latitude, longitude, meters
    FROM end_toilets
    ORDER BY go_back, meters, name
) TO (getvariable('derived_dir') || '/end_toilets.csv') (HEADER);

COPY (
    SELECT go_back, cell_latitude, cell_longitude, n_records, n_buses, n_layovers
    FROM standstill_cells
    ORDER BY go_back, cell_latitude, cell_longitude
) TO (getvariable('derived_dir') || '/end_cells.csv') (HEADER);
