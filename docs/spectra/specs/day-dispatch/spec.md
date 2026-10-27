# day-dispatch Specification

## Purpose

Let a dispatcher lay out today's plan of a route from the measured data on the route's day dispatch page and use it through the day: record when a vehicle came back to an end, give a departure to another vehicle, and retime a departure, while the page shows who runs each departure, how long each vehicle stood, which departures wait for their vehicle and how much rest each sheet keeps in its tightest four hours. Everything stays in the dispatcher's browser; the server receives nothing.

## Requirements

### Requirement: Today's plan on the day dispatch page

While the day dispatch page shows no day, it SHALL show today's plan of the route: the sheets laid out as the timetable page lays them out before any manual edit, from the stored days of the selected day type within the seven Taipei days that end on the latest stored day of that type, with the measured departures per hour, the selected percentile of the planned run times, 85 unless another is selected, and the selected rest minutes at the stopping ends, 15 unless others are selected. The selected day type SHALL be the one in the address, and otherwise weekday when the current Taipei date is a Monday to Friday and holiday when it is a Saturday or Sunday; the dispatcher SHALL be able to select the other day type, which opens the page again with that day type, keeping the selected percentile and rest minutes. The plan SHALL state its covered days and day type, the number of vehicles and the number of departures from each end, and SHALL follow a change of the percentile or the rest minutes without a request to the server. When the route has no stored day of the selected day type, the page SHALL say that today's plan cannot be laid out and SHALL NOT offer to start. Starting SHALL store, in the browser, the day: for every vehicle number its laid-out trips in order with their direction, departure and arrival in minutes of the service day, every trip with an identifier that does not change during the day and with the vehicle it was laid out on as its planned vehicle; the route Id, the Taipei date at the moment of starting, that moment, the covered days with their day type, the percentile and the rest minutes, the directions whose trips end at a stopping end, and the planned run time of every direction and hour at that percentile. Every figure of the day dispatch SHALL start from no change. Starting SHALL show that day on the same page.

#### Scenario: Today's plan before starting

- **WHEN** this browser keeps no day dispatch of route 9001, whose latest stored weekday 2026-10-19 holds three departures from 甲站 and three from 乙站, and `/routes/9001/dispatch?type=weekday` is opened
- **THEN** the page shows today's plan laid out from 2026-10-19 with 4 vehicles, 3 departures from 甲站 and 3 from 乙站, and offers to start the day

#### Scenario: Day type from the day of the week

- **WHEN** the day dispatch page is opened without a day type on Saturday 2026-10-31, Taipei time
- **THEN** the selected day type is holiday

#### Scenario: No stored day of the selected type

- **WHEN** the dispatcher selects holiday on the day dispatch page of route 9001 and route 9001 has no stored holiday
- **THEN** the page says that today's plan cannot be laid out and offers no start

#### Scenario: Starting the day

- **WHEN** the dispatcher selects the percentile 50 in today's plan of route 9001 and starts the day
- **THEN** the day kept for 9001 under the current Taipei date holds the trips of the 4 laid-out vehicles, each trip with its laid-out vehicle as its planned vehicle, its basis names 2026-10-19, weekday, 50 and 15, and the page shows that day dispatch

#### Scenario: Run times of the day's percentile kept

- **WHEN** the dispatcher starts the day with the percentile set to 85
- **THEN** the day keeps the planned run time of every direction and hour at 85 and at no other percentile


<!-- @trace
source: 01-day-dispatch-model
updated: 2026-10-27
code:
  - app/components/timetable_sheet_component.yml
  - app/components/day_start_component.yml
  - app/components/site_bar_component.html.erb
  - app/components/day_dispatch_component.html.erb
  - app/views/layouts/application.html.erb
  - app/controllers/timetables_controller.rb
  - app/models/route_page/dispatch_plan.rb
  - app/frontend/timetable/day_storage.js
  - app/models/route_page/format.rb
  - app/frontend/timetable/day_page.js
  - README.md
  - app/components/day_dispatch_component.yml
  - app/frontend/timetable/component.js
  - app/frontend/entrypoints/application.js
  - app/components/site_bar_component.yml
  - app/components/day_dispatch_component.rb
  - app/components/day_start_component.rb
  - app/components/day_start_component.html.erb
  - app/views/day_dispatches/show.html.erb
  - app/components/timetable_header_component.html.erb
  - app/frontend/timetable/day.js
  - app/frontend/timetable/day_handoff.js
  - app/frontend/timetable/layout.js
  - config/locales/tw.yml
  - app/frontend/timetable/fields.js
  - docs/use-cases.md
  - app/components/timetable_header_component.yml
  - app/frontend/timetable/day_view.js
  - app/components/site_bar_component.rb
  - app/components/timetable_sheet_component.html.erb
  - config/locales/en.yml
  - app/controllers/day_dispatches_controller.rb
  - config/routes.rb
tests:
  - spec/components/day_dispatch_component_spec.rb
  - spec/requests/day_dispatches_spec.rb
  - app/frontend/timetable/day_handoff.test.js
  - spec/system/timetable_day_spec.rb
  - spec/components/day_start_component_spec.rb
  - app/frontend/timetable/day.test.js
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/models/route_page/dispatch_plan_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/day_storage.test.js
  - app/frontend/timetable/fields.test.js
  - app/frontend/timetable/layout.test.js
-->

---
### Requirement: Day dispatch page

The day dispatch of a route SHALL have a page of its own at `/routes/<Id>/dispatch`, apart from the timetable page; it SHALL answer GET only and store nothing on the server. A route that is not configured SHALL get 404; a day type other than `weekday` and `holiday`, or a percentile or rest minutes that the timetable page does not accept, SHALL get 400. Without JavaScript the page SHALL say that it needs JavaScript. The page SHALL show the day of the route that this browser tab could not keep at its latest change, saying that it is not kept on this computer; failing that, the day this browser keeps for the route for the current Taipei date; failing that, today's plan as "Today's plan on the day dispatch page" defines it, offering to continue the day kept for the previous Taipei date when there is one. The page SHALL NOT go to another page by itself. Its link to the plan's timetable SHALL lead to the timetable page of the route with the covered days, the percentile and the rest minutes the shown day was started from. Starting again SHALL ask for confirmation, discard the shown day and show today's plan on the same page.

#### Scenario: Kept day on its own page

- **WHEN** this browser keeps a day dispatch of route 9001 for the current Taipei date and `/routes/9001/dispatch` is opened
- **THEN** that day dispatch is shown

#### Scenario: Nothing kept

- **WHEN** this browser keeps no day dispatch of route 9001 and `/routes/9001/dispatch` is opened
- **THEN** the page shows today's plan with the control that starts the day, and the address stays `/routes/9001/dispatch`

#### Scenario: Previous day offered

- **WHEN** this browser keeps a day dispatch of route 9001 for the previous Taipei date only and `/routes/9001/dispatch` is opened
- **THEN** the page shows today's plan and offers to continue the day of the previous date, and continuing shows that day dispatch

#### Scenario: Route not configured

- **WHEN** `/routes/9999/dispatch` is requested
- **THEN** the response is 404

#### Scenario: Unknown day type

- **WHEN** `/routes/9001/dispatch?type=sunday` is requested
- **THEN** the response is 400

#### Scenario: Day that could not be kept

- **WHEN** writing to the local storage throws and the dispatcher starts the day on the day dispatch page of 9001
- **THEN** the page shows that day and says that it is not kept on this computer, leaving for the timetable page and opening the day dispatch page again still shows it, and loading the day dispatch page again shows today's plan instead

#### Scenario: Tab's day newer than the kept one

- **WHEN** the day of 9001 was kept in this browser, writing to the local storage then throws while the dispatcher retypes the 06:00 departure as 06:10, and the dispatcher leaves for the timetable page and opens the day dispatch page again
- **THEN** the page shows the 06:10 departure and says that the day is not kept on this computer

#### Scenario: Plan's timetable on the day's basis

- **WHEN** the day of 9001 was started from today's plan laid out from 2026-10-19 with the percentile 50 and 15 rest minutes
- **THEN** the day dispatch's link to the plan's timetable leads to the timetable page of 9001 with `day=2026-10-19`, `range=day`, `p=50` and `buffer=15`

#### Scenario: Starting again

- **WHEN** the day dispatch of 9001 is shown and the dispatcher starts again and confirms
- **THEN** the day is discarded and the same page shows today's plan; when the dispatcher dismisses the confirmation instead, the day dispatch stays


<!-- @trace
source: 01-day-dispatch-model
updated: 2026-10-27
code:
  - app/components/timetable_sheet_component.yml
  - app/components/day_start_component.yml
  - app/components/site_bar_component.html.erb
  - app/components/day_dispatch_component.html.erb
  - app/views/layouts/application.html.erb
  - app/controllers/timetables_controller.rb
  - app/models/route_page/dispatch_plan.rb
  - app/frontend/timetable/day_storage.js
  - app/models/route_page/format.rb
  - app/frontend/timetable/day_page.js
  - README.md
  - app/components/day_dispatch_component.yml
  - app/frontend/timetable/component.js
  - app/frontend/entrypoints/application.js
  - app/components/site_bar_component.yml
  - app/components/day_dispatch_component.rb
  - app/components/day_start_component.rb
  - app/components/day_start_component.html.erb
  - app/views/day_dispatches/show.html.erb
  - app/components/timetable_header_component.html.erb
  - app/frontend/timetable/day.js
  - app/frontend/timetable/day_handoff.js
  - app/frontend/timetable/layout.js
  - config/locales/tw.yml
  - app/frontend/timetable/fields.js
  - docs/use-cases.md
  - app/components/timetable_header_component.yml
  - app/frontend/timetable/day_view.js
  - app/components/site_bar_component.rb
  - app/components/timetable_sheet_component.html.erb
  - config/locales/en.yml
  - app/controllers/day_dispatches_controller.rb
  - config/routes.rb
tests:
  - spec/components/day_dispatch_component_spec.rb
  - spec/requests/day_dispatches_spec.rb
  - app/frontend/timetable/day_handoff.test.js
  - spec/system/timetable_day_spec.rb
  - spec/components/day_start_component_spec.rb
  - app/frontend/timetable/day.test.js
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/models/route_page/dispatch_plan_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/day_storage.test.js
  - app/frontend/timetable/fields.test.js
  - app/frontend/timetable/layout.test.js
-->

---
### Requirement: No trip moves by itself

In the day dispatch view a trip's departure SHALL change only when the dispatcher types a departure for it, a trip's vehicle only when the dispatcher gives its departure to another vehicle, and a trip's arrival only when the dispatcher records an arrival for it or types its departure. No other trip SHALL change as a consequence. A departure whose vehicle's previous trip arrives later than that departure SHALL be marked as waiting for its vehicle, with its stop shown as a negative number of minutes. A stop shorter than the rest minutes SHALL be shown as its number of minutes. The push of later trips that the timetable capability applies after a manual edit SHALL NOT apply in the day dispatch view.

#### Scenario: A late arrival marks the next departure

- **WHEN** vehicle 1's trip from 乙站 arrives at 甲站 at 17:52 and vehicle 1's next departure from 甲站 is 17:40
- **THEN** the 17:40 departure stays at 17:40 and is marked as waiting for its vehicle with a stop of −12, and every other trip keeps its times


<!-- @trace
source: 01-day-dispatch-model
updated: 2026-10-27
code:
  - app/components/timetable_sheet_component.yml
  - app/components/day_start_component.yml
  - app/components/site_bar_component.html.erb
  - app/components/day_dispatch_component.html.erb
  - app/views/layouts/application.html.erb
  - app/controllers/timetables_controller.rb
  - app/models/route_page/dispatch_plan.rb
  - app/frontend/timetable/day_storage.js
  - app/models/route_page/format.rb
  - app/frontend/timetable/day_page.js
  - README.md
  - app/components/day_dispatch_component.yml
  - app/frontend/timetable/component.js
  - app/frontend/entrypoints/application.js
  - app/components/site_bar_component.yml
  - app/components/day_dispatch_component.rb
  - app/components/day_start_component.rb
  - app/components/day_start_component.html.erb
  - app/views/day_dispatches/show.html.erb
  - app/components/timetable_header_component.html.erb
  - app/frontend/timetable/day.js
  - app/frontend/timetable/day_handoff.js
  - app/frontend/timetable/layout.js
  - config/locales/tw.yml
  - app/frontend/timetable/fields.js
  - docs/use-cases.md
  - app/components/timetable_header_component.yml
  - app/frontend/timetable/day_view.js
  - app/components/site_bar_component.rb
  - app/components/timetable_sheet_component.html.erb
  - config/locales/en.yml
  - app/controllers/day_dispatches_controller.rb
  - config/routes.rb
tests:
  - spec/components/day_dispatch_component_spec.rb
  - spec/requests/day_dispatches_spec.rb
  - app/frontend/timetable/day_handoff.test.js
  - spec/system/timetable_day_spec.rb
  - spec/components/day_start_component_spec.rb
  - app/frontend/timetable/day.test.js
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/models/route_page/dispatch_plan_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/day_storage.test.js
  - app/frontend/timetable/fields.test.js
  - app/frontend/timetable/layout.test.js
-->

---
### Requirement: Recording an arrival

The dispatcher SHALL be able to record, for a vehicle, an end and a time, that the vehicle arrived at that end at that time, with an optional reason. The recorded time SHALL become the arrival of the vehicle's last trip that ends at that end and departs at or before the recorded time, and that arrival SHALL be marked as recorded. When the vehicle has no such trip, the record SHALL be refused with a message saying so, and nothing SHALL be added to the change log. A later record for the same trip SHALL take effect over an earlier one, and both SHALL stay in the change log.

#### Scenario: Recorded arrival replaces the planned one

- **WHEN** vehicle 1's trip departs 乙站 at 16:00 with a planned arrival at 甲站 of 17:14 and the dispatcher records vehicle 1 at 甲站 at 17:52
- **THEN** that trip arrives at 17:52, marked as recorded, and the change log lists the record

#### Scenario: No trip toward that end

- **WHEN** the dispatcher records vehicle 1 at 甲站 at 05:00 and vehicle 1's first trip toward 甲站 departs at 06:00
- **THEN** the record is refused with a message, and the change log is unchanged


<!-- @trace
source: 01-day-dispatch-model
updated: 2026-10-27
code:
  - app/components/timetable_sheet_component.yml
  - app/components/day_start_component.yml
  - app/components/site_bar_component.html.erb
  - app/components/day_dispatch_component.html.erb
  - app/views/layouts/application.html.erb
  - app/controllers/timetables_controller.rb
  - app/models/route_page/dispatch_plan.rb
  - app/frontend/timetable/day_storage.js
  - app/models/route_page/format.rb
  - app/frontend/timetable/day_page.js
  - README.md
  - app/components/day_dispatch_component.yml
  - app/frontend/timetable/component.js
  - app/frontend/entrypoints/application.js
  - app/components/site_bar_component.yml
  - app/components/day_dispatch_component.rb
  - app/components/day_start_component.rb
  - app/components/day_start_component.html.erb
  - app/views/day_dispatches/show.html.erb
  - app/components/timetable_header_component.html.erb
  - app/frontend/timetable/day.js
  - app/frontend/timetable/day_handoff.js
  - app/frontend/timetable/layout.js
  - config/locales/tw.yml
  - app/frontend/timetable/fields.js
  - docs/use-cases.md
  - app/components/timetable_header_component.yml
  - app/frontend/timetable/day_view.js
  - app/components/site_bar_component.rb
  - app/components/timetable_sheet_component.html.erb
  - config/locales/en.yml
  - app/controllers/day_dispatches_controller.rb
  - config/routes.rb
tests:
  - spec/components/day_dispatch_component_spec.rb
  - spec/requests/day_dispatches_spec.rb
  - app/frontend/timetable/day_handoff.test.js
  - spec/system/timetable_day_spec.rb
  - spec/components/day_start_component_spec.rb
  - app/frontend/timetable/day.test.js
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/models/route_page/dispatch_plan_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/day_storage.test.js
  - app/frontend/timetable/fields.test.js
  - app/frontend/timetable/layout.test.js
-->

---
### Requirement: Giving a departure to another vehicle

The dispatcher SHALL be able to give a departure to another vehicle, with an optional reason. Giving departure D, which leaves end E at time t on vehicle A, to vehicle B SHALL exchange A's trips from D onward with B's trips from B's first trip that departs at or after t. The change SHALL be accepted only when that trip of B leaves from E, or, when B has no trip departing at or after t, when B's last trip ends at E. Otherwise it SHALL be refused with a message that names B and the end it next leaves from, or the end where its day ends, and nothing SHALL be added to the change log. A trip SHALL keep its departure and arrival when it moves to another vehicle. A trip whose current vehicle differs from its planned vehicle SHALL show its planned vehicle.

#### Scenario: Two vehicles exchange the rest of their day

- **WHEN** vehicle 1's departures from 甲站 are 17:40 and 21:00, vehicle 2 arrived at 甲站 at 17:34 and its departures from 甲站 are 18:00 and 21:20, and the dispatcher gives the 17:40 departure to vehicle 2
- **THEN** vehicle 2 runs the 17:40 and 21:00 departures and the trips between them, vehicle 1 runs the 18:00 and 21:20 departures and the trips between them, each of those trips shows its planned vehicle, and the header counts 1 vehicle change

#### Scenario: Vehicle away from that end

- **WHEN** the dispatcher gives vehicle 1's 17:40 departure from 甲站 to vehicle 3, whose first trip at or after 17:40 leaves from 乙站
- **THEN** the change is refused with a message saying that vehicle 3 next leaves from 乙站, and no trip changes


<!-- @trace
source: 01-day-dispatch-model
updated: 2026-10-27
code:
  - app/components/timetable_sheet_component.yml
  - app/components/day_start_component.yml
  - app/components/site_bar_component.html.erb
  - app/components/day_dispatch_component.html.erb
  - app/views/layouts/application.html.erb
  - app/controllers/timetables_controller.rb
  - app/models/route_page/dispatch_plan.rb
  - app/frontend/timetable/day_storage.js
  - app/models/route_page/format.rb
  - app/frontend/timetable/day_page.js
  - README.md
  - app/components/day_dispatch_component.yml
  - app/frontend/timetable/component.js
  - app/frontend/entrypoints/application.js
  - app/components/site_bar_component.yml
  - app/components/day_dispatch_component.rb
  - app/components/day_start_component.rb
  - app/components/day_start_component.html.erb
  - app/views/day_dispatches/show.html.erb
  - app/components/timetable_header_component.html.erb
  - app/frontend/timetable/day.js
  - app/frontend/timetable/day_handoff.js
  - app/frontend/timetable/layout.js
  - config/locales/tw.yml
  - app/frontend/timetable/fields.js
  - docs/use-cases.md
  - app/components/timetable_header_component.yml
  - app/frontend/timetable/day_view.js
  - app/components/site_bar_component.rb
  - app/components/timetable_sheet_component.html.erb
  - config/locales/en.yml
  - app/controllers/day_dispatches_controller.rb
  - config/routes.rb
tests:
  - spec/components/day_dispatch_component_spec.rb
  - spec/requests/day_dispatches_spec.rb
  - app/frontend/timetable/day_handoff.test.js
  - spec/system/timetable_day_spec.rb
  - spec/components/day_start_component_spec.rb
  - app/frontend/timetable/day.test.js
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/models/route_page/dispatch_plan_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/day_storage.test.js
  - app/frontend/timetable/fields.test.js
  - app/frontend/timetable/layout.test.js
-->

---
### Requirement: Typing a departure in the day dispatch

The departure of every trip in the day dispatch view SHALL be editable in a field that accepts the writings the timetable page's departure fields accept. An accepted typed time SHALL become the trip's departure and mark the trip as typed. Its arrival SHALL be the recorded arrival when one is in effect, and otherwise the typed departure plus the planned run time of the typed departure's hour that the day kept when it started, whatever run times today's plan holds when the day is continued. No other trip SHALL change. A typed time that cannot be read SHALL be rejected with a message that quotes it and gives the accepted writings, and nothing SHALL be added to the change log.

#### Scenario: Later departure

- **WHEN** the planned run time of direction 0 in the 18 hour is 57 minutes and the dispatcher types 18:10 for vehicle 1's 18:00 departure of direction 0
- **THEN** that trip departs at 18:10 and arrives at 19:07, is marked as typed, and the header counts 1 typed departure

#### Scenario: Run times kept from the start

- **WHEN** the day was started when the planned run time of direction 0 in the 18 hour was 57 minutes, a newer stored day makes today's plan give 60 minutes for that hour when the day is continued, and the dispatcher types 18:10 for vehicle 1's 18:00 departure of direction 0
- **THEN** that trip arrives at 19:07

#### Scenario: Unreadable time

- **WHEN** the dispatcher types 18:70 for a departure
- **THEN** the field is marked invalid, the message quotes 18:70 and gives the accepted writings, and the departure keeps its time


<!-- @trace
source: 01-day-dispatch-model
updated: 2026-10-27
code:
  - app/components/timetable_sheet_component.yml
  - app/components/day_start_component.yml
  - app/components/site_bar_component.html.erb
  - app/components/day_dispatch_component.html.erb
  - app/views/layouts/application.html.erb
  - app/controllers/timetables_controller.rb
  - app/models/route_page/dispatch_plan.rb
  - app/frontend/timetable/day_storage.js
  - app/models/route_page/format.rb
  - app/frontend/timetable/day_page.js
  - README.md
  - app/components/day_dispatch_component.yml
  - app/frontend/timetable/component.js
  - app/frontend/entrypoints/application.js
  - app/components/site_bar_component.yml
  - app/components/day_dispatch_component.rb
  - app/components/day_start_component.rb
  - app/components/day_start_component.html.erb
  - app/views/day_dispatches/show.html.erb
  - app/components/timetable_header_component.html.erb
  - app/frontend/timetable/day.js
  - app/frontend/timetable/day_handoff.js
  - app/frontend/timetable/layout.js
  - config/locales/tw.yml
  - app/frontend/timetable/fields.js
  - docs/use-cases.md
  - app/components/timetable_header_component.yml
  - app/frontend/timetable/day_view.js
  - app/components/site_bar_component.rb
  - app/components/timetable_sheet_component.html.erb
  - config/locales/en.yml
  - app/controllers/day_dispatches_controller.rb
  - config/routes.rb
tests:
  - spec/components/day_dispatch_component_spec.rb
  - spec/requests/day_dispatches_spec.rb
  - app/frontend/timetable/day_handoff.test.js
  - spec/system/timetable_day_spec.rb
  - spec/components/day_start_component_spec.rb
  - app/frontend/timetable/day.test.js
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/models/route_page/dispatch_plan_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/day_storage.test.js
  - app/frontend/timetable/fields.test.js
  - app/frontend/timetable/layout.test.js
-->

---
### Requirement: Departures at an end

The day dispatch view SHALL list the departures from one end at a time, in departure order. Each SHALL show its departure, its planned vehicle, its current vehicle, the arrival at that end of its current vehicle's previous trip (marked when recorded, absent for a vehicle's first trip), the stop in whole minutes, and a status: waiting for its vehicle as defined in "No trip moves by itself"; otherwise departed when its departure is before now, next for the first departure at or after now, and planned for the rest. The view SHALL offer one control per end. The end listed first SHALL be the end where direction 0 departs when trips of direction 1 end at a stopping end, and the end where direction 1 departs otherwise. Now SHALL be the browser's clock in Taipei time, counted in minutes of the kept day, so that a time after midnight counts on from 24:00.

#### Scenario: Statuses around now

- **WHEN** now is 17:55 and the departures from 甲站 are 17:40 on vehicle 2, 18:00 on vehicle 1 and 18:20 on vehicle 3, each vehicle back before its departure
- **THEN** 17:40 is departed, 18:00 is next and 18:20 is planned

#### Scenario: Stopping end listed first

- **WHEN** trips of direction 1 end at a stopping end and trips of direction 0 end at a pass-through end
- **THEN** the view first lists the departures of direction 0


<!-- @trace
source: 01-day-dispatch-model
updated: 2026-10-27
code:
  - app/components/timetable_sheet_component.yml
  - app/components/day_start_component.yml
  - app/components/site_bar_component.html.erb
  - app/components/day_dispatch_component.html.erb
  - app/views/layouts/application.html.erb
  - app/controllers/timetables_controller.rb
  - app/models/route_page/dispatch_plan.rb
  - app/frontend/timetable/day_storage.js
  - app/models/route_page/format.rb
  - app/frontend/timetable/day_page.js
  - README.md
  - app/components/day_dispatch_component.yml
  - app/frontend/timetable/component.js
  - app/frontend/entrypoints/application.js
  - app/components/site_bar_component.yml
  - app/components/day_dispatch_component.rb
  - app/components/day_start_component.rb
  - app/components/day_start_component.html.erb
  - app/views/day_dispatches/show.html.erb
  - app/components/timetable_header_component.html.erb
  - app/frontend/timetable/day.js
  - app/frontend/timetable/day_handoff.js
  - app/frontend/timetable/layout.js
  - config/locales/tw.yml
  - app/frontend/timetable/fields.js
  - docs/use-cases.md
  - app/components/timetable_header_component.yml
  - app/frontend/timetable/day_view.js
  - app/components/site_bar_component.rb
  - app/components/timetable_sheet_component.html.erb
  - config/locales/en.yml
  - app/controllers/day_dispatches_controller.rb
  - config/routes.rb
tests:
  - spec/components/day_dispatch_component_spec.rb
  - spec/requests/day_dispatches_spec.rb
  - app/frontend/timetable/day_handoff.test.js
  - spec/system/timetable_day_spec.rb
  - spec/components/day_start_component_spec.rb
  - app/frontend/timetable/day.test.js
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/models/route_page/dispatch_plan_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/day_storage.test.js
  - app/frontend/timetable/fields.test.js
  - app/frontend/timetable/layout.test.js
-->

---
### Requirement: Vehicles at an end

Beside the departures, the view SHALL list the vehicles standing at the selected end now, with each one's arrival, the whole minutes it has stood until now and its next departure: a vehicle stands at an end when its latest trip that arrives at or before now ends there and its next trip has not departed. The view SHALL also list the next four vehicles due to arrive at that end after now, each with its arrival and its next departure.

#### Scenario: Vehicle that just came back

- **WHEN** now is 17:55 and vehicle 1 arrived at 甲站 at 17:52 with its next departure from 甲站 at 18:00
- **THEN** vehicle 1 is listed at 甲站 with 17:52, 3 minutes stood and 18:00


<!-- @trace
source: 01-day-dispatch-model
updated: 2026-10-27
code:
  - app/components/timetable_sheet_component.yml
  - app/components/day_start_component.yml
  - app/components/site_bar_component.html.erb
  - app/components/day_dispatch_component.html.erb
  - app/views/layouts/application.html.erb
  - app/controllers/timetables_controller.rb
  - app/models/route_page/dispatch_plan.rb
  - app/frontend/timetable/day_storage.js
  - app/models/route_page/format.rb
  - app/frontend/timetable/day_page.js
  - README.md
  - app/components/day_dispatch_component.yml
  - app/frontend/timetable/component.js
  - app/frontend/entrypoints/application.js
  - app/components/site_bar_component.yml
  - app/components/day_dispatch_component.rb
  - app/components/day_start_component.rb
  - app/components/day_start_component.html.erb
  - app/views/day_dispatches/show.html.erb
  - app/components/timetable_header_component.html.erb
  - app/frontend/timetable/day.js
  - app/frontend/timetable/day_handoff.js
  - app/frontend/timetable/layout.js
  - config/locales/tw.yml
  - app/frontend/timetable/fields.js
  - docs/use-cases.md
  - app/components/timetable_header_component.yml
  - app/frontend/timetable/day_view.js
  - app/components/site_bar_component.rb
  - app/components/timetable_sheet_component.html.erb
  - config/locales/en.yml
  - app/controllers/day_dispatches_controller.rb
  - config/routes.rb
tests:
  - spec/components/day_dispatch_component_spec.rb
  - spec/requests/day_dispatches_spec.rb
  - app/frontend/timetable/day_handoff.test.js
  - spec/system/timetable_day_spec.rb
  - spec/components/day_start_component_spec.rb
  - app/frontend/timetable/day.test.js
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/models/route_page/dispatch_plan_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/day_storage.test.js
  - app/frontend/timetable/fields.test.js
  - app/frontend/timetable/layout.test.js
-->

---
### Requirement: Figures of the day dispatch

The view SHALL show the number of vehicle changes in effect, the number of typed departures in effect, the number of departures waiting for their vehicle, and the shortest stop at a stopping end that is not negative, with its vehicle and the departure that follows it. For every vehicle it SHALL show the rest in the tightest four hours of its current trips, computed by the window rule the timetable capability applies to a sheet and labelled as what one person would get driving the whole sheet, with the value of its planned trips beside it when the two differ. The figures SHALL be numbers only, without marking anything as compliant or non-compliant and without colours that judge.

#### Scenario: Rest after a vehicle change

- **WHEN** a vehicle change and a recorded arrival leave two vehicles with different trips than planned
- **THEN** each of the two shows its rest in the tightest four hours with its planned value beside it, and the shortest stop names the vehicle and departure where it falls

##### Example: 251區 vehicles 8 and 10

- **GIVEN** both vehicles' trips alternate direction 0 and direction 1, starting with direction 0, trips of direction 1 end at the stopping end, vehicle 8 runs 07:00–08:03, 08:45–09:47, 10:40–11:36, 12:20–13:19, 14:20–15:17, 16:00–17:14, 17:40–18:45, 19:20–20:23, 21:00–21:46, 22:45–23:40, vehicle 10 runs 07:20–08:23, 09:00–10:02, 11:00–11:58, 12:40–13:39, 14:40–15:37, 16:20–17:34, 18:00–18:57, 19:40–20:43, 21:20–22:06, 23:00–24:07, and their planned rests in the tightest four hours are 61 and 69 minutes
- **WHEN** vehicle 8 is recorded at the stopping end at 17:52 and the 17:40 departure is given to vehicle 10
- **THEN** vehicle 8 runs 18:00, 19:40, 21:20 and 23:00 after its 16:00 trip and shows 43 with 61 beside it, vehicle 10 runs 17:40, 19:20, 21:00 and 22:45 after its 16:20 trip and shows 35 with 69 beside it, the shortest stop is 6 minutes on vehicle 10 before 17:40, and no departure waits for its vehicle


<!-- @trace
source: 01-day-dispatch-model
updated: 2026-10-27
code:
  - app/components/timetable_sheet_component.yml
  - app/components/day_start_component.yml
  - app/components/site_bar_component.html.erb
  - app/components/day_dispatch_component.html.erb
  - app/views/layouts/application.html.erb
  - app/controllers/timetables_controller.rb
  - app/models/route_page/dispatch_plan.rb
  - app/frontend/timetable/day_storage.js
  - app/models/route_page/format.rb
  - app/frontend/timetable/day_page.js
  - README.md
  - app/components/day_dispatch_component.yml
  - app/frontend/timetable/component.js
  - app/frontend/entrypoints/application.js
  - app/components/site_bar_component.yml
  - app/components/day_dispatch_component.rb
  - app/components/day_start_component.rb
  - app/components/day_start_component.html.erb
  - app/views/day_dispatches/show.html.erb
  - app/components/timetable_header_component.html.erb
  - app/frontend/timetable/day.js
  - app/frontend/timetable/day_handoff.js
  - app/frontend/timetable/layout.js
  - config/locales/tw.yml
  - app/frontend/timetable/fields.js
  - docs/use-cases.md
  - app/components/timetable_header_component.yml
  - app/frontend/timetable/day_view.js
  - app/components/site_bar_component.rb
  - app/components/timetable_sheet_component.html.erb
  - config/locales/en.yml
  - app/controllers/day_dispatches_controller.rb
  - config/routes.rb
tests:
  - spec/components/day_dispatch_component_spec.rb
  - spec/requests/day_dispatches_spec.rb
  - app/frontend/timetable/day_handoff.test.js
  - spec/system/timetable_day_spec.rb
  - spec/components/day_start_component_spec.rb
  - app/frontend/timetable/day.test.js
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/models/route_page/dispatch_plan_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/day_storage.test.js
  - app/frontend/timetable/fields.test.js
  - app/frontend/timetable/layout.test.js
-->

---
### Requirement: Change log and undo of the day dispatch

Every accepted change SHALL be listed in a change log with the Taipei time it was recorded, what it did and its reason when given. A control SHALL undo the latest change still in effect: the change SHALL stay in the log marked as undone, and the day SHALL be computed again from the kept day plan with every change still in effect applied in the order recorded. A change made after an undo SHALL be listed after it. An undone change SHALL NOT be undone again or redone.

#### Scenario: Undoing a vehicle change

- **WHEN** the latest change in effect gave vehicle 1's 17:40 departure to vehicle 2 and the dispatcher undoes it
- **THEN** both vehicles run the trips they ran before that change, the log keeps the change marked as undone, and the header counts 0 vehicle changes


<!-- @trace
source: 01-day-dispatch-model
updated: 2026-10-27
code:
  - app/components/timetable_sheet_component.yml
  - app/components/day_start_component.yml
  - app/components/site_bar_component.html.erb
  - app/components/day_dispatch_component.html.erb
  - app/views/layouts/application.html.erb
  - app/controllers/timetables_controller.rb
  - app/models/route_page/dispatch_plan.rb
  - app/frontend/timetable/day_storage.js
  - app/models/route_page/format.rb
  - app/frontend/timetable/day_page.js
  - README.md
  - app/components/day_dispatch_component.yml
  - app/frontend/timetable/component.js
  - app/frontend/entrypoints/application.js
  - app/components/site_bar_component.yml
  - app/components/day_dispatch_component.rb
  - app/components/day_start_component.rb
  - app/components/day_start_component.html.erb
  - app/views/day_dispatches/show.html.erb
  - app/components/timetable_header_component.html.erb
  - app/frontend/timetable/day.js
  - app/frontend/timetable/day_handoff.js
  - app/frontend/timetable/layout.js
  - config/locales/tw.yml
  - app/frontend/timetable/fields.js
  - docs/use-cases.md
  - app/components/timetable_header_component.yml
  - app/frontend/timetable/day_view.js
  - app/components/site_bar_component.rb
  - app/components/timetable_sheet_component.html.erb
  - config/locales/en.yml
  - app/controllers/day_dispatches_controller.rb
  - config/routes.rb
tests:
  - spec/components/day_dispatch_component_spec.rb
  - spec/requests/day_dispatches_spec.rb
  - app/frontend/timetable/day_handoff.test.js
  - spec/system/timetable_day_spec.rb
  - spec/components/day_start_component_spec.rb
  - app/frontend/timetable/day.test.js
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/models/route_page/dispatch_plan_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/day_storage.test.js
  - app/frontend/timetable/fields.test.js
  - app/frontend/timetable/layout.test.js
-->

---
### Requirement: Day dispatch kept in this browser

The day dispatch SHALL be saved in the browser's local storage after every change, under a key of the route Id and the date, with a format version; nothing about it SHALL be sent to the server. Opening the day dispatch page of a route SHALL show the day kept for that route for the current Taipei date, and offer the one kept for the previous Taipei date, as "Day dispatch page" defines it. Starting again SHALL ask for confirmation and then discard the kept day. Leaving the page SHALL keep it. When the local storage cannot be read or written, the view SHALL say that the day is not kept on this computer and SHALL keep working. A kept day that cannot be read or has another format version SHALL be treated as absent, with one line saying so.

#### Scenario: Reload keeps the day

- **WHEN** the dispatcher records an arrival and reloads the day dispatch page of that route on the same date
- **THEN** the page shows that day dispatch with the recorded arrival

#### Scenario: Storage refused

- **WHEN** writing to the local storage throws
- **THEN** the view says that the day is not kept on this computer and the change still takes effect on the page

#### Scenario: Kept day that cannot be read

- **WHEN** the local storage holds, under the route's key for the current Taipei date, text that is not JSON or a day of another format version
- **THEN** the day dispatch page shows today's plan and says in one line that the kept day could not be read


<!-- @trace
source: 01-day-dispatch-model
updated: 2026-10-27
code:
  - app/components/timetable_sheet_component.yml
  - app/components/day_start_component.yml
  - app/components/site_bar_component.html.erb
  - app/components/day_dispatch_component.html.erb
  - app/views/layouts/application.html.erb
  - app/controllers/timetables_controller.rb
  - app/models/route_page/dispatch_plan.rb
  - app/frontend/timetable/day_storage.js
  - app/models/route_page/format.rb
  - app/frontend/timetable/day_page.js
  - README.md
  - app/components/day_dispatch_component.yml
  - app/frontend/timetable/component.js
  - app/frontend/entrypoints/application.js
  - app/components/site_bar_component.yml
  - app/components/day_dispatch_component.rb
  - app/components/day_start_component.rb
  - app/components/day_start_component.html.erb
  - app/views/day_dispatches/show.html.erb
  - app/components/timetable_header_component.html.erb
  - app/frontend/timetable/day.js
  - app/frontend/timetable/day_handoff.js
  - app/frontend/timetable/layout.js
  - config/locales/tw.yml
  - app/frontend/timetable/fields.js
  - docs/use-cases.md
  - app/components/timetable_header_component.yml
  - app/frontend/timetable/day_view.js
  - app/components/site_bar_component.rb
  - app/components/timetable_sheet_component.html.erb
  - config/locales/en.yml
  - app/controllers/day_dispatches_controller.rb
  - config/routes.rb
tests:
  - spec/components/day_dispatch_component_spec.rb
  - spec/requests/day_dispatches_spec.rb
  - app/frontend/timetable/day_handoff.test.js
  - spec/system/timetable_day_spec.rb
  - spec/components/day_start_component_spec.rb
  - app/frontend/timetable/day.test.js
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/models/route_page/dispatch_plan_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/day_storage.test.js
  - app/frontend/timetable/fields.test.js
  - app/frontend/timetable/layout.test.js
-->

---
### Requirement: No vehicle identifiers from the data in the day dispatch

The day dispatch view SHALL show vehicles only by the vehicle numbers of the sheets and SHALL NOT contain any vehicle identifier from the data.

#### Scenario: Only sheet numbers

- **WHEN** the day dispatch view is shown for a route
- **THEN** it names vehicles by sheet numbers such as 1 and 2 and contains no `BusID` value of the route's trips

<!-- @trace
source: 01-day-dispatch-model
updated: 2026-10-27
code:
  - app/components/timetable_sheet_component.yml
  - app/components/day_start_component.yml
  - app/components/site_bar_component.html.erb
  - app/components/day_dispatch_component.html.erb
  - app/views/layouts/application.html.erb
  - app/controllers/timetables_controller.rb
  - app/models/route_page/dispatch_plan.rb
  - app/frontend/timetable/day_storage.js
  - app/models/route_page/format.rb
  - app/frontend/timetable/day_page.js
  - README.md
  - app/components/day_dispatch_component.yml
  - app/frontend/timetable/component.js
  - app/frontend/entrypoints/application.js
  - app/components/site_bar_component.yml
  - app/components/day_dispatch_component.rb
  - app/components/day_start_component.rb
  - app/components/day_start_component.html.erb
  - app/views/day_dispatches/show.html.erb
  - app/components/timetable_header_component.html.erb
  - app/frontend/timetable/day.js
  - app/frontend/timetable/day_handoff.js
  - app/frontend/timetable/layout.js
  - config/locales/tw.yml
  - app/frontend/timetable/fields.js
  - docs/use-cases.md
  - app/components/timetable_header_component.yml
  - app/frontend/timetable/day_view.js
  - app/components/site_bar_component.rb
  - app/components/timetable_sheet_component.html.erb
  - config/locales/en.yml
  - app/controllers/day_dispatches_controller.rb
  - config/routes.rb
tests:
  - spec/components/day_dispatch_component_spec.rb
  - spec/requests/day_dispatches_spec.rb
  - app/frontend/timetable/day_handoff.test.js
  - spec/system/timetable_day_spec.rb
  - spec/components/day_start_component_spec.rb
  - app/frontend/timetable/day.test.js
  - spec/requests/timetables_spec.rb
  - spec/requests/site_layout_spec.rb
  - spec/models/route_page/dispatch_plan_spec.rb
  - spec/system/timetable_edit_spec.rb
  - app/frontend/timetable/day_storage.test.js
  - app/frontend/timetable/fields.test.js
  - app/frontend/timetable/layout.test.js
-->

---
### Requirement: Day dispatch view follows the clock

While a day is shown, the day dispatch view SHALL follow now, as "Departures at an end" defines it, without any action of the dispatcher: at every whole minute of the browser's clock, and at once when the page is shown again after being hidden, the mark and the line of now on the timeline as `day-dispatch-timeline` defines them, the departures' statuses and their line of now, and the vehicles at the selected end with the minutes they have stood SHALL be drawn for the new now. The clock SHALL NOT draw the timeline's lanes and trips anew, so a trip being dragged, selected or focused stays as it is. While the focus is in the departures, the departures SHALL stay as drawn and SHALL be drawn for now once the focus has left them; while a message about a refused change shows under one of them, they SHALL stay as drawn. The view SHALL follow the clock only while a day is shown, and leaving the page SHALL stop the clock.

#### Scenario: A minute passes

- **WHEN** a day is shown at 17:59 with the 18:00 departure from 甲站 on vehicle 1, which stands at 甲站, and the clock reaches 18:01 while the dispatcher does nothing
- **THEN** the mark of now shows 18:01, the 18:00 departure is departed with the line of now after it, and vehicle 1 is no longer listed as standing at 甲站

#### Scenario: Page shown again

- **WHEN** the page was hidden while a day showed at 17:30 and is shown again at 17:42:20
- **THEN** the mark of now shows 17:42 at once, without waiting for 17:43

#### Scenario: Focus in the departures

- **WHEN** the focus is on the vehicle menu of the 18:20 departure from 甲站 at 17:59 and the clock reaches 18:01
- **THEN** the mark of now shows 18:01, the departures stay as drawn at 17:59 with the focus still on that menu, and once the focus has left the departures the 18:00 departure is departed

<!-- @trace
source: site-bar-github-about
updated: 2026-10-27
code:
  - app/frontend/timetable/day_page.js
  - app/frontend/timetable/day_view.js
  - app/frontend/timetable/day_timeline_view.js
  - app/components/site_bar_component.rb
  - app/components/day_timeline_component.rb
  - app/components/site_bar_component.yml
  - app/components/day_timeline_component.html.erb
  - app/frontend/timetable/minute_clock.js
  - app/components/site_bar_component.html.erb
tests:
  - spec/system/timetable_day_spec.rb
  - spec/system/route_page_mobile_spec.rb
  - spec/system/timetable_day_timeline_spec.rb
  - spec/requests/site_layout_spec.rb
  - app/frontend/timetable/minute_clock.test.js
-->