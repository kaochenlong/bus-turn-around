## MODIFIED Requirements

### Requirement: Verified end nature per route

Every route in the route list configuration SHALL carry the nature of both of its ends, keyed by the direction (`go_back` 0 and 1) of the trips that end there: `stop` when buses stop at that end before the next trip, `pass_through` when they drive on to the first stop of the next trip without stopping. The nature SHALL be a fact verified on the route's own data and written into the configuration together with the date and the evidence of the verification, and it SHALL NOT be derived from the stored layovers or vehicle positions when the page is read. The route Ids of the configuration SHALL remain the list of routes that have a route page.

#### Scenario: Both ends of 中山幹線

- **WHEN** the ends of route 15373 are read
- **THEN** direction 0, whose trips end at 青年公園(馬場町), is `pass_through`, and direction 1, whose trips end at 職能發展學院二, is `stop`

#### Scenario: Both ends of 251

- **WHEN** the ends of route 10712 are read
- **THEN** direction 0, whose trips end at 臺北車站(開封), is `pass_through`, and direction 1, whose trips end at 福安居一, is `stop`

#### Scenario: Both ends of 251區

- **WHEN** the ends of route 11764 are read
- **THEN** direction 0, whose trips end at 捷運公館站, is `pass_through`, and direction 1, whose trips end at 福安居一, is `stop`

#### Scenario: Route list is the set of configured routes

- **WHEN** the configuration holds routes 15373, 10712, 11764 and 9001 and nothing else
- **THEN** the routes that have a route page are exactly 15373, 10712, 11764 and 9001
