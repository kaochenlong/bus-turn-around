## ADDED Requirements

### Requirement: Member routes' stops stay out of the overlap

The nearest-entrance distance SHALL be computed and stored for the stops of every route `Id` of the run, but the overlap share, the overlap stretches and the on-board counts along a stretch SHALL use only the page route's stops. Counts of member route trips attributed to page route stops as defined by `load-profile` SHALL take part in the on-board counts along a stretch.

#### Scenario: Member route stop stored but not counted

- **WHEN** the run is for route 9001 with member route 9050 on 2026-10-23
- **THEN** 己站 has a stored nearest-entrance distance, direction 0's overlap share at 500 metres is 3 of 5 stops as it is without members, and the stretch of direction 0 runs from 乙站 to 丁站

#### Scenario: Member route counts along a stretch

- **WHEN** TEST-0005's 9050 trips carry 5 and 4 at 乙站 and 6 and 5 at 丁站
- **THEN** the morning-peak row of direction 0's stretch counts those trips at 乙站 and 丁站
