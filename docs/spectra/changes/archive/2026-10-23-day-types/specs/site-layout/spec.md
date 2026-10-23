## MODIFIED Requirements

### Requirement: Attribution footer on every page

Every HTML page SHALL end with one footer that carries, verbatim, the three-line attribution statement for the Taipei bus open data recorded in docs/data-sources.md; one line attributing the MRT entrance coordinates dataset to 臺北大眾捷運股份有限公司 under the same licence; one line attributing the office calendar dataset (data.gov.tw/dataset/14718) to 行政院人事行政總處 under the same licence; and one sentence stating that providing the data does not mean the agency recommends, agrees with or approves this project. The footer SHALL be marked with `data-attribution` and `data-license="OGDL-Taiwan-1.0"` and SHALL NOT carry a `data-section` attribute, so that the route page's block order is unchanged.

#### Scenario: Footer on the home page

- **WHEN** `/` is requested
- **THEN** exactly one `footer[data-attribution][data-license="OGDL-Taiwan-1.0"]` is present

#### Scenario: Footer on a route page

- **WHEN** `/routes/9001` is requested and 9001 has no stored days
- **THEN** the response is 200, exactly one `footer[data-attribution][data-license="OGDL-Taiwan-1.0"]` is present, and no element with `data-section` is inside it

#### Scenario: Office calendar line in the footer

- **WHEN** `/` is requested
- **THEN** the footer contains one line naming 行政院人事行政總處, 中華民國政府行政機關辦公日曆表 and data.gov.tw/dataset/14718
