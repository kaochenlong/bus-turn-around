## ADDED Requirements

### Requirement: Depots of the day's vehicles

For each route day the system SHALL record the depots of the vehicles that ran the route that day: each trip's depot SHALL be the `StationID` that occurs most often among the trip's `bus_event` records, the smaller `StationID` on a tie, and for each depot the system SHALL store the number of distinct vehicles and the number of trips. The depot's operator name and station name SHALL come from the row of the day's `GetProvider.gz` whose `stationId` equals it (`nameZn` and `stationNameZn`); when the day's static snapshot has no `GetProvider.gz`, the rows SHALL still be stored with empty names and the load SHALL print one line saying the day's depots have no names.

#### Scenario: One depot on the fixture day

- **WHEN** route 9001 is loaded for 2026-10-19, every event of TEST-0001 to TEST-0004 carrying `StationID` 19001, and `GetProvider.gz` lists `stationId` 19001 as 測試客運 測試站
- **THEN** the route day has one depot row: 測試客運, 測試站, 4 vehicles and as many trips as the day has

#### Scenario: Snapshot without GetProvider.gz

- **WHEN** the day's static snapshot has no `GetProvider.gz`
- **THEN** the depot rows are stored with empty operator and station names and the load prints one line about the missing names

#### Scenario: Majority vote per trip

- **WHEN** a trip has five events with `StationID` 19001 and one with `StationID` 19002
- **THEN** the trip counts under depot 19001

### Requirement: Depot inspection scores on the page

The turnaround facilities block SHALL show, after the two ends, a part listing the depots of the latest covered day in descending order of vehicles, each with its operator name, station name, number of vehicles and number of trips, or with 營業站 Id and the `StationID` when the names are empty. The part SHALL open with a sentence stating that a depot is the station the vehicles belong to and drivers report at, not necessarily the turnaround point, and that the scores are what 臺北市公共運輸處 recorded when it inspected the station for the 115年第1期 evaluation, copied from the report's appendix. For a depot listed with scores in `config/depot_inspections.yml`, the part SHALL show the nine configured items with both printed columns, written once when the two columns are equal and as 「a／b」 when they differ, together with the printed inspection date, the printed appendix page and a link to the report's announcement page. For a depot listed under `not_in_appendix` the part SHALL state that it is not in the inspection list of that term. For a depot in neither list the part SHALL state that it has not been checked against the list. The part SHALL NOT colour, rank or judge any score. When no covered day has depot rows the part SHALL say the days need to be loaded again.

#### Scenario: Depot with scores

- **WHEN** the latest covered day has the depot 測試客運 測試站 with 4 vehicles and 7 trips, and the test configuration lists it with 調度室環境 `[8, 9]`, 休憩室空間及環境 `[7, 7]`, 休憩室設施 `[6, 6]`, 盥洗室環境 `[5, 4]`, 禁菸環境 `[5, 5]`, 停車場使用情形 `[5, 5]`, 男女專用廁所或性別友善廁所 `[2, 2]`, 男女性專用休息室 `[2, 2]`, 總分 `[98, 97]`, inspected on 12月2日 at page A-99
- **THEN** the part shows 測試客運 測試站・4 輛・7 趟, the score of 調度室環境 as 8／9, of 休憩室空間及環境 as 7, of 盥洗室環境 as 5／4, of 總分 as 98／97, the words 檢查日期 12月2日 and 附錄 A-99, and a link to the announcement page

#### Scenario: Depot not in the appendix

- **WHEN** the latest covered day has the depot 測試客運 測試二站 and the test configuration lists it under `not_in_appendix`
- **THEN** the part shows that 測試二站 is not in the inspection list of 115 年第 1 期, with no scores

#### Scenario: Depot not yet checked

- **WHEN** the latest covered day has the depot 測試客運 測試三站, which the configuration mentions nowhere
- **THEN** the part shows that 測試三站 has not been checked against the inspection list

##### Example: three depots on one day

| Depot row of the latest day | In `depots` | In `not_in_appendix` | Status shown |
| --- | --- | --- | --- |
| 測試客運 測試站, 4 vehicles | yes | no | nine scores, 檢查日期 12月2日, 附錄 A-99 |
| 測試客運 測試二站, 2 vehicles | no | yes | 不在 115 年第 1 期的查核名單 |
| 測試客運 測試三站, 1 vehicle | no | no | 這個調度站還沒對過查核名單 |

#### Scenario: Names missing

- **WHEN** a depot row has `station_id` 19005 and empty names
- **THEN** the part names it 營業站 Id 19005

#### Scenario: Days loaded before depots existed

- **WHEN** no covered day has depot rows
- **THEN** the part says the days need to be loaded again, as the toilets part does

##### Example: a day stored before the table existed

- **GIVEN** route 9001's only covered day 2026-10-19 was loaded before `route_day_depots` existed, so it has end rows and toilets but no depot rows
- **WHEN** the page is rendered
- **THEN** the toilets of both ends show as before, and the depot part consists of the one sentence that the days need to be loaded again with `bin/rails derived:load`
