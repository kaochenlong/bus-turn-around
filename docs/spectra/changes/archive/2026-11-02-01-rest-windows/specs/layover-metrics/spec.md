## ADDED Requirements

### Requirement: Six-hour rest windows

Within the same runs as the requirement "Rest-rule windows and chains", for each trip i of a run the system SHALL find the earliest trip j in the same run such that trip j's end time minus trip i's start time is at least the constant `long_rest_window_minutes` of `analysis/params.sql`, which is 360. When such j exists, trip i starts a six-hour window, and the window SHALL be flagged when none of the layovers after trips i through j-1 is at least the constant `long_rest_min_minutes` of `analysis/params.sql`, which is 45. Six-hour windows SHALL NOT be merged into chains, and they SHALL NOT change the chains, the chain report or any other part of the health card.

#### Scenario: No layover reaches 45 minutes

- **WHEN** trips run 06:00 to 08:50, 09:00 to 11:50 and 12:00 to 14:50 with layovers of 10 and 10 minutes
- **THEN** exactly one six-hour window exists, starting at 06:00 and spanning 530 minutes with a longest layover of 10.0 minutes, and it is flagged

#### Scenario: A layover of exactly 45 minutes

- **WHEN** trips run 06:00 to 08:50, 09:35 to 12:25 and 12:35 to 15:25 with layovers of 45 and 10 minutes
- **THEN** the six-hour window starting at 06:00 has a longest layover of 45.0 minutes and is not flagged

#### Scenario: A run shorter than six hours

- **WHEN** a run's last trip ends less than 360 minutes after its first trip starts
- **THEN** no six-hour window exists for that run

#### Scenario: Fixture day

- **WHEN** six-hour windows are computed for the analysis fixture on 2026-10-19
- **THEN** there are 7 windows and none is flagged, and the first is TEST-0001's from 06:00 to 13:14 with 6 trips and a longest layover of 56.0 minutes

### Requirement: Continuous driving stretches

Within the same runs as the requirement "Rest-rule windows and chains", the system SHALL group the trips of each run into continuous driving stretches: the first trip of a run starts a stretch, and so does every trip whose preceding layover is at least the constant `rest_min_minutes` of `analysis/params.sql`, which is 15. A stretch SHALL be reported with its first trip's start time, its last trip's end time and its number of trips.

#### Scenario: A short layover keeps the stretch

- **WHEN** trips run 06:00 to 08:30 and 08:40 to 11:10 with a 10-minute layover
- **THEN** one stretch runs from 06:00 to 11:10 with 2 trips

#### Scenario: A layover of exactly 15 minutes ends the stretch

- **WHEN** trips run 06:00 to 08:30 and 08:45 to 11:15 with a 15-minute layover
- **THEN** two stretches exist, 06:00 to 08:30 and 08:45 to 11:15

#### Scenario: Another route starts a new stretch

- **WHEN** complete trips run 10:20 to 11:08 and 11:20 to 12:08, the vehicle then runs another route, and its next complete trip runs 17:10 to 17:58
- **THEN** one stretch runs from 10:20 to 12:08 with 2 trips and another runs from 17:10 to 17:58 with 1 trip

#### Scenario: Fixture day

- **WHEN** continuous driving stretches are computed for the analysis fixture on 2026-10-19
- **THEN** there are 15 stretches and the longest runs from 06:00 to 11:30 with 5 trips

### Requirement: Rest window figures over route days

The system SHALL provide the query object `RoutePage::RestWindows`, which reads the stored rest windows and driving stretches of any given set of route days, whether or not the set is ordered. For each of the rules `four_hours` and `six_hours` it SHALL report the number of windows, the number of flagged windows, the flagged share of the windows, the lowest and the highest daily flagged share among the days that have a window of that rule, the number of windows with `over_daily_driving` and the number of flagged windows with `over_daily_driving`. Without a window of a rule, the share and the daily shares SHALL be nil. For the stretches it SHALL report their number, the 50th and 90th percentiles of their minutes to one decimal using linear interpolation, the longest in minutes, and how many exceed 240 and 360 minutes. It SHALL report that the days need loading again when any given route day has `rest_windows_loaded` false. It SHALL NOT return any `BusID` value and SHALL NOT carry any judgement of compliance.

#### Scenario: Shares over two days

- **WHEN** one route day has 4 `four_hours` windows of which 2 are flagged, and another has 2 `four_hours` windows of which 2 are flagged
- **THEN** the rule reports 6 windows, 4 flagged, a share of 4/6, a lowest daily share of 0.5 and a highest daily share of 1.0

#### Scenario: A day without windows

- **WHEN** a route day has `rest_windows_loaded` true and no `six_hours` window, and another has 2 `six_hours` windows of which 1 is flagged
- **THEN** the rule reports 2 windows, 1 flagged, and both daily shares are 0.5

#### Scenario: No windows at all

- **WHEN** no given route day has a `six_hours` window
- **THEN** the rule reports 0 windows, 0 flagged, and its share and daily shares are nil

#### Scenario: Stretch figures

- **WHEN** the stretches last 100, 200, 250 and 400 minutes
- **THEN** the report gives 4 stretches, a p50 of 225.0, a p90 of 355.0, a longest of 400.0, 2 over 240 minutes and 1 over 360 minutes

#### Scenario: A day that was not loaded again

- **WHEN** one given route day has `rest_windows_loaded` false
- **THEN** the query object reports that the days need loading again

#### Scenario: No plates in the figures

- **WHEN** the figures are read for a route day whose vehicle is TEST-0001
- **THEN** no returned value contains TEST-0001
