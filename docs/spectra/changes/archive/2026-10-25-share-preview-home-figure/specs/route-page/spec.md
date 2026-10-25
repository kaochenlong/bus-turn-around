## ADDED Requirements

### Requirement: Document title and share text

When the page covers stored days, the page SHALL set its document title to the route name of the latest covered day, the separator ｜ and the site name, as 中山幹線｜折返點 TurnAround; a page with member routes SHALL use the page route's name alone. The page SHALL also set its share text, which the layout's `description`, `og:description` and `twitter:description` metas carry as defined by `site-layout`. The share text SHALL be one string composed of: the departure and destination of the latest covered day joined by －; a comma; the coverage, which for the range `day` is the selected day with its weekday followed by its day type, as 2026-10-22（四）平日, and for the range `7d` is 到 <day with weekday> 為止的最近 7 天，<day type> <count> 天 where count is the number of covered days; a colon; one clause per stopping end as defined by `turnaround-ends`, in direction order, joined by ；, reading 停車端<last stop>：量到 <count> 次折返停留，中位數 <p50> 分鐘，<share> 不到 15 分鐘 when the end has layovers over the covered days and 停車端<last stop>：折返停留 0 次 when it has none, or, when the route has no stopping end, 兩端都是直接折返，沒有停車的一端; a full stop; and the closing sentence 折返停留是駕駛休息的上限，不是工時。. The last stop, count, p50 and share of each clause SHALL be the values of that end's row in the layover table of the same page, formatted as the table formats minutes and shares, so that the share text and the summary key numbers never differ. When the selected day is not stored or the route has no stored days, the page SHALL set neither a title nor share text, so that the layout falls back to the site name and the site description.

#### Scenario: Title of a page with data

- **WHEN** route 9001's latest covered day has the route name 測試幹線 and `/routes/9001` is requested
- **THEN** the document title is 測試幹線｜折返點 TurnAround

#### Scenario: Member routes stay out of the title

- **WHEN** route 9001 lists 9050 under `member_routes` and `/routes/9001` is requested for a stored day
- **THEN** the document title is 測試幹線｜折返點 TurnAround, without any name or Id of 9050

#### Scenario: Share text with one stopping end

- **WHEN** route 9001 is configured with direction 0 as a pass-through end and direction 1 as a stopping end, the stored weekday 2026-10-19 has departure 甲站, destination 戊站 and the last stop 甲站 in direction 1, three layovers of 10, 20 and 30 minutes end in direction 1, and `/routes/9001?day=2026-10-19` is requested
- **THEN** the three description metas are 甲站－戊站，2026-10-19（一）平日：停車端甲站：量到 3 次折返停留，中位數 20.0 分鐘，33.3% 不到 15 分鐘。折返停留是駕駛休息的上限，不是工時。

#### Scenario: Share text with both ends stopping

- **WHEN** both ends of route 9001 are stopping ends, the stored weekday 2026-10-19 has the last stops 戊站 in direction 0 and 甲站 in direction 1, one layover of 5 minutes ends in direction 0 and three of 10, 20 and 30 minutes end in direction 1, and `/routes/9001?day=2026-10-19` is requested
- **THEN** the share text's clauses are 停車端戊站：量到 1 次折返停留，中位數 5.0 分鐘，100.0% 不到 15 分鐘；停車端甲站：量到 3 次折返停留，中位數 20.0 分鐘，33.3% 不到 15 分鐘

#### Scenario: Share text without a stopping end

- **WHEN** both ends of route 9001 are pass-through ends and `/routes/9001` is requested for a stored day
- **THEN** the share text's clause is 兩端都是直接折返，沒有停車的一端

#### Scenario: Stopping end without layovers

- **WHEN** direction 1 of route 9001 is a stopping end whose last stop is 甲站, no layover ends in direction 1 over the covered days, and `/routes/9001` is requested for a stored day
- **THEN** that end's clause is 停車端甲站：折返停留 0 次

#### Scenario: Coverage wording of the seven-day range

- **WHEN** route 9001 has the stored weekdays 2026-10-19 and 2026-10-20 and `/routes/9001?day=2026-10-20&range=7d` is requested
- **THEN** the coverage part of the share text is 到 2026-10-20（二）為止的最近 7 天，平日 2 天

##### Example: coverage wording per range

| Request | Covered days | Coverage part |
| ------- | ------------ | ------------- |
| `/routes/9001?day=2026-10-20` | 2026-10-20 | 2026-10-20（二）平日 |
| `/routes/9001?day=2026-10-20&range=7d` | 2026-10-19, 2026-10-20 | 到 2026-10-20（二）為止的最近 7 天，平日 2 天 |

#### Scenario: Share text uses the summary's values

- **WHEN** a stored day with layovers at a stopping end is rendered
- **THEN** the count, p50 and share in that end's clause of the share text equal the count, the p50 and the share of that end's line in the summary key numbers and in the layover table

#### Scenario: Selected day not stored

- **WHEN** `/routes/9001?day=2026-10-21` is requested and 9001 has no stored day 2026-10-21
- **THEN** the document title is 折返點 TurnAround and the three description metas are the site description
