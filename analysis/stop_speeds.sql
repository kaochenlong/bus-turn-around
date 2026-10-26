-- Stop speeds: where each stop of the page route lies along the route shape
-- of its direction, and how fast each trip of the page route ran between two
-- placed stops, from its vehicle's GPS reports placed on the same shape. It
-- runs after params.sql, every numbered stage, mrt_overlap.sql, whose
-- haversine_meters gives the metres of a degree, gps_reports.sql and
-- route_shape.sql, and before derived_export.sql; its name does not start
-- with a digit, so bin/health-card never runs it.
--
-- Reads stops from stage 10, trips from stage 20, gps_reports from
-- gps_reports.sql, route_shapes from route_shape.sql and the variable
-- route_id. Creates:
--   shape_origins   per direction with a shape: the cosine of the mean
--                   latitude of its points, which scales a degree of longitude
--   shape_pieces    per direction with a shape: each piece between two
--                   consecutive points, in plane metres, with the metres along
--                   the shape where it starts
--   stop_positions  every stop of the run, with the metres along its
--                   direction's shape, NULL when it has no position
--   stop_legs       per direction, each placed stop of the page route with the
--                   next one (a view)
--   placed_reports  the GPS reports of each counted trip from its start to its
--                   end, each at the metres along the trip direction's shape
--                   (a view)
--   report_pairs    consecutive placed reports of a trip (a view)
--   trip_stop_speeds  per counted trip and leg with a counted pair: the band,
--                   the metres and the seconds of its counted pairs (a view)
-- The views read gps_reports, trips and stops when they are queried, so a
-- test can replace those tables after this file has run; stop_positions is a
-- table built when this file runs.

-- Plane metres: a degree of latitude is haversine_meters(0, 0, 1, 0) metres,
-- on the sphere of mrt_overlap.sql, and a degree of longitude that times the
-- cosine of the mean latitude of the direction's shape points. A route spans
-- less than 0.2 degrees of latitude, so the cosine changes by less than one
-- part in a thousand along it.
SET VARIABLE meters_per_degree = haversine_meters(0, 0, 1, 0);

CREATE OR REPLACE TABLE shape_origins AS
SELECT go_back, cos(radians(avg(point[1]))) AS cos_latitude
FROM (SELECT go_back, unnest(points) AS point FROM route_shapes WHERE points IS NOT NULL)
GROUP BY go_back;

-- Pieces of no length, between two equal points, are left out: they hold no
-- point a stop or a report could be placed on that the next piece lacks.
CREATE OR REPLACE TABLE shape_pieces AS
WITH points AS (
    SELECT go_back, unnest(range(1, len(points) + 1)) AS point_no, unnest(points) AS point
    FROM route_shapes
    WHERE points IS NOT NULL
),
plane AS (
    SELECT p.go_back,
           p.point_no,
           p.point[2] * getvariable('meters_per_degree') * o.cos_latitude AS x,
           p.point[1] * getvariable('meters_per_degree') AS y
    FROM points p
    JOIN shape_origins o USING (go_back)
),
pieces AS (
    SELECT go_back,
           point_no AS piece_no,
           x AS x1,
           y AS y1,
           lead(x) OVER direction_points AS x2,
           lead(y) OVER direction_points AS y2
    FROM plane
    WINDOW direction_points AS (PARTITION BY go_back ORDER BY point_no)
),
measured AS (
    SELECT *, sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2) AS length
    FROM pieces
    WHERE x2 IS NOT NULL
)
SELECT go_back,
       piece_no,
       x1,
       y1,
       x2,
       y2,
       length,
       coalesce(sum(length) OVER (PARTITION BY go_back ORDER BY piece_no ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), 0) AS start_meters
FROM measured
WHERE length > 0;

-- The page route's stops of each direction are placed in sequence order. A
-- stop is placed at the nearest point of the shape at or after the last
-- placed stop of its direction: on every piece that reaches that far, the
-- point nearest to the stop, never before that position. Among the pieces'
-- points no more than stop_tie_meters farther than the nearest, the earliest
-- along the shape is taken. A stop farther than shape_snap_meters from all of
-- them has no position, and the next stop is placed after the last placed
-- one. The search starts from the beginning of the shape (after = 0) with a
-- row numbered 0 that stands for no stop.
CREATE OR REPLACE TABLE stop_positions AS
WITH RECURSIVE
ordered AS (
    SELECT s.go_back,
           s.seq,
           row_number() OVER (PARTITION BY s.go_back ORDER BY s.seq) AS stop_no,
           s.longitude * getvariable('meters_per_degree') * o.cos_latitude AS x,
           s.latitude * getvariable('meters_per_degree') AS y
    FROM stops s
    JOIN shape_origins o USING (go_back)
    WHERE s.route_id = getvariable('route_id') AND s.latitude IS NOT NULL AND s.longitude IS NOT NULL
),
placed(go_back, stop_no, seq, shape_meters, after_meters) AS (
    SELECT go_back, 0, CAST(NULL AS INTEGER), CAST(NULL AS DOUBLE), CAST(0 AS DOUBLE)
    FROM shape_origins
    UNION ALL
    SELECT go_back,
           stop_no,
           seq,
           CASE WHEN nearest <= getvariable('shape_snap_meters') THEN along END,
           CASE WHEN nearest <= getvariable('shape_snap_meters') THEN along ELSE after_meters END
    FROM (
        SELECT go_back, stop_no, seq, after_meters, along, distance, min(distance) OVER (PARTITION BY go_back) AS nearest
        FROM (
            SELECT s.go_back,
                   s.stop_no,
                   s.seq,
                   pl.after_meters,
                   p.start_meters + t * p.length AS along,
                   sqrt((s.x - (p.x1 + t * (p.x2 - p.x1))) ** 2 + (s.y - (p.y1 + t * (p.y2 - p.y1))) ** 2) AS distance
            FROM placed pl
            JOIN ordered s ON s.go_back = pl.go_back AND s.stop_no = pl.stop_no + 1
            JOIN shape_pieces p ON p.go_back = s.go_back AND p.start_meters + p.length >= pl.after_meters,
                 LATERAL (
                     SELECT least(1, greatest(0, (pl.after_meters - p.start_meters) / p.length,
                                              ((s.x - p.x1) * (p.x2 - p.x1) + (s.y - p.y1) * (p.y2 - p.y1)) / p.length ** 2)) AS t
                 )
        )
    )
    WHERE distance <= nearest + getvariable('stop_tie_meters')
    QUALIFY row_number() OVER (PARTITION BY go_back ORDER BY along) = 1
)
SELECT s.route_id, s.go_back, s.seq, pl.shape_meters
FROM stops s
LEFT JOIN placed pl ON s.route_id = getvariable('route_id') AND pl.go_back = s.go_back AND pl.seq = s.seq AND pl.stop_no > 0;

CREATE OR REPLACE VIEW stop_legs AS
SELECT go_back, seq, next_seq, start_meters, end_meters
FROM (
    SELECT go_back,
           seq,
           lead(seq) OVER direction_stops AS next_seq,
           shape_meters AS start_meters,
           lead(shape_meters) OVER direction_stops AS end_meters
    FROM stop_positions
    WHERE route_id = getvariable('route_id') AND shape_meters IS NOT NULL
    WINDOW direction_stops AS (PARTITION BY go_back ORDER BY seq)
)
WHERE next_seq IS NOT NULL;

-- The counted trips are the page route's trips whose start is not an arrival:
-- after an arrival at the first stop the vehicle can still be waiting, and the
-- trip's time would hold the wait. Each report of the trip's vehicle from the
-- trip's start to its end, both included, is placed at the nearest point of
-- the shape of the trip's direction, the earliest along the shape among
-- equally near ones, and left out farther than shape_snap_meters. Only the
-- pieces whose box, widened by that distance, holds the report are measured;
-- a piece outside it is farther than that anyway.
CREATE OR REPLACE VIEW placed_reports AS
WITH trip_reports AS (
    SELECT t.trip_id,
           t.bus_id,
           t.start_time,
           t.go_back,
           g.data_time,
           g.longitude * getvariable('meters_per_degree') * o.cos_latitude AS x,
           g.latitude * getvariable('meters_per_degree') AS y
    FROM trips t
    JOIN shape_origins o ON o.go_back = t.go_back
    JOIN gps_reports g ON g.bus_id = t.bus_id AND g.data_time BETWEEN t.start_time AND t.end_time
    WHERE t.route_id = getvariable('route_id')
      AND NOT t.start_from_arrival
      AND g.latitude IS NOT NULL
      AND g.longitude IS NOT NULL
),
nearest AS (
    SELECT r.trip_id,
           r.bus_id,
           r.start_time,
           r.go_back,
           r.data_time,
           min({'distance': sqrt((r.x - (p.x1 + f.t * (p.x2 - p.x1))) ** 2 + (r.y - (p.y1 + f.t * (p.y2 - p.y1))) ** 2),
                'along': p.start_meters + f.t * p.length}) AS best
    FROM trip_reports r
    JOIN shape_pieces p
      ON p.go_back = r.go_back
     AND r.x BETWEEN least(p.x1, p.x2) - getvariable('shape_snap_meters') AND greatest(p.x1, p.x2) + getvariable('shape_snap_meters')
     AND r.y BETWEEN least(p.y1, p.y2) - getvariable('shape_snap_meters') AND greatest(p.y1, p.y2) + getvariable('shape_snap_meters'),
         LATERAL (SELECT least(1, greatest(0, ((r.x - p.x1) * (p.x2 - p.x1) + (r.y - p.y1) * (p.y2 - p.y1)) / p.length ** 2)) AS t) f
    GROUP BY r.trip_id, r.bus_id, r.start_time, r.go_back, r.data_time
)
SELECT trip_id, bus_id, start_time, go_back, data_time, best.along AS shape_meters
FROM nearest
WHERE best.distance <= getvariable('shape_snap_meters');

CREATE OR REPLACE VIEW report_pairs AS
SELECT trip_id,
       bus_id,
       start_time,
       go_back,
       previous_time,
       data_time,
       epoch(data_time) - epoch(previous_time) AS seconds,
       shape_meters - previous_meters AS meters,
       (shape_meters + previous_meters) / 2 AS midpoint
FROM (
    SELECT *,
           lag(data_time) OVER trip_reports AS previous_time,
           lag(shape_meters) OVER trip_reports AS previous_meters
    FROM placed_reports
    WINDOW trip_reports AS (PARTITION BY trip_id ORDER BY data_time)
)
WHERE previous_time IS NOT NULL;

-- A pair counts when it is more than 0 and at most pair_max_seconds long, does
-- not go backwards and covers at most pair_max_meters_per_second. It belongs
-- to the leg whose first stop is at or before its midpoint and whose last stop
-- is after it, and is dropped when the midpoint is less than stop_zone_meters
-- from either stop of the leg; a midpoint before the first placed stop or at or
-- after the last one has no leg. The band is that of the earlier report of the
-- leg's first counted pair. The sums run in time order, so two runs over the
-- same input give the same metres.
CREATE OR REPLACE VIEW trip_stop_speeds AS
SELECT p.trip_id,
       p.bus_id,
       p.start_time,
       p.go_back,
       l.seq,
       time_band(min(p.previous_time)) AS band,
       round(sum(p.meters ORDER BY p.previous_time), 1) AS meters,
       CAST(sum(p.seconds) AS INTEGER) AS seconds
FROM report_pairs p
JOIN stop_legs l ON l.go_back = p.go_back AND p.midpoint >= l.start_meters AND p.midpoint < l.end_meters
WHERE p.seconds > 0
  AND p.seconds <= getvariable('pair_max_seconds')
  AND p.meters >= 0
  AND p.meters <= getvariable('pair_max_meters_per_second') * p.seconds
  AND p.midpoint - l.start_meters >= getvariable('stop_zone_meters')
  AND l.end_meters - p.midpoint >= getvariable('stop_zone_meters')
GROUP BY p.trip_id, p.bus_id, p.start_time, p.go_back, l.seq;
