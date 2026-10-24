## ADDED Requirements

### Requirement: Stop sequence block

The page SHALL show, after the section links and before the layover distribution chart, a stop sequence block built from the stops stored for the latest covered day. The block SHALL hold a disclosure that is closed by default, whose summary gives each direction's number of stops and whose rows are all present in the server response. Inside, the block SHALL list each direction in direction order with its stop names in sequence order, marking the first as the first stop and the last as the last stop, and SHALL NOT show sequence numbers. After each direction's last stop, a row SHALL state the nature of that end as defined by `turnaround-ends` (stopping or pass-through) and SHALL name the first stop of the other direction as where the next trip starts; when the other direction has no stops, the row SHALL state only the nature. The block SHALL state the static snapshot day of the latest covered day. When the latest covered day has no stops, the block SHALL state that the covered days have no stop sequence and SHALL show no list. The block SHALL NOT mark stops as near the MRT, SHALL NOT show on-board counts and SHALL NOT mark which stops another route shares.

#### Scenario: Stops of the latest covered day

- **WHEN** the page covers two days whose stops differ
- **THEN** the block lists the stops of the later day and states that day's static snapshot day

##### Example: two weekdays given oldest first

- **GIVEN** route 9001's covered days are 2026-10-19 and 2026-10-20, given oldest first as the day coverage orders them; 2026-10-19's direction 0 stops are 甲站 and 乙站, and 2026-10-20's direction 0 stops are 甲站, 丙站 and 戊站, with the static snapshot day 2026-10-20
- **WHEN** the block is rendered
- **THEN** direction 0 lists 甲站, 丙站 and 戊站 in that order, and the block names the snapshot day 2026-10-20

#### Scenario: Turnaround row after each direction

- **WHEN** the latest covered day has stops in both directions, and the route's direction 0 is a pass-through end and direction 1 a stopping end
- **THEN** direction 0's list ends with its last stop marked as the last stop, followed by a pass-through row naming direction 1's first stop, and direction 1's list ends with its last stop, followed by a stopping row naming direction 0's first stop

##### Example: the same name at the stopping end

- **GIVEN** the latest covered day's direction 0 stops are 甲站 (sequence 0), 乙站 (1) and 戊站 (2), its direction 1 stops are 己站 (3), 丁站 (4) and 甲站 (5), and the ends are 0 `pass_through` and 1 `stop`
- **WHEN** the block is rendered
- **THEN** direction 0 reads 甲站 marked first stop, 乙站, 戊站 marked last stop, followed by a pass-through row naming 己站; and direction 1 reads 己站 marked first stop, 丁站, 甲站 marked last stop, followed by a stopping row naming 甲站

#### Scenario: No sequence numbers

- **WHEN** direction 1's stops carry the sequence numbers 3 to 5
- **THEN** each row of the list shows only its stop name, with the first stop and last stop marks, and no row shows a sequence number

#### Scenario: List closed by default

- **WHEN** a stored day with stops is rendered
- **THEN** the stop list is inside a disclosure that is closed, its summary gives each direction's number of stops, and the response contains a row for every stop of the latest covered day

#### Scenario: Only one direction stored

- **WHEN** the latest covered day has stops only in direction 0
- **THEN** the block lists direction 0 only, and its turnaround row states the nature of that end without naming a next first stop

#### Scenario: No stops stored

- **WHEN** the latest covered day has no stops
- **THEN** the block states that the covered days have no stop sequence and shows no list, and every other block renders as before

### Requirement: Route name and Id in the header

When the page covers stored days, the page heading SHALL be the route name of the latest covered day alone, without the route's Id. The line under the heading SHALL give the departure and destination of the latest covered day followed by the label 路線 Id and the route's Id, so that the Id appears once in the header.

#### Scenario: Name alone, Id beside the departure and destination

- **WHEN** route 9001's latest covered day has route name 測試幹線, departure 甲站 and destination 戊站
- **THEN** the page heading reads 測試幹線, and the line under it reads 甲站－戊站 followed by 路線 Id 9001

#### Scenario: Selected day not stored

- **WHEN** the selected day is not stored for the route
- **THEN** the page shows neither the heading with the route name nor the line with the Id, and states that the day has no data as the requirement "Day coverage" describes

## MODIFIED Requirements

### Requirement: Page content

The page SHALL show, in this order: a summary with the route name, departure and destination, the covered days, the number of trips and of complete trips, and the key numbers of the requirement "Key numbers in the summary"; the section links of the requirement "Section links"; the stop sequence block of the requirement "Stop sequence block"; the layover distribution chart, followed by the layovers per direction of the ending trip, each row naming that direction's last stop and the nature of that end as defined by `turnaround-ends` (stopping or pass-through), with the number of layovers, p10, p50, p90 and the share under 15 minutes as defined by `layover-metrics`; the round trip and cycle block of the requirement "Round trip and cycle block"; the turnaround facilities as defined by `turnaround-facilities`, one part per end in direction order, each with the direction, the last stop, the nature of the end, the location source with its check numbers, the number of toilet places within 300 and 500 metres, the nearest place with its number of toilets, the places within 500 metres inside a disclosure that is closed by default, the day of the location used and the day of the toilet snapshot that day was loaded with, each part followed by that end's map container and map data as defined by `turnaround-map` and by the line stating the share of the covered days' standstill reports that the drawn cells cover; the buffer estimate as defined by `buffer-trade` for the selected buffer, with the number of covered days, measured layovers at stopping ends, measured layovers at pass-through ends when the route has such an end, and trips, the rest achievement, the lower and upper added vehicle-hours per day, the lower and upper added vehicles with their busiest hour, and the vehicles per day; the run time summary of `run-time` per direction, with the number of excluded trips; the load chart along the route, followed by the MRT overlap as defined by `mrt-overlap`, with each direction's number of stops and overlap share at 300, 500 and 800 metres, the overlap stretches at 500 metres with their first and last sequence numbers and stop names, the on-board counts of each stretch per time band, and the day of the entrance snapshot used; and the load profile as defined by `load-profile`, per direction, time band and stop, each cell giving the median, the p90 and the number of trips with a count, inside a disclosure that is closed by default and whose rows are all present in the server response. Percentiles SHALL be computed over all trips of the covered days, not combined from daily values. The MRT overlap SHALL NOT mark any share as above or below a review threshold, and the turnaround facilities SHALL NOT judge whether the toilets are enough. When the stops of the covered days carry no nearest-entrance distance, the MRT overlap block SHALL say that the days need to be loaded again instead of showing shares; when the covered days carry no end rows, the turnaround facilities block SHALL say the same and SHALL contain no map container. The buffer estimate SHALL offer a control that sets the buffer from 0 to 20 minutes; changing it SHALL replace only the buffer estimate block and SHALL update the page address with the `buffer` parameter while keeping `day` and `range`.

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
