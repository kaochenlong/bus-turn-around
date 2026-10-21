## Purpose

A web page per route that shows drivers and station managers how the route ran on a Taipei day or over the last 7 days: trip counts, run times, layovers at each end and the load profile. It reads only the derived tables and never shows a vehicle identifier.

## ADDED Requirements

### Requirement: Route page address and parameters

The system SHALL serve `GET /routes/:route_id` for route `Id`s listed in the route list configuration, and SHALL respond 404 for any other route `Id`. The optional parameter `day` (`YYYY-MM-DD`) selects a Taipei day and defaults to the latest day stored for the route; the optional parameter `range` is `day` or `7d` and defaults to `day`. A malformed `day` or any other `range` value SHALL respond 400.

#### Scenario: Route not configured

- **WHEN** a visitor requests `/routes/9999` and 9999 is not in the route list
- **THEN** the response is 404

#### Scenario: Defaults

- **WHEN** route 9001 has stored days 2026-10-19 and 2026-10-20 and a visitor requests `/routes/9001`
- **THEN** the page shows 2026-10-20 with the range of one day

#### Scenario: Bad parameter

- **WHEN** a visitor requests `/routes/9001?range=30d`
- **THEN** the response is 400

### Requirement: Day coverage

With `range=day` the page SHALL cover the selected day. With `range=7d` it SHALL cover the selected day and the six Taipei days before it, using only the days stored for the route, and SHALL list the covered dates with their day of week and state that weekdays and holidays are not separated. When the selected day is not stored, the page SHALL respond 200, state that the day has no data and list the stored days.

#### Scenario: Seven days with gaps

- **WHEN** route 9001 has stored days 2026-10-19, 2026-10-20 and 2026-10-22 and a visitor requests `?day=2026-10-22&range=7d`
- **THEN** the page covers exactly 2026-10-19, 2026-10-20 and 2026-10-22 and lists them with their days of week

#### Scenario: Day without data

- **WHEN** a visitor requests `?day=2026-10-25` for route 9001 and that day is not stored
- **THEN** the response is 200, the page says the day has no data and lists the stored days

### Requirement: Page content

The page SHALL show, in this order: a summary with the route name, departure and destination, the covered days, the number of trips and of complete trips; the run time summary of `run-time` per direction, with the number of excluded trips; the layovers per direction of the ending trip, each row naming that direction's last stop, with the number of layovers, p10, p50, p90 and the share under 15 minutes as defined by `layover-metrics`; and the load profile as defined by `load-profile`, per direction, time band and stop, each cell giving the median, the p90 and the number of trips with a count. Percentiles SHALL be computed over all trips of the covered days, not combined from daily values.

#### Scenario: Seven-day percentile pools trips

- **WHEN** day one has layovers of 10 and 20 minutes in direction 0 and day two has one of 30 minutes, and the page covers both days
- **THEN** the direction 0 layover row reports 3 layovers and a p50 of 20.0

### Requirement: No vehicle identifiers on the page

The rendered page SHALL NOT contain any `BusID` value.

#### Scenario: Fixture plates absent

- **WHEN** the fixture day of route 9001 is stored and its page is rendered
- **THEN** none of `TEST-0001` to `TEST-0004` appears in the response body

### Requirement: Data limitations on the page

The page SHALL state the data limitations that apply to its numbers: a vehicle is not a driver and a layover is an upper bound on rest; on-board counts come from fare-card taps and do not return to zero between trips; 10-second polling misses stops and trips missing a terminal are left out of run times; the covered days do not separate weekdays and holidays.

#### Scenario: Limitations present

- **WHEN** any route page with data is rendered
- **THEN** it contains a 資料限制 section with the four statements above
