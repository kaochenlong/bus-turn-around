## MODIFIED Requirements

### Requirement: Page content

The page SHALL show, in this order: a summary with the route name, departure and destination, the covered days, the number of trips and of complete trips; the layover distribution chart; the load chart along the route; the run time summary of `run-time` per direction, with the number of excluded trips; the layovers per direction of the ending trip, each row naming that direction's last stop, with the number of layovers, p10, p50, p90 and the share under 15 minutes as defined by `layover-metrics`; the buffer estimate as defined by `buffer-trade` for the selected buffer, with the number of covered days, measured layovers and trips, the rest achievement, the lower and upper added vehicle-hours per day, the lower and upper added vehicles with their busiest hour, and the vehicles per day; the MRT overlap as defined by `mrt-overlap`, with each direction's number of stops and overlap share at 300, 500 and 800 metres, the overlap stretches at 500 metres with their first and last sequence numbers and stop names, the on-board counts of each stretch per time band, and the day of the entrance snapshot used; and the load profile as defined by `load-profile`, per direction, time band and stop, each cell giving the median, the p90 and the number of trips with a count. Percentiles SHALL be computed over all trips of the covered days, not combined from daily values. The MRT overlap SHALL NOT mark any share as above or below a review threshold. When the stops of the covered days carry no nearest-entrance distance, the MRT overlap block SHALL say that the days need to be loaded again instead of showing shares. The buffer estimate SHALL offer a control that sets the buffer from 0 to 20 minutes; changing it SHALL replace only the buffer estimate block and SHALL update the page address with the `buffer` parameter while keeping `day` and `range`.

#### Scenario: Seven-day percentile pools trips

- **WHEN** day one has layovers of 10 and 20 minutes in direction 0 and day two has one of 30 minutes, and the page covers both days
- **THEN** the direction 0 layover row reports 3 layovers and a p50 of 20.0

#### Scenario: Overlap block in place

- **WHEN** a stored day whose stops carry nearest-entrance distances is rendered
- **THEN** the blocks appear in the order summary, layover chart, load chart, run times, layovers, buffer estimate, MRT overlap, load profile, limitations, and the MRT overlap block names the entrance snapshot day

#### Scenario: Distances missing

- **WHEN** a stored day was loaded before stops carried nearest-entrance distances
- **THEN** the MRT overlap block asks for the day to be loaded again and shows no share

#### Scenario: Buffer from the address

- **WHEN** a visitor requests `/routes/9001?day=2026-10-19&range=7d&buffer=10`
- **THEN** the buffer estimate uses 10 minutes, and its control carries the buffer 10 with the day 2026-10-19 and the range 7d, targeting only the buffer estimate block

## ADDED Requirements

### Requirement: Layover distribution chart

The page SHALL show, per direction of the ending trip, a horizontal bar chart of the layovers of the covered days as defined by `layover-metrics`, counted in the bins of the health card: lower bounds 0, 5, 10, 15, 30 and 60 minutes, each bin including its lower bound and excluding the next one, the last bin open-ended. Each bar SHALL give its bin and its count, and bar lengths SHALL be proportional to the count within the direction. The chart SHALL draw a divider between the bins below 15 minutes and the bins from 15 minutes, and SHALL NOT colour any bin as compliant or non-compliant. Each direction's chart SHALL be titled with that direction's last stop and the first stop of the other direction, where the next trip starts, both from the latest of the covered days. A direction without layovers SHALL show that it has none instead of bars. The bin counts SHALL equal the health card's `bin_counts` on the same input.

#### Scenario: Bins follow the card

- **WHEN** the fixture day 2026-10-19 is loaded for route 9001 and the page covers that day
- **THEN** each direction's bar counts equal the health card's `bin_counts` for that direction

##### Example: fixture day

- **GIVEN** the fixture day 2026-10-19 of route 9001
- **WHEN** the layover distribution is read
- **THEN** direction 0 has counts 0, 0, 6, 3, 1, 0 and direction 1 has counts 0, 0, 3, 3, 0, 3 for the bins from 0, 5, 10, 15, 30 and 60 minutes

#### Scenario: Bin edges

- **WHEN** direction 0 has layovers of 4.9, 5.0, 14.9, 15.0 and 75.0 minutes
- **THEN** the counts are 1, 1, 1, 1, 0, 1 for the bins from 0, 5, 10, 15, 30 and 60 minutes

#### Scenario: Title names both stops

- **WHEN** direction 0's last stop is 戊站 and direction 1's first stop is 己站 on the latest covered day
- **THEN** direction 0's chart is titled with 戊站 and 己站

#### Scenario: Direction without layovers

- **WHEN** a covered day has no layover ending in direction 1
- **THEN** direction 1's chart shows that it has no layovers and no bars

### Requirement: Load chart along the route

The page SHALL show, per direction, a line chart of the load profile as defined by `load-profile` over the covered days: the horizontal axis SHALL be the stop sequence of the latest covered day, and the vertical axis the median on-board count at each stop. The chart SHALL offer the time bands morning peak, daytime, evening peak and other, one shown at a time, morning peak shown first; switching bands SHALL NOT reload the page. All bands of one direction SHALL share one vertical scale whose top is at least the largest median of that direction in any band. A stop without a count in the shown band SHALL break the line instead of being filled. The overlap stretches at 500 metres as defined by `mrt-overlap` SHALL be drawn as shaded spans over their first to last sequence numbers, without any review threshold; when the stops carry no nearest-entrance distance, no span SHALL be drawn. The chart SHALL name the first and last stop of the direction and the first and last stop of each shaded span.

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
