# turnaround-ends Specification

## Purpose

Record, for each route that has a route page, whether buses stop at each end of the route or drive straight on to the first stop of the next trip (the nature of the 折返點), as a fact verified route by route and kept in configuration rather than derived from the data, and define how layovers ending at a pass-through end are treated: they are measured, but they are not rest opportunities.

## Requirements

### Requirement: Verified end nature per route

Every route in the route list configuration SHALL carry the nature of both of its ends, keyed by the direction (`go_back` 0 and 1) of the trips that end there: `stop` when buses stop at that end before the next trip, `pass_through` when they let passengers off at the last stop and drive on to the first stop of the next trip without waiting there. The nature SHALL be a fact verified on the route's own data and written into the configuration together with the date and the evidence of the verification, and it SHALL NOT be derived from the stored layovers or vehicle positions when the page is read. The route Ids of the configuration SHALL remain the list of routes that have a route page. A route Id listed under another route's `member_routes` SHALL NOT be a key of the configuration, and the ends of the page route SHALL apply to the trips of its member routes, which share its two ends.

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


<!-- @trace
source: 01-pass-through-wording
updated: 2026-10-24
code:
  - README.md
  - docs/background.md
  - app/components/route_summary_component.yml
  - app/components/buffer_trade_component.yml
  - config/route_page.yml
  - docs/decisions.md
  - app/components/turnaround_facilities_component.yml
  - app/components/data_limitations_component.yml
  - app/components/stop_sequence_component.yml
  - app/components/layover_chart_component.yml
  - analysis/README.md
  - app/components/layover_table_component.yml
tests:
  - spec/components/route_summary_component_spec.rb
  - spec/components/turnaround_facilities_component_spec.rb
  - spec/components/buffer_trade_component_spec.rb
  - spec/system/end_map_spec.rb
  - spec/models/route_page/cycles_spec.rb
  - spec/components/cycle_table_component_spec.rb
  - spec/analysis/turnaround_facilities_spec.rb
  - spec/components/stop_sequence_component_spec.rb
  - spec/models/route_page/buffer_trade_spec.rb
  - spec/components/layover_table_component_spec.rb
  - spec/models/route_page/ends_spec.rb
  - spec/requests/routes_spec.rb
  - spec/components/layover_chart_component_spec.rb
-->

---
### Requirement: Missing or unknown end nature is an error

When a configured route lacks the nature of either direction, or carries a value other than `stop` or `pass_through`, reading that route's ends SHALL fail with an error that names the route Id and the direction, and SHALL NOT assume a nature for it.

#### Scenario: One direction missing

- **WHEN** route 9001 is configured with direction 0 as `stop` and no entry for direction 1
- **THEN** reading its ends fails with an error that names 9001 and direction 1

#### Scenario: Unknown value

- **WHEN** direction 1 of route 9001 carries the value `depot`
- **THEN** reading its ends fails with an error that names 9001, direction 1 and the value `depot`


<!-- @trace
source: zhongshan-turnaround-ends
updated: 2026-10-22
code:
  - config/route_page.yml
  - app/components/layover_chart_component.rb
  - app/components/layover_chart_component.yml
  - app/components/layover_chart_component.html.erb
  - app/controllers/routes_controller.rb
  - app/components/buffer_trade_component.html.erb
  - app/components/layover_table_component.html.erb
  - app/components/buffer_trade_component.rb
  - app/components/buffer_trade_component.yml
  - app/components/layover_table_component.yml
  - app/models/route_page/buffer_trade.rb
  - app/components/layover_table_component.rb
  - app/components/data_limitations_component.yml
  - app/models/route_page/ends.rb
  - app/views/routes/show.html.erb
  - app/models/route_page.rb
tests:
  - spec/models/route_page/buffer_trade_spec.rb
  - spec/components/buffer_trade_component_spec.rb
  - spec/components/layover_chart_component_spec.rb
  - spec/components/layover_table_component_spec.rb
  - spec/requests/routes_spec.rb
  - spec/models/route_page/ends_spec.rb
-->

---
### Requirement: Layovers at a pass-through end are not rest opportunities

A layover whose ending trip's direction is a `pass_through` end SHALL remain a measured layover as defined by `layover-metrics`, and SHALL NOT count as a rest opportunity: the buffer estimate of `buffer-trade` SHALL exclude it from its base and report it separately, and the route page SHALL label that end as pass-through wherever it shows that end's layovers. The layover definition, its distribution and the rest-rule chains of `layover-metrics` SHALL NOT change.

#### Scenario: Pass-through end excluded from the estimate

- **WHEN** a route's direction 0 is `pass_through` and direction 1 is `stop`, and the covered days hold 3 layovers ending in direction 0 and 2 ending in direction 1
- **THEN** the buffer estimate's base is the 2 layovers ending in direction 1, and it reports 3 layovers at the pass-through end as not counted

#### Scenario: Pass-through end labelled on the page

- **WHEN** the layovers of a route whose direction 0 is `pass_through` and direction 1 is `stop` are shown
- **THEN** direction 0's layovers are labelled as ending at a pass-through end and direction 1's as ending at a stopping end, and the counts and percentiles of both directions are the ones of `layover-metrics`

<!-- @trace
source: zhongshan-turnaround-ends
updated: 2026-10-22
code:
  - config/route_page.yml
  - app/components/layover_chart_component.rb
  - app/components/layover_chart_component.yml
  - app/components/layover_chart_component.html.erb
  - app/controllers/routes_controller.rb
  - app/components/buffer_trade_component.html.erb
  - app/components/layover_table_component.html.erb
  - app/components/buffer_trade_component.rb
  - app/components/buffer_trade_component.yml
  - app/components/layover_table_component.yml
  - app/models/route_page/buffer_trade.rb
  - app/components/layover_table_component.rb
  - app/components/data_limitations_component.yml
  - app/models/route_page/ends.rb
  - app/views/routes/show.html.erb
  - app/models/route_page.rb
tests:
  - spec/models/route_page/buffer_trade_spec.rb
  - spec/components/buffer_trade_component_spec.rb
  - spec/components/layover_chart_component_spec.rb
  - spec/components/layover_table_component_spec.rb
  - spec/requests/routes_spec.rb
  - spec/models/route_page/ends_spec.rb
-->