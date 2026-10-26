-- Turnaround facilities: where each end of the route stood still between
-- trips, the public toilets near that location, and the standstill cells of
-- each end for a map. It runs after params.sql, every numbered stage,
-- mrt_overlap.sql, whose haversine_meters it uses, and gps_reports.sql, and
-- before derived_export.sql; its name does not start with a digit, so
-- bin/health-card never runs it.
--
-- Reads stops from stage 10, layovers from stage 30, gps_reports from
-- gps_reports.sql, and the variables public_toilets_path, a snapshot written by
-- bin/rails external:public_toilets, and end_nature_0 and end_nature_1, the
-- configured nature of each end: 'stop', 'pass_through', or 'unknown' when
-- the route is not configured. Creates:
--   public_toilets      the snapshot's toilets, one row per toilet
--   standstill_records  speed-0 reports during the layovers of both ends (a view)
--   turnaround_ends     per end: last stop, location, its source and the check
--                       numbers (a view)
--   end_toilets         per located end: every toilet within the toilet radius (a view)
--   standstill_cells    per end: cells of standstill reports where at least
--                       cell_min_buses vehicles stood (a view)
-- When either end is 'unknown', the last three are empty. The views read
-- gps_reports and public_toilets when they are queried, so a test can replace
-- those tables after this file has run.

-- Anything else than the three natures would silently leave an end without a
-- location, so it stops the run.
SET VARIABLE end_natures_checked = (
    SELECT CASE WHEN count(*) FILTER (WHERE nature IS NULL OR nature NOT IN ('stop', 'pass_through', 'unknown')) > 0
                THEN error('end_nature_0 與 end_nature_1 要是 stop、pass_through 或 unknown')
                ELSE true END
    FROM (VALUES (getvariable('end_nature_0')), (getvariable('end_nature_1'))) AS t(nature)
);

CREATE OR REPLACE VIEW end_natures AS
SELECT *
FROM (VALUES (0, getvariable('end_nature_0')), (1, getvariable('end_nature_1'))) AS t(go_back, nature)
WHERE NOT EXISTS (
    SELECT 1 FROM (VALUES (getvariable('end_nature_0')), (getvariable('end_nature_1'))) AS n(nature) WHERE nature = 'unknown'
);

-- The cell of a coordinate: the quotient is rounded to six decimals before it
-- is truncated, so a coordinate on a grid line, such as 25.0604, does not fall
-- into the cell below it through a floating point error.
CREATE OR REPLACE MACRO standstill_cell_corner(degrees) AS
    round(trunc(round(degrees / getvariable('standstill_cell_degrees'), 6)) * getvariable('standstill_cell_degrees'), 4);

CREATE OR REPLACE TABLE public_toilets AS
SELECT name, type2 AS category, address, latitude, longitude
FROM read_csv(getvariable('public_toilets_path'), header = true, delim = ',', quote = '"', escape = '"', columns = {
    'county': 'VARCHAR', 'areacode': 'VARCHAR', 'village': 'VARCHAR', 'number': 'VARCHAR', 'name': 'VARCHAR',
    'address': 'VARCHAR', 'administration': 'VARCHAR', 'latitude': 'DOUBLE', 'longitude': 'DOUBLE',
    'grade': 'VARCHAR', 'type2': 'VARCHAR', 'type': 'VARCHAR', 'exec': 'VARCHAR', 'diaper': 'VARCHAR'
});

-- A standstill report is a speed-0 record of the layover's vehicle from the
-- end of its trip to the start of the next, both included, whatever its
-- RouteID; a record without a numeric position cannot be placed and is left
-- out. go_back is the direction of the trip that ended, that is, the end.
CREATE OR REPLACE VIEW standstill_records AS
SELECT l.go_back, l.trip_id, g.bus_id, g.latitude, g.longitude, g.data_time
FROM layovers l
JOIN gps_reports g ON g.bus_id = l.bus_id AND g.data_time BETWEEN l.end_time AND l.next_start_time
WHERE g.speed = 0 AND g.latitude IS NOT NULL AND g.longitude IS NOT NULL;

-- The location of a stopping end. Reports at one coordinate form a standstill
-- point; the seed is the point with the most reports within the standstill
-- radius, itself included, the smaller latitude and then longitude breaking a
-- tie, so the result never depends on row order. The location is the
-- count-weighted mean of the points within the radius of the seed, and every
-- distance from it is measured from the six-decimal value stored.
-- The ends are the page route's last stops; its member routes share its two
-- ends (turnaround-ends), so their stop lists are not read here.
CREATE OR REPLACE VIEW turnaround_ends AS
WITH last_stops AS (
    SELECT go_back, seq AS end_seq, stop_name AS end_stop_name, latitude AS end_latitude, longitude AS end_longitude
    FROM stops
    WHERE route_id = getvariable('route_id')
    QUALIFY row_number() OVER (PARTITION BY go_back ORDER BY seq DESC) = 1
),
layover_counts AS (
    SELECT go_back, count(*) AS n_layovers FROM layovers GROUP BY go_back
),
report_counts AS (
    SELECT go_back, count(*) AS n_standstill_records FROM standstill_records GROUP BY go_back
),
points AS (
    SELECT r.go_back, r.latitude, r.longitude, count(*) AS n_reports
    FROM standstill_records r
    JOIN end_natures e ON e.go_back = r.go_back AND e.nature = 'stop'
    GROUP BY r.go_back, r.latitude, r.longitude
),
seeds AS (
    SELECT p.go_back, p.latitude, p.longitude
    FROM points p
    JOIN points q ON q.go_back = p.go_back
                 AND haversine_meters(p.latitude, p.longitude, q.latitude, q.longitude) <= getvariable('standstill_radius_meters')
    GROUP BY p.go_back, p.latitude, p.longitude
    QUALIFY row_number() OVER (PARTITION BY p.go_back ORDER BY sum(q.n_reports) DESC, p.latitude, p.longitude) = 1
),
locations AS (
    SELECT s.go_back,
           round(sum(p.latitude * p.n_reports) / sum(p.n_reports), 6) AS latitude,
           round(sum(p.longitude * p.n_reports) / sum(p.n_reports), 6) AS longitude
    FROM seeds s
    JOIN points p ON p.go_back = s.go_back
                 AND haversine_meters(s.latitude, s.longitude, p.latitude, p.longitude) <= getvariable('standstill_radius_meters')
    GROUP BY s.go_back
),
located_layovers AS (
    SELECT r.go_back, count(DISTINCT r.trip_id) AS n_located_layovers
    FROM standstill_records r
    JOIN locations l ON l.go_back = r.go_back
    WHERE haversine_meters(l.latitude, l.longitude, r.latitude, r.longitude) <= getvariable('located_radius_meters')
    GROUP BY r.go_back
)
SELECT e.go_back,
       s.end_seq,
       s.end_stop_name,
       s.end_latitude,
       s.end_longitude,
       CASE WHEN e.nature = 'pass_through' THEN 'end_stop'
            WHEN l.latitude IS NOT NULL THEN 'standstill' END AS location_source,
       CASE WHEN e.nature = 'pass_through' THEN s.end_latitude ELSE l.latitude END AS latitude,
       CASE WHEN e.nature = 'pass_through' THEN s.end_longitude ELSE l.longitude END AS longitude,
       coalesce(c.n_layovers, 0) AS n_layovers,
       CASE WHEN l.latitude IS NOT NULL THEN coalesce(k.n_located_layovers, 0) END AS n_located_layovers,
       coalesce(r.n_standstill_records, 0) AS n_standstill_records,
       CASE WHEN e.nature = 'pass_through' THEN 0.0
            WHEN l.latitude IS NOT NULL
            THEN round(haversine_meters(l.latitude, l.longitude, s.end_latitude, s.end_longitude), 1) END AS end_stop_meters
FROM end_natures e
JOIN last_stops s ON s.go_back = e.go_back
LEFT JOIN layover_counts c ON c.go_back = e.go_back
LEFT JOIN report_counts r ON r.go_back = e.go_back
LEFT JOIN locations l ON l.go_back = e.go_back
LEFT JOIN located_layovers k ON k.go_back = e.go_back;

-- One row per toilet, not per place: grouping toilets into places is done
-- where the rows are read.
CREATE OR REPLACE VIEW end_toilets AS
SELECT e.go_back,
       t.name,
       t.category,
       t.address,
       t.latitude,
       t.longitude,
       round(haversine_meters(e.latitude, e.longitude, t.latitude, t.longitude), 1) AS meters
FROM turnaround_ends e
JOIN public_toilets t
  ON haversine_meters(e.latitude, e.longitude, t.latitude, t.longitude) <= getvariable('toilet_radius_meters')
WHERE e.latitude IS NOT NULL;

-- Both ends keep their cells whatever their nature. The vehicle threshold is
-- applied per day, because vehicles of different days cannot be added up.
CREATE OR REPLACE VIEW standstill_cells AS
SELECT r.go_back,
       standstill_cell_corner(r.latitude) AS cell_latitude,
       standstill_cell_corner(r.longitude) AS cell_longitude,
       count(*) AS n_records,
       count(DISTINCT r.bus_id) AS n_buses,
       count(DISTINCT r.trip_id) AS n_layovers
FROM standstill_records r
JOIN end_natures e ON e.go_back = r.go_back
GROUP BY r.go_back, cell_latitude, cell_longitude
HAVING count(DISTINCT r.bus_id) >= getvariable('cell_min_buses');
