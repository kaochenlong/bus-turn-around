## Purpose

Measure how much of a bus route runs near the Taipei MRT and how many riders are on board along those stretches, with a transparent definition that can be recomputed: each stop's straight-line distance to the nearest MRT entrance. The official method for the review rule's overlap figure is not published, so the definition is stated in full and shown under several distance thresholds.

## ADDED Requirements

### Requirement: MRT entrance snapshot

The system SHALL provide the rake task `external:mrt_exits`, which downloads the Taipei MRT entrance coordinates CSV of data.gov.tw dataset 128428, converts it from Big5 to UTF-8, and writes it to `external/taipei-mrt-exits/<Taipei day>.csv` under the data root given by `TURNAROUND_DATA`, replacing a file of the same day. The file SHALL be written only when the header is exactly `項次,出入口名稱,出入口編號,經度,緯度,是否為無障礙用`, there is at least one data row, and every longitude and latitude is a number. Otherwise the task SHALL print the reason, exit with a non-zero status and leave every existing snapshot unchanged. The HTTP request SHALL go through a replaceable fetcher so that tests never use the network.

#### Scenario: Big5 snapshot written as UTF-8

- **WHEN** the fetcher returns a Big5 body with the expected header and two entrances `頂埔站出口1` and `頂埔站出口2`
- **THEN** the task writes a UTF-8 file for today's Taipei day containing both names and reports 2 entrances

#### Scenario: Unexpected file

- **WHEN** the fetcher returns status 500, or a body whose header differs, or a header with no rows, or a row whose latitude is not a number
- **THEN** the task exits with a non-zero status, prints the reason and writes no file

### Requirement: Nearest entrance of each stop

For each stop of the route the system SHALL compute the haversine distance in metres, with an earth radius of 6,371,000 metres, to every entrance of the snapshot, and SHALL keep the smallest distance rounded to one decimal together with that entrance's name.

#### Scenario: Nearest entrance chosen

- **WHEN** a stop lies about 111 metres from entrance A and about 334 metres from entrance B
- **THEN** the stop's nearest entrance is A with a distance of about 111 metres

### Requirement: Overlap share and overlap stretches

A stop SHALL count as near the MRT at a threshold when its nearest-entrance distance is at most that threshold. For each direction and for each of the thresholds 300, 500 and 800 metres, the overlap share SHALL be the number of the direction's stops near the MRT divided by the number of the direction's stops. At 500 metres, consecutive stops of one direction (adjacent sequence numbers) that are all near the MRT SHALL form an overlap stretch when there are at least two of them; a single near stop forms no stretch but still counts toward the share.

#### Scenario: Shares and stretches of one direction

- **WHEN** the five stops of direction 0 have nearest-entrance distances 900, 400, 250, 450 and 700 metres at sequence numbers 0 to 4
- **THEN** the shares are 20% at 300 metres, 60% at 500 metres and 80% at 800 metres, and the only stretch at 500 metres runs from sequence 1 to 3

#### Scenario: Single near stop

- **WHEN** only sequence 4 of a direction is within 500 metres
- **THEN** that direction has no stretch and an overlap share above zero

### Requirement: On-board counts along a stretch

For each overlap stretch and time band, the system SHALL pool the on-board counts of every trip at every stop of the stretch, as stored in the derived tables under `load-profile`, and SHALL report the median and the 90th percentile interpolated linearly and rounded to one decimal, and the number of trips with at least one count in the stretch.

#### Scenario: Pooled counts

- **WHEN** one morning-peak trip has counts 10 and 20 at the two stops of a stretch and another has 30 at the first stop only
- **THEN** the stretch's morning-peak row reports 2 trips, a median of 20.0 and a p90 of 28.0
