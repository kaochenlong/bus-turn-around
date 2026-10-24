## Purpose

The page a visitor gets when the site has nothing at the requested address: a static page in the shape of a bus stop sign that says this stop is not served and links back to the home page. It exists so that a mistyped address, or a link to a route that has been taken off the route list, ends on a page of this site instead of a blank page or the framework's English default.

## ADDED Requirements

### Requirement: Not-found page

The site SHALL have one not-found page, the static file `public/404.html`, and SHALL serve it with status 404 for every path the site does not route and, as `route-page` requires, for every route `Id` outside the route list. The page SHALL be in Traditional Chinese (`lang="zh-Hant-TW"`), SHALL have the document title 這一站沒有停靠｜折返點 TurnAround with no emoticon, SHALL show a bus stop sign whose stop name 這一站沒有停靠 is the page's only `h1`, and SHALL carry exactly one `a` element, linking to `/`, whose text names the route 404 and the destination 往 首頁. The page SHALL keep `<meta name="robots" content="noindex, nofollow">`. The page SHALL be served without the shared layout: it SHALL have no site name bar, no attribution footer and no `script` element, because it shows no data from the feeds.

#### Scenario: Unknown path

- **WHEN** a visitor requests `/no-such-page` with detailed exception pages turned off, as in production
- **THEN** the response is 404 and its body is the content of `public/404.html`

#### Scenario: Page content

- **WHEN** `public/404.html` is parsed
- **THEN** its title is 這一站沒有停靠｜折返點 TurnAround, its only `h1` reads 這一站沒有停靠, it has exactly one `a` element, which points to `/` and whose text contains 404 and 往 首頁, its robots meta is `noindex, nofollow`, and it has no `script` element, no `[data-site-bar]` and no `footer[data-attribution]`
