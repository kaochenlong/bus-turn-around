## MODIFIED Requirements

### Requirement: Page content

The page SHALL show, in this order: a summary with the route name, departure and destination, the covered days, the number of trips and of complete trips, and the key numbers of the requirement "Key numbers in the summary"; the section links of the requirement "Section links"; the layover distribution chart, followed by the layovers per direction of the ending trip, each row naming that direction's last stop and the nature of that end as defined by `turnaround-ends` (stopping or pass-through), with the number of layovers, p10, p50, p90 and the share under 15 minutes as defined by `layover-metrics`; the round trip and cycle block of the requirement "Round trip and cycle block"; the turnaround facilities as defined by `turnaround-facilities`, one part per end in direction order, each with the direction, the last stop, the nature of the end, the location source with its check numbers, the number of toilet places within 300 and 500 metres, the nearest place with its number of toilets, the places within 500 metres inside a disclosure that is closed by default, the day of the location used and the day of the toilet snapshot that day was loaded with; the buffer estimate as defined by `buffer-trade` for the selected buffer, with the number of covered days, measured layovers at stopping ends, measured layovers at pass-through ends when the route has such an end, and trips, the rest achievement, the lower and upper added vehicle-hours per day, the lower and upper added vehicles with their busiest hour, and the vehicles per day; the run time summary of `run-time` per direction, with the number of excluded trips; the load chart along the route, followed by the MRT overlap as defined by `mrt-overlap`, with each direction's number of stops and overlap share at 300, 500 and 800 metres, the overlap stretches at 500 metres with their first and last sequence numbers and stop names, the on-board counts of each stretch per time band, and the day of the entrance snapshot used; and the load profile as defined by `load-profile`, per direction, time band and stop, each cell giving the median, the p90 and the number of trips with a count, inside a disclosure that is closed by default and whose rows are all present in the server response. Percentiles SHALL be computed over all trips of the covered days, not combined from daily values. The MRT overlap SHALL NOT mark any share as above or below a review threshold, and the turnaround facilities SHALL NOT judge whether the toilets are enough. When the stops of the covered days carry no nearest-entrance distance, the MRT overlap block SHALL say that the days need to be loaded again instead of showing shares; when the covered days carry no end rows, the turnaround facilities block SHALL say the same. The buffer estimate SHALL offer a control that sets the buffer from 0 to 20 minutes; changing it SHALL replace only the buffer estimate block and SHALL update the page address with the `buffer` parameter while keeping `day` and `range`.

#### Scenario: Seven-day percentile pools trips

- **WHEN** day one has layovers of 10 and 20 minutes in direction 0 and day two has one of 30 minutes, and the page covers both days
- **THEN** the direction 0 layover row reports 3 layovers and a p50 of 20.0

#### Scenario: Overlap block in place

- **WHEN** a stored day whose stops carry nearest-entrance distances is rendered
- **THEN** the blocks appear in the order summary, layover chart, layovers, round trips and cycles, turnaround facilities, buffer estimate, run times, load chart, MRT overlap, load profile, limitations, and the MRT overlap block names the entrance snapshot day

#### Scenario: Distances missing

- **WHEN** a stored day was loaded before stops carried nearest-entrance distances
- **THEN** the MRT overlap block asks for the day to be loaded again and shows no share

#### Scenario: Facilities block in place

- **WHEN** a stored day whose ends carry a location is rendered for a route whose direction 0 is a pass-through end and direction 1 a stopping end
- **THEN** the turnaround facilities block shows direction 0 with source `end_stop` and direction 1 with source `standstill` and its three check numbers, each with its place counts, nearest place with its number of toilets, closed place list, location day and the toilet snapshot day of that location day

#### Scenario: End rows missing

- **WHEN** every covered day was stored without end rows
- **THEN** the turnaround facilities block asks for the days to be loaded again and shows no location, and every other block renders as before

#### Scenario: Buffer from the address

- **WHEN** a visitor requests `/routes/9001?day=2026-10-19&range=7d&buffer=10`
- **THEN** the buffer estimate uses 10 minutes, and its control carries the buffer 10 with the day 2026-10-19 and the range 7d, targeting only the buffer estimate block

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

### Requirement: Section links

After the summary, the page SHALL show one link to each of the layover, round trip and cycle, turnaround facilities, buffer estimate, run time, load chart, MRT overlap and limitations blocks, in page order, each pointing by its fragment to an element of the page that contains that block. The links SHALL work without JavaScript and SHALL NOT carry a `data-section` attribute. When the selected day has no data, the page SHALL NOT show the section links.

#### Scenario: Links in page order

- **WHEN** a stored day is rendered
- **THEN** there are eight section links in the order layovers, round trips and cycles, turnaround facilities, buffer estimate, run times, load chart, MRT overlap, limitations, and each link's fragment names an element that contains the block of that name

#### Scenario: No links without data

- **WHEN** a visitor requests a day of route 9001 that is not stored
- **THEN** the response is 200 and shows no section links

### Requirement: Data limitations on the page

The page SHALL state the data limitations that apply to its numbers: a vehicle is not a driver and a layover is an upper bound on rest; on-board counts come from fare-card taps and do not return to zero between trips; 10-second polling misses stops and trips missing a terminal are left out of run times; weekdays and holidays follow the office calendar of 行政院人事行政總處, and days off for typhoons are not in that calendar and count as the calendar says; a stop near an MRT entrance does not mean the bus segment can be replaced by the MRT, distances are straight-line, and the entrance data is updated irregularly; the buffer estimate counts vehicle-hours, not driver hours, uses only measured layovers at stopping ends, and its added vehicles are an hourly average, not a schedule; which end buses stop at is a fact verified route by route and written into the configuration, not computed from the data, and it goes stale when the operator changes how the route turns around; layovers at a pass-through end are not rest opportunities and the buffer estimate does not count them; round trips and cycles use only trips whose terminals were observed and that pair up as stored layovers, so their counts are lower than the trip counts, a vehicle's first loop of a day has no cycle, and a cycle is the rhythm of a vehicle, not the roster of one driver; the turnaround point location of a stopping end is where the vehicles stood still during that day's measured layovers, as reported by GPS every 10 seconds, which can be missing for a day, and it is where the vehicle stood, not where the driver went; a pass-through end is anchored on its last stop because buses do not stop there; the toilet data is the national registry of 環境部, updated monthly, with one row per toilet that the page groups into places by address, the toilet distances are straight-line, and the data has no opening hours and says nothing about whether a driver is allowed to use a toilet.

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
