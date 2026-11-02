## MODIFIED Requirements

### Requirement: Preparing a route card

The system SHALL provide the rake task `cards:prepare` taking `ROUTE` (a page route `Id`) and `MONTH` (`YYYY-MM`), with the raw data root from `TURNAROUND_DATA`. It SHALL print the month's coverage. When the coverage is ready it SHALL create version 1 of the route card or update that version's coverage, and exit with status 0. When a day is waiting it SHALL name the waiting days, write nothing and exit with a non-zero status. A `ROUTE` that is a member route or not a page route, a malformed `MONTH`, or a missing `TURNAROUND_DATA` SHALL print the usage and exit with a non-zero status. A month with a version printed as defined by `monthly-card-pdf` SHALL be refused: the task SHALL say so, point to `--revise`, write nothing and exit with a non-zero status.

#### Scenario: Ready month

- **WHEN** `cards:prepare ROUTE=9001 MONTH=2026-10` runs and no day is waiting
- **THEN** version 1 of the route card exists with that coverage and the exit status is 0

#### Scenario: Waiting days

- **WHEN** a day of the month is waiting
- **THEN** the output names that day, no row is written and the exit status is non-zero

#### Scenario: Member route

- **WHEN** `ROUTE` is listed under another route's `member_routes`
- **THEN** the usage names the page route and the exit status is non-zero

#### Scenario: Preparing a printed month

- **WHEN** `cards:prepare ROUTE=15373 MONTH=2026-11` runs and version 1 of that month is printed
- **THEN** the output says the month is printed and points to `--revise`, the row is unchanged and the exit status is non-zero

### Requirement: Month card page

The system SHALL serve the month card of a page route and month at `/routes/<Id>/cards/<YYYY-MM>`, using the highest version of its route card, with a `main[data-month-card]` that holds the blocks marked by `data-card-section` in this order: `summary`, `layovers`, `driving`, `schedule`, `cycles`, `run-times`, `buffer`, `history`, `attribution`. The response SHALL be 404 when the route is not a page route, when the month has no route card, or when the month is malformed. The document title SHALL be 路線名 健檢卡 YYYY 年 M 月 followed by the site name after the separator ｜, and the page SHALL carry a `robots` meta of `noindex`. The page SHALL carry a `turnaround-card` meta holding the route `Id`, the month and the version joined by `/`, a `turnaround-program-version` meta holding the short commit of the running program, and a `turnaround-card-summary` meta holding, as JSON, what the route card stores as its summary. The page SHALL NOT contain any `BusID` value and SHALL NOT state that anything complies or fails to comply with a rule. When rest windows or the published schedule of a covered day need loading again, the page SHALL say at its top, in an element marked `data-card-incomplete`, that those figures are incomplete.

#### Scenario: Blocks in order

- **WHEN** `/routes/9001/cards/2026-10` is requested and the route card exists
- **THEN** the response is 200 and the `data-card-section` values appear in the listed order, each exactly once

#### Scenario: Which card the page is

- **WHEN** `/routes/9001/cards/2026-10` is requested and the highest version of that month's route card is 2
- **THEN** the `turnaround-card` meta is 9001/2026-10/2, and the `turnaround-card-summary` meta parses to the month card's summary

#### Scenario: No route card

- **WHEN** `/routes/9001/cards/2026-11` is requested and that month has no route card
- **THEN** the response is 404

#### Scenario: Route without a page

- **WHEN** `/routes/19108/cards/2026-10` is requested and 19108 is a member route
- **THEN** the response is 404

#### Scenario: Malformed month

- **WHEN** `/routes/9001/cards/2026-13` is requested
- **THEN** the response is 404

#### Scenario: Plates and verdicts

- **WHEN** the page of a route whose vehicles include TEST-0001 is requested
- **THEN** `main[data-month-card]` does not contain TEST-0001, 不合規 or 違規

#### Scenario: Days not loaded again

- **WHEN** one covered route day has `rest_windows_loaded` false
- **THEN** the page says at its top, in an element marked `data-card-incomplete`, that the figures are incomplete
