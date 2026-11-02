## MODIFIED Requirements

### Requirement: Site name bar on every page

Every HTML page SHALL begin, before the page's own content, with one bar that carries, in this order: first the site name from the locale file as a link to `/`; then, only on a route page, a timetable page as defined by `timetable`, a day dispatch page as defined by `day-dispatch`, a month card page as defined by `monthly-card` and a month card list as defined by `monthly-card-pdf`, a link whose text comes from the locale file (班表 in `tw`) to that route's timetable page without parameters, carrying `aria-current="page"` on the timetable page itself, followed by a link whose text comes from the locale file (當天調度 in `tw`) to that route's day dispatch page `/routes/<Id>/dispatch`, carrying `aria-current="page"` on the day dispatch page itself, followed by a link whose text comes from the locale file (健檢卡 in `tw`) to that route's month card list `/routes/<Id>/cards`, carrying `aria-current="page"` on the month card list and on a month card page; then a link to the site's source repository, `https://github.com/kaochenlong/bus-turn-around`, shown as the GitHub mark, whose text comes from the locale file (GitHub in `tw`) and is read by assistive technology only; then a link to the article that introduces the site, `https://kaochenlong.com/bus-turn-around`, whose text comes from the locale file (關於這個網站 in `tw`). The repository link and the article link SHALL sit together at the right end of the bar, apart from the site name and the route links. At every screen width the article link SHALL show only the first part of its text (關於 in `tw`) while its text stays whole for assistive technology. On a screen narrower than 640 px the repository link SHALL NOT be displayed. The home page SHALL carry exactly three links; a route page, a timetable page, a day dispatch page, a month card page and a month card list exactly six. On a screen 360 px wide the bar SHALL fit without horizontal scrolling. The repository link and the article link SHALL open in a new tab: each SHALL carry `target="_blank"` and `rel="noopener"` and SHALL be described to assistive technology as opening in a new tab, in words from the locale file (另開新分頁 in `tw`). The bar SHALL be marked with `data-site-bar` and SHALL NOT carry or contain a `data-section` attribute, so that the block order of every page is unchanged. The static error pages under `public/`, such as the page of `not-found-page`, are outside this requirement: they are served without the shared layout and carry no bar.

#### Scenario: Bar on the home page

- **WHEN** `/` is requested
- **THEN** exactly one `[data-site-bar]` is present before the `main` element, it contains exactly three links, the first points to `/` with the text 折返點 TurnAround, the second points to `https://github.com/kaochenlong/bus-turn-around` with the text GitHub and `target="_blank"`, and the third points to `https://kaochenlong.com/bus-turn-around` with the text 關於這個網站 and `target="_blank"`

#### Scenario: Bar on a route page

- **WHEN** `/routes/9001` is requested and 9001 has no stored days
- **THEN** the response is 200, exactly one `[data-site-bar]` is present, it contains exactly six links, the second points to `/routes/9001/timetable` with the text 班表 and no `aria-current` attribute, the third points to `/routes/9001/dispatch` with the text 當天調度 and no `aria-current` attribute, the fourth points to `/routes/9001/cards` with the text 健檢卡 and no `aria-current` attribute, the fifth points to `https://github.com/kaochenlong/bus-turn-around` with the text GitHub, the sixth points to `https://kaochenlong.com/bus-turn-around` with the text 關於這個網站, and no element with `data-section` is the bar or inside it

#### Scenario: Bar on a timetable page

- **WHEN** `/routes/9001/timetable` is requested
- **THEN** the bar contains exactly six links, its second link points to `/routes/9001/timetable` with `aria-current="page"`, its third link points to `/routes/9001/dispatch` without `aria-current`, and its fourth link points to `/routes/9001/cards` without `aria-current`

#### Scenario: Bar on a day dispatch page

- **WHEN** `/routes/9001/dispatch` is requested
- **THEN** the bar contains exactly six links, its second link points to `/routes/9001/timetable` without `aria-current`, its third link points to `/routes/9001/dispatch` with `aria-current="page"`, and its fourth link points to `/routes/9001/cards` without `aria-current`

#### Scenario: Bar on a month card list

- **WHEN** `/routes/9001/cards` is requested
- **THEN** the bar contains exactly six links and its fourth link points to `/routes/9001/cards` with `aria-current="page"`

#### Scenario: Bar on a month card page

- **WHEN** `/routes/9001/cards/2026-10` is requested and the route card exists
- **THEN** the bar contains exactly six links and its fourth link points to `/routes/9001/cards` with `aria-current="page"`

#### Scenario: Bar on small phones

- **WHEN** a route page is shown on a phone screen 390 px wide, and again on one 360 px wide
- **THEN** the page has no horizontal scrolling and all four route links and the article link are displayed

#### Scenario: Repository link on a phone

- **WHEN** a route page is shown on a phone screen 390 px wide, and again on a screen 1400 px wide
- **THEN** the repository link in the bar is not displayed on the phone screen and is displayed on the 1400 px screen
