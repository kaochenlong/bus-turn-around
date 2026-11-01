-- Stop district snapshot: the county and town each stop location lies in,
-- for bin/rails external:stop_districts. It runs after params.sql alone
-- (AnalysisRun with stages: false), never with the numbered stages, and
-- bin/health-card and derived:load never run it: it needs the DuckDB spatial
-- extension, installed once per machine with `duckdb -c "INSTALL spatial"`,
-- while the nightly load only reads the CSV this writes.
--
-- Reads the variables shapefile_path (the TOWN_MOI_<version>.shp of the
-- township boundaries, with its .shx, .dbf and .prj next to it), stops_path
-- (a GetStop.gz) and output_path. Creates:
--   towns           one row per township polygon: county, town, geom
--   stop_locations  one point per stop location: the stop with the smallest Id
--   located         the stop locations inside a polygon, with its county and town
-- Writes output_path as stop_location_id,county,town, ordered by the Id, and
-- prints one row: n_locations, the stop locations read, and n_assigned, the
-- ones inside a polygon.

LOAD spatial;
SET geometry_always_xy = true;

CREATE OR REPLACE TABLE towns AS
SELECT COUNTYNAME AS county, TOWNNAME AS town, geom
FROM ST_Read(getvariable('shapefile_path'));

CREATE OR REPLACE TABLE stop_locations AS
SELECT stop_location_id, longitude, latitude
FROM (
    SELECT s.stopLocationId AS stop_location_id,
           s.Id AS stop_id,
           TRY_CAST(s.longitude AS DOUBLE) AS longitude,
           TRY_CAST(s.latitude AS DOUBLE) AS latitude
    FROM (
        SELECT unnest(BusInfo) AS s
        FROM read_json(getvariable('stops_path'), maximum_object_size = 268435456)
    )
    WHERE s.stopLocationId IS NOT NULL
)
QUALIFY row_number() OVER (PARTITION BY stop_location_id ORDER BY stop_id) = 1;

-- A point on a shared edge is inside both polygons; the first by county and
-- town wins, so the result does not depend on row order.
CREATE OR REPLACE TABLE located AS
SELECT l.stop_location_id, t.county, t.town
FROM stop_locations l
JOIN towns t ON l.longitude IS NOT NULL AND l.latitude IS NOT NULL AND ST_Within(ST_Point(l.longitude, l.latitude), t.geom)
QUALIFY row_number() OVER (PARTITION BY l.stop_location_id ORDER BY t.county, t.town) = 1;

COPY (
    SELECT stop_location_id, county, town
    FROM located
    ORDER BY stop_location_id
) TO (getvariable('output_path')) (HEADER);

SELECT (SELECT count(*) FROM stop_locations) AS n_locations,
       (SELECT count(*) FROM located) AS n_assigned;
