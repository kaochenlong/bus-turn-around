-- Route shape: the line 臺北市公共運輸處 registers for each direction of the
-- route in the route shapes file (GetBusShape) of the day's static snapshot,
-- for the route map. It runs after params.sql, every numbered stage,
-- mrt_overlap.sql and turnaround_facilities.sql, and before
-- derived_export.sql, but reads nothing they create; its name does not start
-- with a digit, so bin/health-card never runs it, and only this file reads
-- the route shapes file.
--
-- Reads the variables route_id and bus_shape_path: the snapshot's route
-- shapes file, or a file holding an empty array when the snapshot has none.
-- Creates:
--   route_shape_rows  the file's rows of the route itself, SubRouteID -1, each
--                     with its points and, when it cannot be kept, why
--   route_shapes      one row for direction 0 and one for direction 1: the
--                     update time and points of the row kept, and issue, the
--                     reason when the direction has no row that can be kept or
--                     had more than one row

-- The file is one JSON array. Its values are read as VARCHAR and cast, so a
-- value of another type makes a row that cannot be kept instead of failing
-- the run. utime is Taipei time without an offset. SubRouteID -1 is the
-- whole route; any other value is a special sub-route.
CREATE OR REPLACE TABLE route_shape_rows AS
WITH route_rows AS (
    SELECT TRY_CAST(GoBack AS INTEGER) AS go_back,
           TRY_CAST(utime AS TIMESTAMP) AS updated_at,
           wkt
    FROM read_json(getvariable('bus_shape_path'), format = 'array', maximum_object_size = 268435456,
                   columns = { RouteID: 'VARCHAR', SubRouteID: 'VARCHAR', GoBack: 'VARCHAR', utime: 'VARCHAR', wkt: 'VARCHAR' })
    WHERE TRY_CAST(RouteID AS BIGINT) = getvariable('route_id')
      AND TRY_CAST(SubRouteID AS BIGINT) = -1
),
-- A WKT LINESTRING lists its points between the parentheses, separated by
-- commas, each as longitude and latitude separated by a space. A point that
-- is not two numbers, or a geometry of another type, leaves a NULL
-- coordinate.
coordinates AS (
    SELECT go_back, updated_at, wkt,
           list_transform(
               regexp_split_to_array(trim(regexp_extract(wkt, '^LINESTRING\s*\((.*)\)$', 1)), '\s*,\s*'),
               lambda point: regexp_extract(trim(point), '^(\S+)\s+(\S+)$', ['longitude', 'latitude'])
           ) AS texts
    FROM route_rows
),
-- Six decimals are about 0.1 metres.
points AS (
    SELECT go_back, updated_at, wkt,
           list_transform(texts, lambda c: {
               'latitude': round(TRY_CAST(c.latitude AS DOUBLE), 6),
               'longitude': round(TRY_CAST(c.longitude AS DOUBLE), 6)
           }) AS coordinates
    FROM coordinates
)
SELECT go_back,
       updated_at,
       wkt,
       list_transform(coordinates, lambda c: [c.latitude, c.longitude]) AS points,
       CASE
           WHEN NOT coalesce(list_bool_and(list_transform(coordinates, lambda c: c.latitude IS NOT NULL AND c.longitude IS NOT NULL)), false)
               THEN 'not_linestring'
           WHEN len(coordinates) < getvariable('route_shape_min_points') THEN 'too_few_points'
           WHEN NOT list_bool_and(list_transform(coordinates, lambda c:
                    c.latitude BETWEEN getvariable('route_shape_min_latitude') AND getvariable('route_shape_max_latitude')
                    AND c.longitude BETWEEN getvariable('route_shape_min_longitude') AND getvariable('route_shape_max_longitude')))
               THEN 'out_of_range'
           WHEN updated_at IS NULL THEN 'no_update_time'
       END AS unusable
FROM points;

-- Per direction, the row kept is the usable row with the latest update time;
-- the geometry breaks a tie, so two runs keep the same row. A direction
-- without a usable row reports why its first row in that order cannot be
-- kept. A kept row is reported when the direction had any other row.
CREATE OR REPLACE TABLE route_shapes AS
WITH ranked AS (
    SELECT *,
           row_number() OVER (PARTITION BY go_back ORDER BY unusable IS NOT NULL, updated_at DESC NULLS LAST, wkt) AS rank_in_direction,
           count(*) OVER (PARTITION BY go_back) AS n_rows
    FROM route_shape_rows
)
SELECT d.go_back,
       CASE WHEN r.unusable IS NULL THEN r.updated_at END AS shape_updated_at,
       CASE WHEN r.unusable IS NULL THEN r.points END AS points,
       CASE
           WHEN r.go_back IS NULL THEN 'no_row'
           WHEN r.unusable IS NOT NULL THEN r.unusable
           WHEN r.n_rows > 1 THEN 'duplicate_rows'
       END AS issue
FROM (VALUES (0), (1)) AS d(go_back)
LEFT JOIN ranked r ON r.go_back = d.go_back AND r.rank_in_direction = 1
ORDER BY d.go_back;
