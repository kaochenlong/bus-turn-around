// The day dispatch of the timetable page, as in the day-dispatch spec: the
// sheets as they stood when the dispatcher started the day, and the changes
// recorded since, in order. Every view of the day is worked out again from
// the two, so nothing moves by itself. Times are minutes of the kept day and
// may pass 1440 after midnight. An end is named by the direction that departs
// from it, 0 or 1.

import { OTHER_END, plan } from "./layout.js"
import { minimumCredit } from "./rest_windows.js"

// The format of a kept day; a day of another version is not read.
export const VERSION = 1

// How many vehicles due at an end the view lists.
export const ARRIVING_COUNT = 4

const MINUTES_PER_DAY = 24 * 60
const MS_PER_DAY = MINUTES_PER_DAY * 60 * 1000

// The browser's clock read in Taipei time, whatever the computer's own zone.
const TAIPEI = new Intl.DateTimeFormat("en-CA", {
  timeZone: "Asia/Taipei", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", hourCycle: "h23",
})

// The day started from the planning view's vehicles: each trip's direction
// and times, with an identifier for the day, "<vehicle>-<n>" in sheet order.
// The planning view's marks (typed, edited, pushed, fell back) stay behind,
// so every figure of the day starts from no change. meta carries the route,
// the Taipei date, the moment of starting, the basis of the plan, the
// directions whose trips end at a stopping end and the page's run times,
// which the day keeps at the basis percentile only: whatever the page embeds
// when the day is continued, the day plans with the run times it started
// with.
export function startDay(vehicles, { routeId, date, startedAt, basis, stoppingEnds, runTimes }) {
  return {
    version: VERSION,
    routeId,
    date,
    startedAt,
    basis,
    stoppingEnds,
    runTimes: atPercentile(runTimes, basis.percentile),
    plan: vehicles.map(({ number, trips }) => ({
      vehicle: number,
      trips: trips.map(({ goBack, departure, arrival }, i) => ({ id: `${number}-${i + 1}`, goBack, departure, arrival })),
    })),
    changes: [],
  }
}

// The day as it stands: every vehicle's trips, each with the vehicle it was
// planned on, whether its arrival was recorded and its departure typed, and
// the stop before it; the header's figures; and every vehicle's rest in the
// tightest four hours, now and as planned.
export function currentDay(day) {
  const vehicles = vehiclesNow(day).map((vehicle) => ({ ...vehicle, trips: withStops(vehicle.trips) }))
  return { vehicles, figures: figures(day, vehicles), credits: credits(day, vehicles) }
}

// The day with its latest change still in effect marked as undone, so the
// day is worked out without it; the day itself when no change is in effect.
// An undone change stays in the log and is never undone again or redone.
export function undoLast(day) {
  const latest = day.changes.findLastIndex((change) => !change.undone)
  if (latest === -1) return day
  return { ...day, changes: day.changes.map((change, i) => (i === latest ? { ...change, undone: true } : change)) }
}

// The end listed first: where direction 0 departs when trips of direction 1
// end at a stopping end, otherwise where direction 1 departs.
export function defaultEnd(day) {
  return day.stoppingEnds.includes(1) ? 0 : 1
}

// The departures from the end in departure order, each with its planned and
// current vehicle, the arrival of that vehicle's previous trip (null on its
// first trip), the stop, and a status: waiting when its vehicle is not back
// in time, whatever the time; otherwise departed before now, next for the
// first departure at or after now, planned for the rest. When the first
// departure at or after now waits, none is next.
export function departuresAt(current, end, now) {
  const rows = current.vehicles
    .flatMap((vehicle) => vehicle.trips.map((trip, i) => ({ trip, vehicle: vehicle.number, previous: vehicle.trips[i - 1] ?? null })))
    .filter(({ trip }) => trip.goBack === end)
    .sort((a, b) => a.trip.departure - b.trip.departure || a.vehicle - b.vehicle)
  const next = rows.find(({ trip }) => trip.departure >= now)
  return rows.map((row) => ({
    id: row.trip.id,
    departure: row.trip.departure,
    plannedVehicle: row.trip.plannedVehicle,
    vehicle: row.vehicle,
    arrival: row.previous?.arrival ?? null,
    recorded: row.previous?.recorded ?? false,
    stop: row.trip.stop,
    typed: row.trip.typed,
    status: departureStatus(row, next, now),
  }))
}

// The vehicles standing at the end now: the latest trip each has arrived on
// by now ends there, and its next trip has not left, a departure waiting for
// it included. Each with its arrival, the minutes it has stood and its next
// departure, null when its day ended there; the longest standing first.
export function vehiclesAt(current, end, now) {
  return current.vehicles
    .flatMap((vehicle) => {
      const index = vehicle.trips.findLastIndex((trip) => trip.arrival <= now)
      const last = vehicle.trips[index]
      const next = vehicle.trips[index + 1] ?? null
      if (index === -1 || endOf(last) !== end || (next && departed(next, now))) return []
      return [{ vehicle: vehicle.number, arrival: last.arrival, recorded: last.recorded, stood: now - last.arrival, next: next?.departure ?? null }]
    })
    .sort((a, b) => a.arrival - b.arrival || a.vehicle - b.vehicle)
}

// The vehicles due at the end after now, each by its first trip arriving
// there after now, with that arrival and the departure after it (null when
// that trip ends its day); the earliest ARRIVING_COUNT.
export function arrivingAt(current, end, now) {
  return current.vehicles
    .flatMap((vehicle) => {
      const index = vehicle.trips.findIndex((trip) => endOf(trip) === end && trip.arrival > now)
      if (index === -1) return []
      const trip = vehicle.trips[index]
      return [{ vehicle: vehicle.number, arrival: trip.arrival, recorded: trip.recorded, next: vehicle.trips[index + 1]?.departure ?? null }]
    })
    .sort((a, b) => a.arrival - b.arrival || a.vehicle - b.vehicle)
    .slice(0, ARRIVING_COUNT)
}

// The Taipei date of an instant, as YYYY-MM-DD.
export function taipeiDate(instant) {
  return taipei(instant).date
}

// An instant as minutes of the kept Taipei date: past midnight it counts on
// from 24:00, as the sheets' times do.
export function minutesOfDay(date, instant) {
  const { date: today, minutes } = taipei(instant)
  return ((Date.parse(today) - Date.parse(date)) / MS_PER_DAY) * MINUTES_PER_DAY + minutes
}

// The date before a YYYY-MM-DD date: a day kept yesterday is still offered
// after midnight.
export function previousDate(date) {
  return new Date(Date.parse(date) - MS_PER_DAY).toISOString().slice(0, 10)
}

// A vehicle recorded back at an end at a time, with an optional reason. The
// time becomes the arrival of the vehicle's last trip toward that end that
// departs at or before it; without such a trip the record is refused.
export function recordArrival(day, { vehicle, end, time, reason, at }) {
  if (end !== 0 && end !== 1) throw new Error(`end must be 0 or 1, not ${JSON.stringify(end)}`)
  if (!Number.isInteger(time)) throw new Error(`time must be whole minutes, not ${time}`)
  return withChange(day, { kind: "arrival", vehicle, end, time }, { reason, at })
}

// A departure given to another vehicle, with an optional reason: from that
// departure on, the two vehicles exchange the rest of their day.
export function changeVehicle(day, { tripId, vehicle, reason, at }) {
  return withChange(day, { kind: "vehicle", tripId, vehicle }, { reason, at })
}

// A departure typed anew, with an optional reason: only that trip changes.
// It arrives at its recorded arrival when one is in effect, otherwise after
// the run time the day kept for the typed departure's hour.
export function changeDeparture(day, { tripId, departure, reason, at }) {
  if (!Number.isInteger(departure)) throw new Error(`departure must be whole minutes, not ${departure}`)
  return withChange(day, { kind: "departure", tripId, departure }, { reason, at })
}

// What each kind of change does to the vehicles of the day as they stand:
// the vehicles after it and what the change log keeps about it, or why it is
// refused.
const EFFECTS = { arrival: arrive, vehicle: exchange, departure: retime }

function arrive(vehicles, { vehicle, end, time }) {
  const trip = vehicleNumbered(vehicles, vehicle).trips.findLast((candidate) => endOf(candidate) === end && candidate.departure <= time)
  if (!trip) return { refused: { kind: "no-trip" } }
  return { vehicles: withTrip(vehicles, trip.id, { arrival: time, recorded: true }), noted: { tripId: trip.id } }
}

// Departure D of vehicle A, leaving its end at t, given to vehicle B: A's
// trips from D on and B's from B's first trip departing at or after t change
// places, keeping their times and their planned vehicle.
function exchange(vehicles, { tripId, vehicle }) {
  const from = vehicleRunning(vehicles, tripId)
  if (from.number === vehicle) throw new Error(`trip ${tripId} already runs on vehicle ${vehicle}`)
  const to = vehicleNumbered(vehicles, vehicle)
  const index = from.trips.findIndex((trip) => trip.id === tripId)
  const given = from.trips[index]
  const next = to.trips.findIndex((trip) => trip.departure >= given.departure)
  const refusal = exchangeRefusal(to, next, given.goBack)
  if (refusal) return { refused: refusal }
  const cut = next === -1 ? to.trips.length : next
  return {
    vehicles: vehicles.map((candidate) => {
      if (candidate === from) return { ...from, trips: [...from.trips.slice(0, index), ...to.trips.slice(cut)] }
      if (candidate === to) return { ...to, trips: [...to.trips.slice(0, cut), ...from.trips.slice(index)] }
      return candidate
    }),
    noted: { from: from.number, departure: given.departure },
  }
}

function retime(vehicles, { tripId, departure }, day) {
  const vehicle = vehicleRunning(vehicles, tripId)
  const trip = vehicle.trips.find((candidate) => candidate.id === tripId)
  const arrival = trip.recorded ? trip.arrival : plan(day.runTimes, day.basis.percentile, trip.goBack, departure).arrival
  return { vehicles: withTrip(vehicles, tripId, { departure, arrival, typed: true }), noted: { vehicle: vehicle.number, from: trip.departure } }
}

// Why vehicle B cannot take a departure from the end, its trip at index next
// being its first one departing at or after that departure (-1 for none):
// that trip leaves from another end; or B has no trip left and ended its day
// at another end; or B has no trip at all, so nothing says where it is. Null
// when B can take it.
function exchangeRefusal(to, next, end) {
  if (next !== -1) {
    const leaves = to.trips[next].goBack
    return leaves === end ? null : { kind: "elsewhere", vehicle: to.number, end: leaves }
  }
  const last = to.trips.at(-1)
  if (!last) return { kind: "no-trips", vehicle: to.number }
  return endOf(last) === end ? null : { kind: "day-ended", vehicle: to.number, end: endOf(last) }
}

// The day with the change added to its log when the change applies to the
// day as it stands, or the refusal; the given day is left alone either way.
function withChange(day, change, { reason, at }) {
  const effect = effectOf(change)(vehiclesNow(day), change, day)
  if (effect.refused) return { refused: effect.refused }
  return { ...day, changes: [...day.changes, { ...change, ...effect.noted, reason: reason ?? "", at, undone: false }] }
}

// The snapshot's vehicles with every change still in effect applied in the
// order recorded. Each of them applied when it was recorded, on the same
// changes before it, so one that no longer applies means the kept day was
// altered outside the page.
function vehiclesNow(day) {
  return day.changes.reduce((vehicles, change) => {
    if (change.undone) return vehicles
    const effect = effectOf(change)(vehicles, change, day)
    if (effect.refused) throw new Error(`the ${change.kind} change recorded at ${change.at} no longer applies: ${effect.refused.kind}`)
    return effect.vehicles
  }, plannedVehicles(day))
}

function effectOf(change) {
  if (!Object.hasOwn(EFFECTS, change.kind)) throw new Error(`unknown change kind ${JSON.stringify(change.kind)}`)
  return EFFECTS[change.kind]
}

// The end a trip arrives at.
function endOf(trip) {
  return OTHER_END[trip.goBack]
}

function vehicleNumbered(vehicles, number) {
  const vehicle = vehicles.find((candidate) => candidate.number === number)
  if (!vehicle) throw new Error(`no vehicle ${number} in the day`)
  return vehicle
}

function vehicleRunning(vehicles, tripId) {
  const vehicle = vehicles.find((candidate) => candidate.trips.some((trip) => trip.id === tripId))
  if (!vehicle) throw new Error(`no trip ${tripId} in the day`)
  return vehicle
}

// The vehicles with one trip's fields replaced.
function withTrip(vehicles, id, fields) {
  return vehicles.map((vehicle) => ({ ...vehicle, trips: vehicle.trips.map((trip) => (trip.id === id ? { ...trip, ...fields } : trip)) }))
}

// The page's run times in the same shape, holding the one percentile, so the
// layout's plan reads them; an hour without a run time stays null.
function atPercentile(runTimes, percentile) {
  const key = String(percentile)
  return Object.fromEntries(Object.entries(runTimes).map(([goBack, hours]) => [goBack, hours.map((entry) => (entry?.[key] ? { [key]: entry[key] } : null))]))
}

// The vehicles as the snapshot has them, every trip on its planned vehicle.
function plannedVehicles(day) {
  return day.plan.map(({ vehicle, trips }) => ({
    number: vehicle,
    trips: trips.map((trip) => ({ ...trip, plannedVehicle: vehicle, recorded: false, typed: false })),
  }))
}

// Each trip with the minutes from the previous trip's arrival to its
// departure, null on a vehicle's first trip. A negative stop means the
// departure waits for its vehicle.
function withStops(trips) {
  return trips.map((trip, i) => {
    const stop = i === 0 ? null : trip.departure - trips[i - 1].arrival
    return { ...trip, stop, waiting: stop !== null && stop < 0 }
  })
}

// The header's figures: the vehicle changes in effect, the departures typed,
// the departures waiting for their vehicle, and the shortest stop.
function figures(day, vehicles) {
  const trips = vehicles.flatMap((vehicle) => vehicle.trips)
  return {
    swaps: day.changes.filter((change) => !change.undone && change.kind === "vehicle").length,
    typed: trips.filter((trip) => trip.typed).length,
    waiting: trips.filter((trip) => trip.waiting).length,
    shortestStop: shortestStop(day, vehicles),
  }
}

// The shortest stop that is not negative after a trip ending at a stopping
// end, with its vehicle and the departure after it; at equal minutes the
// earlier departure, then the lower vehicle number. Null without one.
function shortestStop(day, vehicles) {
  const stops = vehicles.flatMap((vehicle) =>
    vehicle.trips.flatMap((trip, i) => {
      if (i === 0 || trip.stop < 0 || !day.stoppingEnds.includes(vehicle.trips[i - 1].goBack)) return []
      return [{ minutes: trip.stop, vehicle: vehicle.number, departure: trip.departure }]
    }),
  )
  stops.sort((a, b) => a.minutes - b.minutes || a.departure - b.departure || a.vehicle - b.vehicle)
  return stops[0] ?? null
}

// Every vehicle's rest in the tightest four hours, of its trips now and of
// its planned trips, in the order of the plan.
function credits(day, vehicles) {
  return day.plan.map(({ vehicle, trips }) => ({ vehicle, now: minimumCredit(vehicleNumbered(vehicles, vehicle).trips), planned: minimumCredit(trips) }))
}

function departureStatus(row, next, now) {
  if (row.trip.waiting) return "waiting"
  if (row.trip.departure < now) return "departed"
  return row === next ? "next" : "planned"
}

// Whether a trip has left by now: a departure waiting for its vehicle has
// not, whatever the time.
function departed(trip, now) {
  return !trip.waiting && trip.departure < now
}

// The Taipei date and the minutes since its midnight of an instant.
function taipei(instant) {
  const parts = Object.fromEntries(TAIPEI.formatToParts(instant).map(({ type, value }) => [type, value]))
  return { date: `${parts.year}-${parts.month}-${parts.day}`, minutes: Number(parts.hour) * 60 + Number(parts.minute) }
}
