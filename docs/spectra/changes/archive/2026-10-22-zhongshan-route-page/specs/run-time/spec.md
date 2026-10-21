## Purpose

Define the run time of a trip and how it is summarized, so the route page can report how long a trip takes per direction and departure hour. Only trips whose start and end times are both observed at the terminals count.

## ADDED Requirements

### Requirement: Run time of a trip

The run time of a trip SHALL be its end time minus its start time in minutes. Only trips with completeness `complete` SHALL have a run time. A complete trip whose start time comes from an arrival (`start_from_arrival`) or whose end time comes from a departure (`end_from_departure`) SHALL be excluded and counted as excluded.

#### Scenario: Excluded trips

- **WHEN** a day has three complete trips, one of them with `start_from_arrival`, and one trip missing its last stop
- **THEN** two trips have a run time, one is counted as excluded, and the incomplete trip is neither counted nor excluded

### Requirement: Run time summary

The system SHALL group trips with a run time by direction and by the hour of the start time in Taipei time, and SHALL report for each group the number of trips and the 50th, 85th and 95th percentile of the run time, interpolated linearly between order statistics and rounded to one decimal. It SHALL also report, per direction, the number of excluded trips. A group with fewer than 5 trips SHALL be marked as a small sample.

#### Scenario: Percentiles of one hour

- **WHEN** direction 0 has five trips starting in the 07 hour with run times 50, 52, 55, 60 and 70 minutes
- **THEN** the 07 row of direction 0 reports 5 trips, p50 55.0, p85 64.0 and p95 68.0, not marked as a small sample

#### Scenario: Small sample

- **WHEN** direction 1 has two trips starting in the 22 hour
- **THEN** the 22 row of direction 1 is marked as a small sample and still shows its percentiles

#### Scenario: Hour from Taipei time

- **WHEN** a trip starts at 2026-10-19 23:40 Taipei time and ends the next day at 00:50
- **THEN** it belongs to the 23 hour of 2026-10-19 with a run time of 70.0 minutes
