-- Stage 40: on-board counts from bus_seat_event attached to the trips of
-- stage 20, net boarding between counted stops, and the load profile.
--
-- Reads seat_events, routes and stops from stage 10 and trips, trip_events
-- from stage 20. Creates views:
--   seat_stop_events   seat_events mapped to the route and the stop's seqNo
--   trip_seat_records  the seat records attached to each trip
--   trip_stop_counts   one on-board count per counted stop of a trip, with
--                      the stop's sequence number on the page route (page_seq)
--   net_boarding       change of the count from the previous counted stop
--   count_coverage     how many trips and observed trip stops have a count
--   trip_bands         the time band of each trip, by its start hour
--   load_profile       per direction, band and stop with a count: trips,
--                      median and upper percentile of the count
--   reset_counts       per complete trip, the count before boarding at its
--                      first stop and after alighting at its last stop
--   reset_check        per direction and end, with the stop's name: trips
--                      with and without such a count, the shares at zero
--                      and near zero, and the maximum
--   count_anomalies    negative counts and jumps between counted stops

CREATE OR REPLACE VIEW seat_stop_events AS
SELECT e.bus_id,
       r.route_id,
       e.path_attribute_id,
       e.go_back,
       s.seq,
       e.stop_id,
       e.car_on_stop,
       e.remaining_num,
       e.data_time
FROM seat_events e
JOIN routes r USING (path_attribute_id)
JOIN stops s ON s.route_id = r.route_id AND s.go_back = e.go_back AND s.stop_id = e.stop_id;

-- Same vehicle, route and direction, with DataTime inside the trip, both ends
-- included. A record without a count carries nothing to attach.
CREATE OR REPLACE VIEW trip_seat_records AS
SELECT t.trip_id, c.*
FROM trips t
JOIN seat_stop_events c
  ON c.bus_id = t.bus_id AND c.route_id = t.route_id AND c.go_back = t.go_back
 AND c.data_time BETWEEN t.start_time AND t.end_time
WHERE c.remaining_num IS NOT NULL;

-- The count when leaving a stop is the departure record's; without one, the
-- arrival record's. Of several records of one kind, the latest is taken.
-- page_seq is the stop's sequence number on the page route: the trip's own
-- seq for the page route's trips; for a member route's trips, the page
-- route's stop of the same direction and stop location, or NULL when the
-- page route does not serve that location in that direction. The profile and
-- the stored counts use page_seq; net boarding keeps the trip's own seq. Of
-- two page route stops at one location, the earlier is taken.
CREATE OR REPLACE VIEW trip_stop_counts AS
WITH counted AS (
    SELECT trip_id,
           route_id,
           go_back,
           seq,
           coalesce(
               arg_max(remaining_num, data_time) FILTER (WHERE car_on_stop = 0),
               arg_max(remaining_num, data_time) FILTER (WHERE car_on_stop = 1)
           ) AS on_board
    FROM trip_seat_records
    GROUP BY trip_id, route_id, go_back, seq
)
SELECT c.trip_id,
       c.seq,
       c.on_board,
       CASE WHEN c.route_id = getvariable('route_id') THEN c.seq ELSE p.seq END AS page_seq
FROM counted c
LEFT JOIN stops own ON own.route_id = c.route_id AND own.go_back = c.go_back AND own.seq = c.seq
LEFT JOIN stops p ON c.route_id <> getvariable('route_id') AND p.route_id = getvariable('route_id')
                 AND p.go_back = c.go_back AND p.stop_location_id = own.stop_location_id
QUALIFY row_number() OVER (PARTITION BY c.trip_id, c.seq ORDER BY p.seq) = 1;

-- The first counted stop of a trip has no previous count, so no net boarding.
-- A span over 1 means the change covers stops without a count.
CREATE OR REPLACE VIEW net_boarding AS
SELECT trip_id,
       seq,
       on_board,
       on_board - lag(on_board) OVER trip_stops AS net_boarding,
       seq - lag(seq) OVER trip_stops AS span,
       seq - lag(seq) OVER trip_stops > 1 AS crosses_missing_stops
FROM trip_stop_counts
WINDOW trip_stops AS (PARTITION BY trip_id ORDER BY seq);

-- Observed trip stops are the stops with a bus_event in the trip.
CREATE OR REPLACE VIEW count_coverage AS
WITH observed AS (
    SELECT DISTINCT t.trip_id, e.seq
    FROM trips t
    JOIN trip_events e USING (bus_id, route_id, segment_no)
),
totals AS (
    SELECT (SELECT count(*) FROM trips) AS n_trips,
           (SELECT count(DISTINCT trip_id) FROM trip_seat_records) AS trips_with_count,
           (SELECT count(*) FROM observed) AS n_trip_stops,
           (SELECT count(*) FROM trip_stop_counts c JOIN observed o USING (trip_id, seq)) AS stops_with_count
)
SELECT trips_with_count,
       n_trips,
       CASE WHEN n_trips = 0 THEN NULL ELSE trips_with_count / n_trips END AS trip_share,
       stops_with_count,
       n_trip_stops,
       CASE WHEN n_trip_stops = 0 THEN NULL ELSE stops_with_count / n_trip_stops END AS stop_share
FROM totals;

-- Each band includes its start hour and excludes its end hour.
CREATE OR REPLACE VIEW trip_bands AS
SELECT trip_id,
       CASE
           WHEN hour(start_time) >= getvariable('morning_peak_start_hour')
            AND hour(start_time) < getvariable('daytime_start_hour') THEN 'morning_peak'
           WHEN hour(start_time) >= getvariable('daytime_start_hour')
            AND hour(start_time) < getvariable('evening_peak_start_hour') THEN 'daytime'
           WHEN hour(start_time) >= getvariable('evening_peak_start_hour')
            AND hour(start_time) < getvariable('evening_peak_end_hour') THEN 'evening_peak'
           ELSE 'other'
       END AS band
FROM trips;

-- Only stops with at least one count appear; n_trips is the number of trips
-- with a count at that stop. The stops are the page route's, by page_seq, so
-- a member route's count at a shared location pools with the page route's
-- and a count at a stop only the member serves stays out.
CREATE OR REPLACE VIEW load_profile AS
SELECT t.go_back,
       b.band,
       c.page_seq AS seq,
       s.stop_name,
       count(*) AS n_trips,
       round(median(c.on_board), 1) AS median,
       round(quantile_cont(c.on_board, getvariable('profile_upper_level')), 1) AS p90
FROM trip_stop_counts c
JOIN trips t USING (trip_id)
JOIN trip_bands b USING (trip_id)
JOIN stops s ON s.route_id = getvariable('route_id') AND s.go_back = t.go_back AND s.seq = c.page_seq
GROUP BY t.go_back, b.band, c.page_seq, s.stop_name;

-- Whether the count is zero when nobody should be on board: before boarding
-- at the first stop, from the latest arrival record before the start, and
-- after alighting at the last stop, from the earliest departure record after
-- the end. Both lie outside the trip, so they never enter the profile.
CREATE OR REPLACE VIEW reset_counts AS
SELECT t.trip_id, 'first' AS terminal, arg_max(c.remaining_num, c.data_time) AS on_board
FROM trips t
JOIN seat_stop_events c
  ON c.bus_id = t.bus_id AND c.route_id = t.route_id AND c.go_back = t.go_back
 AND c.seq = t.first_seq AND c.car_on_stop = 1
 AND minutes_between(c.data_time, t.start_time) BETWEEN 0 AND getvariable('reset_record_minutes')
WHERE t.completeness = 'complete' AND c.remaining_num IS NOT NULL
GROUP BY t.trip_id
UNION ALL
SELECT t.trip_id, 'last' AS terminal, arg_min(c.remaining_num, c.data_time) AS on_board
FROM trips t
JOIN seat_stop_events c
  ON c.bus_id = t.bus_id AND c.route_id = t.route_id AND c.go_back = t.go_back
 AND c.seq = t.last_seq AND c.car_on_stop = 0
 AND minutes_between(t.end_time, c.data_time) BETWEEN 0 AND getvariable('reset_record_minutes')
WHERE t.completeness = 'complete' AND c.remaining_num IS NOT NULL
GROUP BY t.trip_id;

-- One row per direction and end, named after the page route's stop at that
-- end (its member routes share the ends), because the two ends of a route
-- can behave differently. Every direction is listed. A complete trip without
-- a count at an end is left out of that end's shares and counted as missing.
CREATE OR REPLACE VIEW reset_check AS
WITH ends AS (
    SELECT d.go_back, m.terminal, CASE m.terminal WHEN 'first' THEN d.min_seq ELSE d.max_seq END AS seq
    FROM (SELECT go_back, min(seq) AS min_seq, max(seq) AS max_seq FROM stops WHERE route_id = getvariable('route_id') GROUP BY go_back) d
    CROSS JOIN (SELECT unnest(['first', 'last']) AS terminal) m
),
complete_trips AS (
    SELECT go_back, count(*) AS n FROM trips WHERE completeness = 'complete' GROUP BY go_back
),
counts AS (
    SELECT t.go_back, r.terminal, r.on_board FROM reset_counts r JOIN trips t USING (trip_id)
)
SELECT m.terminal,
       m.go_back,
       s.stop_name,
       count(c.on_board) AS n_trips,
       coalesce(max(k.n), 0) - count(c.on_board) AS n_missing,
       CASE WHEN count(c.on_board) = 0 THEN NULL
            ELSE count(c.on_board) FILTER (WHERE c.on_board = 0) / count(c.on_board) END AS share_zero,
       CASE WHEN count(c.on_board) = 0 THEN NULL
            ELSE count(c.on_board) FILTER (WHERE c.on_board <= getvariable('reset_near_zero')) / count(c.on_board) END AS share_near_zero,
       max(c.on_board) AS max_count
FROM ends m
JOIN stops s ON s.route_id = getvariable('route_id') AND s.go_back = m.go_back AND s.seq = m.seq
LEFT JOIN complete_trips k ON k.go_back = m.go_back
LEFT JOIN counts c ON c.go_back = m.go_back AND c.terminal = m.terminal
GROUP BY m.terminal, m.go_back, s.stop_name;

-- Negative counts are counted over every record attached to a trip, so a
-- negative arrival record hidden behind a departure record still shows.
CREATE OR REPLACE VIEW count_anomalies AS
SELECT (SELECT count(*) FROM trip_seat_records WHERE remaining_num < 0) AS negative_counts,
       (SELECT count(*) FROM net_boarding WHERE abs(net_boarding) > getvariable('jump_threshold')) AS jumps;
