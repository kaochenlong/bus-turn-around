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

The route list SHALL contain one entry per route Id in the route list configuration, in configuration order, built from one query for the latest stored day of every configured route. An entry whose route has stored days SHALL show the route name without the Id beside it; the departure and destination of the latest stored day, followed by the label 路線 Id and the route's Id; and that day with its weekday in the format the route page uses for covered days, followed by its day type as defined by `day-types`; and SHALL link to `/routes/<Id>`. An entry whose route has no stored days SHALL show only the label 路線 Id with the route's Id, SHALL state that the route has no data yet, and SHALL NOT link anywhere.

#### Scenario: Entries in configuration order

- **WHEN** the configuration lists 15373 then 9001, 15373 has no stored days and 9001 has the stored days 2026-10-19 and 2026-10-20
- **THEN** the list shows 15373 first, marked as having no data and without a link, then 9001 with the latest day 2026-10-20 and a link to `/routes/9001`

##### Example: entry of a route with data

- **GIVEN** route 9001 has the stored weekdays 2026-10-19 and 2026-10-20 whose latest row has route name 測試幹線, departure 甲站 and destination 戊站
- **WHEN** `/` is requested
- **THEN** the 9001 entry's name reads 測試幹線 alone, and the entry shows 甲站－戊站 followed by 路線 Id 9001, and 2026-10-20（二）平日

##### Example: entry of a route without data

- **GIVEN** the configuration lists 15373, which has no stored days
- **WHEN** `/` is requested
- **THEN** the 15373 entry reads 路線 Id 15373, states that the route has no data yet and has no link

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
source: 02-route-stop-sequence
updated: 2026-10-24
code:
  - app/models/route_day_end_cell.rb
  - config/locales/en.yml
  - output/branding-v2/a-bus/logo.png
  - app/components/route_coverage_component.html.erb
  - app/components/route_list_component.yml
  - app/models/route_day_end.rb
  - bin/health-card
  - app/frontend/entrypoints/application.js
  - app/controllers/routes_controller.rb
  - db/schema.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/12.jsonl
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - analysis/params.sql
  - app/models/route_day_end_toilet.rb
  - app/components/stop_sequence_component.html.erb
  - app/components/stop_sequence_component.yml
  - app/models/route_page/stop_sequence.rb
  - app/components/section_nav_component.yml
  - app/models/route_day_loader.rb
  - app/components/attribution_component.rb
  - config/map.yml
  - public/robots.txt
  - docs/data-sources.md
  - app/components/turnaround_facilities_component.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/08.jsonl
  - app/components/turnaround_facilities_component.html.erb
  - spec/support/duckdb.rb
  - app/views/routes/show.html.erb
  - .ruby-version
  - app/models/derived_load_command.rb
  - app/components/layover_chart_component.yml
  - Dockerfile
  - app/frontend/stylesheets/application.css
  - app/components/home_hero_component.yml
  - app/components/load_chart_component.html.erb
  - app/models/map_tiles.rb
  - config/locales/tw.yml
  - app/components/data_limitations_component.yml
  - app/components/section_nav_component.rb
  - app/views/layouts/application.html.erb
  - app/components/attribution_component.yml
  - output/branding-v2/a-bus/favicon-preview.png
  - Gemfile
  - app/models/route_day.rb
  - package.json
  - app/frontend/rest_command.js
  - app/models/route_page/end_map.rb
  - spec/fixtures/analysis/external/public-toilets/2026-10-19.csv
  - analysis/turnaround_facilities.sql
  - analysis/derived_export.sql
  - app/components/end_map_component.html.erb
  - app/components/route_coverage_component.yml
  - app/frontend/end_map/runtime.js
  - app/frontend/hero/scene.js
  - app/components/home_hero_component.html.erb
  - app/components/end_map_component.rb
  - app/components/end_map_component.yml
  - config/deploy.yml
  - app/models/route_page/facilities.rb
  - db/migrate/20261023190654_add_turnaround_facilities_to_derived_tables.rb
  - public/404.html
  - output/branding-v2/a-bus/favicon.ico
  - analysis/README.md
  - spec/fixtures/analysis/README.md
  - spec/fixtures/analysis/bus_data/2026-10-19/11.jsonl
  - spec/factories/route_day_end_toilets.rb
  - spec/factories/route_days.rb
  - app/components/load_chart_component.rb
  - lib/tasks/external.rake
  - app/components/attribution_component.html.erb
  - app/components/turnaround_facilities_component.yml
  - spec/factories/route_day_end_cells.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/07.jsonl
  - app/assets/images/home-hero-wide.webp
  - app/assets/images/home-hero-narrow.webp
  - Gemfile.lock
  - app/components/stop_sequence_component.rb
  - config/initializers/mime_types.rb
  - spec/factories/route_day_ends.rb
  - public/turnaround/og-image-v2.jpg
  - app/frontend/hero/runtime.js
  - app/models/public_toilets_snapshot.rb
  - app/components/route_list_component.html.erb
tests:
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_day_spec.rb
  - spec/requests/pages_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/requests/routes_spec.rb
  - spec/system/rest_command_spec.rb
  - spec/models/public_toilets_snapshot_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/route_page/stop_sequence_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/models/route_page/end_map_spec.rb
  - spec/components/route_list_component_spec.rb
  - spec/components/load_chart_component_spec.rb
  - spec/system/load_chart_hover_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/models/map_tiles_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/requests/not_found_page_spec.rb
  - spec/components/stop_sequence_component_spec.rb
  - spec/analysis/params_spec.rb
  - spec/models/route_page/facilities_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/system/end_map_spec.rb
  - spec/components/route_coverage_component_spec.rb
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/requests/easter_eggs_spec.rb
-->

---
### Requirement: Hero picture

The hero block SHALL show the illustration in two framings from the same scene: a wide framing for viewports of at least 640 px and a narrow framing below that. The server response SHALL contain the illustration as a static image asset: a `picture` whose source for narrow viewports is the narrow image with width and height in its proportions, and an `img` of the wide image with explicit width and height and a non-empty `alt` sentence describing the scene. Both image files SHALL exist under `app/assets/images/`, the wide file SHALL be at most 200 KB and the narrow file at most 120 KB.

When scripts run, the visitor does not prefer reduced motion and WebGL is available, the home page SHALL keep the illustration's box reserved without showing the static image, load the 3D library and play the turnaround on a loop, starting with the bus driving in. In each lap, the bus drives into the terminal and stops, the front door opens and the driver steps out and rests beside the bus; the driver then walks back in, the bus pulls up to the stop, where the waiting riders board, and drives out of the block; new riders walk to the stop and the next bus drives in. The moment of each lap at which the driver rests beside the bus, called the still, SHALL have the same composition as the static image. The animation SHALL NOT show a clock, a countdown or any other number. While the driver is out of the bus, from the moment the driver starts stepping out until the front door has closed again, the destination sign above the bus's windscreen SHALL show the words 暫停服務 moving from right to left; at every other moment of the lap the sign SHALL be blank. At the still the words SHALL be wholly in view on the sign. The framing SHALL follow the viewport width, whether the animation is rendering or not. In the narrow framing, the view SHALL rest on the terminal and SHALL move to the stop together with the bus as it pulls up there, so that the riders boarding, the bus leaving and the new riders walking in are in view; it SHALL stay on the stop for the rest of the lap and SHALL move back to the terminal at the start of the next lap, as the next bus comes in. At the still the narrow framing SHALL be on the terminal.

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

#### Scenario: Destination sign while the driver is out

- **WHEN** the scene is posed at a moment of the lap
- **THEN** the destination sign above the bus's windscreen shows 暫停服務 moving from right to left from the moment the driver starts stepping out until the front door has closed again, and is blank at every other moment

##### Example: seconds into the lap

| Seconds | The destination sign |
| ------- | -------------------- |
| 1.5 | blank, as the bus drives in |
| 3.4 | blank, the front door opening with the driver still inside |
| 4.2 | 暫停服務 moving in from the right, as the driver steps out |
| 5.5 | 暫停服務 wholly in view, at the still |
| 10.6 | 暫停服務 still shown, the driver back inside and the door closing |
| 11.2 | blank, the door closed and the bus pulling away |
| 14.4 | blank, the bus at the stop with the riders boarding |

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
source: home-hero-samoyed-out-of-service
updated: 2026-10-24
code:
  - app/components/home_hero_component.yml
  - output/branding-v2/a-bus/favicon-preview.png
  - lib/tasks/external.rake
  - spec/fixtures/analysis/README.md
  - app/components/section_nav_component.rb
  - spec/factories/route_day_end_toilets.rb
  - app/components/turnaround_facilities_component.html.erb
  - analysis/params.sql
  - app/components/end_map_component.html.erb
  - analysis/README.md
  - app/models/route_day.rb
  - output/branding-v2/a-bus/logo.png
  - spec/fixtures/analysis/bus_data/2026-10-19/11.jsonl
  - app/components/end_map_component.yml
  - app/views/routes/show.html.erb
  - spec/factories/route_days.rb
  - app/frontend/end_map/runtime.js
  - app/views/layouts/application.html.erb
  - spec/support/duckdb.rb
  - app/components/attribution_component.rb
  - app/components/end_map_component.rb
  - spec/fixtures/analysis/bus_data/2026-10-19/07.jsonl
  - app/models/route_day_end.rb
  - app/components/attribution_component.yml
  - app/frontend/stylesheets/application.css
  - app/frontend/hero/runtime.js
  - Gemfile.lock
  - config/locales/en.yml
  - .ruby-version
  - spec/fixtures/analysis/bus_data/2026-10-19/12.jsonl
  - docs/data-sources.md
  - package.json
  - config/map.yml
  - analysis/derived_export.sql
  - app/components/turnaround_facilities_component.yml
  - app/components/home_hero_component.html.erb
  - analysis/turnaround_facilities.sql
  - app/components/data_limitations_component.yml
  - output/branding-v2/a-bus/favicon.ico
  - spec/factories/route_day_ends.rb
  - app/frontend/entrypoints/application.js
  - app/frontend/hero/scene.js
  - app/models/route_page/facilities.rb
  - app/assets/images/home-hero-wide.webp
  - app/models/route_day_end_toilet.rb
  - db/schema.rb
  - app/components/turnaround_facilities_component.rb
  - app/models/map_tiles.rb
  - spec/factories/route_day_end_cells.rb
  - spec/fixtures/analysis/external/public-toilets/2026-10-19.csv
  - app/assets/images/home-hero-narrow.webp
  - Gemfile
  - Dockerfile
  - app/models/public_toilets_snapshot.rb
  - db/migrate/20261023190654_add_turnaround_facilities_to_derived_tables.rb
  - app/models/derived_load_command.rb
  - public/turnaround/og-image-v2.jpg
  - app/components/section_nav_component.yml
  - bin/health-card
  - config/locales/tw.yml
  - app/components/attribution_component.html.erb
  - app/models/route_page/end_map.rb
  - config/deploy.yml
  - spec/fixtures/analysis/bus_data/2026-10-19/08.jsonl
  - spec/fixtures/analysis/bus_data/2026-10-19/06.jsonl
  - app/models/route_day_end_cell.rb
  - app/models/route_day_loader.rb
tests:
  - spec/models/map_tiles_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/system/end_map_spec.rb
  - spec/requests/routes_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/models/route_day_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/models/route_page/end_map_spec.rb
  - spec/requests/route_page_fixture_spec.rb
  - spec/analysis/params_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/models/public_toilets_snapshot_spec.rb
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/models/route_page/facilities_spec.rb
  - spec/analysis/cli_spec.rb
  - spec/requests/site_layout_spec.rb
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

---
### Requirement: Route list entry of a page with member routes

An entry of a page route that lists member routes SHALL show the label 路線 Id followed by every route `Id` of the page, the page route first, joined by 「・」, whether or not the route has stored days; SHALL link to `/routes/<page Id>` only when the route has stored days; and the member routes SHALL have no entry of their own.

#### Scenario: Entry with two Ids

- **WHEN** the configuration lists 9001 with 9050 under `member_routes`, and 9001 has a stored day
- **THEN** the list has one entry for them, reading 路線 Id 9001・9050 after the departure and destination and linking to `/routes/9001`, and no entry for 9050

#### Scenario: Entry with two Ids and no data

- **WHEN** the configuration lists 9001 with 9050 under `member_routes`, and 9001 has no stored day
- **THEN** the entry reads 路線 Id 9001・9050, states that the route has no data yet and links nowhere

<!-- @trace
source: 02-route-307-page
updated: 2026-10-24
code:
  - db/migrate/20261024050300_require_route_id_on_derived_rows.rb
  - app/components/turnaround_facilities_component.rb
  - analysis/10_load.sql
  - bin/health-card
  - spec/fixtures/analysis/README.md
  - analysis/params.sql
  - spec/fixtures/analysis/bus_event/2026-10-23/07.jsonl
  - app/components/turnaround_facilities_component.yml
  - analysis/60_export.sql
  - docs/background.md
  - app/models/route_day.rb
  - analysis/50_quality.sql
  - app/components/data_limitations_component.yml
  - spec/factories/route_day_ends.rb
  - spec/fixtures/analysis/static/2026-10-19/GetPathDetail.gz
  - README.md
  - app/components/data_limitations_component.rb
  - db/migrate/20261024035750_create_route_day_shapes.rb
  - spec/fixtures/analysis/static/2026-10-23/GetProvider.gz
  - analysis/depots.sql
  - spec/fixtures/analysis/static/2026-10-19/GetBusShape.gz
  - app/components/stop_sequence_component.yml
  - spec/fixtures/analysis/bus_data/2026-10-23/07.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-23/07.jsonl
  - app/components/attribution_component.html.erb
  - app/models/trip.rb
  - app/frontend/maps/base_map.js
  - app/models/route_page/route_shape.rb
  - app/models/route_page/stop_sequence.rb
  - config/depot_inspections.yml
  - analysis/40_load_profile.sql
  - analysis/route_shape.sql
  - spec/factories/route_day_shapes.rb
  - db/schema.rb
  - app/models/route_page/depots.rb
  - spec/fixtures/analysis/static/2026-10-23/GetBusShape.gz
  - app/models/route_page/depot_inspections.rb
  - db/migrate/20261024062215_create_route_day_depots.rb
  - app/models/route_day_depot.rb
  - spec/fixtures/analysis/static/2026-10-19/GetRoute.gz
  - app/components/end_map_component.html.erb
  - app/models/route_day_loader.rb
  - config/locales/en.yml
  - analysis/README.md
  - spec/fixtures/analysis/bus_event/2026-10-23/08.jsonl
  - spec/fixtures/analysis/bus_seat_event/2026-10-23/09.jsonl
  - app/components/route_map_component.html.erb
  - spec/factories/route_day_depots.rb
  - spec/factories/route_day_end_cells.rb
  - app/components/attribution_component.yml
  - spec/fixtures/analysis/static/2026-10-23/GetRoute.gz
  - app/models/route_page/load_profile.rb
  - app/frontend/route_map/runtime.js
  - spec/fixtures/analysis/static/2026-10-19/GetStop.gz
  - app/components/route_map_component.rb
  - app/models/route_page/layover_stats.rb
  - app/models/derived_load_command.rb
  - spec/fixtures/analysis/bus_seat_event/2026-10-23/08.jsonl
  - db/migrate/20261024050200_backfill_route_id_on_derived_rows.rb
  - app/frontend/entrypoints/application.js
  - app/models/route_day_shape.rb
  - analysis/turnaround_facilities.sql
  - app/models/pto_assessment_snapshot.rb
  - docs/data-sources.md
  - app/frontend/stylesheets/application.css
  - app/components/application_component.rb
  - analysis/derived_export.sql
  - spec/fixtures/analysis/static/2026-10-19/GetProvider.gz
  - app/components/route_list_component.rb
  - analysis/mrt_overlap.sql
  - app/models/route_page/mrt_overlap.rb
  - app/models/route_page/summary.rb
  - config/route_page.yml
  - lib/tasks/external.rake
  - spec/factories/route_day_end_toilets.rb
  - spec/factories/route_days.rb
  - spec/fixtures/analysis/static/2026-10-23/GetStop.gz
  - app/components/route_map_component.yml
  - spec/fixtures/analysis/bus_event/2026-10-23/09.jsonl
  - app/models/tdx_s2s_travel_time_snapshot.rb
  - app/components/turnaround_facilities_component.html.erb
  - app/components/buffer_trade_component.yml
  - app/views/routes/show.html.erb
  - spec/fixtures/analysis/static/2026-10-23/GetPathDetail.gz
  - db/migrate/20261024050100_add_member_route_columns_to_derived_tables.rb
  - app/frontend/end_map/runtime.js
  - app/models/route_day_stop.rb
  - app/components/route_coverage_component.html.erb
  - app/models/route_page.rb
  - spec/fixtures/analysis/bus_event/2026-10-24/01.jsonl
  - app/components/route_list_component.html.erb
  - spec/support/duckdb.rb
  - app/components/data_limitations_component.html.erb
  - app/components/route_coverage_component.rb
  - app/components/stop_sequence_component.html.erb
  - config/locales/tw.yml
  - lib/analysis_run.rb
  - app/components/buffer_trade_component.html.erb
  - app/components/stop_sequence_component.rb
  - docs/decisions.md
tests:
  - spec/models/route_day_spec.rb
  - spec/migrations/member_route_columns_spec.rb
  - spec/analysis/depots_spec.rb
  - spec/models/route_page/route_shape_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/components/data_limitations_component_spec.rb
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/models/derived_load_command_spec.rb
  - spec/analysis/fixtures_spec.rb
  - spec/analysis/load_spec.rb
  - spec/models/route_page/depots_spec.rb
  - spec/models/route_page/summary_spec.rb
  - spec/analysis/card_spec.rb
  - spec/components/end_map_component_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/models/route_page/card_consistency_spec.rb
  - spec/models/route_day_loader_spec.rb
  - spec/analysis/derived_export_spec.rb
  - spec/analysis/trips_spec.rb
  - spec/models/pto_assessment_snapshot_spec.rb
  - spec/models/route_page/layover_stats_spec.rb
  - spec/models/tdx_s2s_travel_time_snapshot_spec.rb
  - spec/requests/routes_spec.rb
  - spec/requests/pages_spec.rb
  - spec/models/route_page/stop_sequence_spec.rb
  - spec/components/attribution_component_spec.rb
  - spec/system/route_map_spec.rb
  - spec/components/route_coverage_component_spec.rb
  - spec/analysis/profile_spec.rb
  - spec/analysis/mrt_overlap_spec.rb
  - spec/analysis/quality_spec.rb
  - spec/components/route_list_component_spec.rb
  - spec/analysis/route_shape_spec.rb
  - spec/models/route_page/depot_inspections_spec.rb
  - spec/analysis/layovers_spec.rb
  - spec/models/route_page/load_profile_spec.rb
  - spec/analysis/analysis_run_spec.rb
  - spec/models/route_page/mrt_overlap_spec.rb
  - spec/components/route_map_component_spec.rb
  - spec/models/route_page/ends_spec.rb
  - spec/system/end_map_spec.rb
  - spec/analysis/params_spec.rb
  - spec/components/stop_sequence_component_spec.rb
  - spec/analysis/attribution_spec.rb
  - spec/analysis/cli_spec.rb
-->