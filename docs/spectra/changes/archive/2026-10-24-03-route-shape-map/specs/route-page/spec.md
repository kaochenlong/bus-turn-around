## MODIFIED Requirements

### Requirement: Stop sequence block

The page SHALL show, after the section links and before the layover distribution chart, a stop sequence block built from the stops stored for the latest covered day. Between its heading and its disclosure, outside the disclosure, the block SHALL show the route map as defined by `route-shape`, or that capability's sentence when the covered days have no route shape. The block SHALL hold a disclosure that is closed by default, whose summary gives each direction's number of stops and whose rows are all present in the server response. Inside, the block SHALL list each direction in direction order with its stop names in sequence order, marking the first as the first stop and the last as the last stop, and SHALL NOT show sequence numbers. After each direction's last stop, a row SHALL state the nature of that end as defined by `turnaround-ends` (stopping or pass-through) and SHALL name the first stop of the other direction as where the next trip starts; when the other direction has no stops, the row SHALL state only the nature. The block SHALL state the static snapshot day of the latest covered day. When the latest covered day has no stops, the block SHALL state that the covered days have no stop sequence and SHALL show no list. The block SHALL NOT mark stops as near the MRT, SHALL NOT show on-board counts and SHALL NOT mark which stops another route shares.

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

#### Scenario: Route map above the list

- **WHEN** a stored day with stops and route shapes is rendered
- **THEN** the block's route map container comes after the block's heading and before the closed disclosure, and is not inside the disclosure

#### Scenario: Only one direction stored

- **WHEN** the latest covered day has stops only in direction 0
- **THEN** the block lists direction 0 only, and its turnaround row states the nature of that end without naming a next first stop

#### Scenario: No stops stored

- **WHEN** the latest covered day has no stops
- **THEN** the block states that the covered days have no stop sequence and shows no list, and every other block renders as before

### Requirement: Data limitations on the page

The page SHALL state the data limitations that apply to its numbers: a vehicle is not a driver and a layover is an upper bound on rest; on-board counts come from fare-card taps and do not return to zero between trips; 10-second polling misses stops and trips missing a terminal are left out of run times; weekdays and holidays follow the office calendar of 行政院人事行政總處, and days off for typhoons are not in that calendar and count as the calendar says; a stop near an MRT entrance does not mean the bus segment can be replaced by the MRT, distances are straight-line, and the entrance data is updated irregularly; the buffer estimate counts vehicle-hours, not driver hours, uses only measured layovers at stopping ends, and its added vehicles are an hourly average, not a schedule; which end buses stop at is a fact verified route by route and written into the configuration, not computed from the data, and it goes stale when the operator changes how the route turns around; layovers at a pass-through end are not rest opportunities and the buffer estimate does not count them; round trips and cycles use only trips whose terminals were observed and that pair up as stored layovers, so their counts are lower than the trip counts, a vehicle's first loop of a day has no cycle, and a cycle is the rhythm of a vehicle, not the roster of one driver; the turnaround point location of a stopping end is where the vehicles stood still during that day's measured layovers, as reported by GPS every 10 seconds, which can be missing for a day, and it is where the vehicle stood, not where the driver went; a pass-through end is anchored on its last stop because buses do not stop there; the toilet data is the national registry of 環境部, updated monthly, with one row per toilet that the page groups into places by address, the toilet distances are straight-line, and the data has no opening hours and says nothing about whether a driver is allowed to use a toilet; the squares on the maps are cells of about 20 metres that at least three vehicles stood in on a day, their shade sums GPS reports taken every 10 seconds and is not minutes stood and not rest, cells with fewer vehicles are left out, and the basemap is third-party data shown as it is; the route map draws the route shape registered by 臺北市公共運輸處, not measured GPS, so temporary detours and diversions do not appear on it, and the registered shape can be older than the stop list.

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
