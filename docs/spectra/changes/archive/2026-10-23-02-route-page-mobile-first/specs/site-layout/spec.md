## ADDED Requirements

### Requirement: Site name bar on every page

Every HTML page SHALL begin, before the page's own content, with one bar that carries the site name from the locale file as a link to `/`. The bar SHALL be marked with `data-site-bar` and SHALL NOT carry or contain a `data-section` attribute, so that the block order of every page is unchanged.

#### Scenario: Bar on the home page

- **WHEN** `/` is requested
- **THEN** exactly one `[data-site-bar]` is present before the `main` element, and its link points to `/` with the text 折返點 TurnAround

#### Scenario: Bar on a route page

- **WHEN** `/routes/9001` is requested and 9001 has no stored days
- **THEN** the response is 200, exactly one `[data-site-bar]` is present, and no element with `data-section` is the bar or inside it
