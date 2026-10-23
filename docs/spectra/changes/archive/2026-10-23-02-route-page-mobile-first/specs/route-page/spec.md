## MODIFIED Requirements

### Requirement: Page content

The page SHALL show, in this order: a summary with the route name, departure and destination, the covered days, the number of trips and of complete trips, and the key numbers of the requirement "Key numbers in the summary"; the section links of the requirement "Section links"; the layover distribution chart, followed by the layovers per direction of the ending trip, each row naming that direction's last stop and the nature of that end as defined by `turnaround-ends` (stopping or pass-through), with the number of layovers, p10, p50, p90 and the share under 15 minutes as defined by `layover-metrics`; the buffer estimate as defined by `buffer-trade` for the selected buffer, with the number of covered days, measured layovers at stopping ends, measured layovers at pass-through ends when the route has such an end, and trips, the rest achievement, the lower and upper added vehicle-hours per day, the lower and upper added vehicles with their busiest hour, and the vehicles per day; the run time summary of `run-time` per direction, with the number of excluded trips; the load chart along the route, followed by the MRT overlap as defined by `mrt-overlap`, with each direction's number of stops and overlap share at 300, 500 and 800 metres, the overlap stretches at 500 metres with their first and last sequence numbers and stop names, the on-board counts of each stretch per time band, and the day of the entrance snapshot used; and the load profile as defined by `load-profile`, per direction, time band and stop, each cell giving the median, the p90 and the number of trips with a count, inside a disclosure that is closed by default and whose rows are all present in the server response. Percentiles SHALL be computed over all trips of the covered days, not combined from daily values. The MRT overlap SHALL NOT mark any share as above or below a review threshold. When the stops of the covered days carry no nearest-entrance distance, the MRT overlap block SHALL say that the days need to be loaded again instead of showing shares. The buffer estimate SHALL offer a control that sets the buffer from 0 to 20 minutes; changing it SHALL replace only the buffer estimate block and SHALL update the page address with the `buffer` parameter while keeping `day` and `range`.

#### Scenario: Seven-day percentile pools trips

- **WHEN** day one has layovers of 10 and 20 minutes in direction 0 and day two has one of 30 minutes, and the page covers both days
- **THEN** the direction 0 layover row reports 3 layovers and a p50 of 20.0

#### Scenario: Overlap block in place

- **WHEN** a stored day whose stops carry nearest-entrance distances is rendered
- **THEN** the blocks appear in the order summary, layover chart, layovers, buffer estimate, run times, load chart, MRT overlap, load profile, limitations, and the MRT overlap block names the entrance snapshot day

#### Scenario: Distances missing

- **WHEN** a stored day was loaded before stops carried nearest-entrance distances
- **THEN** the MRT overlap block asks for the day to be loaded again and shows no share

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

### Requirement: Load chart along the route

The page SHALL show, per direction, a line chart of the load profile as defined by `load-profile` over the covered days: the horizontal axis SHALL be the stop sequence of the latest covered day, and the vertical axis the median on-board count at each stop. The chart SHALL offer the time bands morning peak, daytime, evening peak and other, one shown at a time, morning peak shown first; switching bands SHALL NOT reload the page. All bands of one direction SHALL share one vertical scale whose top is at least the largest median of that direction in any band. A stop without a count in the shown band SHALL break the line instead of being filled. The overlap stretches at 500 metres as defined by `mrt-overlap` SHALL be drawn as shaded spans over their first to last sequence numbers, without any review threshold; when the stops carry no nearest-entrance distance, no span SHALL be drawn. The chart SHALL name the first and last stop of the direction and the first and last stop of each shaded span.

Below 640 px wide, the page SHALL show the same medians as one row per stop of the latest covered day instead of the line chart, in stop order, each row giving the stop name, a bar whose length is proportional to the median on the direction's shared scale, and the median, with the same time bands and band switch as the chart. A stop without a count in the shown band SHALL show a dash and no bar. The rows of each overlap stretch at 500 metres SHALL be shaded, and the stretch SHALL be named with its first and last stop before its first row; when the stops carry no nearest-entrance distance, no row SHALL be shaded.

#### Scenario: Points per band

- **WHEN** direction 0 has medians 3.0 at sequence 0 and 8.0 at sequence 1 in the morning peak, and 5.0 at sequence 0 in the daytime
- **THEN** the morning peak line has points at sequence 0 with 3.0 and sequence 1 with 8.0, and the daytime line has one point at sequence 0 with 5.0 and a break at sequence 1

#### Scenario: Shared scale

- **WHEN** direction 0's largest median is 8.0 in the morning peak and 5.0 in the daytime
- **THEN** both bands of direction 0 use the same vertical scale, whose top is at least 8.0

#### Scenario: Shaded overlap stretch

- **WHEN** direction 0 has an overlap stretch at 500 metres from sequence 2 to sequence 4
- **THEN** direction 0's chart has one shaded span from sequence 2 to sequence 4, named with the stops at those sequences

#### Scenario: Distances missing on the chart

- **WHEN** the stops of the covered days carry no nearest-entrance distance
- **THEN** the load charts show their lines and no shaded span

#### Scenario: Rows on a narrow screen

- **WHEN** direction 0 has a morning peak median of 3.0 at sequence 0 and no count at sequence 1
- **THEN** direction 0's per-stop rows for the morning peak give 3.0 with a bar at sequence 0, and a dash without a bar at sequence 1

#### Scenario: Shaded rows

- **WHEN** direction 0 has an overlap stretch at 500 metres from sequence 2 to sequence 4
- **THEN** direction 0's per-stop rows at sequences 2 to 4 are shaded, and the stretch is named with the stops at sequences 2 and 4 before the row of sequence 2

## ADDED Requirements

### Requirement: Key numbers in the summary

The summary SHALL show, after the trip counts, three key numbers, each with the same text as a value that a table of the page shows: the p50 of every stopping end as defined by `turnaround-ends` and the share under 15 minutes of every stopping end, both taken from that end's layover row and each labelled with that end's last stop; and the overlap share at 500 metres of each direction, taken from the MRT overlap. When the route has no stopping end, the summary SHALL state that no end is a stopping end instead of the two layover numbers. When a layover row shows a dash, the key number SHALL show a dash. When the MRT overlap asks for the days to be loaded again, the overlap number SHALL be a dash. The layover numbers SHALL link to the layover block and the overlap number SHALL link to the MRT overlap block. No key number SHALL be marked as meeting or missing a threshold, and the summary SHALL NOT show any value that no table of the page shows.

#### Scenario: One stopping end

- **WHEN** route 9001 is configured with direction 0 as a pass-through end and direction 1 as a stopping end, and the covered layovers ending in direction 1 are 10, 20 and 30 minutes
- **THEN** the summary gives direction 1's last stop with a p50 of 20.0 and a share under 15 minutes of 33.3%, the same text as direction 1's layover row, and gives no layover number for direction 0

#### Scenario: Both ends stopping

- **WHEN** route 9001 is configured with both ends as stopping ends and both directions have layovers
- **THEN** each of the two layover key numbers has one line per end, each line labelled with that end's last stop and holding the text of that end's layover row

#### Scenario: No stopping end

- **WHEN** both ends of the route are pass-through ends
- **THEN** the summary states that no end is a stopping end and gives no layover number

#### Scenario: Stopping end without layovers

- **WHEN** direction 1 is a stopping end and no covered layover ends in direction 1
- **THEN** both layover key numbers show a dash for direction 1's last stop, as direction 1's layover row does

#### Scenario: Distances missing in the summary

- **WHEN** the stops of the covered days carry no nearest-entrance distance
- **THEN** the overlap key number is a dash

#### Scenario: Key numbers link to their blocks

- **WHEN** a stored day is rendered
- **THEN** the layover key numbers link to the layover block and the overlap key number links to the MRT overlap block

### Requirement: Section links

After the summary, the page SHALL show one link to each of the layover, buffer estimate, run time, load chart, MRT overlap and limitations blocks, in page order, each pointing by its fragment to an element of the page that contains that block. The links SHALL work without JavaScript and SHALL NOT carry a `data-section` attribute. When the selected day has no data, the page SHALL NOT show the section links.

#### Scenario: Links in page order

- **WHEN** a stored day is rendered
- **THEN** there are six section links in the order layovers, buffer estimate, run times, load chart, MRT overlap, limitations, and each link's fragment names an element that contains the block of that name

#### Scenario: No links without data

- **WHEN** a visitor requests a day of route 9001 that is not stored
- **THEN** the response is 200 and shows no section links

### Requirement: Run time bars

At 640 px wide or wider, each run time row SHALL show a bar from its p50 to its p95 with a mark at its p85, on one scale shared by both directions of the block: from the smallest p50 of the block rounded down to a multiple of 10 minutes to the largest p95 of the block rounded up to a multiple of 10 minutes, and at least 10 minutes long. A small-sample row SHALL keep its bar. A direction without rows SHALL NOT affect the scale; when neither direction has a row, the block SHALL show no scale, no bars and no bar legend. Below 640 px wide, the rows SHALL show their numbers without the bars.

#### Scenario: Shared scale for both directions

- **WHEN** direction 0 has one row with p50 55.0, p85 64.0 and p95 68.0, and direction 1 one row with p50 40.0, p85 45.0 and p95 52.0
- **THEN** the scale runs from 40 to 70 minutes, direction 0's bar runs from 55.0 to 68.0 with its mark at 64.0, and direction 1's bar runs from 40.0 to 52.0 with its mark at 45.0

##### Example: scale ends

| Smallest p50 | Largest p95 | Scale | Notes |
| ------------ | ----------- | ----- | ----- |
| 54.7 | 102.3 | 50 to 110 | rounded outwards |
| 40.0 | 70.0 | 40 to 70 | multiples kept |
| 60.0 | 60.0 | 60 to 70 | at least 10 minutes long |

#### Scenario: No rows, no scale

- **WHEN** neither direction of the covered days has a trip with a run time
- **THEN** the run time block states for each direction that there is no trip to compute, and shows no scale, no bar and no bar legend

#### Scenario: No bars on a narrow screen

- **WHEN** a visitor on a 390 px wide screen opens a stored day with run times
- **THEN** the run time rows show their numbers and no bar is displayed

### Requirement: One direction at a time on narrow screens

Below 640 px wide, the run time block and the per-stop load rows SHALL each show one direction at a time, the outbound direction first, with a control that switches the direction without reloading the page and without changing the page address. At 640 px wide or wider, both directions of the run time block SHALL be shown and the control SHALL NOT be shown. Without JavaScript, both directions of the run time block and of the per-stop load rows SHALL be in the response with neither marked as hidden, and the controls SHALL NOT be shown.

#### Scenario: Switching on a phone

- **WHEN** a visitor on a 390 px wide screen opens a stored day with run times in both directions and switches the run time block to inbound
- **THEN** only the inbound run time table is displayed and the page address is unchanged

#### Scenario: Wide screens show both directions

- **WHEN** a visitor on a 1400 px wide screen opens the same stored day
- **THEN** both run time tables are displayed and no direction switch is displayed

#### Scenario: Without JavaScript

- **WHEN** the page of a stored day is fetched without running any script
- **THEN** the response contains both directions' run time tables and both directions' per-stop load rows, and none of them is marked as hidden
