## ADDED Requirements

### Requirement: Counts of member route trips at shared stops

For a trip of a member route, each stop's on-board count SHALL be attributed to the page route's stop of the same direction that has the same `stopLocationId` in the day's `GetStop.gz`, and SHALL carry that stop's sequence number in the health card's profile and in the stored trip stop counts. A count at a stop the page route does not serve in that direction SHALL be left out of the profile and of the stored counts, and SHALL be counted in the quality report as an unmatched count. Counts of the page route's own trips SHALL keep their sequence numbers. Net boarding SHALL be computed on each trip's own stop list before this attribution, so that a count at a stop only the member route serves still takes part in the net boarding of its trip.

#### Scenario: Shared stop pooled

- **WHEN** the run is for route 9001 with member route 9050 on 2026-10-23, and TEST-0005's two 9050 trips in direction 0 carry 5 and 4 at 乙站, route 9050's sequence 1 with `stopLocationId` 81001, which is also route 9001's sequence 1 of direction 0
- **THEN** direction 0 at sequence 1 has two trips with counts 5 and 4, stored under route 9001's sequence 1

##### Example: direction 0 of the member day

| Route 9001 sequence | Stop | Trips with a count | Counts |
| --- | --- | --- | --- |
| 0 | 甲站 | 2 | 3, 2 |
| 1 | 乙站 | 2 | 5, 4 |
| 2 | 丙站 | 0 | none: route 9050 does not serve it and no 9001 trip ran direction 0 that day |
| 3 | 丁站 | 2 | 6, 5 |
| 4 | 戊站 | 2 | 2, 1 |

#### Scenario: Stop only the member route serves

- **WHEN** TEST-0005's 9050 trips carry 7 and 6 at 己站 (`stopLocationId` 85002), which route 9001 does not serve
- **THEN** neither count appears in the profile or in the stored counts, and the quality report counts 2 unmatched counts

#### Scenario: Page route counts unchanged

- **WHEN** TEST-0005's 9001 trip in direction 1 carries 4, 6, 5, 3 and 1 at sequences 5 to 9
- **THEN** those counts keep sequences 5 to 9

#### Scenario: Net boarding before attribution

- **WHEN** TEST-0005's first 9050 trip carries 5 at 乙站 (sequence 1 of route 9050), 7 at 己站 (sequence 2) and 6 at 丁站 (sequence 3)
- **THEN** the trip's net boarding at 己站 is 2 and at 丁站 is -1, each with a span of 1
