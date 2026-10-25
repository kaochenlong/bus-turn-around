## ADDED Requirements

### Requirement: Segments observing too few stops are not trips

A segment cut by Trip segmentation SHALL be a trip only when it observes at least the number of distinct stops given by the constant `min_trip_stops` of `analysis/params.sql`, which is 2, because a segment observing one stop is not a run: the vehicle did not move from one stop to another within it. A segment observing fewer distinct stops SHALL NOT be a trip of any day: it SHALL NOT be among the trips, and every count, pair, run and stored row built from the trips SHALL leave it out. The system SHALL keep the segments that start on the requested day and observe fewer distinct stops than `min_trip_stops`, so that their number can be reported.

#### Scenario: Arrival reported before the first trip of the day

- **WHEN** on route 9001, whose direction 0 runs sequences 0 to 4 and direction 1 sequences 5 to 9, a vehicle's first record of the day is an arrival at sequence 4 at 06:09, and the vehicle then departs sequence 5 at 06:19, arrives at sequence 7 at 06:50 and arrives at sequence 9 at 07:41
- **THEN** the vehicle has one trip, the complete direction-1 trip from 06:19 to 07:41, and the 06:09 arrival is one segment that starts on the day and is not a trip

#### Scenario: Arrival reported again after a gap longer than the split gap

- **WHEN** on route 9001 a vehicle departs sequence 0 at 07:59, arrives at sequence 2 at 08:40, arrives at sequence 4 at 09:30, reports an arrival at sequence 4 again at 09:40, has no record until another arrival at sequence 4 at 13:01, then departs sequence 5 at 13:14, arrives at sequence 7 at 14:10 and arrives at sequence 9 at 15:05
- **THEN** the vehicle has two complete trips, from 07:59 to 09:30 and from 13:14 to 15:05, and the 13:01 arrival is one segment that starts on the day and is not a trip

#### Scenario: Two observed stops make a trip

- **WHEN** on route 9001 a vehicle departs sequence 5 at 08:00 and arrives at sequence 6 at 08:05, with no other record that day
- **THEN** the vehicle has one trip in direction 1, classified `missing_end`, with 2 stops observed

##### Example: Distinct stops decide

| Records of the segment | Distinct stops | Trip |
| --- | --- | --- |
| arrival at sequence 4 at 06:09 | 1 | no |
| arrival at sequence 4 at 13:01, departure from sequence 4 at 13:05 | 1 | no |
| departure from sequence 5 at 08:00, arrival at sequence 6 at 08:05 | 2 | yes, `missing_end` |

#### Scenario: Fixture days have no such segment

- **WHEN** trips are built for the analysis fixture on 2026-10-19, and for route 9001 with member route 9050 on 2026-10-23
- **THEN** no segment that starts on either day observes fewer than 2 distinct stops, and the 2026-10-19 trips are the 27 trips hand-computed in `spec/fixtures/analysis/README.md`
