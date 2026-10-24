## ADDED Requirements

### Requirement: Buffer estimate controls

The buffer estimate SHALL offer, in one form that requests the route page with the `get` method and carries the current `day` and `range`: a control for the buffer from 0 to 20 minutes, a control for the lateness from 0 to 20 minutes, a choice of the first hour from 0 to 23 that offers only hours below the selected last hour and a choice of the last hour from 1 to 24 that offers only hours above the selected first hour, and, only when both ends of the route are stopping ends, a choice of the end among every stopping end and each stopping end named as `buffer-trade` names it. The block SHALL carry an identifier that differs on every response that renders it. With JavaScript, moving the buffer or the lateness control SHALL replace every figure, the curve marker and the hourly values of the block with those of the curve point at the new minutes to hold, taken from the curve data in the response, without sending a request; it SHALL replace the page address with one whose `buffer` and `late` are the new values and whose other parameters are kept, without adding a history entry; and leaving the page and coming back through the history SHALL show the moved values. Changing the hours or the end SHALL send the form, replace only the buffer estimate block and update the page address with every parameter of the form. Without JavaScript, the form SHALL have a submit button that is not marked hidden, and the response SHALL show the figures of the requested values; a pair of hours that `buffer-trade` rejects SHALL respond 400 like any other rejected parameter.

#### Scenario: Moving the buffer control

- **WHEN** a visitor opens `/routes/9001?day=2026-10-19&range=7d` with JavaScript and moves the buffer control from 15 to 10
- **THEN** every figure of the block equals the curve point at 10 minutes to hold, the block's identifier is unchanged, the page address carries `buffer=10` with `day=2026-10-19` and `range=7d`, and the history has as many entries as before

#### Scenario: Changing the hours

- **WHEN** a visitor with JavaScript sets the first hour to 9
- **THEN** the block's identifier changes, and the page address carries `from=9`, `to=24` and the current `buffer`, `late`, `day` and `range`

#### Scenario: Back to a moved estimate

- **WHEN** a visitor with JavaScript moves the lateness control to 6, follows a link to another page and goes back through the history
- **THEN** the lateness control shows 6 and the figures are those of the curve point at the buffer plus 6

#### Scenario: Controls without JavaScript

- **WHEN** the page of a stored day with layovers is fetched without running any script
- **THEN** the buffer estimate contains a form with the fields `buffer`, `late`, `from`, `to`, `day` and `range` and a submit button that is not marked hidden

#### Scenario: Hour choices stay valid

- **WHEN** the buffer estimate is rendered with the first hour 9 and the last hour 12
- **THEN** the first-hour choices are 0 to 11 and the last-hour choices are 10 to 24

#### Scenario: End choice only with two stopping ends

- **WHEN** the buffer estimate is rendered for a route whose both ends are stopping ends and for a route whose direction 0 is a pass-through end
- **THEN** the first offers the end choice with every stopping end and the two named ends, and the second offers no end choice

### Requirement: Buffer estimate curve

When the base of the buffer estimate holds a layover, the block SHALL show the curve of `buffer-trade` as an inline SVG drawn by the server, without a chart library, tooltip, zoom or animation: the minutes to hold from 0 to 40 along the horizontal axis, the added vehicle-hours per day along the vertical axis from 0 to the upper bound at 40 minutes, a line for the lower bound and a line for the upper bound through the 41 points, the area between them, and a marker at the selected minutes to hold on both lines. The response SHALL carry the curve data: for every point, the figures the block shows, formatted as the block shows them, and the coordinates of the marker. The SVG SHALL have the role `img` and a label stating the range of both bounds.

#### Scenario: Curve from the response

- **WHEN** the page of a stored day with layovers is requested with `buffer=15&late=6`
- **THEN** the curve has a lower line and an upper line of 41 points each, the marker stands at 21 minutes with the coordinates of the curve data's point at 21, and the figures shown equal that point's

#### Scenario: No curve without a base

- **WHEN** the base of the buffer estimate is empty
- **THEN** the block contains neither the curve nor the curve data

##### Example: hours without layovers

- **GIVEN** route 9001 has the stored day 2026-10-19 whose layovers at stopping ends all end before 12:00
- **WHEN** a visitor requests `/routes/9001?day=2026-10-19&from=12&to=13`
- **THEN** the buffer estimate contains no curve SVG and no curve data, and still contains its form

## MODIFIED Requirements

### Requirement: Route page address and parameters

The system SHALL serve `GET /routes/:route_id` for route `Id`s listed in the route list configuration, and SHALL respond 404 with the site's not-found page, as defined by `not-found-page`, for any other route `Id`. The optional parameter `day` (`YYYY-MM-DD`) selects a Taipei day and defaults to the latest day stored for the route; the optional parameter `range` is `day` or `7d` and defaults to `day`; the optional parameter `buffer` is the buffer in minutes of `buffer-trade`, shown as the rest, and defaults to 15; the optional parameter `late` is the lateness of `buffer-trade` and defaults to 0; the optional parameters `from` and `to` are the first and last selected hours of `buffer-trade` and default to 0 and 24; the optional parameter `end` is the selected end of `buffer-trade` and defaults to every stopping end. A malformed `day`, any other `range` value, or a `buffer`, `late`, `from`, `to` or `end` value that `buffer-trade` rejects SHALL respond 400.

#### Scenario: Route not configured

- **WHEN** a visitor requests `/routes/9999` and 9999 is not in the route list
- **THEN** the response is 404 and its body is the content of `public/404.html`

#### Scenario: Defaults

- **WHEN** route 9001 has stored days 2026-10-19 and 2026-10-20 and a visitor requests `/routes/9001`
- **THEN** the page shows 2026-10-20 with the range of one day, a buffer of 15 minutes and a lateness of 0 minutes over the whole day at every stopping end

#### Scenario: Bad parameter

- **WHEN** a visitor requests `/routes/9001?range=30d`
- **THEN** the response is 400

#### Scenario: Bad buffer

- **WHEN** a visitor requests `/routes/9001?buffer=21`
- **THEN** the response is 400

#### Scenario: Bad lateness, hours or end

- **WHEN** a visitor requests the page of route 9001 with one of the values below
- **THEN** the response is 400

##### Example: rejected estimate parameters

| Request | Why |
| --- | --- |
| `/routes/9001?late=21` | the lateness is above 20 |
| `/routes/9001?from=10&to=9` | the first hour is not below the last |
| `/routes/9001?end=2` | not a direction |

### Requirement: Page content

The page SHALL show, in this order: a summary with the route name, departure and destination, the covered days, the number of trips and of complete trips, and the key numbers of the requirement "Key numbers in the summary"; the section links of the requirement "Section links"; the stop sequence block of the requirement "Stop sequence block"; the layover distribution chart, followed by the layovers per direction of the ending trip, each row naming that direction's last stop and the nature of that end as defined by `turnaround-ends` (stopping or pass-through), with the number of layovers, p10, p50, p90 and the share under 15 minutes as defined by `layover-metrics`; the round trip and cycle block of the requirement "Round trip and cycle block"; the turnaround facilities as defined by `turnaround-facilities`, one part per end in direction order, each with the direction, the last stop, the nature of the end, the location source with its check numbers, the number of toilet places within 300 and 500 metres, the nearest place with its number of toilets, the places within 500 metres inside a disclosure that is closed by default, the day of the location used and the day of the toilet snapshot that day was loaded with, each part followed by that end's map container and map data as defined by `turnaround-map` and by the line stating the share of the covered days' standstill reports that the drawn cells cover; the buffer estimate as defined by `buffer-trade` for the selected buffer, lateness, hours and end, with the number of covered days, trips and measured layovers at stopping ends over all hours, the number of layovers in the base when hours or an end are selected, measured layovers at pass-through ends when the route has such an end, the minutes to hold with the buffer and the lateness it adds up from, the rest achievement now and, with a lateness above zero, the rest achievement with the same vehicles, the lower and upper added vehicle-hours per day, the cost of one more minute, the lower and upper added vehicles with their busiest hour, the curve of the requirement "Buffer estimate curve", the added vehicles of every hour inside a disclosure that is closed by default, and the vehicles per day; the run time summary of `run-time` per direction, with the number of excluded trips; the load chart along the route, followed by the MRT overlap as defined by `mrt-overlap`, with each direction's number of stops and overlap share at 300, 500 and 800 metres, the overlap stretches at 500 metres with their first and last sequence numbers and stop names, the on-board counts of each stretch per time band, and the day of the entrance snapshot used; and the load profile as defined by `load-profile`, per direction, time band and stop, each cell giving the median, the p90 and the number of trips with a count, inside a disclosure that is closed by default and whose rows are all present in the server response. Percentiles SHALL be computed over all trips of the covered days, not combined from daily values. The MRT overlap SHALL NOT mark any share as above or below a review threshold, and the turnaround facilities SHALL NOT judge whether the toilets are enough. When the stops of the covered days carry no nearest-entrance distance, the MRT overlap block SHALL say that the days need to be loaded again instead of showing shares; when the covered days carry no end rows, the turnaround facilities block SHALL say the same and SHALL contain no map container. When the base of the buffer estimate is empty, the block SHALL say that no layover could be measured, naming the selected hours and end when either is selected, SHALL show none of its figures and no curve, and SHALL keep its controls. The buffer estimate SHALL offer the controls of the requirement "Buffer estimate controls".

#### Scenario: Seven-day percentile pools trips

- **WHEN** day one has layovers of 10 and 20 minutes in direction 0 and day two has one of 30 minutes, and the page covers both days
- **THEN** the direction 0 layover row reports 3 layovers and a p50 of 20.0

#### Scenario: Overlap block in place

- **WHEN** a stored day whose stops carry nearest-entrance distances is rendered
- **THEN** the blocks appear in the order summary, stop sequence, layover chart, layovers, round trips and cycles, turnaround facilities, buffer estimate, run times, load chart, MRT overlap, load profile, limitations, and the MRT overlap block names the entrance snapshot day

#### Scenario: Distances missing

- **WHEN** a stored day was loaded before stops carried nearest-entrance distances
- **THEN** the MRT overlap block asks for the day to be loaded again and shows no share

#### Scenario: Facilities block in place

- **WHEN** a stored day whose ends carry a location is rendered for a route whose direction 0 is a pass-through end and direction 1 a stopping end
- **THEN** the turnaround facilities block shows direction 0 with source `end_stop` and direction 1 with source `standstill` and its three check numbers, each with its place counts, nearest place with its number of toilets, closed place list, location day and the toilet snapshot day of that location day, and each end's part is followed by a map container holding that end's map data and by its coverage line

#### Scenario: Map container without JavaScript

- **WHEN** the page of a stored day with end rows is fetched without running any script
- **THEN** each end's map container is in the state `pending` with its map data and its sentence, and every number of the facilities block is in the response

#### Scenario: End rows missing

- **WHEN** every covered day was stored without end rows
- **THEN** the turnaround facilities block asks for the days to be loaded again, shows no location and contains no map container, and every other block renders as before

#### Scenario: Buffer from the address

- **WHEN** a visitor requests `/routes/9001?day=2026-10-19&range=7d&buffer=10&late=5`
- **THEN** the buffer estimate holds 15 minutes, made of a buffer of 10 and a lateness of 5, and its controls carry the buffer 10 and the lateness 5 with the day 2026-10-19 and the range 7d, targeting only the buffer estimate block

#### Scenario: End nature on the layover rows

- **WHEN** the layovers of a route whose direction 0 is a pass-through end and direction 1 a stopping end are rendered
- **THEN** direction 0's row is labelled pass-through, direction 1's row is labelled stopping, and both rows keep the counts and percentiles of `layover-metrics`

#### Scenario: Both ends stopping

- **WHEN** route 9001 is configured with both ends as stopping ends and its page is rendered
- **THEN** both layover rows are labelled stopping and the buffer estimate reports no pass-through layovers

#### Scenario: Pass-through layovers in the estimate block

- **WHEN** the buffer estimate of a route whose direction 0 is a pass-through end is rendered with 3 layovers ending in direction 0 and 2 ending in direction 1
- **THEN** the block reports 2 measured layovers at stopping ends and 3 layovers at the pass-through end as not counted

#### Scenario: Load profile closed by default

- **WHEN** a stored day with load profile rows is rendered
- **THEN** the load profile table is inside a disclosure that is closed, and the response contains a row for every stop that has a count

#### Scenario: No layover in the selected hours on the page

- **WHEN** a visitor requests `/routes/9001?day=2026-10-19&from=12&to=13` and no layover at a stopping end ends between 12:00 and 13:00 on that day
- **THEN** the buffer estimate says that no layover could be measured from 12 to 13, shows no figure and no curve, and still shows its controls

### Requirement: Data limitations on the page

The page SHALL state the data limitations that apply to its numbers: a vehicle is not a driver and a layover is an upper bound on rest; on-board counts come from fare-card taps and do not return to zero between trips; 10-second polling misses stops and trips missing a terminal are left out of run times; weekdays and holidays follow the office calendar of 行政院人事行政總處, and days off for typhoons are not in that calendar and count as the calendar says; a stop near an MRT entrance does not mean the bus segment can be replaced by the MRT, distances are straight-line, and the entrance data is updated irregularly; the buffer estimate counts vehicle-hours, not driver hours, uses only measured layovers at stopping ends, and its added vehicles are an hourly average, not a schedule; the lateness of the buffer estimate is an assumption that every arrival at a stopping end is that many minutes later than measured, the lateness of the measured days is already in the measured layovers, and lateness longer than a layover would delay the next departure, which the estimate does not follow; the selected hours of the buffer estimate are the hours buses arrive at the stopping end; which end buses stop at is a fact verified route by route and written into the configuration, not computed from the data, and it goes stale when the operator changes how the route turns around; layovers at a pass-through end are not rest opportunities and the buffer estimate does not count them; round trips and cycles use only trips whose terminals were observed and that pair up as stored layovers, so their counts are lower than the trip counts, a vehicle's first loop of a day has no cycle, and a cycle is the rhythm of a vehicle, not the roster of one driver; the turnaround point location of a stopping end is where the vehicles stood still during that day's measured layovers, as reported by GPS every 10 seconds, which can be missing for a day, and it is where the vehicle stood, not where the driver went; a pass-through end is anchored on its last stop because buses do not stop there; the toilet data is the national registry of 環境部, updated monthly, with one row per toilet that the page groups into places by address, the toilet distances are straight-line, and the data has no opening hours and says nothing about whether a driver is allowed to use a toilet; the squares on the maps are cells of about 20 metres that at least three vehicles stood in on a day, their shade sums GPS reports taken every 10 seconds and is not minutes stood and not rest, cells with fewer vehicles are left out, and the basemap is third-party data shown as it is; the route map draws the route shape registered by 臺北市公共運輸處, not measured GPS, so temporary detours and diversions do not appear on it, and the registered shape can be older than the stop list.

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
