## ADDED Requirements

### Requirement: Link to the timetable

The buffer estimate block SHALL contain one link to the route's timetable page as defined by `timetable`, whose address carries the page's current `day`, `range` and `buffer` and SHALL NOT carry `late`, `from`, `to` or `end`. The link SHALL load the whole timetable page, not the block's frame. When the selected day has no data, the buffer estimate block is not shown and so carries no such link.

#### Scenario: Link carries the current parameters

- **WHEN** a visitor opens `/routes/9001?day=2026-10-19&range=7d&buffer=10&late=6&from=9&to=12`
- **THEN** the buffer estimate block contains a link to `/routes/9001/timetable` whose query is exactly `day=2026-10-19`, `range=7d` and `buffer=10`

#### Scenario: No link without data

- **WHEN** a visitor requests a day of route 9001 that is not stored
- **THEN** the response is 200 and the page's own content contains no link to `/routes/9001/timetable`

#### Scenario: Link leaves the frame

- **WHEN** a visitor activates the link in a browser
- **THEN** the whole page changes to the timetable page with the same `day`, `range` and `buffer`
