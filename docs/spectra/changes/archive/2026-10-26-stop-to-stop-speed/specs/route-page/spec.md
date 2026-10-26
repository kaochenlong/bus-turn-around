## MODIFIED Requirements

### Requirement: Page content

The page SHALL show, in this order: a summary with the route name, departure and destination, the covered days, the number of trips and of complete trips, and the key numbers of the requirement "Key numbers in the summary"; the section links of the requirement "Section links"; the stop sequence block of the requirement "Stop sequence block"; the layover distribution chart, followed by the layovers per direction of the ending trip, each row naming that direction's last stop and the nature of that end as defined by `turnaround-ends` (stopping or pass-through), with the number of layovers, p10, p50, p90 and the share under 15 minutes as defined by `layover-metrics`; the round trip and cycle block of the requirement "Round trip and cycle block"; the turnaround facilities as defined by `turnaround-facilities`, one part per end in direction order, each with the direction, the last stop, the nature of the end, the location source with its check numbers, the number of toilet places within 300 and 500 metres, the nearest place with its number of toilets, the places within 500 metres inside a disclosure that is closed by default, the day of the location used and the day of the toilet snapshot that day was loaded with, each part followed by that end's map container and map data as defined by `turnaround-map` and by the line stating the share of the covered days' standstill reports that the drawn cells cover; the buffer estimate as defined by `buffer-trade` for the selected buffer, lateness, hours and end, with the number of covered days, trips and measured layovers at stopping ends over all hours, the number of layovers in the base when hours or an end are selected, measured layovers at pass-through ends when the route has such an end, the minutes to hold with the buffer and the lateness it adds up from, the rest achievement now and, with a lateness above zero, the rest achievement with the same vehicles, the lower and upper added vehicle-hours per day, the cost of one more minute, the lower and upper added vehicles with their busiest hour, the curve of the requirement "Buffer estimate curve", the added vehicles of every hour inside a disclosure that is closed by default, and the vehicles per day; the run time summary of `run-time` per direction, with the number of excluded trips, followed in the same card by the stop speed block of `stop-to-stop-speed`; the load chart along the route, followed by the MRT overlap as defined by `mrt-overlap`, with each direction's number of stops and overlap share at 300, 500 and 800 metres, the overlap stretches at 500 metres with their first and last sequence numbers and stop names, the on-board counts of each stretch per time band, and the day of the entrance snapshot used; and the load profile as defined by `load-profile`, per direction, time band and stop, each cell giving the median, the p90 and the number of trips with a count, inside a disclosure that is closed by default and whose rows are all present in the server response. Percentiles SHALL be computed over all trips of the covered days, not combined from daily values. The MRT overlap SHALL NOT mark any share as above or below a review threshold, and the turnaround facilities SHALL NOT judge whether the toilets are enough. When the stops of the covered days carry no nearest-entrance distance, the MRT overlap block SHALL say that the days need to be loaded again instead of showing shares; when the covered days carry no end rows, the turnaround facilities block SHALL say the same and SHALL contain no map container. When the base of the buffer estimate is empty, the block SHALL say that no layover could be measured, naming the selected hours and end when either is selected, SHALL show none of its figures and no curve, and SHALL keep its controls. The buffer estimate SHALL offer the controls of the requirement "Buffer estimate controls".

#### Scenario: Seven-day percentile pools trips

- **WHEN** day one has layovers of 10 and 20 minutes in direction 0 and day two has one of 30 minutes, and the page covers both days
- **THEN** the direction 0 layover row reports 3 layovers and a p50 of 20.0

#### Scenario: Overlap block in place

- **WHEN** a stored day whose stops carry nearest-entrance distances is rendered
- **THEN** the blocks appear in the order summary, stop sequence, layover chart, layovers, round trips and cycles, turnaround facilities, buffer estimate, run times, stop speeds, load chart, MRT overlap, load profile, limitations, and the MRT overlap block names the entrance snapshot day

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

The page SHALL state the data limitations that apply to its numbers: a vehicle is not a driver and a layover is an upper bound on rest; on-board counts come from fare-card taps and do not return to zero between trips; 10-second polling misses stops and trips missing a terminal are left out of run times; weekdays and holidays follow the office calendar of 行政院人事行政總處, and days off for typhoons are not in that calendar and count as the calendar says; a stop near an MRT entrance does not mean the bus segment can be replaced by the MRT, distances are straight-line, and the entrance data is updated irregularly; the buffer estimate counts vehicle-hours, not driver hours, uses only measured layovers at stopping ends, and its added vehicles are an hourly average, not a schedule; the lateness of the buffer estimate is an assumption that every arrival at a stopping end is that many minutes later than measured, the lateness of the measured days is already in the measured layovers, and lateness longer than a layover would delay the next departure, which the estimate does not follow; the selected hours of the buffer estimate are the hours buses arrive at the stopping end; which end buses stop at is a fact verified route by route and written into the configuration, not computed from the data, and it goes stale when the operator changes how the route turns around; layovers at a pass-through end are not rest opportunities and the buffer estimate does not count them; round trips and cycles use only trips whose terminals were observed and that pair up as stored layovers, so their counts are lower than the trip counts, a vehicle's first loop of a day has no cycle, and a cycle is the rhythm of a vehicle, not the roster of one driver; the turnaround point location of a stopping end is where the vehicles stood still during that day's measured layovers, as reported by GPS every 10 seconds, which can be missing for a day, and it is where the vehicle stood, not where the driver went; a pass-through end is anchored on its last stop because buses do not stop there; the toilet data is the national registry of 環境部, updated monthly, with one row per toilet that the page groups into places by address, the toilet distances are straight-line, and the data has no opening hours and says nothing about whether a driver is allowed to use a toilet; the squares on the maps are cells of about 20 metres that at least three vehicles stood in on a day, their shade sums GPS reports taken every 10 seconds and is not minutes stood and not rest, cells with fewer vehicles are left out, and the basemap is third-party data shown as it is; the route map draws the route shape registered by 臺北市公共運輸處, not measured GPS, so temporary detours and diversions do not appear on it, and the registered shape can be older than the stop list; the stop speeds come from consecutive GPS reports of a vehicle placed on that registered route shape, the 40 metres around each stop are left out so braking, stopping and boarding are not in them, two stops 80 metres apart or closer have no speed, trips whose start is only an arrival are left out, and the shades compare the legs of one direction only.

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


### Requirement: Data limitation of a page with member routes

When the page route lists member routes, the data limitations block SHALL add one item stating which route `Id`s the page counts as one route; that trips, run times, layovers, round trips, cycles and the rest estimate pool their vehicles; that the stop speeds count only the page route's trips; that the load chart, the MRT overlap and the stop sequence use the page route's stops, with the member routes' on-board counts pooled at the stops both serve and the stops only a member serves left out; and the number of trips of each route `Id` over the covered days. A page without member routes SHALL NOT show this item.

#### Scenario: Trip counts per Id

- **WHEN** the page of route 9001 with member route 9050 covers 2026-10-23, whose stored trips are one of 9001 and two of 9050
- **THEN** the data limitations block has an item that names 9001 and 9050 and contains 9001 1 趟、9050 2 趟

#### Scenario: Absent without member routes

- **WHEN** the page of route 10712 is shown
- **THEN** the data limitations block has no item about counting route `Id`s as one route


#### Scenario: Stop speeds of the page route only

- **WHEN** the page of route 9001 with member route 9050 covers 2026-10-23
- **THEN** the item about counting route `Id`s as one route says that the stop speeds count only the trips of 9001
