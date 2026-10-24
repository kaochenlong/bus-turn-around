## MODIFIED Requirements

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
