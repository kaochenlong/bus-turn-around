-- Depots: the depots the vehicles that ran the route on the day belong to,
-- for the turnaround facilities block. It runs after params.sql, every
-- numbered stage, mrt_overlap.sql, turnaround_facilities.sql and
-- route_shape.sql, and before derived_export.sql, but reads nothing those
-- three create; its name does not start with a digit, so bin/health-card
-- never runs it, and only this file reads the operators file (GetProvider).
--
-- Reads trip_events and trips from stage 20 and the variable provider_path:
-- the static snapshot's operators file, or a file whose BusInfo is empty when
-- the snapshot has none. Creates:
--   providers         one row per station of the operators file: its
--                     stationId, operator name and station name
--   trip_depots       each trip of the day with its depot (a view)
--   route_day_depots  one row per depot of the day's trips: the names, empty
--                     when the operators file has no row for it, the number
--                     of vehicles and the number of trips (a view)

-- The file is one JSON object whose rows sit in the BusInfo array, like the
-- other static snapshots. Only the three keys used are read, as VARCHAR.
CREATE OR REPLACE TABLE providers AS
SELECT TRY_CAST(p.stationId AS BIGINT) AS station_id,
       p.nameZn AS provider_name,
       p.stationNameZn AS station_name
FROM (
    SELECT unnest(BusInfo) AS p
    FROM read_json(getvariable('provider_path'), maximum_object_size = 268435456,
                   columns = { BusInfo: 'STRUCT(stationId VARCHAR, nameZn VARCHAR, stationNameZn VARCHAR)[]' })
);

-- A stationId on more than one row stops the run: left alone, its depot
-- would be counted once per row. A stationId that is not an integer matches
-- no depot.
SET VARIABLE providers_checked = (
    SELECT CASE WHEN count(*) > 0
                THEN error('GetProvider.gz 的 stationId ' || string_agg(CAST(station_id AS VARCHAR), '、' ORDER BY station_id) || ' 不只一列')
                ELSE true END
    FROM (SELECT station_id FROM providers WHERE station_id IS NOT NULL GROUP BY station_id HAVING count(*) > 1)
);

-- A trip's depot is the StationID carried by most of the trip's events; a tie
-- goes to the smaller StationID so the result does not depend on row order.
-- An event without a StationID does not vote.
CREATE OR REPLACE VIEW trip_depots AS
SELECT t.trip_id, t.bus_id, v.station_id
FROM trips t
JOIN (
    SELECT bus_id,
           route_id,
           segment_no,
           station_id,
           row_number() OVER (
               PARTITION BY bus_id, route_id, segment_no ORDER BY count(*) DESC, station_id
           ) AS rank_in_trip
    FROM trip_events
    WHERE station_id IS NOT NULL
    GROUP BY bus_id, route_id, segment_no, station_id
) v USING (bus_id, route_id, segment_no)
WHERE v.rank_in_trip = 1;

CREATE OR REPLACE VIEW route_day_depots AS
SELECT d.station_id,
       coalesce(any_value(p.provider_name), '') AS provider_name,
       coalesce(any_value(p.station_name), '') AS station_name,
       count(DISTINCT d.bus_id) AS n_buses,
       count(*) AS n_trips
FROM trip_depots d
LEFT JOIN providers p USING (station_id)
GROUP BY d.station_id;
