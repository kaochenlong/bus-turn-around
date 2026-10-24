## MODIFIED Requirements

### Requirement: Limitations and attribution text

The 資料限制 section SHALL state: the vehicle is not the driver and layover is an upper bound on rest; the on-board count depends on alighting tap rates and the reset logic; 10-second polling misses stops; same-second arrival and departure records collapse to one; the card uses a single day and its percentiles are for definition testing only. The 資料來源與授權 section SHALL reproduce verbatim the three attribution paragraphs of the 授權 subsection of `docs/data-sources.md`.

#### Scenario: Attribution reproduced

- **WHEN** the card is generated
- **THEN** the 資料來源與授權 section contains the line beginning `臺北市公共運輸處 2026 臺北市公車開放資料`, which names GetRoute, GetStop and GetPathDetail as well as GetBusData, GetBusEvent and BusSeatEvent, and the URL `https://data.gov.tw/license`
