## MODIFIED Requirements

### Requirement: Route page address and parameters

The system SHALL serve `GET /routes/:route_id` for route `Id`s listed in the route list configuration, and SHALL respond 404 with the site's not-found page, as defined by `not-found-page`, for any other route `Id`. The optional parameter `day` (`YYYY-MM-DD`) selects a Taipei day and defaults to the latest day stored for the route; the optional parameter `range` is `day` or `7d` and defaults to `day`; the optional parameter `buffer` is the buffer in minutes of `buffer-trade` and defaults to 15. A malformed `day`, any other `range` value or a `buffer` value that `buffer-trade` rejects SHALL respond 400.

#### Scenario: Route not configured

- **WHEN** a visitor requests `/routes/9999` and 9999 is not in the route list
- **THEN** the response is 404 and its body is the content of `public/404.html`

#### Scenario: Defaults

- **WHEN** route 9001 has stored days 2026-10-19 and 2026-10-20 and a visitor requests `/routes/9001`
- **THEN** the page shows 2026-10-20 with the range of one day and a buffer of 15 minutes

#### Scenario: Bad parameter

- **WHEN** a visitor requests `/routes/9001?range=30d`
- **THEN** the response is 400

#### Scenario: Bad buffer

- **WHEN** a visitor requests `/routes/9001?buffer=21`
- **THEN** the response is 400
