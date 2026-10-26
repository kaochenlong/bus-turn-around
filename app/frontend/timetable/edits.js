// The dispatcher's manual edits, as in the requirement "Manual edits
// recomputed in the browser": each returns a new list of vehicles and leaves
// the given one alone, and works the edited sheet out again with `settle`.
// `plan(goBack, departure, edited)` is the layout's plan bound to the page's
// run times and percentile; `holds` are the minutes a vehicle waits after
// arriving from a trip of each direction.

import { OTHER_END } from "./layout.js"

// One trip's departure typed anew: it leaves at the typed time and is marked
// edited. The trips after it that were not typed move later when they no
// longer connect, or back towards their original departures when they do.
export function changeDeparture(vehicles, { vehicle, index, departure }, plan, holds) {
  return vehicles.map((candidate) => {
    if (candidate.number !== vehicle) return candidate
    const trips = candidate.trips.map((trip, i) => (i === index ? typedTrip(trip.goBack, departure, plan) : trip))
    return { ...candidate, trips: settle(trips, plan, holds) }
  })
}

// The row's trips (two, or one on a single-trip row) taken out of the sheet,
// so the trips after them may go back towards their original departures; a
// vehicle with no trip left disappears.
export function deleteRow(vehicles, { vehicle, row }, plan, holds) {
  const start = (row - 1) * 2
  return vehicles
    .map((candidate) => {
      if (candidate.number !== vehicle) return candidate
      return { ...candidate, trips: settle(candidate.trips.filter((_, i) => i < start || i >= start + 2), plan, holds) }
    })
    .filter((candidate) => candidate.trips.length > 0)
}

// A row added to a sheet: a round trip in the sheet's first direction from
// the typed departure.
export function addRow(vehicles, { vehicle, departure }, plan, holds) {
  return vehicles.map((candidate) => {
    if (candidate.number !== vehicle) return candidate
    return { ...candidate, trips: settle([...candidate.trips, ...roundTrip(candidate.trips[0].goBack, departure, plan, holds)], plan, holds) }
  })
}

// A vehicle added beside the laid-out ones: a new sheet numbered one above
// the highest number on the page, with one round trip in the chosen
// direction from the typed departure.
export function addVehicle(vehicles, { goBack, departure }, plan, holds) {
  const number = Math.max(0, ...vehicles.map((vehicle) => vehicle.number)) + 1
  return [...vehicles, { number, trips: settle(roundTrip(goBack, departure, plan, holds), plan, holds) }]
}

// A trip typed by the dispatcher and the way back from its arrival plus the
// hold at that end, both edited. The way back was worked out, not typed, so
// its original departure is that time and later edits may push it.
function roundTrip(goBack, departure, plan, holds) {
  const first = typedTrip(goBack, departure, plan)
  const back = first.arrival + holds[goBack]
  return [first, { ...plan(OTHER_END[goBack], back, true), typed: false, original: back }]
}

// A trip leaving at a time the dispatcher typed: edited, typed, and with that
// time as its original departure.
function typedTrip(goBack, departure, plan) {
  return { ...plan(goBack, departure, true), typed: true, original: departure }
}

// A sheet's trips worked out again in order: a typed trip leaves at its
// typed time, which is its original departure; any other trip at its
// original departure, or later when the previous trip arrives too late to
// keep the hold at that end, so never earlier than its original departure.
// Arrivals are planned again from the departures, and every trip keeps its
// marks. The given trips are left alone.
export function settle(trips, plan, holds) {
  const settled = []
  for (const trip of trips) {
    const previous = settled.at(-1)
    const departure = trip.typed || !previous ? trip.original : Math.max(trip.original, previous.arrival + holds[previous.goBack])
    settled.push({ ...plan(trip.goBack, departure, trip.edited), typed: trip.typed, original: trip.original })
  }
  return settled
}

// The minutes a trip leaves after its original departure: how far the edits
// before it pushed it, 0 for a trip that has not moved.
export function pushedMinutes(trip) {
  return trip.departure - trip.original
}

// The departure cells a dispatcher edited, over every sheet.
export function countEdited(vehicles) {
  return vehicles.reduce((count, vehicle) => count + vehicle.trips.filter((trip) => trip.edited).length, 0)
}

// The departure cells pushed later than their original departure, over every
// sheet.
export function countPushed(vehicles) {
  return vehicles.reduce((count, vehicle) => count + vehicle.trips.filter((trip) => pushedMinutes(trip) > 0).length, 0)
}
