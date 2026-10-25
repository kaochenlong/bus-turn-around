## MODIFIED Requirements

### Requirement: Site name bar on every page

Every HTML page SHALL begin, before the page's own content, with one bar that carries: first the site name from the locale file as a link to `/`; then, only on a route page and on a timetable page as defined by `timetable`, a link whose text comes from the locale file (班表 in `tw`) to that route's timetable page without parameters, carrying `aria-current="page"` on the timetable page itself; then a link to the article that introduces the site, `https://kaochenlong.com/bus-turn-around`, whose text comes from the locale file (關於這個網站 in `tw`). The home page SHALL carry exactly two links, a route page and a timetable page exactly three. The article link SHALL open in the same tab: it SHALL NOT carry a `target` attribute. The bar SHALL be marked with `data-site-bar` and SHALL NOT carry or contain a `data-section` attribute, so that the block order of every page is unchanged. The static error pages under `public/`, such as the page of `not-found-page`, are outside this requirement: they are served without the shared layout and carry no bar.

#### Scenario: Bar on the home page

- **WHEN** `/` is requested
- **THEN** exactly one `[data-site-bar]` is present before the `main` element, it contains exactly two links, the first points to `/` with the text 折返點 TurnAround, and the second points to `https://kaochenlong.com/bus-turn-around` with the text 關於這個網站 and has no `target` attribute

#### Scenario: Bar on a route page

- **WHEN** `/routes/9001` is requested and 9001 has no stored days
- **THEN** the response is 200, exactly one `[data-site-bar]` is present, it contains exactly three links, the second points to `/routes/9001/timetable` with the text 班表 and no `aria-current` attribute, the third points to `https://kaochenlong.com/bus-turn-around` with the text 關於這個網站, and no element with `data-section` is the bar or inside it

#### Scenario: Bar on a timetable page

- **WHEN** `/routes/9001/timetable` is requested
- **THEN** the bar contains exactly three links and its second link points to `/routes/9001/timetable` with `aria-current="page"`
