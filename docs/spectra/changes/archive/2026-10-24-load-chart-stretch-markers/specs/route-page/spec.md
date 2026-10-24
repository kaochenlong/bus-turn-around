## MODIFIED Requirements

### Requirement: Load chart along the route

The page SHALL show, per direction, a line chart of the load profile as defined by `load-profile` over the covered days: the horizontal axis SHALL be the stop sequence of the latest covered day, and the vertical axis the median on-board count at each stop. The chart SHALL offer the time bands morning peak, daytime, evening peak and other, one shown at a time, morning peak shown first; switching bands SHALL NOT reload the page. All bands of one direction SHALL share one vertical scale whose top is at least the largest median of that direction in any band. A stop without a count in the shown band SHALL break the line instead of being filled. The overlap stretches at 500 metres as defined by `mrt-overlap` SHALL be drawn as shaded spans over their first to last sequence numbers, without any review threshold; when the stops carry no nearest-entrance distance, no span SHALL be drawn. The chart SHALL name the first and last stop of the direction. Each shaded span SHALL carry a number, counted from 1 in stop order within its direction, and the chart SHALL NOT contain any text naming a span. Below each direction's chart, outside the area that scrolls sideways, the page SHALL list that direction's spans in the same order, each entry giving the span's number and the first and last stop of the span; a direction without a shaded span SHALL have no such list. While the pointer rests on a shaded span, including its number, or on its entry in that list, the page SHALL highlight that span and that entry and no other span or entry, and the highlight SHALL end when the pointer leaves them; pointing SHALL NOT be needed to read any span's name.

Below 640 px wide, the page SHALL show the same medians as one row per stop of the latest covered day instead of the line chart, in stop order, each row giving the stop name, a bar whose length is proportional to the median on the direction's shared scale, and the median, with the same time bands and band switch as the chart. A stop without a count in the shown band SHALL show a dash and no bar. The rows of each overlap stretch at 500 metres SHALL be shaded, and the stretch SHALL be named with its first and last stop before its first row; when the stops carry no nearest-entrance distance, no row SHALL be shaded.

#### Scenario: Points per band

- **WHEN** direction 0 has medians 3.0 at sequence 0 and 8.0 at sequence 1 in the morning peak, and 5.0 at sequence 0 in the daytime
- **THEN** the morning peak line has points at sequence 0 with 3.0 and sequence 1 with 8.0, and the daytime line has one point at sequence 0 with 5.0 and a break at sequence 1

#### Scenario: Shared scale

- **WHEN** direction 0's largest median is 8.0 in the morning peak and 5.0 in the daytime
- **THEN** both bands of direction 0 use the same vertical scale, whose top is at least 8.0

#### Scenario: Shaded overlap stretch

- **WHEN** direction 0 has an overlap stretch at 500 metres from sequence 2 to sequence 4
- **THEN** direction 0's chart has one shaded span from sequence 2 to sequence 4 carrying the number 1, and the list below direction 0's chart has one entry, 1, named with the stops at those sequences

#### Scenario: Spans numbered in stop order

- **WHEN** direction 0 has two overlap stretches at 500 metres, one from sequence 0 to sequence 1 and one from sequence 3 to sequence 4
- **THEN** the span over sequences 0 to 1 carries the number 1 and the span over sequences 3 to 4 carries the number 2, the list below direction 0's chart gives entry 1 before entry 2, each named with the first and last stop of its span, and no text inside the chart names either span

##### Example: two stretches

- **GIVEN** direction 0's stops at sequences 0 to 4 are 甲站, 乙站, 丙站, 丁站, 戊站 with nearest-entrance distances 400, 450, 900, 250 and 300 metres
- **WHEN** the page is rendered
- **THEN** the spans carry 1 over sequences 0 to 1 and 2 over sequences 3 to 4, and the list below the chart reads 1 甲站–乙站, then 2 丁站–戊站

#### Scenario: Distances missing on the chart

- **WHEN** the stops of the covered days carry no nearest-entrance distance
- **THEN** the load charts show their lines and no shaded span, no span number, and no list of spans below the charts

##### Example: no distances

- **GIVEN** direction 0's stops at sequences 0 to 4 carry no nearest-entrance distance, and sequence 0 has a morning peak count of 3
- **WHEN** the page is rendered
- **THEN** direction 0's chart has its line, no shaded span, no span number, and no list below it

#### Scenario: Pointing at a list entry

- **WHEN** direction 0 has spans numbered 1 and 2 and the pointer rests on entry 2 of the list below direction 0's chart
- **THEN** span 2 and entry 2 of direction 0 are highlighted, and no other span or entry on the page is

##### Example: second entry of two

- **GIVEN** direction 0's stops at sequences 0 to 4 are 甲站, 乙站, 丙站, 丁站, 戊站 with nearest-entrance distances 400, 450, 900, 250 and 300 metres, and direction 1's stops at sequences 5 to 9 have 300, 350, 900, 900 and 900 metres
- **WHEN** the pointer rests on direction 0's entry 2, 丁站–戊站
- **THEN** the highlighted elements are direction 0's span 2 and entry 2 only

#### Scenario: Pointing at a span

- **WHEN** direction 0 has spans numbered 1 and 2, direction 1 has a span numbered 1, and the pointer rests on the number of direction 0's span 1
- **THEN** span 1 and entry 1 of direction 0 are highlighted, and direction 1's span 1 and entry 1 and every other span or entry are not

#### Scenario: Pointer moved away

- **WHEN** the pointer leaves a highlighted span or entry for a place outside every span and entry
- **THEN** no span or entry is highlighted

#### Scenario: Rows on a narrow screen

- **WHEN** direction 0 has a morning peak median of 3.0 at sequence 0 and no count at sequence 1
- **THEN** direction 0's per-stop rows for the morning peak give 3.0 with a bar at sequence 0, and a dash without a bar at sequence 1

#### Scenario: Shaded rows

- **WHEN** direction 0 has an overlap stretch at 500 metres from sequence 2 to sequence 4
- **THEN** direction 0's per-stop rows at sequences 2 to 4 are shaded, and the stretch is named with the stops at sequences 2 and 4 before the row of sequence 2
