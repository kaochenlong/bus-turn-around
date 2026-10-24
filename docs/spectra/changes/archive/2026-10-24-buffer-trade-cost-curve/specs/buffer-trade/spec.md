## ADDED Requirements

### Requirement: Lateness minutes

The lateness D SHALL be a whole number of minutes from 0 to 20, defaulting to 0 when the value is absent or empty. It is an assumption: every arrival at a stopping end is D minutes later than measured while the next trip leaves at its measured time, so every layover in the base is D minutes shorter. The lateness of the measured days is already in the measured layovers, so D is lateness beyond those days. Any other value SHALL be rejected as a parameter the route page does not accept.

#### Scenario: Default lateness

- **WHEN** no lateness value is given
- **THEN** D is 0

#### Scenario: Rejected lateness values

- **WHEN** the lateness value is `21`, `-1`, `abc` or `1.5`
- **THEN** the value is rejected as a parameter the route page does not accept

#### Scenario: No lateness changes nothing

- **WHEN** D is 0
- **THEN** every figure of the estimate equals the figure computed for the buffer B alone

##### Example: four layovers without lateness

- **GIVEN** the four layovers of the example "Four layovers over two days" and B of 15
- **WHEN** D is 0
- **THEN** the added vehicle-hours are 0.2 and 0.5, the rest achievement is 25.0%, and the busiest hour of both bounds is hour 8 with 0.1 and 0.4 vehicles

### Requirement: Minutes to hold

The minutes to hold H SHALL be the buffer B, shown as the rest, plus the lateness D, from 0 to 40: the minutes every turnaround at a stopping end has to hold to give B minutes of rest after arriving D minutes late. The added vehicle-hours, the cost of one more minute, the added vehicles and the rest achievement with the same vehicles SHALL be computed for H; the rest achievement now SHALL be computed for B.

#### Scenario: Rest and lateness add up

- **WHEN** B is 15 and D is 6
- **THEN** H is 21

### Requirement: Selected hours

The selected hours SHALL be a first hour from 0 to 23 and a last hour from 1 to 24, the first below the last, defaulting to 0 and 24, the whole day, when a value is absent or empty. A layover is within the selected hours when the Taipei hour of its end time is at least the first hour and below the last. A layover ending after midnight falls in hour 0 or 1, and a range of hours that wraps past midnight SHALL NOT be selectable. Any other value SHALL be rejected as a parameter the route page does not accept.

#### Scenario: Whole day by default

- **WHEN** no hours are given
- **THEN** the selected hours are 0 to 24 and every layover at a stopping end is within them

#### Scenario: Rejected hours

- **WHEN** the first and last hours are given as below
- **THEN** each pair is rejected as a parameter the route page does not accept

##### Example: rejected first and last hours

| First hour | Last hour | Why |
| --- | --- | --- |
| 10 | 9 | the first hour is not below the last |
| 24 | 24 | the first hour is above 23 |
| 0 | 0 | the last hour is below 1 |
| 0 | 25 | the last hour is above 24 |
| abc | 24 | not a whole number |

### Requirement: Selected end

The selected end SHALL be absent or empty, meaning every stopping end, or the direction of the trips ending at one stopping end, 0 or 1. A direction whose end is a pass-through end, or any value other than 0 and 1, SHALL be rejected as a parameter the route page does not accept. Each stopping end SHALL be named by the stop with the highest sequence number of its direction on the latest covered day, among the stops of the page's own route `Id`.

#### Scenario: One of two stopping ends

- **WHEN** both ends are stopping ends and the end of direction 1 is selected
- **THEN** only the layovers ending in direction 1 are in the base

##### Example: end 1 selected

- **GIVEN** both ends are stopping ends and one covered day holds a layover ending in direction 0 at 08:00 lasting 5 minutes, and layovers ending in direction 1 at 08:20 lasting 20 minutes and at 09:10 lasting 2 minutes
- **WHEN** B is 15, D is 0 and the end of direction 1 is selected
- **THEN** the base is 2 layovers, the added vehicle-hours are 0.2 and 0.5, and the rest achievement is 50.0%

#### Scenario: Pass-through end rejected

- **WHEN** direction 0 is a pass-through end and the end of direction 0 is selected
- **THEN** the value is rejected as a parameter the route page does not accept

#### Scenario: The only stopping end selected

- **WHEN** direction 0 is a pass-through end, direction 1 a stopping end, and the end of direction 1 is selected
- **THEN** every figure equals the figure without a selected end

#### Scenario: Ends named from the latest covered day

- **WHEN** the stopping ends are named
- **THEN** each name is the last stop of its direction on the latest covered day, among the stops of the page's own route `Id`

##### Example: two covered days and a member route

- **GIVEN** route 9001 with member route 9050 covers 2026-10-19, whose direction 1 stops of route 9001 end at 甲站, and 2026-10-20, whose direction 1 stops of route 9001 end at 乙站 and whose direction 1 stops of route 9050 end at 丙站 with a higher sequence number
- **WHEN** the end of direction 1 is named for the two covered days
- **THEN** it is named 乙站

### Requirement: Cost curve

The estimate SHALL compute, for the selected hours and end, one point for every whole number of minutes to hold from 0 to 40. Each point SHALL carry the lower and upper added vehicle-hours, the cost of one more minute, the share of layovers in the base lasting at least that many minutes, the busiest hour of each bound with its added vehicles, and the added vehicles of every hour with a layover in the base, each as defined for H by the requirements of this capability. The figures reported for the selected B and D SHALL be those of the point at H, and the rest achievement now that of the point at B. With no layover in the base there SHALL be no curve.

#### Scenario: Forty-one points

- **WHEN** the base holds at least one layover
- **THEN** the curve has one point for each minute to hold from 0 to 40, and the point at 0 has 0.0 added vehicle-hours for both bounds and a share of 100.0%

#### Scenario: Reported figures are points of the curve

- **WHEN** B is 15 and D is 6 over the four layovers of the example "Four layovers over two days"
- **THEN** the reported added vehicle-hours are those of the point at 21, 0.4 and 0.7, the rest achievement now is the share of the point at 15, 25.0%, and the rest achievement with the same vehicles is the share of the point at 21, 0.0%

### Requirement: Cost of one more minute

At every point of the curve, the cost of one more minute SHALL be, for each bound, the added vehicle-hours per day at H + 1 minus those at H, computed from the sums before rounding and rounded to one decimal. At H of 40 it SHALL use the sums at 41.

#### Scenario: Next minute of a mixed day

- **WHEN** one covered day holds twelve layovers in the base, six lasting 10 minutes and six lasting 30 minutes, and H is 15
- **THEN** the lower bound grows from 0.5 to 0.6 and the upper bound from 3.0 to 3.2 vehicle-hours at H of 16, so the cost of one more minute is 0.1 for the lower bound and 0.2 for the upper bound

## MODIFIED Requirements

### Requirement: Measured base of the estimate

The estimate SHALL use only the layovers stored for the covered days, as defined by `layover-metrics`, whose ending trip's direction is a stopping end as defined by `turnaround-ends`, and SHALL NOT extrapolate to trips without a measured layover. The base of the estimate SHALL be those of these layovers that end within the selected hours and, when an end is selected, end at that end; every figure of the estimate SHALL use only the base. Layovers ending at a pass-through end SHALL be counted and reported as not rest opportunities, and SHALL NOT enter any figure of the estimate. It SHALL report the number of covered days, the number of measured layovers at stopping ends over all hours, the number of layovers in the base, the number of measured layovers at pass-through ends over all hours, and the number of trips on the covered days, so the share of trips with a measured layover is visible. It SHALL report the average number of distinct vehicles per covered day, rounded to one decimal. The number of trips, the vehicles per day and the two counts over all hours SHALL NOT depend on the selected hours or end.

#### Scenario: Coverage reported

- **WHEN** both ends are stopping ends and two covered days hold 5 and 3 trips, 3 and 1 layovers, and 2 and 3 distinct vehicles
- **THEN** the estimate reports 2 days, 4 layovers at stopping ends over all hours, 4 layovers in the base, 0 layovers at pass-through ends, 8 trips and 2.5 vehicles per day

#### Scenario: Pass-through end reported, not counted

- **WHEN** direction 0 is a pass-through end and direction 1 a stopping end, and the covered day holds 3 layovers ending in direction 0 and 1 layover ending in direction 1
- **THEN** the base of the estimate is 1 layover and 3 layovers at the pass-through end are reported

#### Scenario: Selected hours narrow the base

- **WHEN** hours are selected
- **THEN** only the layovers ending within them are in the base, and the counts over all hours, the trips and the vehicles per day stay as without a selection

##### Example: hour 9 only

- **GIVEN** the four layovers of the example "Four layovers over two days"
- **WHEN** the selected hours are 9 to 10, B is 15 and D is 0
- **THEN** the base is 1 of the 4 layovers at stopping ends over all hours, the added vehicle-hours are 0.1 and 0.1, the rest achievement is 0.0%, and the busiest hour of both bounds is hour 9

### Requirement: Rest achievement

The rest achievement SHALL be the share of layovers in the base lasting at least B minutes. With a lateness D above zero, the estimate SHALL also report the rest achievement with the same vehicles: the share of layovers in the base that, D minutes shorter, still last at least B minutes, which is the share lasting at least H minutes. A layover shorter than D counts as not reaching B, and the later departure of the next trip it would cause is not followed. Both are upper bounds on rest because a layover includes returning to the depot, refuelling and waiting. With no layover in the base, neither achievement SHALL be reported.

#### Scenario: Share at or above the buffer

- **WHEN** the measured layovers at stopping ends last 5, 20, 2 and 10 minutes and B is 15
- **THEN** the rest achievement is 25.0%

#### Scenario: Pass-through layovers do not count

- **WHEN** the layovers at stopping ends last 20 and 10 minutes, three layovers at a pass-through end last 2 minutes each, and B is 15
- **THEN** the rest achievement is 50.0%

#### Scenario: Achievement with the same vehicles

- **WHEN** the layovers in the base last 5, 20, 2 and 10 minutes, B is 15 and D is 6
- **THEN** the rest achievement now is 25.0% and the rest achievement with the same vehicles is 0.0%

#### Scenario: No lateness, no second achievement

- **WHEN** D is 0
- **THEN** only the rest achievement now is reported

#### Scenario: No layover

- **WHEN** the covered days hold no layover
- **THEN** no rest achievement, vehicle-hours, vehicles or curve are reported

#### Scenario: Layovers only at a pass-through end

- **WHEN** the covered days hold layovers ending only at a pass-through end
- **THEN** no rest achievement, vehicle-hours, vehicles or curve are reported, and the number of layovers at the pass-through end is reported

##### Example: Three pass-through layovers and nothing else

- **GIVEN** direction 0 is a pass-through end and direction 1 a stopping end, and one covered day holds three layovers ending in direction 0 lasting 2 minutes each and none ending in direction 1
- **WHEN** B is 15
- **THEN** the rest achievement, the vehicle-hours and the vehicles are absent, and 3 layovers at the pass-through end are reported

#### Scenario: No layover in the selected hours

- **WHEN** layovers at stopping ends exist on the covered days but none ends within the selected hours
- **THEN** no rest achievement, vehicle-hours, vehicles or curve are reported, and the number of layovers at stopping ends over all hours is reported

##### Example: hours without layovers

- **GIVEN** the four layovers of the example "Four layovers over two days"
- **WHEN** the selected hours are 12 to 13
- **THEN** the base is 0 layovers, nothing is estimated, and 4 layovers at stopping ends over all hours are reported

### Requirement: Added vehicle-hours as a range

The added vehicle-hours SHALL be reported as a lower and an upper bound for the minutes to hold H, each as a daily average over the covered days rounded to one decimal. The lower bound SHALL be the sum over the layovers in the base of the minutes each falls short of H, zero for a layover of at least H minutes; a layover shorter than D therefore adds more than B, the lateness it cannot absorb plus the rest. The upper bound SHALL be H minutes for every layover in the base. Layovers at pass-through ends SHALL add nothing to either bound. Both sums SHALL be divided by the number of covered days and by 60. With D of 0, H equals B and the bounds equal those of the buffer alone.

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

#### Scenario: Lateness on top of the rest

- **WHEN** the four layovers of the example "Four layovers over two days" are computed with B of 15 and D of 6
- **THEN** the lower bound is 0.4 vehicle-hours per day (47 minutes over 2 days) and the upper bound is 0.7 (84 minutes over 2 days)

#### Scenario: Lateness costs like rest at the same hold

- **WHEN** the four layovers of the example "Four layovers over two days" are computed once with B of 15 and D of 6 and once with B of 21 and D of 0
- **THEN** both give the bounds 0.4 and 0.7, while the rest achievement now is 25.0% for the first and 0.0% for the second

#### Scenario: Lateness longer than a layover

- **WHEN** a layover in the base lasts 2 minutes, B is 15 and D is 6
- **THEN** it adds 19 minutes to the lower sum, more than B, and 21 minutes to the upper sum

### Requirement: Added vehicles in the busiest hour

The added vehicles SHALL be estimated for the lower and the upper bound separately: the added minutes for H of each layover in the base SHALL be grouped by the Taipei hour of the layover's end time, each hour's sum divided by 60 and by the number of covered days, and the hour with the largest value reported with that value rounded to one decimal. When two hours have the same value, the earlier hour SHALL be reported. Every hour with a layover in the base SHALL also be reported, in hour order, with its lower and upper value rounded to one decimal. Layovers at pass-through ends SHALL NOT enter any hour. The estimate is an hourly average, not a schedule.

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

##### Example: Busiest hour with lateness

- **GIVEN** the four layovers of the example "Four layovers over two days"
- **WHEN** B is 15 and D is 6
- **THEN** the lower bound reports hour 8 with 0.2 vehicles (28 minutes over 2 days) and the upper bound reports hour 8 with 0.5 vehicles (63 minutes over 2 days)

#### Scenario: Every hour listed

- **WHEN** the added vehicles of every hour are reported
- **THEN** each hour with a layover in the base appears once, in hour order, with its lower and upper value

##### Example: hours 8 and 9

- **GIVEN** the four layovers of the example "Four layovers over two days" and B of 15
- **WHEN** D is 0
- **THEN** hour 8 has 0.1 and 0.4 vehicles and hour 9 has 0.1 and 0.1 vehicles
