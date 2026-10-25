## MODIFIED Requirements

### Requirement: Home page content and order

The system SHALL serve `GET /` with these blocks in this order: a hero block with a one-question heading, one sentence naming the two numbers the site measures per route, and the hero picture; the origin story block; the route list; the data limitations; the data sources. The site name SHALL appear in the page body only in the site name bar of `site-layout`, not in the hero. Every block SHALL be present in the server response without JavaScript. The only page-specific script SHALL be the hero animation, which the home page alone loads on demand. The page SHALL show no metric other than the stop-end figure of each route list entry that the requirement "Route list" describes: no trip count, percentile or estimate anywhere else, and no figure of another kind on an entry. Figures quoted from the article that the origin story block cites, namely its times, its dates and the interval between two of its times, are not metrics; the page SHALL show them only inside the origin story block, next to the article's citation. Every date on the page SHALL come from stored route days, except the dates quoted from that article and its publication date, and the copy SHALL NOT promise an update cadence.

#### Scenario: Blocks in order

- **WHEN** a visitor requests `/`
- **THEN** the response is 200 and the blocks appear in the order hero, origin, routes, limitations, sources

#### Scenario: Complete without JavaScript

- **WHEN** route 9001 has the stored day 2026-10-20 and a visitor fetches `/` without running any script
- **THEN** the response already contains the hero picture, the origin story block with its link to the article, the 9001 entry with its latest day, the four limitations and the dataset links

#### Scenario: Site name once

- **WHEN** a visitor requests `/`
- **THEN** the text 折返點 TurnAround appears in the page body exactly once, inside the site name bar

#### Scenario: No percentage outside the route list

- **WHEN** route 9001 has a stored day whose stopping end has layovers and a visitor requests `/`
- **THEN** the 9001 entry carries its figure block, and no text outside the route list block matches a percentage such as 33.3%

---
### Requirement: Route list

The route list SHALL contain one entry per route Id in the route list configuration, in configuration order, built from one query for the latest stored day of every configured route. An entry whose route has stored days SHALL show the route name without the Id beside it; the departure and destination of the latest stored day, followed by the label 路線 Id and the route's Id; and that day with its weekday in the format the route page uses for covered days, followed by its day type as defined by `day-types`; and SHALL link to `/routes/<Id>`. After the day, the entry SHALL show one figure block headed 停車端停不到 15 分鐘的比例 with one line per stopping end of the route as defined by `turnaround-ends`, in direction order: the share of the layovers ending at that end on the latest stored day that are under 15 minutes, formatted as the route page's layover table formats shares, followed by the end's last stop and the count of those layovers in the form 末站・共 N 次折返. The end's last stop, count and share SHALL be the ones the route page's summary shows for that route's latest stored day, so that the card and the page a visitor reaches by following it agree. An end without a layover on that day SHALL show a dash and the count 0. When the route has no stopping end, the figure block SHALL state 兩端都是直接折返，沒有停車的一端 and carry no line. The figures of every entry SHALL come from one query besides the route days query, and that query SHALL NOT read route_days. The entry SHALL remain a single link to `/routes/<Id>`. An entry whose route has no stored days SHALL show only the label 路線 Id with the route's Id, SHALL state that the route has no data yet, SHALL carry no figure block and SHALL NOT link anywhere. The note under the list SHALL state that the share is the share of the measured layovers at the stopping end under 15 minutes on the latest day, and that a layover is an upper bound on the driver's rest, not working time.

#### Scenario: Entries in configuration order

- **WHEN** the configuration lists 15373 then 9001, 15373 has no stored days and 9001 has the stored days 2026-10-19 and 2026-10-20
- **THEN** the list shows 15373 first, marked as having no data and without a link, then 9001 with the latest day 2026-10-20 and a link to `/routes/9001`

##### Example: entry of a route with data

- **GIVEN** route 9001 has the stored weekdays 2026-10-19 and 2026-10-20 whose latest row has route name 測試幹線, departure 甲站 and destination 戊站
- **WHEN** `/` is requested
- **THEN** the 9001 entry's name reads 測試幹線 alone, and the entry shows 甲站－戊站 followed by 路線 Id 9001, and 2026-10-20（二）平日

##### Example: entry of a route without data

- **GIVEN** the configuration lists 15373, which has no stored days
- **WHEN** `/` is requested
- **THEN** the 15373 entry reads 路線 Id 15373, states that the route has no data yet, has no figure block and has no link

#### Scenario: Latest day is a holiday

- **WHEN** route 9001's latest stored day is the holiday 2026-10-26
- **THEN** the 9001 entry shows 2026-10-26（一）假日

#### Scenario: Latest day of every route in one query

- **WHEN** two configured routes each have several stored days and the route list is built
- **THEN** the route days are read with a single query and each entry carries its route's latest day

##### Example: two routes, three days each

- **GIVEN** the configuration lists 15373 then 9001, 15373 has stored days 2026-10-19, 2026-10-20 and 2026-10-21, and 9001 has stored days 2026-10-18, 2026-10-19 and 2026-10-20
- **WHEN** the route list is built
- **THEN** exactly one SELECT on route_days is issued, and the entries are 15373 with 2026-10-21 followed by 9001 with 2026-10-20

#### Scenario: Figure line per stopping end

- **WHEN** both ends of route 9001 are stopping ends, its latest stored day 2026-10-20 has the last stops 戊站 in direction 0 and 甲站 in direction 1, three layovers of 10, 20 and 30 minutes end in direction 1 and none ends in direction 0
- **THEN** the 9001 entry's figure block has a line for direction 0 reading — and 戊站・共 0 次折返, then a line for direction 1 reading 33.3% and 甲站・共 3 次折返

#### Scenario: Only stopping ends have a line

- **WHEN** direction 0 of route 9001 is a pass-through end, direction 1 is a stopping end and layovers end in both directions
- **THEN** the figure block has one line, for direction 1

#### Scenario: No stopping end

- **WHEN** both ends of route 9001 are pass-through ends and layovers end in both directions
- **THEN** the figure block states 兩端都是直接折返，沒有停車的一端 and has no line

#### Scenario: Figure comes from the latest day only

- **WHEN** route 9001 has the stored days 2026-10-19 and 2026-10-20, a layover of 10 minutes ends in direction 1 on 2026-10-19, and layovers of 20 and 30 minutes end in direction 1 on 2026-10-20
- **THEN** the 9001 entry's line for direction 1 reads 0.0% and 共 2 次折返

##### Example: layovers per day

| Stored day | Layovers ending in direction 1 | Counted on the entry |
| ---------- | ------------------------------ | -------------------- |
| 2026-10-19 | 10 minutes | no |
| 2026-10-20 | 20 and 30 minutes | yes, 2 layovers, 0.0% under 15 minutes |

#### Scenario: Figure equals the route page's key number

- **WHEN** route 9001's latest stored day has layovers at a stopping end, and `/` and `/routes/9001` are both requested
- **THEN** the share and the 末站・共 N 次折返 text of that end's line on the 9001 entry equal the number and the text of that end's line in the summary key number 停車端停不到 15 分鐘的比例 of the route page

#### Scenario: One query for the figures of every entry

- **WHEN** two configured routes each have a stored day with layovers and the route list is built
- **THEN** besides the single SELECT on route_days, the figures of both entries come from one statement that does not read route_days

##### Example: two routes, one statement

- **GIVEN** the configuration lists 15373 then 9001, 15373 has the stored day 2026-10-21 with two layovers at its stopping end and 9001 has the stored day 2026-10-20 with three layovers at its stopping end
- **WHEN** the route list is built and both entries' figures are read
- **THEN** exactly one SELECT on route_days is issued, exactly one statement reading layovers is issued, that statement does not mention route_days, and the entries carry the counts 2 and 3

#### Scenario: Note under the list

- **WHEN** `/` is requested
- **THEN** the note under the route list states that the share is the share of the stopping end's measured layovers under 15 minutes on the latest day and that a layover is an upper bound on the driver's rest, not working time
