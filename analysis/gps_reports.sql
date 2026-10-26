-- GPS reports: the bus_data records that the analyses after the stages
-- share. It runs after params.sql, every numbered stage and mrt_overlap.sql,
-- and before turnaround_facilities.sql; its name does not start with a digit,
-- so bin/health-card never runs it, and it is the only file that reads
-- bus_data.
--
-- Reads day_files, window_start and window_end of stage 10 and trips of
-- stage 20. Creates:
--   bus_data_files  the bus_data hour files of the read window (a variable)
--   gps_reports     bus_data records of the vehicles that had a trip that day,
--                   one per (BusID, DataTime)

-- The bus_data hour files of the read window, listed the way stage 10 lists
-- the other two feeds. derived:load checks beforehand that the day has one,
-- because read_json fails on an empty list.
SET VARIABLE bus_data_files = (
    WITH listed AS (
        SELECT file FROM day_files('bus_data', getvariable('day') - INTERVAL 1 DAY)
        UNION ALL SELECT file FROM day_files('bus_data', getvariable('day'))
        UNION ALL SELECT file FROM day_files('bus_data', getvariable('day') + INTERVAL 1 DAY)
    ),
    hourly AS (
        SELECT file, regexp_extract(file, '/(\d{4}-\d{2}-\d{2})/(\d{2})\.jsonl(\.gz)?$', ['file_day', 'file_hour']) AS parts
        FROM listed
        WHERE regexp_matches(file, '/\d{4}-\d{2}-\d{2}/\d{2}\.jsonl(\.gz)?$')
    ),
    dated AS (
        SELECT file, CAST(parts.file_day AS DATE) + to_hours(CAST(parts.file_hour AS INTEGER)) AS file_start
        FROM hourly
    )
    SELECT list(file ORDER BY file)
    FROM dated
    WHERE file_start >= getvariable('window_start') AND file_start < getvariable('window_end')
);

-- Raw records are read with explicit VARCHAR columns, as in stage 10, and
-- only those of vehicles with a trip that day are kept: every vehicle with a
-- layover has trips, and the stop speeds need the vehicles of every trip.
-- Speed is compared as a number, so "0.0" is as still as "0". One record
-- per (BusID, DataTime), the one fetched first, as in the other feeds.
CREATE OR REPLACE TABLE gps_reports AS
SELECT bus_id, latitude, longitude, speed, data_time
FROM (
    SELECT BusID AS bus_id,
           TRY_CAST(Latitude AS DOUBLE) AS latitude,
           TRY_CAST(Longitude AS DOUBLE) AS longitude,
           TRY_CAST(Speed AS DOUBLE) AS speed,
           CAST(DataTime AS TIMESTAMP) AS data_time,
           CAST(_fetched_at AS TIMESTAMPTZ) AS fetched_at,
           filename AS source_file
    FROM read_json(
        getvariable('bus_data_files'),
        format = 'newline_delimited',
        filename = true,
        columns = { BusID: 'VARCHAR', Longitude: 'VARCHAR', Latitude: 'VARCHAR', Speed: 'VARCHAR', DataTime: 'VARCHAR', _fetched_at: 'VARCHAR' }
    )
    WHERE BusID IN (SELECT bus_id FROM trips)
)
QUALIFY row_number() OVER (PARTITION BY bus_id, data_time ORDER BY fetched_at, source_file, latitude, longitude, speed) = 1;
