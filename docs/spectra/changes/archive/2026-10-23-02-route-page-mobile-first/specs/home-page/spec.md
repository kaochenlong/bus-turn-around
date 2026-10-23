## MODIFIED Requirements

### Requirement: Home page content and order

The system SHALL serve `GET /` with these blocks in this order: a hero block with a one-question heading, one sentence naming the two numbers the site measures per route, and the hero picture; the route list; the data limitations; the data sources. The site name SHALL appear in the page body only in the site name bar of `site-layout`, not in the hero. Every block SHALL be present in the server response without JavaScript. The only page-specific script SHALL be the hero animation, which the home page alone loads on demand. The page SHALL NOT show any metric: no trip count, percentile, share or estimate. Every date on the page SHALL come from stored route days, and the copy SHALL NOT promise an update cadence.

#### Scenario: Blocks in order

- **WHEN** a visitor requests `/`
- **THEN** the response is 200 and the blocks appear in the order hero, routes, limitations, sources

#### Scenario: Complete without JavaScript

- **WHEN** route 9001 has the stored day 2026-10-20 and a visitor fetches `/` without running any script
- **THEN** the response already contains the hero picture, the 9001 entry with its latest day, the four limitations and the dataset links

#### Scenario: Site name once

- **WHEN** a visitor requests `/`
- **THEN** the text 折返點 TurnAround appears in the page body exactly once, inside the site name bar
