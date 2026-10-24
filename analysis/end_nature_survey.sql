-- End nature survey: the report of bin/rails survey:end_natures, one row per
-- surveyed page route and direction, its evidence pooled over the surveyed
-- days and the nature the rule of params.sql infers from it. The rule never
-- reads the configured natures; they are joined only to say whether the two
-- agree. It runs after params.sql alone (AnalysisRun with stages: false),
-- because it reads only the files the route days wrote; its name does not
-- start with a digit, so bin/health-card never runs it.
--
-- Reads the variables layovers_files and ends_files, the layovers.csv and
-- ends.csv of every route day of the survey with evidence
-- (end_nature_export.sql); configured_path, a file the task writes with the
-- configured nature of each end in config/route_page.yml (route_id, go_back,
-- nature); and report_path. Creates:
--   survey_layovers   every layover of the survey with its evidence
--   survey_ends       every end of every route day with its trip pairs
--   configured_ends   the configured natures
--   inferred_ends     per page route and direction: the pooled evidence, the
--                     inferred nature and why it is undetermined (a view)
-- and writes the report to report_path.

CREATE OR REPLACE TABLE survey_layovers AS
SELECT *
FROM read_csv(getvariable('layovers_files'), header = true, delim = ',', quote = '"', escape = '"', columns = {
    'route_id': 'INTEGER', 'day': 'DATE', 'go_back': 'INTEGER', 'bus_id': 'VARCHAR', 'end_time': 'TIMESTAMP',
    'next_start_time': 'TIMESTAMP', 'minutes': 'DOUBLE', 'next_route_id': 'INTEGER', 'next_go_back': 'INTEGER',
    'stop_gap_meters': 'DOUBLE', 'n_reports': 'INTEGER', 'longest_still_minutes': 'DOUBLE', 'farthest_meters': 'DOUBLE'
});

CREATE OR REPLACE TABLE survey_ends AS
SELECT *
FROM read_csv(getvariable('ends_files'), header = true, delim = ',', quote = '"', escape = '"', columns = {
    'route_id': 'INTEGER', 'route_ids': 'VARCHAR', 'day': 'DATE', 'go_back': 'INTEGER', 'route_name': 'VARCHAR',
    'end_stop_name': 'VARCHAR', 'n_pairs': 'INTEGER', 'n_layovers': 'INTEGER', 'n_no_last_stop': 'INTEGER',
    'n_no_first_stop': 'INTEGER', 'n_other_route': 'INTEGER', 'n_negative': 'INTEGER'
});

CREATE OR REPLACE TABLE configured_ends AS
SELECT *
FROM read_csv(getvariable('configured_path'), header = true, delim = ',', quote = '"', escape = '"', columns = {
    'route_id': 'INTEGER', 'go_back': 'INTEGER', 'nature': 'VARCHAR'
});

-- An end is every page route and direction an ends.csv has, named as on the
-- latest surveyed day. A layover with GPS reports stood still when its
-- longest standstill is longer than nature_still_minutes; the shares are
-- compared as counts, n_stood_still against n_with_gps times the threshold,
-- so a share exactly at a threshold is not lost to floating point.
-- Percentiles interpolate linearly between order statistics, as median does.
CREATE OR REPLACE VIEW inferred_ends AS
WITH ends AS (
    SELECT route_id,
           go_back,
           arg_max(route_ids, day) AS route_ids,
           arg_max(route_name, day) AS route_name,
           arg_max(end_stop_name, day) AS end_stop_name,
           sum(n_pairs) AS n_pairs,
           sum(n_layovers) AS n_layovers,
           sum(n_other_route) AS n_other_route
    FROM survey_ends
    GROUP BY route_id, go_back
),
pooled AS (
    SELECT route_id,
           go_back,
           count(DISTINCT day) AS n_days,
           count(*) FILTER (WHERE n_reports > 0) AS n_with_gps,
           count(*) FILTER (WHERE n_reports > 0 AND longest_still_minutes > getvariable('nature_still_minutes')) AS n_stood_still,
           quantile_cont(minutes, 0.1) AS layover_p10,
           median(minutes) AS layover_p50,
           quantile_cont(minutes, 0.9) AS layover_p90,
           median(stop_gap_meters) AS stop_gap_p50,
           median(longest_still_minutes) AS still_p50,
           max(longest_still_minutes) AS still_max,
           median(farthest_meters) AS farthest_p50,
           quantile_cont(farthest_meters, 0.9) AS farthest_p90,
           max(farthest_meters) AS farthest_max
    FROM survey_layovers
    GROUP BY route_id, go_back
),
counted AS (
    SELECT e.*,
           coalesce(p.n_days, 0) AS n_days,
           coalesce(p.n_with_gps, 0) AS n_with_gps,
           coalesce(p.n_stood_still, 0) AS n_stood_still,
           p.* EXCLUDE (route_id, go_back, n_days, n_with_gps, n_stood_still)
    FROM ends e
    LEFT JOIN pooled p USING (route_id, go_back)
),
classified AS (
    SELECT *,
           CASE WHEN n_with_gps < getvariable('nature_min_layovers') THEN 'few_layovers'
                WHEN n_stood_still <= n_with_gps * getvariable('nature_pass_through_max_share') THEN 'pass_through'
                WHEN n_stood_still >= n_with_gps * getvariable('nature_stop_min_share') THEN 'stop'
                ELSE 'between' END AS verdict
    FROM counted
)
SELECT * EXCLUDE (verdict),
       CASE WHEN n_with_gps > 0 THEN n_stood_still / n_with_gps END AS stood_still_share,
       CASE WHEN verdict IN ('few_layovers', 'between') THEN 'undetermined' ELSE verdict END AS nature,
       CASE WHEN verdict IN ('few_layovers', 'between') THEN verdict END AS reason
FROM classified;

-- Minutes and metres keep one decimal and the share three; a value with
-- nothing to compute from is empty. Agreement is empty for a route that is
-- not configured, and false when the inferred nature is undetermined.
COPY (
    SELECT i.route_id,
           i.route_ids,
           i.route_name,
           i.go_back,
           i.end_stop_name,
           i.n_days,
           i.n_pairs,
           i.n_layovers,
           i.n_other_route,
           i.n_with_gps,
           i.n_stood_still,
           round(i.layover_p10, 1) AS layover_p10,
           round(i.layover_p50, 1) AS layover_p50,
           round(i.layover_p90, 1) AS layover_p90,
           round(i.stop_gap_p50, 1) AS stop_gap_p50,
           round(i.still_p50, 1) AS still_p50,
           round(i.still_max, 1) AS still_max,
           CAST(round(i.stood_still_share, 3) AS DECIMAL(4, 3)) AS stood_still_share,
           round(i.farthest_p50, 1) AS farthest_p50,
           round(i.farthest_p90, 1) AS farthest_p90,
           round(i.farthest_max, 1) AS farthest_max,
           i.nature,
           i.reason,
           c.nature AS configured_nature,
           CASE WHEN c.nature IS NOT NULL THEN i.nature = c.nature END AS agrees
    FROM inferred_ends i
    LEFT JOIN configured_ends c USING (route_id, go_back)
    ORDER BY i.route_id, i.go_back
) TO (getvariable('report_path')) (HEADER);
