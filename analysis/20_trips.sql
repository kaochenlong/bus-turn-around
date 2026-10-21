-- Stage 20: cut the route's stop events into trips.
--
-- Reads stop_events, stops and routes from stage 10. Creates views, so a test can
-- replace stop_events and read the trips built from its own events:
--   trip_events       stop_events with the segment (trip) each belongs to
--   segmented_trips   every trip in the read window
--   trips             the trips that start on the requested day, with trip_id
--   path_trip_counts  trips per sub-route of the requested route

-- Per vehicle and route, events in time order start a new trip when the
-- direction changes, the stop sequence goes back, or the gap exceeds the
-- split gap. (BusID, DataTime) is unique after stage 10, so the order is total.
CREATE OR REPLACE VIEW trip_events AS
WITH ordered AS (
    SELECT *,
           lag(go_back) OVER vehicle_timeline AS previous_go_back,
           lag(seq) OVER vehicle_timeline AS previous_seq,
           lag(data_time) OVER vehicle_timeline AS previous_time
    FROM stop_events
    WINDOW vehicle_timeline AS (PARTITION BY bus_id, route_id ORDER BY data_time)
),
flagged AS (
    SELECT *,
           CASE WHEN previous_time IS NULL
                  OR go_back <> previous_go_back
                  OR seq < previous_seq
                  OR minutes_between(previous_time, data_time) > getvariable('split_gap_minutes')
                THEN 1 ELSE 0 END AS starts_trip
    FROM ordered
)
SELECT * EXCLUDE (previous_go_back, previous_seq, previous_time, starts_trip),
       sum(starts_trip) OVER (
           PARTITION BY bus_id, route_id ORDER BY data_time ROWS UNBOUNDED PRECEDING
       ) AS segment_no
FROM flagged;

-- Start: the departure at the first observed stop, else its arrival. End: the
-- arrival at the last observed stop, else its departure. When a stop has more
-- than one departure the latest is taken (the moment the vehicle left), and
-- of several arrivals the earliest (the moment it got there).
CREATE OR REPLACE VIEW segmented_trips AS
WITH bounds AS (
    SELECT bus_id,
           route_id,
           segment_no,
           min(go_back) AS go_back,
           arg_min(seq, data_time) AS first_seq,
           arg_max(seq, data_time) AS last_seq,
           count(*) AS n_events,
           count(DISTINCT seq) AS n_stops_observed
    FROM trip_events
    GROUP BY bus_id, route_id, segment_no
),
endpoint_times AS (
    SELECT b.bus_id,
           b.route_id,
           b.segment_no,
           max(e.data_time) FILTER (WHERE e.seq = b.first_seq AND e.car_on_stop = 0) AS first_stop_departure,
           min(e.data_time) FILTER (WHERE e.seq = b.first_seq AND e.car_on_stop = 1) AS first_stop_arrival,
           min(e.data_time) FILTER (WHERE e.seq = b.last_seq AND e.car_on_stop = 1) AS last_stop_arrival,
           min(e.data_time) FILTER (WHERE e.seq = b.last_seq AND e.car_on_stop = 0) AS last_stop_departure
    FROM bounds b
    JOIN trip_events e USING (bus_id, route_id, segment_no)
    GROUP BY b.bus_id, b.route_id, b.segment_no
),
-- The sub-route carried by most of the trip's events; a tie goes to the
-- smaller pathAttributeId so the result does not depend on row order.
majority_path AS (
    SELECT bus_id, route_id, segment_no, path_attribute_id
    FROM (
        SELECT bus_id,
               route_id,
               segment_no,
               path_attribute_id,
               row_number() OVER (
                   PARTITION BY bus_id, route_id, segment_no ORDER BY count(*) DESC, path_attribute_id
               ) AS rank_in_trip
        FROM trip_events
        GROUP BY bus_id, route_id, segment_no, path_attribute_id
    )
    WHERE rank_in_trip = 1
),
direction_range AS (
    SELECT route_id, go_back, min(seq) AS min_seq, max(seq) AS max_seq
    FROM stops
    GROUP BY route_id, go_back
)
SELECT b.bus_id,
       b.route_id,
       m.path_attribute_id,
       b.go_back,
       coalesce(t.first_stop_departure, t.first_stop_arrival) AS start_time,
       coalesce(t.last_stop_arrival, t.last_stop_departure) AS end_time,
       b.first_seq,
       b.last_seq,
       b.n_events,
       b.n_stops_observed,
       CASE
           WHEN b.first_seq = d.min_seq AND b.last_seq = d.max_seq THEN 'complete'
           WHEN b.last_seq = d.max_seq THEN 'missing_start'
           WHEN b.first_seq = d.min_seq THEN 'missing_end'
           ELSE 'missing_both'
       END AS completeness,
       t.first_stop_departure IS NULL AS start_from_arrival,
       t.last_stop_arrival IS NULL AS end_from_departure,
       b.segment_no
FROM bounds b
JOIN endpoint_times t USING (bus_id, route_id, segment_no)
JOIN majority_path m USING (bus_id, route_id, segment_no)
JOIN direction_range d ON d.route_id = b.route_id AND d.go_back = b.go_back;

-- A trip belongs to the day its start time falls on.
CREATE OR REPLACE VIEW trips AS
SELECT row_number() OVER (ORDER BY bus_id, start_time, route_id, go_back) AS trip_id,
       *
FROM segmented_trips
WHERE CAST(start_time AS DATE) = getvariable('day');

CREATE OR REPLACE VIEW path_trip_counts AS
SELECT r.path_attribute_id,
       r.path_attribute_name,
       count(t.trip_id) AS n_trips
FROM routes r
LEFT JOIN trips t ON t.path_attribute_id = r.path_attribute_id
GROUP BY r.path_attribute_id, r.path_attribute_name;
