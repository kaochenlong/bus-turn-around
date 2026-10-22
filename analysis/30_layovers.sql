-- Stage 30: layovers between consecutive trips of a vehicle, their
-- distribution, and the four-hour rest windows built on them.
--
-- Reads trips from stage 20 and stops from stage 10. Creates views:
--   layover_pairs         every pair of consecutive trips of a vehicle, with
--                         the category deciding whether it is a layover
--   layovers              the pairs that qualify, in minutes
--   layover_exclusions    pairs that do not qualify, counted per category
--   layover_distribution  overall and per direction of the trip that ended
--   rest_runs             complete trips grouped into runs of consecutive
--                         complete trips of one vehicle on one route
--   rest_windows          per trip of a run, the shortest window reaching the
--                         rest window length, its rest credit and flag
--   chains                flagged windows of a vehicle merged where they
--                         share a trip; carries bus_id for chains.csv only
--   chain_report          the chains for the card, without any vehicle field
--   chain_summary         number of chains and of vehicles with a chain

-- A vehicle's last trip of the day has no following trip and so no pair.
CREATE OR REPLACE VIEW layover_pairs AS
WITH ordered AS (
    SELECT trip_id,
           bus_id,
           route_id,
           go_back,
           start_time,
           end_time,
           completeness,
           lead(trip_id) OVER vehicle_trips AS next_trip_id,
           lead(route_id) OVER vehicle_trips AS next_route_id,
           lead(start_time) OVER vehicle_trips AS next_start_time,
           lead(completeness) OVER vehicle_trips AS next_completeness
    FROM trips
    WINDOW vehicle_trips AS (PARTITION BY bus_id ORDER BY start_time, trip_id)
)
SELECT *,
       minutes_between(end_time, next_start_time) AS minutes,
       -- A layover needs only the arrival at the last stop that ends this trip
       -- and the departure from the first stop that starts the next, so the
       -- other end of either trip may be missing. A pair that fails more than
       -- one condition counts in the first one listed.
       CASE
           WHEN completeness NOT IN ('complete', 'missing_start') THEN 'no_last_stop'
           WHEN next_completeness NOT IN ('complete', 'missing_end') THEN 'no_first_stop'
           WHEN next_route_id <> route_id THEN 'other_route'
           WHEN next_start_time < end_time THEN 'negative'
           ELSE 'layover'
       END AS category
FROM ordered
WHERE next_trip_id IS NOT NULL;

CREATE OR REPLACE VIEW layovers AS
SELECT trip_id, next_trip_id, bus_id, route_id, go_back, end_time, next_start_time, minutes
FROM layover_pairs
WHERE category = 'layover';

CREATE OR REPLACE VIEW layover_exclusions AS
SELECT count(*) FILTER (WHERE category = 'no_last_stop') AS no_last_stop,
       count(*) FILTER (WHERE category = 'no_first_stop') AS no_first_stop,
       count(*) FILTER (WHERE category = 'other_route') AS other_route,
       count(*) FILTER (WHERE category = 'negative') AS negative
FROM layover_pairs;

-- One row for all directions (go_back NULL) and one per direction of the
-- route, even when a direction has no layover. Percentiles interpolate
-- linearly between order statistics and keep one decimal. bin_counts follow
-- layover_bin_lower_bounds; each bin includes its lower bound and excludes the
-- next one.
CREATE OR REPLACE VIEW layover_distribution AS
WITH scopes AS (
    SELECT CAST(NULL AS INTEGER) AS go_back
    UNION ALL
    SELECT DISTINCT go_back FROM stops
),
binned AS (
    SELECT go_back,
           minutes,
           len(list_filter(getvariable('layover_bin_lower_bounds'), lambda lower_bound: lower_bound <= minutes)) AS bin_index
    FROM layovers
),
summary AS (
    SELECT s.go_back,
           count(b.minutes) AS n_layovers,
           quantile_cont(b.minutes, getvariable('percentile_levels')) AS raw_percentiles,
           count(b.minutes) FILTER (WHERE b.minutes < getvariable('short_layover_minutes')) AS n_short,
           coalesce(list(b.bin_index) FILTER (WHERE b.bin_index IS NOT NULL), []) AS bin_indexes
    FROM scopes s
    LEFT JOIN binned b ON s.go_back IS NULL OR s.go_back = b.go_back
    GROUP BY s.go_back
)
SELECT go_back,
       n_layovers,
       list_transform(raw_percentiles, lambda value: round(value, 1)) AS percentiles,
       CASE WHEN n_layovers = 0 THEN NULL ELSE n_short / n_layovers END AS short_share,
       list_transform(
           range(1, len(getvariable('layover_bin_lower_bounds')) + 1),
           lambda position: len(list_filter(bin_indexes, lambda bin: bin = position))
       ) AS bin_counts
FROM summary;

-- Rest rule of 第 19 條之 2. A trip that is not complete, or a change of
-- route, ends a run; the incomplete trip itself belongs to no run.
CREATE OR REPLACE VIEW rest_runs AS
WITH ordered AS (
    SELECT *, lag(route_id) OVER vehicle_trips AS previous_route_id
    FROM trips
    WINDOW vehicle_trips AS (PARTITION BY bus_id ORDER BY start_time, trip_id)
),
numbered AS (
    SELECT *,
           sum(CASE WHEN completeness <> 'complete' OR route_id IS DISTINCT FROM previous_route_id THEN 1 ELSE 0 END)
               OVER (PARTITION BY bus_id ORDER BY start_time, trip_id ROWS UNBOUNDED PRECEDING) AS run_no
    FROM ordered
)
SELECT trip_id, bus_id, route_id, start_time, end_time, run_no,
       row_number() OVER (PARTITION BY bus_id, run_no ORDER BY start_time, trip_id) AS position
FROM numbered
WHERE completeness = 'complete';

-- For each trip i of a run, the earliest trip j of the same run (j may be i)
-- whose end is at least the rest window after i's start. The credit sums the
-- layovers after trips i through j-1 that reach the minimum rest; layovers
-- after j are outside the window.
CREATE OR REPLACE VIEW rest_windows AS
WITH reach AS (
    SELECT i.bus_id, i.run_no, i.position AS first_position, min(j.position) AS last_position
    FROM rest_runs i
    JOIN rest_runs j
      ON j.bus_id = i.bus_id AND j.run_no = i.run_no AND j.position >= i.position
     AND minutes_between(i.start_time, j.end_time) >= getvariable('rest_window_minutes')
    GROUP BY i.bus_id, i.run_no, i.position
),
credited AS (
    SELECT r.bus_id,
           r.run_no,
           r.first_position,
           r.last_position,
           coalesce(sum(l.minutes) FILTER (WHERE l.minutes >= getvariable('rest_min_minutes')), 0) AS credit_minutes
    FROM reach r
    LEFT JOIN rest_runs t
      ON t.bus_id = r.bus_id AND t.run_no = r.run_no
     AND t.position >= r.first_position AND t.position < r.last_position
    LEFT JOIN layovers l ON l.trip_id = t.trip_id
    GROUP BY r.bus_id, r.run_no, r.first_position, r.last_position
)
SELECT c.bus_id,
       c.run_no,
       c.first_position,
       c.last_position,
       f.trip_id AS first_trip_id,
       e.trip_id AS last_trip_id,
       f.start_time,
       e.end_time,
       minutes_between(f.start_time, e.end_time) AS window_minutes,
       CAST(c.credit_minutes AS DOUBLE) AS credit_minutes,
       c.credit_minutes < getvariable('rest_credit_minutes') AS flagged
FROM credited c
JOIN rest_runs f ON f.bus_id = c.bus_id AND f.run_no = c.run_no AND f.position = c.first_position
JOIN rest_runs e ON e.bus_id = c.bus_id AND e.run_no = c.run_no AND e.position = c.last_position;

-- Flagged windows of one run merge when they share a trip: a window starts a
-- new chain only when it begins after every earlier window has ended.
CREATE OR REPLACE VIEW chains AS
WITH flagged AS (
    SELECT bus_id, run_no, first_position, last_position,
           max(last_position) OVER (
               PARTITION BY bus_id, run_no ORDER BY first_position
               ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
           ) AS reached_before
    FROM rest_windows
    WHERE flagged
),
grouped AS (
    SELECT *,
           sum(CASE WHEN reached_before IS NULL OR first_position > reached_before THEN 1 ELSE 0 END)
               OVER (PARTITION BY bus_id, run_no ORDER BY first_position ROWS UNBOUNDED PRECEDING) AS chain_no
    FROM flagged
),
spans AS (
    SELECT bus_id, run_no, chain_no, min(first_position) AS first_position, max(last_position) AS last_position
    FROM grouped
    GROUP BY bus_id, run_no, chain_no
)
SELECT row_number() OVER (ORDER BY f.start_time, s.bus_id) AS chain_id,
       s.bus_id,
       f.trip_id AS first_trip_id,
       e.trip_id AS last_trip_id,
       f.start_time,
       e.end_time,
       s.last_position - s.first_position + 1 AS n_trips
FROM spans s
JOIN rest_runs f ON f.bus_id = s.bus_id AND f.run_no = s.run_no AND f.position = s.first_position
JOIN rest_runs e ON e.bus_id = s.bus_id AND e.run_no = s.run_no AND e.position = s.last_position;

CREATE OR REPLACE VIEW chain_report AS
SELECT chain_id, start_time, end_time, n_trips
FROM chains;

CREATE OR REPLACE VIEW chain_summary AS
SELECT count(*) AS n_chains, count(DISTINCT bus_id) AS n_vehicles
FROM chains;
