## MODIFIED Requirements

### Requirement: Map budget

The map library and the code the maps share SHALL be built into one chunk, and each kind of map (the end maps of `turnaround-map` and the route map of `route-shape`) SHALL have its own drawing chunk. The shared chunk together with either drawing chunk SHALL be at most 100 KB after brotli compression, measured on the built files. These chunks SHALL be requested only on route pages and only after a map container is at least a quarter visible, and a drawing chunk SHALL be requested only after a container of its own kind is. The number and size of tiles each map requests when first drawn SHALL be measured and recorded in the design of the change that adds or changes that map.

#### Scenario: Chunk size

- **WHEN** the frontend is built and the shared chunk and both drawing chunks are compressed with brotli at quality 11
- **THEN** the shared chunk plus the end map's drawing chunk is at most 100 KB, and the shared chunk plus the route map's drawing chunk is at most 100 KB

##### Example: measured on the built files

- **GIVEN** the built chunks of `app/frontend/end_map/runtime.js` and `app/frontend/route_map/runtime.js` and the chunk they both import
- **WHEN** each is compressed with `brotli -q 11` and `gzip -9`
- **THEN** all sizes are recorded in the 03-route-shape-map design's Risks, and each sum of the shared chunk and one drawing chunk is at most 100 KB after brotli

#### Scenario: Drawing chunk of the other kind not requested

- **WHEN** a route page whose covered days have route shapes is opened and only the route map container is scrolled into view
- **THEN** the shared chunk and the route map's drawing chunk are requested, and the end map's drawing chunk is not

## ADDED Requirements

### Requirement: Map gestures

Every map of the route page, the end maps of `turnaround-map` and the route map of `route-shape`, SHALL leave the gestures that scroll a page to the page, as Google Maps does. The zoom key SHALL be ⌘ on a Mac and Ctrl on every other system. Turning the mouse wheel over a drawn map without the zoom key SHALL scroll the page and SHALL NOT zoom the map, and the map SHALL show for a moment a note naming the zoom key. Turning the wheel while holding the zoom key SHALL zoom the map around the pointer, SHALL NOT scroll the page and SHALL show no note; one notch of the wheel SHALL zoom the map by less than one zoom level. A trackpad pinch, which browsers send as a wheel turn with Ctrl held, SHALL zoom the map in the same way on every system, so on a Mac a wheel turn with Ctrl held SHALL zoom the map too. On a touch screen one finger SHALL scroll the page and SHALL NOT move the map, and moving one finger over a drawn map SHALL show for a moment a note saying to use two fingers; two fingers SHALL move and zoom the map. A mouse SHALL still drag the map. A note SHALL NOT take focus or catch the pointer, and SHALL go away about a second after the last gesture.

#### Scenario: Wheel over the route map

- **WHEN** the mouse wheel is turned over a drawn route map in the direction that zooms in
- **THEN** the system and the key held decide whether the page scrolls, whether the map zooms in and whether the note naming the zoom key shows

##### Example: systems and keys held while the wheel turns

| System | Key held | Page scrolls | Map zooms in | Note shown |
| --- | --- | --- | --- | --- |
| Mac | none | yes | no | yes, naming ⌘ |
| Mac | ⌘ | no | yes | no |
| Mac | Ctrl, as a trackpad pinch sends | no | yes | no |
| Windows | none | yes | no | yes, naming Ctrl |
| Windows | Ctrl | no | yes | no |
| Windows | the Windows key | yes | no | yes, naming Ctrl |

#### Scenario: One notch zooms less than a level

- **WHEN** the wheel is turned one notch over a drawn route map with the zoom key held
- **THEN** the map zooms in by less than one zoom level, so the distance between two of its stop marks grows by more than nothing and by less than twice

#### Scenario: One finger on a touch screen

- **WHEN** one finger is dragged across a drawn route map on a touch screen
- **THEN** the map does not move, and the map shows the note saying to use two fingers

#### Scenario: End maps follow the same gestures

- **WHEN** the mouse wheel is turned over a drawn end map without the zoom key
- **THEN** the page scrolls, the map keeps its zoom, and the map shows the note naming the zoom key

### Requirement: Map full screen

Every map of the route page, the end maps of `turnaround-map` and the route map of `route-shape`, SHALL have, below its zoom buttons, a button that shows the map container on the whole screen, when the browser can show an element on the whole screen; where it cannot, as Safari on an iPhone, there SHALL be no such button. Like the zoom buttons, the button SHALL NOT take focus. On the whole screen the map SHALL fill the screen and, because there is no page to scroll, turning the wheel SHALL zoom the map without the zoom key, one finger SHALL move the map and no gesture note SHALL show. Pressing the button again or pressing Escape SHALL leave the whole screen, and the map SHALL return to its place and size in the page with the gestures of Map gestures.

#### Scenario: Button shows the map on the whole screen

- **WHEN** the full screen button of a drawn route map is pressed
- **THEN** the route map container is shown on the whole screen and the map fills it

#### Scenario: Wheel on the whole screen

- **WHEN** the wheel is turned over the route map on the whole screen without the zoom key
- **THEN** the map zooms in and no note shows

#### Scenario: Back to the page

- **WHEN** the full screen button is pressed again while the route map is on the whole screen
- **THEN** the page shows again with the route map in its place and size, and turning the wheel without the zoom key scrolls the page and shows the note

#### Scenario: No button without full screen support

- **WHEN** the browser cannot show an element on the whole screen and a route map is drawn
- **THEN** the route map has no full screen button

#### Scenario: End maps have the button too

- **WHEN** the full screen button of a drawn end map is pressed
- **THEN** the end map container is shown on the whole screen
