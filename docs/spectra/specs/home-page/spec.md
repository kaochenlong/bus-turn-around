# home-page Specification

## Purpose

The root page of the site, `GET /`: what the site is, which routes have a route page and how recent their stored data is, what the numbers can and cannot tell, and where the data comes from. It reads only the derived table of stored route days and shows no metric, so that every number keeps living on the route page next to its definition and its data limitations.

## Requirements

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


<!-- @trace
source: home-origin-story
updated: 2026-10-23
code:
  - app/components/origin_story_component.yml
  - app/views/pages/home.html.erb
  - docs/background.md
  - app/components/origin_story_component.rb
  - app/components/origin_story_component.html.erb
tests:
  - spec/requests/pages_spec.rb
  - spec/components/origin_story_component_spec.rb
-->

---
### Requirement: Route list

The route list SHALL contain one entry per route Id in the route list configuration, in configuration order, built from one query for the latest stored day of every configured route. An entry whose route has stored days SHALL show the route name, the Id, the departure and destination of the latest stored day, and that day with its weekday in the format the route page uses for covered days, followed by its day type as defined by `day-types`, and SHALL link to `/routes/<Id>`. An entry whose route has no stored days SHALL show only the Id, SHALL state that the route has no data yet, and SHALL NOT link anywhere.

#### Scenario: Entries in configuration order

- **WHEN** the configuration lists 15373 then 9001, 15373 has no stored days and 9001 has the stored days 2026-10-19 and 2026-10-20
- **THEN** the list shows 15373 first, marked as having no data and without a link, then 9001 with the latest day 2026-10-20 and a link to `/routes/9001`

##### Example: entry of a route with data

- **GIVEN** route 9001 has the stored weekdays 2026-10-19 and 2026-10-20 whose latest row has route name 測試幹線, departure 甲站 and destination 戊站
- **WHEN** `/` is requested
- **THEN** the 9001 entry shows 測試幹線, 9001, 甲站－戊站 and 2026-10-20（二）平日

#### Scenario: Latest day is a holiday

- **WHEN** route 9001's latest stored day is the holiday 2026-10-26
- **THEN** the 9001 entry shows 2026-10-26（一）假日

#### Scenario: Latest day of every route in one query

- **WHEN** two configured routes each have several stored days and the route list is built
- **THEN** the route days are read with a single query and each entry carries its route's latest day

##### Example: two routes, three days each

- **GIVEN** the configuration lists 15373 then 9001, 15373 has stored days 2026-10-19, 2026-10-20 and 2026-10-21, and 9001 has stored days 2026-10-18, 2026-10-19 and 2026-10-20
- **WHEN** the route list is built
- **THEN** exactly one SELECT on route_days is issued, and the entries are 15373 with 2026-10-21 followed by 9001 with 2026-10-20


<!-- @trace
source: day-types
updated: 2026-10-23
code:
  - lib/tasks/external.rake
  - app/models/office_calendar_snapshot.rb
  - docs/data-sources.md
  - config/locales/tw.yml
  - app/models/route_day_loader.rb
  - app/components/data_limitations_component.yml
  - app/components/route_coverage_component.rb
  - app/components/route_coverage_component.yml
  - app/models/mrt_exits_snapshot.rb
  - app/components/route_coverage_component.html.erb
  - db/schema.rb
  - app/components/route_list_component.html.erb
  - db/migrate/20261022230942_add_day_type_to_route_days.rb
  - spec/factories/route_days.rb
  - app/components/attribution_component.html.erb
  - app/components/attribution_component.yml
  - config/locales/en.yml
  - spec/fixtures/analysis/README.md
  - app/models/route_page/coverage.rb
  - app/components/application_component.rb
  - app/components/route_list_component.yml
  - app/models/http_fetcher.rb
  - spec/fixtures/analysis/external/office-calendar/2026/2026-10-19.csv
  - app/models/route_day.rb
  - db/migrate/20261022231802_require_day_type_on_route_days.rb
tests:
  - spec/components/mrt_overlap_component_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/components/route_summary_component_spec.rb
  - spec/models/route_page/buffer_trade_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/components/load_profile_table_component_spec.rb
  - spec/components/run_time_table_component_spec.rb
  - spec/system/home_hero_spec.rb
  - spec/models/http_fetcher_spec.rb
  - spec/models/route_day_spec.rb
  - spec/components/buffer_trade_component_spec.rb
  - spec/components/layover_chart_component_spec.rb
  - spec/components/load_chart_component_spec.rb
  - spec/components/application_component_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/route_page/coverage_spec.rb
  - spec/components/layover_table_component_spec.rb
  - spec/components/route_list_component_spec.rb
  - spec/models/home_page/route_list_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/models/office_calendar_snapshot_spec.rb
  - spec/requests/pages_spec.rb
  - spec/requests/routes_spec.rb
  - spec/models/route_page/layover_distribution_spec.rb
  - spec/models/route_page/run_times_spec.rb
  - spec/components/route_coverage_component_spec.rb
-->

---
### Requirement: Hero picture

The hero block SHALL show the illustration in two framings from the same scene: a wide framing for viewports of at least 640 px and a narrow framing below that. The server response SHALL contain the illustration as a static image asset: a `picture` whose source for narrow viewports is the narrow image with width and height in its proportions, and an `img` of the wide image with explicit width and height and a non-empty `alt` sentence describing the scene. Both image files SHALL exist under `app/assets/images/`, the wide file SHALL be at most 200 KB and the narrow file at most 120 KB.

When scripts run, the visitor does not prefer reduced motion and WebGL is available, the home page SHALL keep the illustration's box reserved without showing the static image, load the 3D library and play the turnaround on a loop, starting with the bus driving in. In each lap, the bus drives into the terminal and stops, the front door opens and the driver steps out and rests beside the bus; the driver then walks back in, the bus pulls up to the stop, where the waiting riders board, and drives out of the block; new riders walk to the stop and the next bus drives in. The moment of each lap at which the driver rests beside the bus, called the still, SHALL have the same composition as the static image. The animation SHALL NOT show a clock, a countdown or any other figure. The framing SHALL follow the viewport width, whether the animation is rendering or not. In the narrow framing, the view SHALL rest on the terminal and SHALL move to the stop together with the bus as it pulls up there, so that the riders boarding, the bus leaving and the new riders walking in are in view; it SHALL stay on the stop for the rest of the lap and SHALL move back to the terminal at the start of the next lap, as the next bus comes in. At the still the narrow framing SHALL be on the terminal.

The hero SHALL show a pause button inside the illustration's box while the animation plays or is paused, and at no other time. Pressing the button SHALL stop rendering on the current frame and change its label to offer resuming; pressing it again SHALL continue the lap from that frame and change the label back. The animation SHALL NOT render while less than half of the illustration's box is inside the viewport, and SHALL continue the lap from where it stopped once at least half of the box is back. Coming back to the home page SHALL start a new lap that is not paused, even when the animation was paused before leaving.

When the visitor prefers reduced motion, the page SHALL show the static image and SHALL NOT request the 3D library. When WebGL is unavailable or the animation fails to load, the page SHALL show the static image. When no script takes over the hero within 3 seconds, the static image SHALL become visible. In each of these cases the pause button SHALL NOT be visible. Pages other than the home page SHALL NOT request the 3D library.

#### Scenario: Picture element

- **WHEN** `/` is requested
- **THEN** the hero block contains a `picture` with a `source` whose media query is `(max-width: 639px)`, whose srcset is the narrow image and whose width and height have the narrow image's proportions, and an `img` whose src is the wide image with width, height and a non-empty alt

#### Scenario: Image files within budget

- **WHEN** the files `app/assets/images/home-hero-wide.webp` and `app/assets/images/home-hero-narrow.webp` are checked
- **THEN** both exist, the wide file is at most 200 KB and the narrow file is at most 120 KB

#### Scenario: Animation keeps playing after one lap

- **WHEN** a visitor whose browser runs scripts, has WebGL and does not prefer reduced motion opens `/` and keeps the whole illustration in the viewport
- **THEN** the hero shows a canvas in place of the static image, and one lap after the animation started it still renders new frames and is not paused

#### Scenario: Still matches the static image

- **WHEN** the scene is posed at the still with each framing and exported as the static images are
- **THEN** the exported images are pixel-identical to the committed static images

##### Example: both framings at the still

- **GIVEN** the committed `home-hero-wide.webp` of 2048×976 pixels and `home-hero-narrow.webp` of 1170×780 pixels
- **WHEN** the scene is posed at the still and exported with the wide and the narrow framing
- **THEN** comparing each export with its committed file reports 0 differing pixels

#### Scenario: Narrow framing follows the bus to the stop

- **WHEN** the scene is rendered with the narrow framing at a moment of the lap
- **THEN** the frame shows where the story is at that moment: the terminal while the driver rests, the stop while the riders board and new riders walk in

##### Example: seconds into the lap

| Seconds | In the narrow frame |
| ------- | ------------------- |
| 0 | the stop with the riders waiting and no bus, before the view moves back to the terminal |
| 5.5 | the bus at the terminal with the driver resting beside it |
| 14.4 | the bus at the stop with the riders boarding |
| 19.6 | the stop with the new riders walking in |

#### Scenario: Pausing and resuming with the pause button

- **WHEN** the visitor presses the pause button while the animation plays, and then presses it again
- **THEN** rendering stops on the current frame with the label offering to resume, and then continues with the label offering to pause

##### Example: states of the hero and the button

| Step | `data-hero` | Label shown | New frames |
| ---- | ----------- | ----------- | ---------- |
| the animation plays | `playing` | pause | yes |
| the visitor presses the button | `paused` | resume | none |
| the visitor presses it again | `playing` | pause | yes |

#### Scenario: Illustration scrolled out of view stops rendering

- **WHEN** the visitor scrolls until less than half of the illustration's box is inside the viewport, and later scrolls back
- **THEN** no new frame is rendered while less than half is inside, and the lap continues once at least half is back

##### Example: share of the box inside the viewport

| Share of the illustration's box inside the viewport | New frames |
| --------------------------------------------------- | ---------- |
| all of it | yes |
| less than half | none |
| half or more again | yes, continuing the lap |

#### Scenario: Reduced motion keeps the static image

- **WHEN** a visitor who prefers reduced motion opens `/`
- **THEN** the static image is visible, no canvas is added, the pause button is not visible and the 3D library is not requested

#### Scenario: No WebGL keeps the static image

- **WHEN** a visitor whose browser has no WebGL opens `/`
- **THEN** the static image is visible, no canvas is added and the pause button is not visible

#### Scenario: Animation that fails to load falls back

- **WHEN** the animation's script cannot be loaded
- **THEN** the static image is visible and the pause button is not visible

##### Example: the animation's script is blocked

- **GIVEN** a browser that runs scripts, has WebGL and does not prefer reduced motion, and that blocks the request for the animation's script
- **WHEN** it opens `/`
- **THEN** the static image is visible, no canvas is added and the pause button is not visible

#### Scenario: Static image appears when no script takes over

- **WHEN** the browser has scripting enabled but the page's scripts do not run
- **THEN** the static image becomes visible within 3 seconds and the pause button is not visible

#### Scenario: Route pages do not load the animation

- **WHEN** a visitor opens `/routes/9001`
- **THEN** neither the animation's script nor the 3D library is requested

#### Scenario: Returning to the home page

- **WHEN** a visitor pauses the animation, goes from `/` to a route page and comes back
- **THEN** no stale canvas remains, the page Turbo restores from its cache is in the server's state, and the animation plays again, not paused

#### Scenario: Framing follows the viewport width

- **WHEN** the viewport is narrower than 640 px while the animation plays and is then widened past 640 px
- **THEN** the animation uses the narrow framing first and the wide framing after the widening

#### Scenario: Framing changes while paused

- **WHEN** the animation is paused and the viewport is then narrowed below 640 px
- **THEN** the narrow framing is rendered once, without requesting animation frames, and the animation stays paused


<!-- @trace
source: home-hero-turnaround-loop
updated: 2026-10-24
code:
  - app/frontend/stylesheets/application.css
  - config/deploy.yml
  - app/assets/images/home-hero-narrow.webp
  - app/components/home_hero_component.rb
  - tools/hero/export.js
  - config/database.yml
  - app/components/home_hero_component.html.erb
  - config/environments/production.rb
  - app/components/home_hero_component.yml
  - app/components/origin_story_component.html.erb
  - docs/background.md
  - tools/hero/index.html
  - .kamal/secrets
  - app/frontend/hero/runtime.js
  - app/components/origin_story_component.yml
  - app/assets/images/home-hero-wide.webp
  - app/components/origin_story_component.rb
  - app/assets/images/home-hero-tall.webp
  - app/views/pages/home.html.erb
  - app/frontend/hero/scene.js
  - app/frontend/entrypoints/application.js
tests:
  - spec/assets/home_hero_images_spec.rb
  - spec/components/home_hero_component_spec.rb
  - spec/components/origin_story_component_spec.rb
  - spec/requests/pages_spec.rb
  - spec/system/home_hero_spec.rb
-->

---
### Requirement: Data limitations on the home page

The home page SHALL state the four general limitations of the data: a vehicle is not a driver and a layover is an upper bound on rest; on-board counts come from fare-card taps, not head counts, and depend on how many riders tap off; polling every 10 seconds misses stops; events can repeat across hourly files and are de-duplicated again before analysis. The route page SHALL keep rendering its own limitation list, which this capability does not alter.

#### Scenario: Four items on the home page

- **WHEN** `/` is requested
- **THEN** the limitations block lists exactly four items

#### Scenario: Route page list untouched

- **WHEN** the limitations component is rendered for the route page
- **THEN** it lists every item of the route page's own list and none of the home page's four

##### Example: route scope follows the route list in the component's translation file

- **GIVEN** the component's translation file has N entries under `items` and four entries under `home_items`
- **WHEN** the component is rendered with the route scope
- **THEN** it renders exactly N list items, and none of the four `home_items` sentences appears among them


<!-- @trace
source: home-page
updated: 2026-10-23
code:
  - app/assets/images/home-hero-tall.webp
  - app/components/route_coverage_component.rb
  - app/components/route_list_component.yml
  - app/controllers/pages_controller.rb
  - app/assets/images/home-hero-wide.webp
  - app/components/data_limitations_component.rb
  - config/locales/en.yml
  - config/locales/tw.yml
  - app/frontend/hero/scene.js
  - app/components/route_list_component.html.erb
  - app/components/attribution_component.yml
  - app/components/data_limitations_component.html.erb
  - app/frontend/hero/runtime.js
  - .dockerignore
  - app/frontend/entrypoints/application.js
  - app/views/pages/home.html.erb
  - spec/support/system.rb
  - package.json
  - tools/hero/export.js
  - app/frontend/stylesheets/application.css
  - tools/hero/index.html
  - app/components/home_hero_component.yml
  - app/components/route_list_component.rb
  - app/components/attribution_component.rb
  - app/components/attribution_component.html.erb
  - app/components/data_sources_component.yml
  - app/components/home_hero_component.html.erb
  - app/components/data_limitations_component.yml
  - .rubocop.yml
  - app/models/home_page/route_list.rb
  - app/components/data_sources_component.html.erb
  - app/views/layouts/application.html.erb
  - app/components/application_component.rb
  - app/components/data_sources_component.rb
  - app/components/home_hero_component.rb
tests:
  - spec/requests/site_layout_spec.rb
  - spec/components/home_hero_component_spec.rb
  - spec/components/data_sources_component_spec.rb
  - spec/requests/pages_spec.rb
  - spec/system/home_hero_spec.rb
  - spec/components/data_limitations_component_spec.rb
  - spec/models/home_page/route_list_spec.rb
  - spec/assets/home_hero_images_spec.rb
  - spec/components/route_list_component_spec.rb
-->

---
### Requirement: Data sources block

The home page SHALL name the three feeds the site is built from (arrival and departure events, on-board counts, GPS), state that they are polled every 10 seconds across the whole network, and link to the three dataset pages on data.gov.tw: 128710 (定時車機資訊), 175726 (公車車上擁擠度) and 128428 (捷運車站出入口座標). It SHALL NOT link to a source-code repository or to a raw-data release.

#### Scenario: Dataset links present

- **WHEN** `/` is requested
- **THEN** the sources block contains exactly three links, to `https://data.gov.tw/dataset/128710`, `https://data.gov.tw/dataset/175726` and `https://data.gov.tw/dataset/128428`

<!-- @trace
source: home-page
updated: 2026-10-23
code:
  - app/assets/images/home-hero-tall.webp
  - app/components/route_coverage_component.rb
  - app/components/route_list_component.yml
  - app/controllers/pages_controller.rb
  - app/assets/images/home-hero-wide.webp
  - app/components/data_limitations_component.rb
  - config/locales/en.yml
  - config/locales/tw.yml
  - app/frontend/hero/scene.js
  - app/components/route_list_component.html.erb
  - app/components/attribution_component.yml
  - app/components/data_limitations_component.html.erb
  - app/frontend/hero/runtime.js
  - .dockerignore
  - app/frontend/entrypoints/application.js
  - app/views/pages/home.html.erb
  - spec/support/system.rb
  - package.json
  - tools/hero/export.js
  - app/frontend/stylesheets/application.css
  - tools/hero/index.html
  - app/components/home_hero_component.yml
  - app/components/route_list_component.rb
  - app/components/attribution_component.rb
  - app/components/attribution_component.html.erb
  - app/components/data_sources_component.yml
  - app/components/home_hero_component.html.erb
  - app/components/data_limitations_component.yml
  - .rubocop.yml
  - app/models/home_page/route_list.rb
  - app/components/data_sources_component.html.erb
  - app/views/layouts/application.html.erb
  - app/components/application_component.rb
  - app/components/data_sources_component.rb
  - app/components/home_hero_component.rb
tests:
  - spec/requests/site_layout_spec.rb
  - spec/components/home_hero_component_spec.rb
  - spec/components/data_sources_component_spec.rb
  - spec/requests/pages_spec.rb
  - spec/system/home_hero_spec.rb
  - spec/components/data_limitations_component_spec.rb
  - spec/models/home_page/route_list_spec.rb
  - spec/assets/home_hero_images_spec.rb
  - spec/components/route_list_component_spec.rb
-->

---
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

<!-- @trace
source: home-origin-story
updated: 2026-10-23
code:
  - app/components/origin_story_component.yml
  - app/views/pages/home.html.erb
  - docs/background.md
  - app/components/origin_story_component.rb
  - app/components/origin_story_component.html.erb
tests:
  - spec/requests/pages_spec.rb
  - spec/components/origin_story_component_spec.rb
-->