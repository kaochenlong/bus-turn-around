-- Stage 50: the numbers of the 資料品質 section.
--
-- Reads load_counts, unknown_stop_events, sequence_check, routes and stops
-- from stage 10, trips, trip_events and path_trip_counts from stage 20.
-- Creates views:
--   completeness_counts    trips per completeness class, every class listed
--   path_trip_shares       trips and their share per sub-route
--   vehicle_day_ends       per sub-route, trips that are a vehicle's first or
--                          last trip of the day
--   last_stop_departures   per direction, complete trips and those whose last
--                          stop has a departure event after the trip's end
--   missing_stop_rate      stops without an event among complete trips
--   duty_status_counts     DutyStatus values of the events in the day's trips
--   duty_status_trip_ends  how DutyStatus 2 lines up with trip ends
--   unmatched_page_stop_counts  counts of member route trips at stops the
--                          page route does not serve in that direction
--   quality                every number above as metric, subject, value rows
-- Shares are fractions; the card turns them into percentages.

CREATE OR REPLACE VIEW completeness_counts AS
SELECT c.completeness, count(t.trip_id) AS n_trips
FROM (VALUES ('complete'), ('missing_start'), ('missing_end'), ('missing_both')) AS c(completeness)
LEFT JOIN trips t ON t.completeness = c.completeness
GROUP BY c.completeness;

CREATE OR REPLACE VIEW path_trip_shares AS
SELECT path_attribute_id,
       path_attribute_name,
       n_trips,
       CASE WHEN sum(n_trips) OVER () = 0 THEN NULL ELSE n_trips / sum(n_trips) OVER () END AS share
FROM path_trip_counts;

-- A vehicle's trips of the day are its trips on any route Id of the run that
-- start on the day, of any completeness: the page counts its member routes as
-- one route. The earliest is its first trip and the latest its last; a
-- vehicle's only trip is both. Trips on other routes are not read.
CREATE OR REPLACE VIEW vehicle_day_ends AS
WITH ranked AS (
    SELECT path_attribute_id,
           row_number() OVER (PARTITION BY bus_id ORDER BY start_time, trip_id) = 1 AS is_first,
           row_number() OVER (PARTITION BY bus_id ORDER BY start_time DESC, trip_id DESC) = 1 AS is_last
    FROM trips
)
SELECT r.path_attribute_id,
       count(*) FILTER (WHERE k.is_first) AS n_first,
       count(*) FILTER (WHERE k.is_last) AS n_last
FROM routes r
LEFT JOIN ranked k USING (path_attribute_id)
GROUP BY r.path_attribute_id;

-- Whether the feed reports leaving the last stop. Without such an event the
-- reset check has no count after alighting at that end. The window after the
-- end is the reset check's. Every direction is listed, named after the page
-- route's last stop; each trip's last stop is its own route's.
CREATE OR REPLACE VIEW last_stop_departures AS
WITH directions AS (
    SELECT go_back, max(seq) AS last_seq FROM stops WHERE route_id = getvariable('route_id') GROUP BY go_back
),
complete_trips AS (
    SELECT t.trip_id,
           t.go_back,
           EXISTS (
               SELECT 1 FROM stop_events e
               WHERE e.bus_id = t.bus_id AND e.route_id = t.route_id AND e.go_back = t.go_back
                 AND e.seq = t.last_seq AND e.car_on_stop = 0
                 AND minutes_between(t.end_time, e.data_time) BETWEEN 0 AND getvariable('reset_record_minutes')
           ) AS has_departure
    FROM trips t
    WHERE t.completeness = 'complete'
)
SELECT d.go_back,
       s.stop_name,
       count(c.trip_id) AS complete_trips,
       count(c.trip_id) FILTER (WHERE c.has_departure) AS with_departure
FROM directions d
JOIN stops s ON s.route_id = getvariable('route_id') AND s.go_back = d.go_back AND s.seq = d.last_seq
LEFT JOIN complete_trips c ON c.go_back = d.go_back
GROUP BY d.go_back, s.stop_name;

-- Stops of the direction with no event, over stops of the direction, both
-- summed over complete trips.
CREATE OR REPLACE VIEW missing_stop_rate AS
WITH direction_sizes AS (
    SELECT route_id, go_back, count(*) AS n_stops
    FROM stops
    GROUP BY route_id, go_back
),
complete_trips AS (
    SELECT d.n_stops, t.n_stops_observed
    FROM trips t
    JOIN direction_sizes d ON d.route_id = t.route_id AND d.go_back = t.go_back
    WHERE t.completeness = 'complete'
)
-- sum() of integers is a HUGEINT, which the JSON output prints as a string.
SELECT CAST(coalesce(sum(n_stops - n_stops_observed), 0) AS BIGINT) AS missing_stops,
       CAST(coalesce(sum(n_stops), 0) AS BIGINT) AS direction_stops,
       CASE WHEN coalesce(sum(n_stops), 0) = 0 THEN NULL
            ELSE sum(n_stops - n_stops_observed) / sum(n_stops) END AS rate
FROM complete_trips;

CREATE OR REPLACE VIEW duty_status_counts AS
SELECT e.duty_status, count(*) AS n_events
FROM trips t
JOIN trip_events e USING (bus_id, route_id, segment_no)
GROUP BY e.duty_status;

CREATE OR REPLACE VIEW duty_status_trip_ends AS
WITH day_events AS (
    SELECT t.trip_id,
           e.duty_status,
           e.data_time = max(e.data_time) OVER (PARTITION BY t.trip_id) AS is_last
    FROM trips t
    JOIN trip_events e USING (bus_id, route_id, segment_no)
),
counted AS (
    SELECT count(DISTINCT trip_id) FILTER (WHERE is_last AND duty_status = getvariable('duty_status_end_code')) AS trips_ending_duty_2,
           (SELECT count(*) FROM trips) AS n_trips,
           count(*) FILTER (WHERE is_last AND duty_status = getvariable('duty_status_end_code')) AS final_duty_2_events,
           count(*) FILTER (WHERE duty_status = getvariable('duty_status_end_code')) AS duty_2_events
    FROM day_events
)
SELECT trips_ending_duty_2,
       n_trips,
       CASE WHEN n_trips = 0 THEN NULL ELSE trips_ending_duty_2 / n_trips END AS trip_share,
       final_duty_2_events,
       duty_2_events,
       CASE WHEN duty_2_events = 0 THEN NULL ELSE final_duty_2_events / duty_2_events END AS event_share
FROM counted;

-- Counts left out of the profile and the stored counts because the page
-- route has no stop at that location in that direction (load-profile).
CREATE OR REPLACE VIEW unmatched_page_stop_counts AS
SELECT count(*) AS n_counts
FROM trip_stop_counts
WHERE page_seq IS NULL;

CREATE OR REPLACE VIEW quality AS
SELECT 'records_read' AS metric, feed AS subject, CAST(n_read AS VARCHAR) AS value FROM load_counts
UNION ALL
SELECT 'duplicates_removed', feed, CAST(n_removed AS VARCHAR) FROM load_counts
UNION ALL
SELECT 'unknown_stop_events', '', CAST(count(*) AS VARCHAR) FROM unknown_stop_events
UNION ALL
SELECT 'sequence_check',
       CAST(path_attribute_id AS VARCHAR),
       CASE WHEN identical THEN 'identical' ELSE 'not identical' END
           || ', directions ' || coalesce(nullif(array_to_string(directions, '+'), ''), 'none')
FROM sequence_check
UNION ALL
SELECT 'trips', completeness, CAST(n_trips AS VARCHAR) FROM completeness_counts
UNION ALL
SELECT 'trip_share', CAST(path_attribute_id AS VARCHAR), CAST(share AS VARCHAR) FROM path_trip_shares
UNION ALL
SELECT 'first_trips', CAST(path_attribute_id AS VARCHAR), CAST(n_first AS VARCHAR) FROM vehicle_day_ends
UNION ALL
SELECT 'last_trips', CAST(path_attribute_id AS VARCHAR), CAST(n_last AS VARCHAR) FROM vehicle_day_ends
UNION ALL
SELECT 'complete_trips', CAST(go_back AS VARCHAR), CAST(complete_trips AS VARCHAR) FROM last_stop_departures
UNION ALL
SELECT 'last_stop_departures', CAST(go_back AS VARCHAR), CAST(with_departure AS VARCHAR) FROM last_stop_departures
UNION ALL
SELECT 'missing_stops', 'complete', CAST(missing_stops AS VARCHAR) FROM missing_stop_rate
UNION ALL
SELECT 'direction_stops', 'complete', CAST(direction_stops AS VARCHAR) FROM missing_stop_rate
UNION ALL
SELECT 'missing_stop_rate', 'complete', CAST(rate AS VARCHAR) FROM missing_stop_rate
UNION ALL
SELECT 'duty_status_events', CAST(duty_status AS VARCHAR), CAST(n_events AS VARCHAR) FROM duty_status_counts
UNION ALL
SELECT 'trips_ending_duty_status_end_share', '', CAST(trip_share AS VARCHAR) FROM duty_status_trip_ends
UNION ALL
SELECT 'duty_status_end_events_trip_final_share', '', CAST(event_share AS VARCHAR) FROM duty_status_trip_ends
UNION ALL
SELECT 'unmatched_page_stop_counts', '', CAST(n_counts AS VARCHAR) FROM unmatched_page_stop_counts;
