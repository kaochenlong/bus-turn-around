## Purpose

Record, for each route that has a route page, whether buses stop at each end of the route or drive straight on to the first stop of the next trip (the nature of the 折返點), as a fact verified route by route and kept in configuration rather than derived from the data, and define how layovers ending at a pass-through end are treated: they are measured, but they are not rest opportunities.

## ADDED Requirements

### Requirement: Verified end nature per route

Every route in the route list configuration SHALL carry the nature of both of its ends, keyed by the direction (`go_back` 0 and 1) of the trips that end there: `stop` when buses stop at that end before the next trip, `pass_through` when they drive on to the first stop of the next trip without stopping. The nature SHALL be a fact verified on the route's own data and written into the configuration together with the date and the evidence of the verification, and it SHALL NOT be derived from the stored layovers or vehicle positions when the page is read. The route Ids of the configuration SHALL remain the list of routes that have a route page.

#### Scenario: Both ends of 中山幹線

- **WHEN** the ends of route 15373 are read
- **THEN** direction 0, whose trips end at 青年公園(馬場町), is `pass_through`, and direction 1, whose trips end at 職能發展學院二, is `stop`

#### Scenario: Route list is the set of configured routes

- **WHEN** the configuration holds routes 15373 and 9001 and nothing else
- **THEN** the routes that have a route page are exactly 15373 and 9001

### Requirement: Missing or unknown end nature is an error

When a configured route lacks the nature of either direction, or carries a value other than `stop` or `pass_through`, reading that route's ends SHALL fail with an error that names the route Id and the direction, and SHALL NOT assume a nature for it.

#### Scenario: One direction missing

- **WHEN** route 9001 is configured with direction 0 as `stop` and no entry for direction 1
- **THEN** reading its ends fails with an error that names 9001 and direction 1

#### Scenario: Unknown value

- **WHEN** direction 1 of route 9001 carries the value `depot`
- **THEN** reading its ends fails with an error that names 9001, direction 1 and the value `depot`

### Requirement: Layovers at a pass-through end are not rest opportunities

A layover whose ending trip's direction is a `pass_through` end SHALL remain a measured layover as defined by `layover-metrics`, and SHALL NOT count as a rest opportunity: the buffer estimate of `buffer-trade` SHALL exclude it from its base and report it separately, and the route page SHALL label that end as pass-through wherever it shows that end's layovers. The layover definition, its distribution and the rest-rule chains of `layover-metrics` SHALL NOT change.

#### Scenario: Pass-through end excluded from the estimate

- **WHEN** a route's direction 0 is `pass_through` and direction 1 is `stop`, and the covered days hold 3 layovers ending in direction 0 and 2 ending in direction 1
- **THEN** the buffer estimate's base is the 2 layovers ending in direction 1, and it reports 3 layovers at the pass-through end as not counted

#### Scenario: Pass-through end labelled on the page

- **WHEN** the layovers of a route whose direction 0 is `pass_through` and direction 1 is `stop` are shown
- **THEN** direction 0's layovers are labelled as ending at a pass-through end and direction 1's as ending at a stopping end, and the counts and percentiles of both directions are the ones of `layover-metrics`
