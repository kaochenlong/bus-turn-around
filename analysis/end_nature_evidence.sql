-- End nature evidence: for every layover of the run, what the vehicle's GPS
-- reports say about whether it waited at that end, measured the way the ends
-- in config/route_page.yml were verified by hand; and for every direction of
-- the page route, the trip pairs ending there by category. It runs after
-- params.sql, every numbered stage, mrt_overlap.sql, whose haversine_meters
-- it uses, and turnaround_facilities.sql, whose gps_reports it reads, and
-- before end_nature_export.sql. Its name does not start with a digit, so
-- bin/health-card never runs it; only bin/rails survey:end_natures does.
--
-- Reads stops from stage 10, trips from stage 20, layover_pairs and layovers
-- from stage 30, and gps_reports. Creates views, so a test can replace trips
-- and gps_reports after this file has run:
--   layover_evidence  per layover, paired across member routes as stage 30
--                     pairs them: the end (go_back of the trip that ended),
--                     the next trip's route Id and direction, the distance
--                     between the two stops, and the number of GPS reports,
--                     the longest standstill and the farthest distance
--   end_pair_counts   per direction of the page route: its last stop and the
--                     trip pairs ending there, by category

-- The stop pair of a layover is the last stop of the ended trip's route Id
-- and direction and the first stop of the next trip's. A layover's reports
-- are the vehicle's from the end of its trip to the start of the next, both
-- included, whatever their RouteID; a report without a numeric position is
-- left out. Distances keep one decimal; minutes keeps its seconds, so
-- percentiles of the pooled layovers are those of the layovers themselves.
CREATE OR REPLACE VIEW layover_evidence AS
WITH first_stops AS (
    SELECT route_id, go_back, latitude, longitude
    FROM stops
    QUALIFY row_number() OVER (PARTITION BY route_id, go_back ORDER BY seq) = 1
),
last_stops AS (
    SELECT route_id, go_back, latitude, longitude
    FROM stops
    QUALIFY row_number() OVER (PARTITION BY route_id, go_back ORDER BY seq DESC) = 1
),
pairs AS (
    SELECT l.trip_id,
           l.bus_id,
           l.go_back,
           l.end_time,
           l.next_start_time,
           l.minutes,
           n.route_id AS next_route_id,
           n.go_back AS next_go_back,
           e.latitude AS end_latitude,
           e.longitude AS end_longitude,
           s.latitude AS start_latitude,
           s.longitude AS start_longitude
    FROM layovers l
    JOIN trips n ON n.trip_id = l.next_trip_id
    LEFT JOIN last_stops e ON e.route_id = l.route_id AND e.go_back = l.go_back
    LEFT JOIN first_stops s ON s.route_id = n.route_id AND s.go_back = n.go_back
),
-- A speed-0 report continues the standstill run of the report just before
-- it when that report also has speed 0 and lies within the standstill
-- radius of it; otherwise it starts a new run. A report that is not speed 0
-- cuts the run, because the vehicle moved; the time between two reports does
-- not, because a standing vehicle reports rarely or not at all.
reports AS (
    SELECT p.trip_id,
           g.data_time,
           g.speed,
           least(haversine_meters(g.latitude, g.longitude, p.end_latitude, p.end_longitude),
                 haversine_meters(g.latitude, g.longitude, p.start_latitude, p.start_longitude)) AS stop_meters,
           coalesce(g.speed = 0
                    AND lag(g.speed) OVER layover_reports = 0
                    AND haversine_meters(lag(g.latitude) OVER layover_reports, lag(g.longitude) OVER layover_reports,
                                         g.latitude, g.longitude) <= getvariable('standstill_radius_meters'),
                    false) AS continues_run
    FROM pairs p
    JOIN gps_reports g ON g.bus_id = p.bus_id AND g.data_time BETWEEN p.end_time AND p.next_start_time
    WHERE g.latitude IS NOT NULL AND g.longitude IS NOT NULL
    WINDOW layover_reports AS (PARTITION BY p.trip_id ORDER BY g.data_time)
),
runs AS (
    SELECT trip_id,
           data_time,
           speed,
           sum(CASE WHEN continues_run THEN 0 ELSE 1 END)
               OVER (PARTITION BY trip_id ORDER BY data_time ROWS UNBOUNDED PRECEDING) AS run_no
    FROM reports
),
-- A run lasts from its first report to its last.
longest_runs AS (
    SELECT trip_id, max(run_minutes) AS longest_still_minutes
    FROM (
        SELECT trip_id, minutes_between(min(data_time), max(data_time)) AS run_minutes
        FROM runs
        WHERE speed = 0
        GROUP BY trip_id, run_no
    )
    GROUP BY trip_id
),
report_counts AS (
    SELECT trip_id, count(*) AS n_reports, max(stop_meters) AS farthest_meters
    FROM reports
    GROUP BY trip_id
)
-- A layover with reports but none at speed 0 stood still for 0.0 minutes; one
-- without reports has neither a longest standstill nor a farthest distance.
SELECT p.go_back,
       p.bus_id,
       p.end_time,
       p.next_start_time,
       p.minutes,
       p.next_route_id,
       p.next_go_back,
       round(haversine_meters(p.end_latitude, p.end_longitude, p.start_latitude, p.start_longitude), 1) AS stop_gap_meters,
       coalesce(c.n_reports, 0) AS n_reports,
       CASE WHEN c.n_reports IS NOT NULL THEN round(coalesce(r.longest_still_minutes, 0), 1) END AS longest_still_minutes,
       round(c.farthest_meters, 1) AS farthest_meters
FROM pairs p
LEFT JOIN report_counts c USING (trip_id)
LEFT JOIN longest_runs r USING (trip_id);

-- A pair ends in the direction of its first trip, whatever its category; a
-- direction of the page route without any pair has a row of zeros. The ends
-- are the page route's last stops; its member routes share its two ends
-- (turnaround-ends), so their stop lists are not read here.
CREATE OR REPLACE VIEW end_pair_counts AS
WITH last_stops AS (
    SELECT go_back, stop_name AS end_stop_name
    FROM stops
    WHERE route_id = getvariable('route_id')
    QUALIFY row_number() OVER (PARTITION BY go_back ORDER BY seq DESC) = 1
)
SELECT s.go_back,
       s.end_stop_name,
       count(p.trip_id) AS n_pairs,
       count(p.trip_id) FILTER (WHERE p.category = 'layover') AS n_layovers,
       count(p.trip_id) FILTER (WHERE p.category = 'no_last_stop') AS n_no_last_stop,
       count(p.trip_id) FILTER (WHERE p.category = 'no_first_stop') AS n_no_first_stop,
       count(p.trip_id) FILTER (WHERE p.category = 'other_route') AS n_other_route,
       count(p.trip_id) FILTER (WHERE p.category = 'negative') AS n_negative
FROM last_stops s
LEFT JOIN layover_pairs p ON p.go_back = s.go_back
GROUP BY s.go_back, s.end_stop_name;
