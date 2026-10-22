## MODIFIED Requirements

### Requirement: Page content

The page SHALL show, in this order: a summary with the route name, departure and destination, the covered days, the number of trips and of complete trips; the layover distribution chart; the load chart along the route; the run time summary of `run-time` per direction, with the number of excluded trips; the layovers per direction of the ending trip, each row naming that direction's last stop and the nature of that end as defined by `turnaround-ends` (stopping or pass-through), with the number of layovers, p10, p50, p90 and the share under 15 minutes as defined by `layover-metrics`; the buffer estimate as defined by `buffer-trade` for the selected buffer, with the number of covered days, measured layovers at stopping ends, measured layovers at pass-through ends when the route has such an end, and trips, the rest achievement, the lower and upper added vehicle-hours per day, the lower and upper added vehicles with their busiest hour, and the vehicles per day; the MRT overlap as defined by `mrt-overlap`, with each direction's number of stops and overlap share at 300, 500 and 800 metres, the overlap stretches at 500 metres with their first and last sequence numbers and stop names, the on-board counts of each stretch per time band, and the day of the entrance snapshot used; and the load profile as defined by `load-profile`, per direction, time band and stop, each cell giving the median, the p90 and the number of trips with a count. Percentiles SHALL be computed over all trips of the covered days, not combined from daily values. The MRT overlap SHALL NOT mark any share as above or below a review threshold. When the stops of the covered days carry no nearest-entrance distance, the MRT overlap block SHALL say that the days need to be loaded again instead of showing shares. The buffer estimate SHALL offer a control that sets the buffer from 0 to 20 minutes; changing it SHALL replace only the buffer estimate block and SHALL update the page address with the `buffer` parameter while keeping `day` and `range`.

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

#### Scenario: End nature on the layover rows

- **WHEN** the layovers of a route whose direction 0 is a pass-through end and direction 1 a stopping end are rendered
- **THEN** direction 0's row is labelled pass-through, direction 1's row is labelled stopping, and both rows keep the counts and percentiles of `layover-metrics`

#### Scenario: Both ends stopping

- **WHEN** route 9001 is configured with both ends as stopping ends and its page is rendered
- **THEN** both layover rows are labelled stopping and the buffer estimate reports no pass-through layovers

#### Scenario: Pass-through layovers in the estimate block

- **WHEN** the buffer estimate of a route whose direction 0 is a pass-through end is rendered with 3 layovers ending in direction 0 and 2 ending in direction 1
- **THEN** the block reports 2 measured layovers at stopping ends and 3 layovers at the pass-through end as not counted

### Requirement: Data limitations on the page

The page SHALL state the data limitations that apply to its numbers: a vehicle is not a driver and a layover is an upper bound on rest; on-board counts come from fare-card taps and do not return to zero between trips; 10-second polling misses stops and trips missing a terminal are left out of run times; the covered days do not separate weekdays and holidays; a stop near an MRT entrance does not mean the bus segment can be replaced by the MRT, distances are straight-line, and the entrance data is updated irregularly; the buffer estimate counts vehicle-hours, not driver hours, uses only measured layovers at stopping ends, and its added vehicles are an hourly average, not a schedule; which end buses stop at is a fact verified route by route and written into the configuration, not computed from the data, and it goes stale when the operator changes how the route turns around; layovers at a pass-through end are not rest opportunities and the buffer estimate does not count them.

#### Scenario: Limitations present

- **WHEN** any route page with data is rendered
- **THEN** it contains a 資料限制 section with the statements above

### Requirement: Layover distribution chart

The page SHALL show, per direction of the ending trip, a horizontal bar chart of the layovers of the covered days as defined by `layover-metrics`, counted in the bins of the health card: lower bounds 0, 5, 10, 15, 30 and 60 minutes, each bin including its lower bound and excluding the next one, the last bin open-ended. Each bar SHALL give its bin and its count, and bar lengths SHALL be proportional to the count within the direction. The chart SHALL draw a divider between the bins below 15 minutes and the bins from 15 minutes, and SHALL NOT colour any bin as compliant or non-compliant. Each direction's chart SHALL be titled with that direction's last stop and the first stop of the other direction, where the next trip starts, both from the latest of the covered days, and SHALL state the nature of that end as defined by `turnaround-ends` (stopping or pass-through). A direction without layovers SHALL show that it has none instead of bars. The bin counts SHALL equal the health card's `bin_counts` on the same input.

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

#### Scenario: Title states the end nature

- **WHEN** direction 0 is a pass-through end and direction 1 a stopping end
- **THEN** direction 0's chart title states pass-through and direction 1's chart title states stopping

#### Scenario: Direction without layovers

- **WHEN** a covered day has no layover ending in direction 1
- **THEN** direction 1's chart shows that it has no layovers and no bars
