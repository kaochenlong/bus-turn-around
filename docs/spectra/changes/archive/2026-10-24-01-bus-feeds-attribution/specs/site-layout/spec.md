## MODIFIED Requirements

### Requirement: Attribution footer on every page

Every HTML page SHALL end with one footer that carries, verbatim, the three-line attribution statement for the Taipei bus open data recorded in docs/data-sources.md, whose first line SHALL name every feed of 臺北市公共運輸處 that the derived tables and the health card are built from; one line attributing the MRT entrance coordinates dataset to 臺北大眾捷運股份有限公司 under the same licence; one line attributing the office calendar dataset (data.gov.tw/dataset/14718) to 行政院人事行政總處 under the same licence; one line attributing the national public toilet registry (data.gov.tw/dataset/30794) to 環境部 under the same licence; one line carrying the basemap attribution configured in `config/map.yml` as defined by `turnaround-map`; and one sentence stating that providing the data does not mean the agency recommends, agrees with or approves this project. The footer SHALL be marked with `data-attribution` and `data-license="OGDL-Taiwan-1.0"` and SHALL NOT carry a `data-section` attribute, so that the route page's block order is unchanged.

#### Scenario: Footer on the home page

- **WHEN** `/` is requested
- **THEN** exactly one `footer[data-attribution][data-license="OGDL-Taiwan-1.0"]` is present

#### Scenario: Footer on a route page

- **WHEN** `/routes/9001` is requested and 9001 has no stored days
- **THEN** the response is 200, exactly one `footer[data-attribution][data-license="OGDL-Taiwan-1.0"]` is present, and no element with `data-section` is inside it

#### Scenario: Statement as recorded

- **WHEN** `/` is requested
- **THEN** the footer's three statement lines are, in order and character for character, the three quoted paragraphs of the 授權 section of docs/data-sources.md

#### Scenario: Every bus feed named

- **WHEN** the site's code reads a feed of 臺北市公共運輸處, either as a folder of hourly files passed to `day_files` in `analysis/` or as a snapshot file whose name starts with `Get` and ends with `.gz`
- **THEN** the first line of the statement names that feed by its code

##### Example: feeds read today

| Read by the code | Named in the first line |
| --- | --- |
| `bus_event` hourly files | GetBusEvent |
| `bus_seat_event` hourly files | BusSeatEvent |
| `bus_data` hourly files | GetBusData |
| `GetRoute.gz` | GetRoute |
| `GetStop.gz` | GetStop |
| `GetPathDetail.gz` | GetPathDetail |

#### Scenario: Office calendar line in the footer

- **WHEN** `/` is requested
- **THEN** the footer contains one line naming 行政院人事行政總處, 中華民國政府行政機關辦公日曆表 and data.gov.tw/dataset/14718

#### Scenario: Public toilet line in the footer

- **WHEN** `/` is requested
- **THEN** the footer contains one line naming 環境部, 全國公廁建檔資料 and data.gov.tw/dataset/30794

#### Scenario: Basemap line in the footer

- **WHEN** `/` is requested in the test environment
- **THEN** the footer contains one line that is the basemap attribution of the test environment in `config/map.yml`, 測試用空白底圖
