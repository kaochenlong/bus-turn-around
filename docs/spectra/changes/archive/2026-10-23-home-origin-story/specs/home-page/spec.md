## MODIFIED Requirements

### Requirement: Home page content and order

The system SHALL serve `GET /` with these blocks in this order: a hero block with a one-question heading, one sentence naming the two numbers the site measures per route, and the hero picture; the origin story block; the route list; the data limitations; the data sources. The site name SHALL appear in the page body only in the site name bar of `site-layout`, not in the hero. Every block SHALL be present in the server response without JavaScript. The only page-specific script SHALL be the hero animation, which the home page alone loads on demand. The page SHALL NOT show any metric: no trip count, percentile, share or estimate. Figures quoted from the article that the origin story block cites, namely its times, its dates and the interval between two of its times, are not metrics; the page SHALL show them only inside the origin story block, next to the article's citation. Every date on the page SHALL come from stored route days, except the dates quoted from that article and its publication date, and the copy SHALL NOT promise an update cadence.

#### Scenario: Blocks in order

- **WHEN** a visitor requests `/`
- **THEN** the response is 200 and the blocks appear in the order hero, origin, routes, limitations, sources

#### Scenario: Complete without JavaScript

- **WHEN** route 9001 has the stored day 2026-10-20 and a visitor fetches `/` without running any script
- **THEN** the response already contains the hero picture, the origin story block with its link to the article, the 9001 entry with its latest day, the four limitations and the dataset links

#### Scenario: Site name once

- **WHEN** a visitor requests `/`
- **THEN** the text 折返點 TurnAround appears in the page body exactly once, inside the site name bar

## ADDED Requirements

### Requirement: Origin story block

The home page SHALL show, between the hero and the route list, a block that tells where the site started: the article 〈「我也開始搶黃燈了！」陽明交大碩士生開公車60天，把駕駛掙扎寫進論文推動排班改革〉, published by 《未來城市》 on 2026-07-31. The block SHALL contain a heading that quotes the title phrase 「我也開始搶黃燈了！」; one paragraph that names the driver, the route 中山幹線 and the operator 光華巴士, states that the schedule gives less time than a trip takes so that the driver makes up the difference by driving faster or resting less, and states that the site measures how long each bus actually stops at the end of the line before it leaves again; a list of the article's times in time order, each in a `time` element carrying its `datetime`: the 06:50 departure, the return to the station at 09:50 and the 10:00 departure, with the 10-minute interval between 09:50 and 10:00 marked as its own entry between those two, together with the article's quote 「幾乎只能跑步去上廁所」; a caption of the list that gives the start of the day at 06:30 and its end at 20:30; and the citation, made of the outlet, the title as a link to `https://futurecity.cw.com.tw/article/4090` and the publication date 2026-07-31 in a `time` element.

When route 15373 is in the route list configuration, the block SHALL link to `/routes/15373#layovers` and `/routes/15373#buffer`. When it is not, the block SHALL contain neither link and every other part of the block SHALL stay as it is. The block SHALL NOT read the database and SHALL NOT contain any figure computed by the site.

#### Scenario: Times in order with the interval between 09:50 and 10:00

- **WHEN** the origin story block is rendered
- **THEN** its list holds the departure at 06:50, the return at 09:50, the interval entry and the departure at 10:00, in that order

##### Example: entries of the list

| Position | Entry | `datetime` |
| -------- | ----- | ---------- |
| 1 | departure | 06:50 |
| 2 | return to the station | 09:50 |
| 3 | interval of 10 minutes with the quote 「幾乎只能跑步去上廁所」 | none |
| 4 | departure | 10:00 |

#### Scenario: Citation links to the article

- **WHEN** the origin story block is rendered
- **THEN** it contains exactly one link to `https://futurecity.cw.com.tw/article/4090` and a `time` element whose `datetime` is 2026-07-31

#### Scenario: Route links when 15373 has a route page

- **WHEN** the route list configuration contains 15373 and the origin story block is rendered
- **THEN** the block links to `/routes/15373#layovers` and to `/routes/15373#buffer`

#### Scenario: No route links without 15373

- **WHEN** the route list configuration contains only 9001 and the origin story block is rendered
- **THEN** the block contains no link to `/routes/15373`, and it still contains the list of times and the link to the article

#### Scenario: No database read

- **WHEN** the origin story block is rendered
- **THEN** no SQL query is issued
