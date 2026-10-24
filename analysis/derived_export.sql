-- Derived export: the per-trip results of one route and one Taipei day, for
-- the PostgreSQL derived tables. It runs after params.sql, every numbered
-- stage, mrt_overlap.sql, turnaround_facilities.sql, route_shape.sql and
-- depots.sql; its name does not start with a digit, so bin/health-card never
-- runs it.
--
-- Reads routes and stops from stage 10, trips from stage 20, layovers from
-- stage 30, trip_bands and trip_stop_counts from stage 40, stop_mrt_distances
-- from mrt_overlap.sql, turnaround_ends, end_toilets and standstill_cells from
-- turnaround_facilities.sql, route_shapes from route_shape.sql,
-- route_day_depots from depots.sql, and the variables route_id, day,
-- static_day, mrt_exits_day, public_toilets_day and derived_dir. Writes to
-- derived_dir:
--   route_day.csv         the page route's name and terminals and its member
--                         routes' names, one row
--   stops.csv             the stops of both directions of every route Id of
--                         the run, with the nearest MRT entrance, the route Id
--                         and the stop location
--   trips.csv             the day's trips with their time band and route Id
--   layovers.csv          the end of each trip and the start of the next
--   trip_stop_counts.csv  the on-board count per counted stop of each trip
--   ends.csv              both ends: last stop, location and check numbers
--   end_toilets.csv       the toilets within the radius of each located end
--   end_cells.csv         the standstill cells of each end
--   shapes.csv            the route shape of each direction, or why it has none
--   depots.csv            the depots of the day's trips, with their vehicles and trips
-- Timestamps carry the Taipei offset, and every file has a fixed column order
-- and row order, so two runs over the same input give the same bytes.

CREATE OR REPLACE MACRO taipei_text(ts) AS strftime(ts, '%Y-%m-%d %H:%M:%S') || '+08:00';

-- The page route names the day; its own pathAttributeId names it, another
-- sub-route only when it has none. member_names is a JSON object of the
-- member routes' names keyed by route Id, in Id order, {} without members.
COPY (
    SELECT route_id,
           strftime(getvariable('day'), '%Y-%m-%d') AS day,
           route_name,
           departure,
           destination,
           strftime(getvariable('static_day'), '%Y-%m-%d') AS static_day,
           strftime(getvariable('mrt_exits_day'), '%Y-%m-%d') AS mrt_exits_day,
           strftime(getvariable('public_toilets_day'), '%Y-%m-%d') AS public_toilets_day,
           (SELECT coalesce('{' || string_agg(format('"{}":{}', route_id, to_json(route_name)), ',' ORDER BY route_id) || '}', '{}')
            FROM (SELECT route_id, any_value(route_name) AS route_name FROM routes WHERE route_id <> getvariable('route_id') GROUP BY route_id)) AS member_names
    FROM routes
    WHERE route_id = getvariable('route_id')
    ORDER BY path_attribute_id <> route_id, path_attribute_id
    LIMIT 1
) TO (getvariable('derived_dir') || '/route_day.csv') (HEADER);

-- The page route's stops first, then each member route's, by route Id.
COPY (
    SELECT s.go_back, s.seq, s.stop_name, d.latitude, d.longitude, d.nearest_exit_name, d.nearest_exit_meters, s.route_id, s.stop_location_id
    FROM stops s
    LEFT JOIN stop_mrt_distances d USING (route_id, go_back, seq)
    ORDER BY s.route_id <> getvariable('route_id'), s.route_id, s.go_back, s.seq
) TO (getvariable('derived_dir') || '/stops.csv') (HEADER);

COPY (
    SELECT t.bus_id, t.path_attribute_id, t.go_back, b.band,
           taipei_text(t.start_time) AS start_time, taipei_text(t.end_time) AS end_time,
           t.first_seq, t.last_seq, t.n_events, t.n_stops_observed, t.completeness,
           t.start_from_arrival, t.end_from_departure, t.route_id
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
-- find it again in PostgreSQL. seq is the page route's sequence number
-- (page_seq of stage 40); a count the page route has no stop for is not
-- written.
COPY (
    SELECT t.bus_id, taipei_text(t.start_time) AS start_time, c.page_seq AS seq, c.on_board
    FROM trip_stop_counts c
    JOIN trips t USING (trip_id)
    WHERE c.page_seq IS NOT NULL
    ORDER BY t.bus_id, t.start_time, c.page_seq
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

-- One row per direction. A direction without a route shape has no update time
-- and no points; its issue says why, and the loader stores only the rows with
-- points.
COPY (
    SELECT go_back, taipei_text(shape_updated_at) AS shape_updated_at, to_json(points) AS points, issue
    FROM route_shapes
    ORDER BY go_back
) TO (getvariable('derived_dir') || '/shapes.csv') (HEADER);

-- The depot with the most vehicles first. A name the operators file does not
-- give is an empty string, which the file writes as "".
COPY (
    SELECT station_id, provider_name, station_name, n_buses, n_trips
    FROM route_day_depots
    ORDER BY n_buses DESC, station_id
) TO (getvariable('derived_dir') || '/depots.csv') (HEADER);
