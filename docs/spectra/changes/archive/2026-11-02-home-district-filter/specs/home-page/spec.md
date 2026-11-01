## MODIFIED Requirements

### Requirement: Home page content and order

The system SHALL serve `GET /` with these blocks in this order: a hero block with a one-question heading, one sentence naming the two numbers the site measures per route, and the hero picture; the origin story block; the route list; the data limitations; the data sources. The site name SHALL appear in the page body only in the site name bar of `site-layout`, not in the hero. Every block SHALL be present in the server response without JavaScript. The page-specific scripts SHALL be the hero animation, which the home page alone loads on demand, and the district filter of the route list described by the requirement "Route list district filter", which only hides entries already in the response. The page SHALL show no metric other than the stop-end figure of each route list entry that the requirement "Route list" describes: no trip count, percentile or estimate anywhere else, and no figure of another kind on an entry. Figures quoted from the article that the origin story block cites, namely its times, its dates and the interval between two of its times, are not metrics; the page SHALL show them only inside the origin story block, next to the article's citation. Every date on the page SHALL come from stored route days, except the dates quoted from that article and its publication date, and the copy SHALL NOT promise an update cadence.

#### Scenario: Blocks in order

- **WHEN** a visitor requests `/`
- **THEN** the response is 200 and the blocks appear in the order hero, origin, routes, limitations, sources

#### Scenario: Complete without JavaScript

- **WHEN** route 9001 has the stored day 2026-10-20 and a visitor fetches `/` without running any script
- **THEN** the response already contains the hero picture, the origin story block with its link to the article, the 9001 entry with its latest day, the four limitations and the dataset links

#### Scenario: Site name once

- **WHEN** a visitor requests `/`
- **THEN** the text 折返點 TurnAround appears in the page body exactly once, inside the site name bar

#### Scenario: No percentage outside the route list

- **WHEN** route 9001 has a stored day whose stopping end has layovers and a visitor requests `/`
- **THEN** the 9001 entry carries its figure block, and no text outside the route list block matches a percentage such as 33.3%

## ADDED Requirements

### Requirement: Route list district filter

The route list SHALL offer a district filter: a select labelled 行政區 in the heading row of the list, whose options are the districts in which at least one listed route qualifies on its latest stored day, as stored in `route_day_districts` as defined by `stop-districts`, read with one query for all the listed routes' latest days; there is no option for every route. The default district SHALL be 中山區 when it is an option and the first option otherwise, and the server SHALL render the response with the default already applied: the default option selected, every entry outside it carrying the `hidden` attribute, and the line below the list written for it. A district SHALL be named by its town alone when its county is 臺北市 and by its county and town otherwise, and the options SHALL be ordered with the districts of 臺北市 first, then the other counties by county name, and within a county by town name, compared by code point in the application rather than by a database collation. Every entry whose route has stored days SHALL carry `data-districts` holding the names of the districts it qualifies in, separated by spaces. Selecting a district SHALL hide, in the browser, every entry that does not carry that name, keep the order and content of the remaining entries unchanged, write the line stating the district and the number of entries shown as 士林區：1 條, and set the page address's query parameter `district` to the name. On load, a `district` parameter naming one of the options SHALL be applied as if selected, and any other value SHALL leave the default district applied; the address SHALL NOT be changed until the visitor changes the selection. Without JavaScript every entry SHALL be present in the response and the page SHALL stay on the default district. When no listed route with stored days has a stop district snapshot day on its latest stored day, the list SHALL show the sentence 這幾天的資料還沒有行政區 in place of the select; when some have and some have not, the select SHALL be shown, the line SHALL add ，另有 N 條的資料還沒有行政區 with N those routes, and their entries SHALL be hidden under every district. The line and the select are not metrics of a route and SHALL stay outside the entries.

#### Scenario: Options from the latest days

- **WHEN** route 9001's latest stored day has the qualifying districts 臺北市 測試區 and 新北市 甲區 and the non-qualifying district 臺北市 乙區, and route 15373's latest stored day has the qualifying district 臺北市 士林區
- **THEN** the select's options are, in order, 士林區, 測試區 and 新北市甲區, with 士林區 selected since 中山區 is not among them; the 9001 entry carries `data-districts="測試區 新北市甲區"` and the `hidden` attribute, the 15373 entry carries `data-districts="士林區"` and no `hidden`, and the line reads 士林區：1 條

##### Example: district names

| county | town | name |
| --- | --- | --- |
| 臺北市 | 士林區 | 士林區 |
| 新北市 | 新莊區 | 新北市新莊區 |
| 臺北市 | 中正區 | 中正區 |

#### Scenario: Default district

- **WHEN** route 9001's latest stored day has the qualifying district 臺北市 中山區 and route 15373's has 臺北市 士林區
- **THEN** 中山區 is selected and the 15373 entry carries `hidden`

#### Scenario: Filtering in the browser

- **WHEN** a visitor on `/` with the routes of the first scenario selects 測試區
- **THEN** only the 9001 entry is visible, the line reads 測試區：1 條, and the page address ends with `?district=測試區`; selecting 士林區 afterwards shows only the 15373 entry and sets the parameter to 士林區

#### Scenario: District in the address on load

- **WHEN** a visitor opens `/?district=新北市甲區`
- **THEN** 新北市甲區 is selected, only the 9001 entry is visible and the line reads 新北市甲區：1 條

#### Scenario: Unknown district in the address

- **WHEN** a visitor opens `/?district=天母`
- **THEN** the default district stays selected and applied, and the address is left as it is

#### Scenario: Without JavaScript

- **WHEN** `/` is fetched without running any script
- **THEN** the response holds the select with its options, every entry, the `hidden` attribute on the entries outside the default district and the line written for it

#### Scenario: No district data yet

- **WHEN** no listed route's latest stored day has a stop district snapshot day
- **THEN** the list shows 這幾天的資料還沒有行政區 and no select

#### Scenario: Some routes without district data

- **WHEN** route 9001's latest stored day has a stop district snapshot day and qualifying districts, and route 15373's latest stored day has none
- **THEN** the select is shown with 測試區 selected, the line reads 測試區：1 條，另有 1 條的資料還沒有行政區, and the 15373 entry is hidden
