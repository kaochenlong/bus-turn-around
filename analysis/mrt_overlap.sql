-- MRT overlap: each stop's nearest Taipei MRT entrance and its straight-line
-- distance. It runs after params.sql and every numbered stage, before
-- derived_export.sql; its name does not start with a digit, so
-- bin/health-card never runs it. Which distance counts as near is decided
-- where the distances are read, so one set of distances serves every
-- threshold.
--
-- Reads stops from stage 10 and the variable mrt_exits_path, a UTF-8
-- snapshot written by bin/rails external:mrt_exits. Creates:
--   mrt_exits           the snapshot's entrances
--   stop_mrt_distances  per stop of every route Id of the run: coordinates,
--                       nearest entrance, metres

-- Great-circle distance in metres on a sphere of radius 6,371,000 m.
CREATE OR REPLACE MACRO haversine_meters(lat1, lon1, lat2, lon2) AS
    2 * 6371000 * asin(sqrt(
        pow(sin(radians(lat2 - lat1) / 2), 2)
        + cos(radians(lat1)) * cos(radians(lat2)) * pow(sin(radians(lon2 - lon1) / 2), 2)
    ));

CREATE OR REPLACE TABLE mrt_exits AS
SELECT 出入口名稱 AS exit_name, 緯度 AS latitude, 經度 AS longitude
FROM read_csv(getvariable('mrt_exits_path'), header = true, columns = {
    '項次': 'INTEGER', '出入口名稱': 'VARCHAR', '出入口編號': 'VARCHAR',
    '經度': 'DOUBLE', '緯度': 'DOUBLE', '是否為無障礙用': 'VARCHAR'
});

-- Of two entrances at the same distance, the one first by name wins, so the
-- result does not depend on row order.
CREATE OR REPLACE TABLE stop_mrt_distances AS
SELECT s.route_id,
       s.go_back,
       s.seq,
       s.latitude,
       s.longitude,
       e.exit_name AS nearest_exit_name,
       round(haversine_meters(s.latitude, s.longitude, e.latitude, e.longitude), 1) AS nearest_exit_meters
FROM stops s
CROSS JOIN mrt_exits e
QUALIFY row_number() OVER (
    PARTITION BY s.route_id, s.go_back, s.seq
    ORDER BY haversine_meters(s.latitude, s.longitude, e.latitude, e.longitude), e.exit_name
) = 1;
