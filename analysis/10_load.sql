-- Stage 10: load one route and one Taipei day from the raw n-gear files.
--
-- Reads the variables data_root, route_id, day and static_day, plus the
-- window constants of params.sql. Creates:
--   input_files          the hourly files read, per feed
--   routes               the GetRoute.gz rows of the requested route
--   bus_events           bus_event records of the route's sub-routes, deduplicated
--   seat_events          bus_seat_event records of the route's sub-routes, deduplicated
--   load_counts          records read and removed per feed, after the route filter
--   stops                the route's GetStop.gz stop list, both directions
--   path_stops           the GetPathDetail.gz stops of the route's sub-routes
--   stop_events          bus_events mapped to the route and the stop's seqNo
--   unknown_stop_events  bus_events whose stop is not in their direction's list
--   sequence_check       per sub-route: directions compared and whether its
--                        stop sequence equals the route's (a view)

SET VARIABLE static_dir = getvariable('data_root') || '/static/' || strftime(getvariable('static_day'), '%Y-%m-%d');

-- The window covers the hours [day - lookback, day + 1 day + overflow), taken
-- from the day directory and the hour in the file name.
SET VARIABLE window_start = getvariable('day') - to_hours(getvariable('lookback_hours'));
SET VARIABLE window_end = getvariable('day') + INTERVAL 1 DAY + to_hours(getvariable('overflow_hours'));

-- Every file in one feed's directory for one day; a missing directory lists nothing.
CREATE OR REPLACE MACRO day_files(feed_name, file_day) AS TABLE
    SELECT feed_name AS feed, file
    FROM glob(getvariable('data_root') || '/' || feed_name || '/' || strftime(file_day, '%Y-%m-%d') || '/*');

CREATE OR REPLACE TABLE input_files AS
WITH listed AS (
    SELECT * FROM day_files('bus_event', getvariable('day') - INTERVAL 1 DAY)
    UNION ALL SELECT * FROM day_files('bus_event', getvariable('day'))
    UNION ALL SELECT * FROM day_files('bus_event', getvariable('day') + INTERVAL 1 DAY)
    UNION ALL SELECT * FROM day_files('bus_seat_event', getvariable('day') - INTERVAL 1 DAY)
    UNION ALL SELECT * FROM day_files('bus_seat_event', getvariable('day'))
    UNION ALL SELECT * FROM day_files('bus_seat_event', getvariable('day') + INTERVAL 1 DAY)
),
hourly AS (
    -- Only <day>/<HH>.jsonl and <day>/<HH>.jsonl.gz count as hourly files.
    SELECT feed, file, regexp_extract(file, '/(\d{4}-\d{2}-\d{2})/(\d{2})\.jsonl(\.gz)?$', ['file_day', 'file_hour']) AS parts
    FROM listed
    WHERE regexp_matches(file, '/\d{4}-\d{2}-\d{2}/\d{2}\.jsonl(\.gz)?$')
),
dated AS (
    SELECT feed, file, CAST(parts.file_day AS DATE) AS file_day, CAST(parts.file_hour AS INTEGER) AS file_hour
    FROM hourly
)
SELECT feed, file, file_day, file_hour
FROM dated
WHERE file_day + to_hours(file_hour) >= getvariable('window_start')
  AND file_day + to_hours(file_hour) < getvariable('window_end');

SET VARIABLE bus_event_files = (SELECT list(file ORDER BY file) FROM input_files WHERE feed = 'bus_event');
SET VARIABLE seat_event_files = (SELECT list(file ORDER BY file) FROM input_files WHERE feed = 'bus_seat_event');

-- Static snapshots are one JSON object whose rows sit in the BusInfo array.
-- The object limit is set explicitly instead of relying on the default.
CREATE OR REPLACE TABLE routes AS
SELECT r.Id AS route_id,
       r.pathAttributeId AS path_attribute_id,
       r.nameZh AS route_name,
       r.pathAttributeName AS path_attribute_name,
       r.departureZh AS departure,
       r.destinationZh AS destination
FROM (
    SELECT unnest(BusInfo) AS r
    FROM read_json(getvariable('static_dir') || '/GetRoute.gz', maximum_object_size = 268435456)
)
WHERE r.Id = getvariable('route_id');

-- Raw records are read with explicit VARCHAR columns, so an hour file whose
-- values are all null or all strings cannot change a column's type. Records
-- of other routes are dropped before anything else.
CREATE OR REPLACE TABLE raw_bus_events AS
SELECT BusID AS bus_id,
       TRY_CAST(RouteID AS BIGINT) AS path_attribute_id,
       TRY_CAST(GoBack AS INTEGER) AS go_back,
       TRY_CAST(StopID AS BIGINT) AS stop_id,
       TRY_CAST(CarOnStop AS INTEGER) AS car_on_stop,
       TRY_CAST(DutyStatus AS INTEGER) AS duty_status,
       TRY_CAST(BusStatus AS INTEGER) AS bus_status,
       CAST(DataTime AS TIMESTAMP) AS data_time,
       CAST(_fetched_at AS TIMESTAMPTZ) AS fetched_at,
       filename AS source_file
FROM read_json(
    getvariable('bus_event_files'),
    format = 'newline_delimited',
    filename = true,
    columns = {
        BusID: 'VARCHAR', RouteID: 'VARCHAR', GoBack: 'VARCHAR', StopID: 'VARCHAR', CarOnStop: 'VARCHAR',
        DutyStatus: 'VARCHAR', BusStatus: 'VARCHAR', DataTime: 'VARCHAR', _fetched_at: 'VARCHAR'
    }
)
WHERE TRY_CAST(RouteID AS BIGINT) IN (SELECT path_attribute_id FROM routes);

CREATE OR REPLACE TABLE raw_seat_events AS
SELECT BusID AS bus_id,
       TRY_CAST(RouteID AS BIGINT) AS path_attribute_id,
       TRY_CAST(GoBack AS INTEGER) AS go_back,
       TRY_CAST(StopID AS BIGINT) AS stop_id,
       TRY_CAST(CarOnStop AS INTEGER) AS car_on_stop,
       TRY_CAST(RemainingNum AS INTEGER) AS remaining_num,
       TRY_CAST(Level AS INTEGER) AS level,
       CAST(DataTime AS TIMESTAMP) AS data_time,
       CAST(_fetched_at AS TIMESTAMPTZ) AS fetched_at,
       filename AS source_file
FROM read_json(
    getvariable('seat_event_files'),
    format = 'newline_delimited',
    filename = true,
    columns = {
        BusID: 'VARCHAR', RouteID: 'VARCHAR', GoBack: 'VARCHAR', StopID: 'VARCHAR', CarOnStop: 'VARCHAR',
        RemainingNum: 'VARCHAR', Level: 'VARCHAR', DataTime: 'VARCHAR', _fetched_at: 'VARCHAR'
    }
)
WHERE TRY_CAST(RouteID AS BIGINT) IN (SELECT path_attribute_id FROM routes);

-- Downstream deduplication of decision 5: one record per (BusID, DataTime) in
-- each feed, the one fetched first. The feeds are not compared with each other.
CREATE OR REPLACE TABLE bus_events AS
SELECT * EXCLUDE (rank_in_key)
FROM (
    SELECT *, row_number() OVER (
        PARTITION BY bus_id, data_time
        ORDER BY fetched_at, source_file, stop_id, car_on_stop, path_attribute_id
    ) AS rank_in_key
    FROM raw_bus_events
)
WHERE rank_in_key = 1;

CREATE OR REPLACE TABLE seat_events AS
SELECT * EXCLUDE (rank_in_key)
FROM (
    SELECT *, row_number() OVER (
        PARTITION BY bus_id, data_time
        ORDER BY fetched_at, source_file, stop_id, car_on_stop, path_attribute_id
    ) AS rank_in_key
    FROM raw_seat_events
)
WHERE rank_in_key = 1;

CREATE OR REPLACE TABLE load_counts AS
SELECT 'bus_event' AS feed,
       (SELECT count(*) FROM raw_bus_events) AS n_read,
       (SELECT count(*) FROM raw_bus_events) - (SELECT count(*) FROM bus_events) AS n_removed
UNION ALL
SELECT 'bus_seat_event',
       (SELECT count(*) FROM raw_seat_events),
       (SELECT count(*) FROM raw_seat_events) - (SELECT count(*) FROM seat_events);

CREATE OR REPLACE TABLE stops AS
SELECT s.routeId AS route_id,
       TRY_CAST(s.goBack AS INTEGER) AS go_back,
       s.seqNo AS seq,
       s.Id AS stop_id,
       s.nameZh AS stop_name
FROM (
    SELECT unnest(BusInfo) AS s
    FROM read_json(getvariable('static_dir') || '/GetStop.gz', maximum_object_size = 268435456)
)
WHERE s.routeId = getvariable('route_id');

CREATE OR REPLACE TABLE path_stops AS
SELECT p.pathAttributeId AS path_attribute_id,
       p.sequenceNo AS sequence_no,
       p.stopId AS stop_id
FROM (
    SELECT unnest(BusInfo) AS p
    FROM read_json(getvariable('static_dir') || '/GetPathDetail.gz', maximum_object_size = 268435456)
)
WHERE p.pathAttributeId IN (SELECT path_attribute_id FROM routes);

-- A sub-route's events are segmented under its route, not separately; the
-- stop's position comes from the route's stop list of the event's direction.
CREATE OR REPLACE TABLE stop_events AS
SELECT e.bus_id,
       r.route_id,
       e.path_attribute_id,
       e.go_back,
       s.seq,
       e.stop_id,
       e.car_on_stop,
       e.duty_status,
       e.bus_status,
       e.data_time,
       e.source_file
FROM bus_events e
JOIN routes r USING (path_attribute_id)
JOIN stops s ON s.route_id = r.route_id AND s.go_back = e.go_back AND s.stop_id = e.stop_id;

CREATE OR REPLACE TABLE unknown_stop_events AS
SELECT e.*
FROM bus_events e
JOIN routes r USING (path_attribute_id)
WHERE NOT EXISTS (
    SELECT 1 FROM stops s
    WHERE s.route_id = r.route_id AND s.go_back = e.go_back AND s.stop_id = e.stop_id
);

-- Merging sub-routes is checked on every run, not assumed. The directions
-- compared are those of the route's stops that appear in the sub-route; the
-- comparison is on stop order only, because sequenceNo restarts at 0 for each
-- sub-route. A sub-route spanning both directions is compared with the whole
-- route, ordered by seqNo.
CREATE OR REPLACE VIEW sequence_check AS
WITH path_lists AS (
    SELECT path_attribute_id, list(stop_id ORDER BY sequence_no) AS path_stop_ids
    FROM path_stops
    GROUP BY path_attribute_id
),
path_directions AS (
    SELECT p.path_attribute_id, list(DISTINCT s.go_back ORDER BY s.go_back) AS directions
    FROM path_stops p
    JOIN stops s ON s.stop_id = p.stop_id
    GROUP BY p.path_attribute_id
),
compared AS (
    SELECT r.path_attribute_id,
           r.path_attribute_name,
           coalesce(d.directions, []::INTEGER[]) AS directions,
           l.path_stop_ids,
           (SELECT list(s.stop_id ORDER BY s.seq) FROM stops s WHERE list_contains(d.directions, s.go_back)) AS route_stop_ids
    FROM routes r
    LEFT JOIN path_lists l USING (path_attribute_id)
    LEFT JOIN path_directions d USING (path_attribute_id)
)
SELECT path_attribute_id,
       path_attribute_name,
       directions,
       coalesce(len(directions) > 0 AND path_stop_ids = route_stop_ids, false) AS identical
FROM compared;
