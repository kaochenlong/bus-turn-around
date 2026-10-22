# home-page Specification

## Purpose

The root page of the site, `GET /`: what the site is, which routes have a route page and how recent their stored data is, what the numbers can and cannot tell, and where the data comes from. It reads only the derived table of stored route days and shows no metric, so that every number keeps living on the route page next to its definition and its data limitations.

## Requirements

### Requirement: Home page content and order

The system SHALL serve `GET /` with these blocks in this order: a hero block with the site name, a one-question heading, one sentence naming the two numbers the site measures per route, and the hero picture; the route list; the data limitations; the data sources. Every block SHALL be present in the server response without JavaScript. The only page-specific script SHALL be the hero animation, which the home page alone loads on demand. The page SHALL NOT show any metric: no trip count, percentile, share or estimate. Every date on the page SHALL come from stored route days, and the copy SHALL NOT promise an update cadence.

#### Scenario: Blocks in order

- **WHEN** a visitor requests `/`
- **THEN** the response is 200 and the blocks appear in the order hero, routes, limitations, sources

#### Scenario: Complete without JavaScript

- **WHEN** route 9001 has the stored day 2026-10-20 and a visitor fetches `/` without running any script
- **THEN** the response already contains the hero picture, the 9001 entry with its latest day, the four limitations and the dataset links


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
### Requirement: Route list

The route list SHALL contain one entry per route Id in the route list configuration, in configuration order, built from one query for the latest stored day of every configured route. An entry whose route has stored days SHALL show the route name, the Id, the departure and destination of the latest stored day, and that day with its weekday in the format the route page uses for covered days, and SHALL link to `/routes/<Id>`. An entry whose route has no stored days SHALL show only the Id, SHALL state that the route has no data yet, and SHALL NOT link anywhere.

#### Scenario: Entries in configuration order

- **WHEN** the configuration lists 15373 then 9001, 15373 has no stored days and 9001 has the stored days 2026-10-19 and 2026-10-20
- **THEN** the list shows 15373 first, marked as having no data and without a link, then 9001 with the latest day 2026-10-20 and a link to `/routes/9001`

##### Example: entry of a route with data

- **GIVEN** route 9001 has stored days 2026-10-19 and 2026-10-20 whose latest row has route name 測試幹線, departure 甲站 and destination 戊站
- **WHEN** `/` is requested
- **THEN** the 9001 entry shows 測試幹線, 9001, 甲站－戊站 and 2026-10-20（二）

#### Scenario: Latest day of every route in one query

- **WHEN** two configured routes each have several stored days and the route list is built
- **THEN** the route days are read with a single query and each entry carries its route's latest day

##### Example: two routes, three days each

- **GIVEN** the configuration lists 15373 then 9001, 15373 has stored days 2026-10-19, 2026-10-20 and 2026-10-21, and 9001 has stored days 2026-10-18, 2026-10-19 and 2026-10-20
- **WHEN** the route list is built
- **THEN** exactly one SELECT on route_days is issued, and the entries are 15373 with 2026-10-21 followed by 9001 with 2026-10-20


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
### Requirement: Hero picture

The hero block SHALL show the illustration in two framings from the same scene: a wide framing for viewports of at least 640 px and a tall framing below that. The server response SHALL contain the illustration as a static image asset: a `picture` whose source for narrow viewports is the tall image, and an `img` of the wide image with explicit width and height and a non-empty `alt` sentence describing the scene. Both image files SHALL exist under `app/assets/images/`, the wide file SHALL be at most 200 KB and the tall file at most 120 KB.

When scripts run, the visitor does not prefer reduced motion and WebGL is available, the home page SHALL keep the illustration's box reserved without showing the static image, load the 3D library, play the animation once and stop rendering on a final frame with the same composition as the static image. In the animation, the bus drives into the terminal and stops, the front door opens and the driver steps out beside the bus. The framing SHALL follow the viewport width while and after the animation plays.

When the visitor prefers reduced motion, the page SHALL show the static image and SHALL NOT request the 3D library. When WebGL is unavailable or the animation fails to load, the page SHALL show the static image. When no script takes over the hero within 3 seconds, the static image SHALL become visible. Pages other than the home page SHALL NOT request the 3D library.

#### Scenario: Picture element

- **WHEN** `/` is requested
- **THEN** the hero block contains a `picture` with a `source` whose media query is `(max-width: 639px)` and whose srcset is the tall image, and an `img` whose src is the wide image with width, height and a non-empty alt

#### Scenario: Image files within budget

- **WHEN** the files `app/assets/images/home-hero-wide.webp` and `app/assets/images/home-hero-tall.webp` are checked
- **THEN** both exist, the wide file is at most 200 KB and the tall file is at most 120 KB

#### Scenario: Animation plays once and stops

- **WHEN** a visitor whose browser runs scripts, has WebGL and does not prefer reduced motion opens `/`
- **THEN** the hero shows a canvas in place of the static image, plays the animation once and then stops rendering

#### Scenario: Final frame matches the static image

- **WHEN** the scene is rendered at the end of the animation with each framing and exported as the static images are
- **THEN** the exported images are pixel-identical to the committed static images

##### Example: both framings at the end of the animation

- **GIVEN** the committed `home-hero-wide.webp` of 2048×1152 pixels and `home-hero-tall.webp` of 1170×1170 pixels
- **WHEN** the scene is posed at the end of the animation and exported with the wide and the tall framing
- **THEN** comparing each export with its committed file reports 0 differing pixels

#### Scenario: Reduced motion keeps the static image

- **WHEN** a visitor who prefers reduced motion opens `/`
- **THEN** the static image is visible, no canvas is added and the 3D library is not requested

#### Scenario: No WebGL keeps the static image

- **WHEN** a visitor whose browser has no WebGL opens `/`
- **THEN** the static image is visible and no canvas is added

#### Scenario: Animation that fails to load falls back

- **WHEN** the animation's script cannot be loaded
- **THEN** the static image is visible

##### Example: the animation's script is blocked

- **GIVEN** a browser that runs scripts, has WebGL and does not prefer reduced motion, and that blocks the request for the animation's script
- **WHEN** it opens `/`
- **THEN** the static image is visible and no canvas is added

#### Scenario: Static image appears when no script takes over

- **WHEN** the browser has scripting enabled but the page's scripts do not run
- **THEN** the static image becomes visible within 3 seconds

#### Scenario: Route pages do not load the animation

- **WHEN** a visitor opens `/routes/9001`
- **THEN** neither the animation's script nor the 3D library is requested

#### Scenario: Returning to the home page

- **WHEN** a visitor goes from `/` to a route page and back
- **THEN** no stale canvas remains and the animation plays again to its final frame

#### Scenario: Framing follows the viewport width

- **WHEN** the viewport is narrower than 640 px while the animation plays and is then widened past 640 px
- **THEN** the animation uses the tall framing first and the wide framing after the widening


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