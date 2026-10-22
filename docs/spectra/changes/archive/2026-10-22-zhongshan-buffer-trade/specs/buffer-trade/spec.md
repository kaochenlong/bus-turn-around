## Purpose

Estimate what it costs to give every trip of a route a schedule buffer of B minutes at its terminal, from the layovers measured on the covered days, as the first action of the 換休息試算. The estimate is stated in vehicle-hours and vehicles, never driver hours, because the data identifies vehicles, not drivers, and a layover is an upper bound on rest.

## ADDED Requirements

### Requirement: Buffer minutes

The buffer B SHALL be a whole number of minutes from 0 to 20, defaulting to 15 when no value is given. Any other value SHALL be rejected as a parameter the route page does not accept.

#### Scenario: Default buffer

- **WHEN** no buffer value is given
- **THEN** B is 15

#### Scenario: Rejected buffer values

- **WHEN** the buffer value is `21`, `-1`, `abc` or `1.5`
- **THEN** the value is rejected as a parameter the route page does not accept

### Requirement: Measured base of the estimate

The estimate SHALL use only the layovers stored for the covered days, as defined by `layover-metrics`, and SHALL NOT extrapolate to trips without a measured layover. It SHALL report the number of covered days, the number of measured layovers and the number of trips on the covered days, so the share of trips with a measured layover is visible. It SHALL report the average number of distinct vehicles per covered day, rounded to one decimal.

#### Scenario: Coverage reported

- **WHEN** two covered days hold 5 and 3 trips, 3 and 1 layovers, and 2 and 3 distinct vehicles
- **THEN** the estimate reports 2 days, 4 layovers, 8 trips and 2.5 vehicles per day

### Requirement: Rest achievement

The rest achievement SHALL be the share of measured layovers lasting at least B minutes. It is an upper bound on rest because a layover includes returning to the depot, refuelling and waiting. With no measured layover the achievement SHALL be absent.

#### Scenario: Share at or above the buffer

- **WHEN** the measured layovers last 5, 20, 2 and 10 minutes and B is 15
- **THEN** the rest achievement is 25.0%

#### Scenario: No layover

- **WHEN** the covered days hold no layover
- **THEN** no rest achievement, vehicle-hours or vehicles are reported

### Requirement: Added vehicle-hours as a range

The added vehicle-hours SHALL be reported as a lower and an upper bound, each as a daily average over the covered days rounded to one decimal. The lower bound SHALL be the sum over measured layovers of the minutes each falls short of B, zero for a layover of at least B minutes. The upper bound SHALL be B minutes for every measured layover. Both sums SHALL be divided by the number of covered days and by 60.

#### Scenario: Two days pooled

- **WHEN** the measured layovers are computed with B of 15
- **THEN** the lower bound counts only the shortfall and the upper bound counts B for every layover

##### Example: Four layovers over two days

- **GIVEN** day one has layovers ending at 08:00 lasting 5 minutes, at 08:20 lasting 20 minutes and at 09:10 lasting 2 minutes, and day two has one ending at 08:30 lasting 10 minutes
- **WHEN** B is 15
- **THEN** the lower bound is 0.2 vehicle-hours per day (28 minutes over 2 days) and the upper bound is 0.5 (60 minutes over 2 days)

### Requirement: Added vehicles in the busiest hour

The added vehicles SHALL be estimated for the lower and the upper bound separately: the added minutes of each measured layover SHALL be grouped by the Taipei hour of the layover's end time, each hour's sum divided by 60 and by the number of covered days, and the hour with the largest value reported with that value rounded to one decimal. When two hours have the same value, the earlier hour SHALL be reported. The estimate is an hourly average, not a schedule.

#### Scenario: Busiest hour of each bound

- **WHEN** the added minutes are grouped by the hour the layovers end
- **THEN** each bound reports its own busiest hour and its average added vehicles

##### Example: Hour 8 is busiest

- **GIVEN** the four layovers of the example "Four layovers over two days" and B of 15
- **WHEN** the busiest hour is computed
- **THEN** the lower bound reports hour 8 with 0.1 vehicles (15 minutes over 2 days) and the upper bound reports hour 8 with 0.4 vehicles (45 minutes over 2 days)

##### Example: Tie goes to the earlier hour

- **GIVEN** one day with a layover ending at 07:30 and one ending at 08:30, both lasting 5 minutes
- **WHEN** B is 15
- **THEN** the lower bound reports hour 7 with 0.2 vehicles

### Requirement: No threshold or compliance marking

The estimate SHALL NOT mark any number as meeting or failing a regulation, a review threshold or a target, and SHALL NOT state driver hours.

#### Scenario: Plain numbers

- **WHEN** the estimate is shown for a route whose rest achievement is 23.4%
- **THEN** the number is shown without a pass or fail mark
