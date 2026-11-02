-- Published schedule: the headways and scheduled departures 臺北市公共運輸處
-- publishes for the run's routes, for the comparison with the measured trips.
-- It runs after params.sql and every numbered stage, and before
-- derived_export.sql; its name does not start with a digit, so bin/health-card
-- never runs it, and only this file reads the two files.
--
-- Reads routes from stage 10 and the variables semi_time_table_path (the static
-- snapshot's GetSemiTimeTable.gz) and time_table_path (its GetTimeTable.gz), or
-- a file whose BusInfo is empty when the snapshot has no such file. Creates:
--   published_headway_rows    the headway rows of the run's sub-routes, as written
--   published_departure_rows  the departure rows of the run's sub-routes, as written
--   published_headways        the kept headway rows, in minutes (a view)
--   published_departures      the kept departure rows, in minutes (a view)
--
-- A kept row has a DateType of 0, whose DateValue is a day of the week: 1 is
-- Sunday, 2 Monday and 7 Saturday (API document V6.3). A DateType of 1 names a
-- special date, which no page route has had so far, so those rows are not
-- stored. A row of the run's routes that cannot be read stops the run, because
-- the comparison would lose a period without anyone knowing; rows of other
-- routes are not looked at.

-- An integer written only in digits: TRY_CAST alone would turn '12.5' into 12.
-- NULL when it cannot be read.
CREATE OR REPLACE MACRO published_integer(text) AS
    CASE WHEN regexp_full_match(coalesce(text, ''), '[0-9]+') THEN TRY_CAST(text AS INTEGER) END;

-- HHMM as a minute of the day, NULL when it cannot be read.
CREATE OR REPLACE MACRO published_minute(text) AS
    CASE WHEN regexp_full_match(coalesce(text, ''), '([01][0-9]|2[0-3])[0-5][0-9]')
         THEN CAST(substr(text, 1, 2) AS INTEGER) * 60 + CAST(substr(text, 3, 2) AS INTEGER) END;

-- Each file is one JSON object whose rows sit in the BusInfo array, like the
-- other static snapshots. Every key is read as VARCHAR, so a value of another
-- type reaches the checks below instead of failing without naming the file.
CREATE OR REPLACE TABLE published_headway_rows AS
SELECT r.route_id,
       r.path_attribute_id,
       h.DateType AS date_type,
       h.DateValue AS date_value,
       h.StartTime AS start_time,
       h.EndTime AS end_time,
       h.LongHeadway AS long_headway,
       h.LowHeadway AS low_headway
FROM (
    SELECT unnest(BusInfo) AS h
    FROM read_json(getvariable('semi_time_table_path'), maximum_object_size = 268435456,
                   columns = { BusInfo: 'STRUCT(PathAttributeId VARCHAR, StartTime VARCHAR, EndTime VARCHAR, LongHeadway VARCHAR, LowHeadway VARCHAR, DateType VARCHAR, DateValue VARCHAR)[]' })
)
JOIN routes r ON r.path_attribute_id = TRY_CAST(h.PathAttributeId AS BIGINT);

CREATE OR REPLACE TABLE published_departure_rows AS
SELECT r.route_id,
       r.path_attribute_id,
       d.DateType AS date_type,
       d.DateValue AS date_value,
       d.DepartureTime AS departure_time
FROM (
    SELECT unnest(BusInfo) AS d
    FROM read_json(getvariable('time_table_path'), maximum_object_size = 268435456,
                   columns = { BusInfo: 'STRUCT(PathAttributeId VARCHAR, DateType VARCHAR, DateValue VARCHAR, DepartureTime VARCHAR)[]' })
)
JOIN routes r ON r.path_attribute_id = TRY_CAST(d.PathAttributeId AS BIGINT);

-- The names are misleading: LongHeadway is the low end of the headway and
-- LowHeadway the high end. A headway of 0 cannot be read: a bus every 0 minutes
-- means nothing, and the comparison divides by it.
SET VARIABLE published_headway_rows_checked = (
    SELECT CASE WHEN count(*) > 0
                THEN error('GetSemiTimeTable.gz 有讀不懂的值：' || string_agg(DISTINCT problem, '、'))
                ELSE true END
    FROM (
        SELECT 'DateType ' || coalesce(date_type, '（空的）') AS problem
        FROM published_headway_rows
        WHERE published_integer(date_type) IS NULL
        UNION ALL
        SELECT problem
        FROM (
            SELECT CASE WHEN published_integer(date_value) IS NULL THEN 'DateValue ' || coalesce(date_value, '（空的）') END AS date_value_problem,
                   CASE WHEN published_minute(start_time) IS NULL THEN 'StartTime ' || coalesce(start_time, '（空的）') END AS start_time_problem,
                   CASE WHEN published_minute(end_time) IS NULL THEN 'EndTime ' || coalesce(end_time, '（空的）') END AS end_time_problem,
                   CASE WHEN coalesce(published_integer(long_headway), 0) < 1 THEN 'LongHeadway ' || coalesce(long_headway, '（空的）') END AS long_headway_problem,
                   CASE WHEN coalesce(published_integer(low_headway), 0) < 1 THEN 'LowHeadway ' || coalesce(low_headway, '（空的）') END AS low_headway_problem,
                   CASE WHEN published_integer(long_headway) > published_integer(low_headway)
                        THEN 'LongHeadway ' || long_headway || ' 大於 LowHeadway ' || low_headway END AS range_problem
            FROM published_headway_rows
            WHERE published_integer(date_type) = 0
        )
        UNPIVOT (problem FOR field IN (date_value_problem, start_time_problem, end_time_problem, long_headway_problem, low_headway_problem, range_problem))
    )
);

SET VARIABLE published_departure_rows_checked = (
    SELECT CASE WHEN count(*) > 0
                THEN error('GetTimeTable.gz 有讀不懂的值：' || string_agg(DISTINCT problem, '、'))
                ELSE true END
    FROM (
        SELECT 'DateType ' || coalesce(date_type, '（空的）') AS problem
        FROM published_departure_rows
        WHERE published_integer(date_type) IS NULL
        UNION ALL
        SELECT 'DateValue ' || coalesce(date_value, '（空的）')
        FROM published_departure_rows
        WHERE published_integer(date_type) = 0 AND published_integer(date_value) IS NULL
        UNION ALL
        SELECT 'DepartureTime ' || coalesce(departure_time, '（空的）')
        FROM published_departure_rows
        WHERE published_integer(date_type) = 0 AND published_minute(departure_time) IS NULL
    )
);

-- A period whose end is not later than its start runs past midnight, so 1700 to
-- 0000 is minute 1020 to minute 1440.
CREATE OR REPLACE VIEW published_headways AS
SELECT route_id,
       path_attribute_id,
       published_integer(date_value) AS date_value,
       published_minute(start_time) AS start_minute,
       published_minute(end_time) + CASE WHEN published_minute(end_time) <= published_minute(start_time) THEN 1440 ELSE 0 END AS end_minute,
       published_integer(long_headway) AS low_minutes,
       published_integer(low_headway) AS high_minutes
FROM published_headway_rows
WHERE published_integer(date_type) = 0;

CREATE OR REPLACE VIEW published_departures AS
SELECT route_id,
       path_attribute_id,
       published_integer(date_value) AS date_value,
       published_minute(departure_time) AS minute
FROM published_departure_rows
WHERE published_integer(date_type) = 0;
