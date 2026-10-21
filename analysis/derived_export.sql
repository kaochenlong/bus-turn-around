-- Derived export: the per-trip results of one route and one Taipei day, for
-- the PostgreSQL derived tables. It runs after params.sql, every numbered
-- stage and mrt_overlap.sql; its name does not start with a digit, so
-- bin/health-card never runs it.
--
-- Reads routes and stops from stage 10, trips from stage 20, layovers from
-- stage 30, trip_bands and trip_stop_counts from stage 40, stop_mrt_distances
-- from mrt_overlap.sql, and the variables route_id, day, static_day,
-- mrt_exits_day and derived_dir. Writes to derived_dir:
--   route_day.csv         the route's name and terminals, one row
--   stops.csv             the stops of both directions, with the nearest MRT
--                         entrance
--   trips.csv             the day's trips with their time band
--   layovers.csv          the end of each trip and the start of the next
--   trip_stop_counts.csv  the on-board count per counted stop of each trip
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
           strftime(getvariable('mrt_exits_day'), '%Y-%m-%d') AS mrt_exits_day
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
