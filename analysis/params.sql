-- Definition constants of the health card. Change a definition here and
-- nowhere else: the stage files read these values through getvariable().

-- Trip segmentation: a gap longer than this between two events of the same
-- vehicle starts a new trip.
SET VARIABLE split_gap_minutes = 60;
-- A segment cut this way is a trip only when it observes at least this many
-- distinct stops: at one stop the vehicle did not run from one stop to another.
SET VARIABLE min_trip_stops = 2;

-- Read window, by the day and hour in the file path.
-- Lookback is at least twice the split gap, rounded up to whole hours. The
-- first event of a trip cut by the window start lies within one split gap
-- after it, and that stop's departure lies within another split gap; both
-- must fall before midnight for the trip to start on the previous day.
SET VARIABLE lookback_hours = CAST(ceil(2 * getvariable('split_gap_minutes') / 60) AS INTEGER);
-- Overflow covers trips that leave before midnight: last departure 23:00 and
-- a single trip under three hours on route 15373.
SET VARIABLE overflow_hours = 2;

-- Layovers: shorter than this counts as short; bins include their lower
-- bound and exclude their upper bound, the last bin is open-ended.
SET VARIABLE short_layover_minutes = 15;
SET VARIABLE layover_bin_lower_bounds = [0, 5, 10, 15, 30, 60];
SET VARIABLE percentile_levels = [0.1, 0.5, 0.9];

-- A vehicle ran another route between two trips when its records on other
-- routes in between cover at least this many distinct stops. RouteID 0 never
-- counts: it marks non-revenue states such as the end of duty at a terminal.
-- One or two stops is a route code set at a terminal, not a run. Of the 248
-- pairs with such records on routes 15373, 16111, 11764 and 10712 from
-- 2026-10-19 to 10-22, 8 covered 1 stop and 240 at least 57.
SET VARIABLE other_route_min_stops = 3;

-- Rest rule of 汽車運輸業管理規則第 19 條之 2: within any 240 minutes, rests
-- of at least 15 minutes each must add up to 30 minutes.
SET VARIABLE rest_window_minutes = 240;
SET VARIABLE rest_min_minutes = 15;
SET VARIABLE rest_credit_minutes = 30;

-- Time bands by the hour of a trip's start, each including its start hour
-- and excluding its end hour; every other hour is the "other" band.
SET VARIABLE morning_peak_start_hour = 7;
SET VARIABLE daytime_start_hour = 9;
SET VARIABLE evening_peak_start_hour = 17;
SET VARIABLE evening_peak_end_hour = 19;

-- On-board counts: at most this many at a terminal counts as near zero, and a
-- change larger than the jump threshold between counted stops is an anomaly.
-- The load profile reports the median and this upper percentile per stop.
SET VARIABLE reset_near_zero = 2;
SET VARIABLE jump_threshold = 30;

-- The reset check looks this far before a complete trip's start for the
-- arrival record at its first stop, and this far after its end for the
-- departure record at its last stop. It matches the split gap: a record
-- further away is not known to belong to the same trip.
SET VARIABLE reset_record_minutes = 60;
SET VARIABLE profile_upper_level = 0.9;

-- The DutyStatus code the feed documents as the end of duty (結束). Whether
-- it marks the end of a trip is what the 資料品質 section measures.
SET VARIABLE duty_status_end_code = 2;

-- Turnaround facilities (analysis/turnaround_facilities.sql). The location of
-- a stopping end is the count-weighted mean of the standstill points within
-- the standstill radius of the densest one: 50 metres is three to four bus
-- lengths, so the GPS jitter of one parking space stays together. A layover
-- counts as located when one of its standstill reports lies within the
-- located radius of the location; the stopping ends verified by hand stood
-- within 112 and 136 metres of the nearer stop. Toilets are stored within the
-- toilet radius; the route page applies 300 metres when it reads them.
SET VARIABLE standstill_radius_meters = 50;
SET VARIABLE located_radius_meters = 150;
SET VARIABLE toilet_radius_meters = 500;
-- Standstill cells, for a map: the south-west corner of a cell is a multiple
-- of this many degrees (about 22 metres north-south and 20 metres east-west in
-- Taipei), and a cell is exported only when at least this many vehicles stood
-- in it that day, so no cell traces a single vehicle.
SET VARIABLE standstill_cell_degrees = 0.0002;
SET VARIABLE cell_min_buses = 3;

-- Route shapes (analysis/route_shape.sql): a row of GetBusShape can be kept
-- only when its line has at least this many points and every point lies
-- within these bounds. The bounds take in Taiwan and its outlying islands;
-- what they catch is latitude and longitude swapped, which puts a latitude
-- near 121.
SET VARIABLE route_shape_min_points = 2;
SET VARIABLE route_shape_min_latitude = 20;
SET VARIABLE route_shape_max_latitude = 27;
SET VARIABLE route_shape_min_longitude = 118;
SET VARIABLE route_shape_max_longitude = 123;

-- End nature survey (analysis/end_nature_survey.sql). The rule was fixed
-- before the whole network was surveyed, from the eight ends verified by hand
-- (docs/spectra/changes/02-end-nature-survey). A layover stood still when its
-- longest standstill is longer than nature_still_minutes: at the
-- pass-through ends of 251 and 251區, the two whose standstills were measured,
-- it never went past 2.0 minutes, the largest being exactly 2.0 at
-- 臺北車站(開封), and "longer than" keeps that below. An end whose layovers
-- with GPS reports are fewer than nature_min_layovers is undetermined: over
-- four days that is at least 5 a day, and under 20 one layover moves the
-- share by 5 points, as much as the pass-through threshold. Of the layovers
-- with GPS reports, a share that stood still of at most
-- nature_pass_through_max_share is pass-through: it was 0 at both of those
-- ends, and 5% leaves room for a bus that waits now and then. It is no wider
-- because an end where buses stop for two minutes, taken for pass-through,
-- drops out of the rest trade-off with the very problem it has.
-- A share of at least nature_stop_min_share is a stop: 168 of 211 and 198 of
-- 223 at the two ends of 307 stood still for 2 minutes or more, and the
-- median longest standstill at the stopping ends of 251 and 251區 was 14.4 and
-- 3.5 minutes, so more than half. A share in between is undetermined.
SET VARIABLE nature_still_minutes = 2;
SET VARIABLE nature_min_layovers = 20;
SET VARIABLE nature_pass_through_max_share = 0.05;
SET VARIABLE nature_stop_min_share = 0.5;

-- Minutes from one timestamp to a later one, with the seconds kept.
CREATE OR REPLACE MACRO minutes_between(earlier, later) AS epoch(later - earlier) / 60;
