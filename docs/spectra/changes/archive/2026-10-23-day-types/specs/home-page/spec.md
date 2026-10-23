## MODIFIED Requirements

### Requirement: Route list

The route list SHALL contain one entry per route Id in the route list configuration, in configuration order, built from one query for the latest stored day of every configured route. An entry whose route has stored days SHALL show the route name, the Id, the departure and destination of the latest stored day, and that day with its weekday in the format the route page uses for covered days, followed by its day type as defined by `day-types`, and SHALL link to `/routes/<Id>`. An entry whose route has no stored days SHALL show only the Id, SHALL state that the route has no data yet, and SHALL NOT link anywhere.

#### Scenario: Entries in configuration order

- **WHEN** the configuration lists 15373 then 9001, 15373 has no stored days and 9001 has the stored days 2026-10-19 and 2026-10-20
- **THEN** the list shows 15373 first, marked as having no data and without a link, then 9001 with the latest day 2026-10-20 and a link to `/routes/9001`

##### Example: entry of a route with data

- **GIVEN** route 9001 has the stored weekdays 2026-10-19 and 2026-10-20 whose latest row has route name 測試幹線, departure 甲站 and destination 戊站
- **WHEN** `/` is requested
- **THEN** the 9001 entry shows 測試幹線, 9001, 甲站－戊站 and 2026-10-20（二）平日

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
