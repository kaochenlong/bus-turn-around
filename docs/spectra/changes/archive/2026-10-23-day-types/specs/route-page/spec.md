## MODIFIED Requirements

### Requirement: Day coverage

With `range=day` the page SHALL cover the selected day. With `range=7d` it SHALL cover the selected day and those of the six Taipei days before it that are stored for the route and have the same day type as the selected day, as defined by `day-types`. The page SHALL state whether the covered days are weekdays or holidays, and SHALL list each covered date with its day of week and with its calendar note when it has one. The page SHALL link to the latest stored day on or before the selected day whose day type differs from the selected day's, keeping the range and naming that day and its day type; when there is no such day, the page SHALL NOT show that link. When the selected day is not stored, the page SHALL respond 200, state that the day has no data and list the stored days.

#### Scenario: Seven days with gaps

- **WHEN** route 9001 has the stored weekdays 2026-10-19, 2026-10-20 and 2026-10-22 and a visitor requests `?day=2026-10-22&range=7d`
- **THEN** the page covers exactly 2026-10-19, 2026-10-20 and 2026-10-22, states that they are weekdays and lists them with their days of week

#### Scenario: Seven days keep the selected day's type

- **WHEN** route 9001 has stored weekdays and holidays in the same seven Taipei days and a visitor selects a holiday with `range=7d`
- **THEN** the page covers only the holidays of those seven days and links to the latest weekday before them

##### Example: the Retrocession Day weekend

- **GIVEN** route 9001 has the stored weekdays 2026-10-19 to 2026-10-23 and the stored holidays 2026-10-24, 2026-10-25 and 2026-10-26, the last with the note 補假
- **WHEN** a visitor requests `/routes/9001?day=2026-10-26&range=7d`
- **THEN** the page states holidays, covers exactly 2026-10-24（六）, 2026-10-25（日） and 2026-10-26（一） with the note 補假, and links to `/routes/9001?day=2026-10-23&range=7d`, naming 2026-10-23（五） and weekdays

#### Scenario: No day of the other type before the selected day

- **WHEN** route 9001 has the stored weekdays 2026-10-19 to 2026-10-23 and the stored holidays 2026-10-24 to 2026-10-26, and a visitor requests `?day=2026-10-23&range=7d`
- **THEN** the page covers 2026-10-19 to 2026-10-23, states weekdays and shows no link to holidays

#### Scenario: One day states its type

- **WHEN** route 9001 has the stored weekday 2026-10-23 and the stored holiday 2026-10-26 with the note 補假, and a visitor requests `/routes/9001` without parameters
- **THEN** the page covers 2026-10-26, states that it is a holiday, shows the note 補假 and links to `/routes/9001?day=2026-10-23&range=day`

#### Scenario: Day without data

- **WHEN** a visitor requests `?day=2026-10-25` for route 9001 and that day is not stored
- **THEN** the response is 200, the page says the day has no data and lists the stored days

### Requirement: Data limitations on the page

The page SHALL state the data limitations that apply to its numbers: a vehicle is not a driver and a layover is an upper bound on rest; on-board counts come from fare-card taps and do not return to zero between trips; 10-second polling misses stops and trips missing a terminal are left out of run times; weekdays and holidays follow the office calendar of 行政院人事行政總處, and days off for typhoons are not in that calendar and count as the calendar says; a stop near an MRT entrance does not mean the bus segment can be replaced by the MRT, distances are straight-line, and the entrance data is updated irregularly; the buffer estimate counts vehicle-hours, not driver hours, uses only measured layovers at stopping ends, and its added vehicles are an hourly average, not a schedule; which end buses stop at is a fact verified route by route and written into the configuration, not computed from the data, and it goes stale when the operator changes how the route turns around; layovers at a pass-through end are not rest opportunities and the buffer estimate does not count them.

#### Scenario: Limitations present

- **WHEN** any route page with data is rendered
- **THEN** it contains a 資料限制 section with the statements above

#### Scenario: No statement that days are mixed

- **WHEN** a route page with data is rendered with either range
- **THEN** it does not state that weekdays and holidays are not separated

##### Example: both ranges of a stored weekday

- **GIVEN** route 9001 has the stored weekday 2026-10-19
- **WHEN** a visitor requests `/routes/9001?day=2026-10-19` and `/routes/9001?day=2026-10-19&range=7d`
- **THEN** neither response contains 沒有分平日與假日
