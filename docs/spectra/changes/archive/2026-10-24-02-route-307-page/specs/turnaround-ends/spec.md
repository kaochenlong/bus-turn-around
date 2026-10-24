## MODIFIED Requirements

### Requirement: Verified end nature per route

Every route in the route list configuration SHALL carry the nature of both of its ends, keyed by the direction (`go_back` 0 and 1) of the trips that end there: `stop` when buses stop at that end before the next trip, `pass_through` when they drive on to the first stop of the next trip without stopping. The nature SHALL be a fact verified on the route's own data and written into the configuration together with the date and the evidence of the verification, and it SHALL NOT be derived from the stored layovers or vehicle positions when the page is read. The route Ids of the configuration SHALL remain the list of routes that have a route page. A route Id listed under another route's `member_routes` SHALL NOT be a key of the configuration, and the ends of the page route SHALL apply to the trips of its member routes, which share its two ends.

#### Scenario: Both ends of 中山幹線

- **WHEN** the ends of route 15373 are read
- **THEN** direction 0, whose trips end at 青年公園(馬場町), is `pass_through`, and direction 1, whose trips end at 職能發展學院二, is `stop`

#### Scenario: Both ends of 251

- **WHEN** the ends of route 10712 are read
- **THEN** direction 0, whose trips end at 臺北車站(開封), is `pass_through`, and direction 1, whose trips end at 福安居一, is `stop`

#### Scenario: Both ends of 251區

- **WHEN** the ends of route 11764 are read
- **THEN** direction 0, whose trips end at 捷運公館站, is `pass_through`, and direction 1, whose trips end at 福安居一, is `stop`

#### Scenario: Both ends of 307

- **WHEN** the ends of route 16111 are read
- **THEN** direction 0, whose trips end at 莊敬里, is `stop`, and direction 1, whose trips end at 臺北客運板橋前站(藝文), is `stop`, and the same two natures apply to the trips of its member route 19108

#### Scenario: Route list is the set of configured routes

- **WHEN** the configuration holds routes 15373, 10712, 11764, 16111 and 9001 and nothing else, 16111 listing 19108 and 9001 listing 9050 under `member_routes`
- **THEN** the routes that have a route page are exactly 15373, 10712, 11764, 16111 and 9001, and neither 19108 nor 9050 has one

#### Scenario: Member route configured as a key

- **WHEN** the configuration lists 9050 under route 9001's `member_routes` and also as a key of its own
- **THEN** reading the configuration raises a configuration error that names 9050
