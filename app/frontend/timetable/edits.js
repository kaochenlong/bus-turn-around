// The dispatcher's manual edits, as in the requirement "Manual edits
// recomputed in the browser": each returns a new list of vehicles and leaves
// the given one alone. `plan(goBack, departure, edited)` is the layout's plan
// bound to the page's run times and percentile.

import { OTHER_END } from "./layout.js"

// One trip's departure typed anew: it is planned again from the typed
// departure and marked edited; every other trip stays as it is.
export function changeDeparture(vehicles, { vehicle, index, departure }, plan) {
  return vehicles.map((candidate) => {
    if (candidate.number !== vehicle) return candidate
    return { ...candidate, trips: candidate.trips.map((trip, i) => (i === index ? plan(trip.goBack, departure, true) : trip)) }
  })
}

// The row's trips (two, or one on a single-trip row) taken out of the sheet;
// a vehicle with no trip left disappears.
export function deleteRow(vehicles, { vehicle, row }) {
  const start = (row - 1) * 2
  return vehicles
    .map((candidate) => (candidate.number !== vehicle ? candidate : { ...candidate, trips: candidate.trips.filter((_, i) => i < start || i >= start + 2) }))
    .filter((candidate) => candidate.trips.length > 0)
}

// A row added to a sheet: a round trip in the sheet's first direction from
// the typed departure.
export function addRow(vehicles, { vehicle, departure }, plan, holds) {
  return vehicles.map((candidate) => {
    if (candidate.number !== vehicle) return candidate
    return { ...candidate, trips: [...candidate.trips, ...roundTrip(candidate.trips[0].goBack, departure, plan, holds)] }
  })
}

// A vehicle added beside the laid-out ones: a new sheet numbered one above
// the highest number on the page, with one round trip in the chosen
// direction from the typed departure.
export function addVehicle(vehicles, { goBack, departure }, plan, holds) {
  const number = Math.max(0, ...vehicles.map((vehicle) => vehicle.number)) + 1
  return [...vehicles, { number, trips: roundTrip(goBack, departure, plan, holds) }]
}

// A trip typed by the dispatcher and the way back from its arrival plus the
// hold at that end, both edited.
function roundTrip(goBack, departure, plan, holds) {
  const first = plan(goBack, departure, true)
  return [first, plan(OTHER_END[goBack], first.arrival + holds[goBack], true)]
}

// The departure cells a dispatcher edited, over every sheet.
export function countEdited(vehicles) {
  return vehicles.reduce((count, vehicle) => count + vehicle.trips.filter((trip) => trip.edited).length, 0)
}
