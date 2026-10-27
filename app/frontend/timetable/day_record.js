// The day record of the day-dispatch-record spec as text, made in the browser
// from the day kept by day.js. Its two files, as in the requirements
// "Exporting the change log" and "Exporting the day's sheets": the change log
// and the day's current sheets as CSV text. Both files start with a byte
// order mark, so Excel reads their Chinese, end every row with CRLF, start
// with a header row and quote fields as RFC 4180 requires. Times are of the
// service day, so 24:07 stays 24:07; the files' labels are the caller's
// words: the two headers, the kinds of change, yes and no, how a trip is
// named, and the names of the directions and of the ends trips leave from.
// And the words printed on the record's sheets, in the day dispatch view's
// labels: the line under each sheet's title, the marks after its times and
// the notes under it, as in the requirement "Marks on the printed sheets".

import { minutesOfDay, taipeiDate } from "./day.js"
import { clock, fieldClock, fill, formatDay } from "./format.js"

const BYTE_ORDER_MARK = "﻿"
const LINE_END = "\r\n"
// A field holding one of these is quoted, its double quotes doubled.
const NEEDS_QUOTES = /[",\r\n]/

// The files of a day record, by the word ending their names.
const FILES = ["changes", "sheets"]

// day-dispatch-<route Id>-<YYYY-MM-DD>-<kind>.csv; a kind of file the record
// does not export is refused, rather than named.
export function csvFileName(day, kind) {
  if (!FILES.includes(kind)) throw new Error(`kind must be one of ${FILES.join(", ")}, not ${JSON.stringify(kind)}`)
  return `day-dispatch-${day.routeId}-${day.date}-${kind}.csv`
}

// One row per change in the order recorded, undone ones included: when it
// was recorded in Taipei time, its kind, the vehicle it is about, the trip
// as its direction and departure when the change was made, the vehicle a
// departure was given to, the recorded arrival or the typed departure, the
// reason and whether it is undone.
export function changeLogCsv(day, labels) {
  return csv(labels.changesHeader, day.changes.map((change, index) => [
    recordedAt(change.at),
    labels.kinds[change.kind],
    change.kind === "vehicle" ? change.from : change.vehicle,
    fill(labels.trip, { direction: labels.directions[plannedTrip(day, change.tripId).goBack], departure: fieldClock(departureWhenMade(day, change, index)) }),
    change.kind === "vehicle" ? change.vehicle : "",
    timeOf(change),
    change.reason,
    change.undone ? labels.yes : labels.no,
  ]))
}

// One row per trip of the day as it stands, in vehicle number order and
// sheet order: the vehicle, the direction, the end it leaves from, the
// departure, the arrival, whether the arrival is recorded, the planned
// vehicle, whether the departure was typed, and the departure of the day
// plan.
export function sheetsCsv(day, current, labels) {
  const vehicles = [...current.vehicles].sort((a, b) => a.number - b.number)
  return csv(labels.sheetsHeader, vehicles.flatMap((vehicle) => vehicle.trips.map((trip) => [
    vehicle.number,
    labels.directions[trip.goBack],
    labels.stops[trip.goBack],
    fieldClock(trip.departure),
    fieldClock(trip.arrival),
    trip.recorded ? labels.yes : labels.no,
    trip.plannedVehicle,
    trip.typed ? labels.yes : labels.no,
    fieldClock(plannedTrip(day, trip.id).departure),
  ])))
}

// The line under a printed sheet's title: the day's date and what the day was
// planned from, the covered day or days with their day type, the percentile
// and the rest minutes.
export function sheetHeader(day, labels) {
  const { days, dayType, percentile, buffer } = day.basis
  const type = labels.dayTypes[dayType]
  const covered = days.length === 1
    ? fill(labels.sheetDaysOne, { day: formatDay(labels, days[0]), dayType: type })
    : fill(labels.sheetDaysRange, { first: formatDay(labels, days[0]), last: formatDay(labels, days.at(-1)), dayType: type, count: days.length })
  return fill(labels.sheetHeader, { date: formatDay(labels, day.date), days: covered, percentile, buffer })
}

// The marks printed right after the times of a vehicle's sheet, as the sheet
// view takes them: ＊ after the departure of a trip planned on another
// vehicle, then ‡ when that departure was typed; † after a recorded arrival.
export function marksFor(vehicle, labels) {
  return {
    departureMark: (trip) => (trip.plannedVehicle === vehicle.number ? "" : labels.marks.swapped) + (trip.typed ? labels.marks.typed : ""),
    arrivalMark: (trip) => (trip.recorded ? labels.marks.recorded : ""),
  }
}

// The notes under a vehicle's printed sheet, one a line, explaining every
// mark on it: one note for the trips planned on each other vehicle, listing
// their departures, in the order of their first one; then each recorded
// arrival with the arrival planned for it, or the words for no value when
// none is known; then each typed departure with its departure in the day
// plan. A sheet without marks has none.
export function sheetNotes(day, vehicle, labels) {
  const time = (minutes) => clock(minutes, labels.nextDay)
  const byPlanned = new Map()
  for (const trip of vehicle.trips) {
    if (trip.plannedVehicle !== vehicle.number) byPlanned.set(trip.plannedVehicle, [...(byPlanned.get(trip.plannedVehicle) ?? []), time(trip.departure)])
  }
  return [
    ...[...byPlanned].map(([planned, departures]) => fill(labels.notes.swapped, { mark: labels.marks.swapped, departures: departures.join(labels.notes.separator), vehicle: fill(labels.vehicle, { number: planned }) })),
    ...vehicle.trips.filter((trip) => trip.recorded).map((trip) => fill(labels.notes.recorded, {
      mark: labels.marks.recorded, arrival: time(trip.arrival), planned: trip.plannedArrival === null ? labels.none : time(trip.plannedArrival),
    })),
    ...vehicle.trips.filter((trip) => trip.typed).map((trip) => fill(labels.notes.typed, { mark: labels.marks.typed, departure: time(trip.departure), from: time(plannedTrip(day, trip.id).departure) })),
  ]
}

// An instant as YYYY-MM-DD HH:MM in Taipei time.
function recordedAt(instant) {
  const moment = new Date(instant)
  const date = taipeiDate(moment)
  return `${date} ${fieldClock(minutesOfDay(date, moment))}`
}

function plannedTrip(day, tripId) {
  return day.plan.flatMap((vehicle) => vehicle.trips).find((trip) => trip.id === tripId)
}

// The departure of a change's trip when the change was made: the one a
// vehicle change or a typed departure kept; for a recorded arrival, the
// departure typed for that trip by the latest change before it that is in
// effect, or else the planned one. Before a change still in effect, a change
// undone now was undone before it was made, since undo takes the latest
// change in effect; an undone change is read the same way.
function departureWhenMade(day, change, index) {
  if (change.kind === "vehicle") return change.departure
  if (change.kind === "departure") return change.from
  const typed = day.changes.slice(0, index).findLast((earlier) => !earlier.undone && earlier.kind === "departure" && earlier.tripId === change.tripId)
  return typed ? typed.departure : plannedTrip(day, change.tripId).departure
}

// The recorded arrival or the typed departure; nothing for a vehicle change.
function timeOf(change) {
  if (change.kind === "arrival") return fieldClock(change.time)
  if (change.kind === "departure") return fieldClock(change.departure)
  return ""
}

function csv(header, rows) {
  return BYTE_ORDER_MARK + [header, ...rows].map((fields) => fields.map(csvField).join(",") + LINE_END).join("")
}

function csvField(value) {
  const text = String(value)
  return NEEDS_QUOTES.test(text) ? `"${text.replaceAll('"', '""')}"` : text
}
