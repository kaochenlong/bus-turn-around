## MODIFIED Requirements

### Requirement: Measured base of the estimate

The estimate SHALL use only the layovers stored for the covered days, as defined by `layover-metrics`, whose ending trip's direction is a stopping end as defined by `turnaround-ends`, and SHALL NOT extrapolate to trips without a measured layover. Layovers ending at a pass-through end SHALL be counted and reported as not rest opportunities, and SHALL NOT enter any figure of the estimate. It SHALL report the number of covered days, the number of measured layovers at stopping ends (the base of the estimate), the number of measured layovers at pass-through ends, and the number of trips on the covered days, so the share of trips with a measured layover is visible. It SHALL report the average number of distinct vehicles per covered day, rounded to one decimal.

#### Scenario: Coverage reported

- **WHEN** both ends are stopping ends and two covered days hold 5 and 3 trips, 3 and 1 layovers, and 2 and 3 distinct vehicles
- **THEN** the estimate reports 2 days, 4 layovers at stopping ends, 0 layovers at pass-through ends, 8 trips and 2.5 vehicles per day

#### Scenario: Pass-through end reported, not counted

- **WHEN** direction 0 is a pass-through end and direction 1 a stopping end, and the covered day holds 3 layovers ending in direction 0 and 1 layover ending in direction 1
- **THEN** the base of the estimate is 1 layover and 3 layovers at the pass-through end are reported

### Requirement: Rest achievement

The rest achievement SHALL be the share of measured layovers at stopping ends lasting at least B minutes. It is an upper bound on rest because a layover includes returning to the depot, refuelling and waiting. With no measured layover at a stopping end the achievement SHALL be absent.

#### Scenario: Share at or above the buffer

- **WHEN** the measured layovers at stopping ends last 5, 20, 2 and 10 minutes and B is 15
- **THEN** the rest achievement is 25.0%

#### Scenario: Pass-through layovers do not count

- **WHEN** the layovers at stopping ends last 20 and 10 minutes, three layovers at a pass-through end last 2 minutes each, and B is 15
- **THEN** the rest achievement is 50.0%

#### Scenario: No layover

- **WHEN** the covered days hold no layover
- **THEN** no rest achievement, vehicle-hours or vehicles are reported

#### Scenario: Layovers only at a pass-through end

- **WHEN** the covered days hold layovers ending only at a pass-through end
- **THEN** no rest achievement, vehicle-hours or vehicles are reported, and the number of layovers at the pass-through end is reported

##### Example: Three pass-through layovers and nothing else

- **GIVEN** direction 0 is a pass-through end and direction 1 a stopping end, and one covered day holds three layovers ending in direction 0 lasting 2 minutes each and none ending in direction 1
- **WHEN** B is 15
- **THEN** the rest achievement, the vehicle-hours and the vehicles are absent, and 3 layovers at the pass-through end are reported

### Requirement: Added vehicle-hours as a range

The added vehicle-hours SHALL be reported as a lower and an upper bound, each as a daily average over the covered days rounded to one decimal. The lower bound SHALL be the sum over measured layovers at stopping ends of the minutes each falls short of B, zero for a layover of at least B minutes. The upper bound SHALL be B minutes for every measured layover at a stopping end. Layovers at pass-through ends SHALL add nothing to either bound. Both sums SHALL be divided by the number of covered days and by 60.

#### Scenario: Two days pooled

- **WHEN** the measured layovers at stopping ends are computed with B of 15
- **THEN** the lower bound counts only the shortfall and the upper bound counts B for every layover at a stopping end

##### Example: Four layovers over two days

- **GIVEN** both ends are stopping ends, day one has layovers ending at 08:00 lasting 5 minutes, at 08:20 lasting 20 minutes and at 09:10 lasting 2 minutes, and day two has one ending at 08:30 lasting 10 minutes
- **WHEN** B is 15
- **THEN** the lower bound is 0.2 vehicle-hours per day (28 minutes over 2 days) and the upper bound is 0.5 (60 minutes over 2 days)

##### Example: Pass-through layovers add nothing

- **GIVEN** one covered day with layovers at the stopping end lasting 5 and 20 minutes and layovers at the pass-through end lasting 2 and 1 minutes
- **WHEN** B is 15
- **THEN** the lower bound is 0.2 vehicle-hours per day (10 minutes) and the upper bound is 0.5 (30 minutes)

### Requirement: Added vehicles in the busiest hour

The added vehicles SHALL be estimated for the lower and the upper bound separately: the added minutes of each measured layover at a stopping end SHALL be grouped by the Taipei hour of the layover's end time, each hour's sum divided by 60 and by the number of covered days, and the hour with the largest value reported with that value rounded to one decimal. When two hours have the same value, the earlier hour SHALL be reported. Layovers at pass-through ends SHALL NOT enter any hour. The estimate is an hourly average, not a schedule.

#### Scenario: Busiest hour of each bound

- **WHEN** the added minutes are grouped by the hour the layovers at stopping ends end
- **THEN** each bound reports its own busiest hour and its average added vehicles

##### Example: Hour 8 is busiest

- **GIVEN** the four layovers of the example "Four layovers over two days" and B of 15
- **WHEN** the busiest hour is computed
- **THEN** the lower bound reports hour 8 with 0.1 vehicles (15 minutes over 2 days) and the upper bound reports hour 8 with 0.4 vehicles (45 minutes over 2 days)

##### Example: Tie goes to the earlier hour

- **GIVEN** one day with a layover ending at 07:30 and one ending at 08:30, both lasting 5 minutes, both at a stopping end
- **WHEN** B is 15
- **THEN** the lower bound reports hour 7 with 0.2 vehicles

##### Example: Pass-through hour ignored

- **GIVEN** one day with layovers at the stopping end ending at 08:10 lasting 3 minutes and at 08:40 lasting 9 minutes, and three layovers at the pass-through end ending at 17:10, 17:20 and 17:30 lasting 2 minutes each
- **WHEN** B is 15
- **THEN** the lower bound reports hour 8 with 0.3 vehicles (18 minutes) and the upper bound reports hour 8 with 0.5 vehicles (30 minutes); hour 17 is not reported
