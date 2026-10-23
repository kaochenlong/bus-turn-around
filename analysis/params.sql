-- Definition constants of the health card. Change a definition here and
-- nowhere else: the stage files read these values through getvariable().

-- Trip segmentation: a gap longer than this between two events of the same
-- vehicle starts a new trip.
SET VARIABLE split_gap_minutes = 60;

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

-- Minutes from one timestamp to a later one, with the seconds kept.
CREATE OR REPLACE MACRO minutes_between(earlier, later) AS epoch(later - earlier) / 60;
