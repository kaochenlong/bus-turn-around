-- End nature export: the evidence of one route day, for
-- bin/rails survey:end_natures. It runs after end_nature_evidence.sql; its
-- name does not start with a digit, so bin/health-card never runs it.
--
-- Reads routes from stage 10, layover_evidence and end_pair_counts from
-- end_nature_evidence.sql, and the variables route_id, route_ids (stage 10),
-- day and survey_dir. Writes to survey_dir, which is never inspect_dir, so
-- the health card's layovers.csv stays as stage 60 wrote it:
--   layovers.csv  every layover with its evidence
--   ends.csv      every direction of the page route with its last stop and
--                 the trip pairs ending there, by category
-- Times are Taipei times without an offset, and both files have a fixed
-- column order and a row order ending in a unique key, so two runs over the
-- same input give the same bytes.

COPY (
    SELECT getvariable('route_id') AS route_id,
           strftime(getvariable('day'), '%Y-%m-%d') AS day,
           go_back,
           bus_id,
           strftime(end_time, '%Y-%m-%d %H:%M:%S') AS end_time,
           strftime(next_start_time, '%Y-%m-%d %H:%M:%S') AS next_start_time,
           minutes,
           next_route_id,
           next_go_back,
           stop_gap_meters,
           n_reports,
           longest_still_minutes,
           farthest_meters
    FROM layover_evidence
    ORDER BY go_back, end_time, bus_id
) TO (getvariable('survey_dir') || '/layovers.csv') (HEADER);

-- The route name is the page route's, named as derived_export.sql names the
-- route day: by its own pathAttributeId, another sub-route only when it has
-- none.
COPY (
    SELECT getvariable('route_id') AS route_id,
           array_to_string(getvariable('route_ids'), '・') AS route_ids,
           strftime(getvariable('day'), '%Y-%m-%d') AS day,
           go_back,
           (SELECT route_name FROM routes WHERE route_id = getvariable('route_id')
            ORDER BY path_attribute_id <> route_id, path_attribute_id LIMIT 1) AS route_name,
           end_stop_name,
           n_pairs,
           n_layovers,
           n_no_last_stop,
           n_no_first_stop,
           n_other_route,
           n_negative
    FROM end_pair_counts
    ORDER BY go_back
) TO (getvariable('survey_dir') || '/ends.csv') (HEADER);
