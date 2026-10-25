## MODIFIED Requirements

### Requirement: Document title carries the site name

Every page SHALL have a document title that carries the site name 折返點 TurnAround from the locale file. When a page sets no title of its own, the title SHALL be the site name alone. A page that sets its own title SHALL end it with the site name after the separator ｜, as `route-page` does with 路線名｜折返點 TurnAround. The `application-name` meta SHALL carry the site name on every page. The `og:title` and `twitter:title` metas SHALL equal the document title.

#### Scenario: Home page title

- **WHEN** `/` is requested
- **THEN** the document title is 折返點 TurnAround, the `application-name` meta is 折返點 TurnAround, and the `og:title` and `twitter:title` metas are 折返點 TurnAround

#### Scenario: Route page title

- **WHEN** `/routes/9001` is requested and 9001 has no stored days
- **THEN** the response is 200 and the document title is 折返點 TurnAround

#### Scenario: Share title follows the document title

- **WHEN** `/routes/9001` is requested and 9001's latest covered day has the route name 測試幹線
- **THEN** the document title, the `og:title` meta and the `twitter:title` meta are all 測試幹線｜折返點 TurnAround

## ADDED Requirements

### Requirement: Share description follows the page

Every page SHALL carry three description metas, `description`, `og:description` and `twitter:description`, with the same content: the page's own description when the page sets one, otherwise the site description from the locale file. On every page the `og:url` meta SHALL be the requested URL, the `og:site_name` meta the site name, and the `og:image` meta the site's share image. The static error pages under `public/` are outside this requirement, as they are served without the shared layout.

#### Scenario: Home page descriptions

- **WHEN** `/` is requested
- **THEN** the `description`, `og:description` and `twitter:description` metas are all the site description from the locale file

#### Scenario: Route page without stored days

- **WHEN** `/routes/9001` is requested and 9001 has no stored days
- **THEN** the response is 200 and the three description metas are all the site description from the locale file

#### Scenario: Route page with data

- **WHEN** `/routes/9001` is requested and the selected day is stored
- **THEN** the three description metas are all the share text that `route-page` defines for that page, and none of them is the site description
