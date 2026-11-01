-- Stop districts: the district of each stop and the districts of the page
-- route, from the newest stop district snapshot written by
-- bin/rails external:stop_districts. It runs after params.sql and every
-- numbered stage, before derived_export.sql; its name does not start with a
-- digit, so bin/health-card never runs it.
--
-- Reads stops from stage 10 and the variable stop_districts_path, a UTF-8
-- snapshot of stop_location_id,county,town. Creates:
--   stop_districts       the snapshot
--   stop_district_names  per stop of every route Id of the run: district, the
--                        county and town joined, NULL for a stop whose stop
--                        location is not in the snapshot
--   page_stop_locations  the page route's distinct stop locations, both directions
--   route_day_districts  per district of the page route: n_locations of those
--                        stop locations in it, n_total of all of them, share
--                        and whether it qualifies under district_min_share_percent

CREATE OR REPLACE TABLE stop_districts AS
SELECT stop_location_id, county, town
FROM read_csv(getvariable('stop_districts_path'), header = true,
              columns = {'stop_location_id': 'INTEGER', 'county': 'VARCHAR', 'town': 'VARCHAR'});

CREATE OR REPLACE TABLE stop_district_names AS
SELECT s.route_id, s.go_back, s.seq, d.county || d.town AS district
FROM stops s
LEFT JOIN stop_districts d ON d.stop_location_id = s.stop_location_id;

-- A stop location once, over both directions; member routes' stops stay out.
CREATE OR REPLACE TABLE page_stop_locations AS
SELECT DISTINCT stop_location_id
FROM stops
WHERE route_id = getvariable('route_id') AND stop_location_id IS NOT NULL;

-- The share compares whole counts against a whole percentage, so a share
-- exactly on the threshold qualifies and no floating point rounding moves it.
-- A stop location without a district counts in n_total and in no district.
CREATE OR REPLACE TABLE route_day_districts AS
SELECT d.county,
       d.town,
       count(*) AS n_locations,
       (SELECT count(*) FROM page_stop_locations) AS n_total,
       round(count(*) / (SELECT count(*) FROM page_stop_locations), 3) AS share,
       count(*) * 100 >= (SELECT count(*) FROM page_stop_locations) * getvariable('district_min_share_percent') AS qualifies
FROM page_stop_locations l
JOIN stop_districts d USING (stop_location_id)
GROUP BY d.county, d.town;
