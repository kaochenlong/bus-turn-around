// Lays out one day's timetable from the departures per direction and Taipei
// hour, as in the timetable spec, with the data the server embeds in the
// page. The n departures of an hour are spread at floor(k × 60 / n) minutes;
// both directions' departures are taken in time order, direction 0 first at
// equal times; each goes to the vehicle standing at that end that has waited
// longest, the lower number at equal times, and a new vehicle is created when
// none is available. A trip arrives after its planned run time and the
// vehicle is available again after the hold at that end. Times are minutes of
// the day and may pass 1440 after midnight.

const MINUTES_PER_HOUR = 60
const HOURS_PER_DAY = 24

// The end a vehicle stands at after a trip of each direction: the first stop
// of the other direction.
export const OTHER_END = { 0: 1, 1: 0 }

// The minutes within the hour of n departures.
export function minutesInHour(count) {
  return Array.from({ length: count }, (_, k) => Math.floor((k * MINUTES_PER_HOUR) / count))
}

// The planned run time of a direction's trip departing at the minute, as
// [whole minutes, whether the hour fell back to the whole day], or null when
// the data has none. The hour is taken within the day, so a departure after
// 24:00 looks up the small hours.
export function plannedMinutes(runTimes, percentile, goBack, departure) {
  const hour = Math.floor(departure / MINUTES_PER_HOUR) % HOURS_PER_DAY
  const entry = runTimes[goBack]?.[hour]
  return entry ? (entry[String(percentile)] ?? null) : null
}

// One trip planned from its departure. The manual edits plan their trips with
// this too.
export function plan(runTimes, percentile, goBack, departure, edited = false) {
  const planned = plannedMinutes(runTimes, percentile, goBack, departure)
  if (!planned) throw new Error(`direction ${goBack} has no run time`)
  const [minutes, fallback] = planned
  return { goBack, departure, arrival: departure + minutes, fallback, edited }
}

// The vehicles in order of creation, each with its trips in time order. A
// laid-out trip was not typed by the dispatcher, and its laid-out departure
// is its original one, the earliest the manual edits let it leave.
// departures: { 0: [24 counts], 1: [24 counts] }; holds: minutes a vehicle
// waits after arriving from a trip of each direction.
export function layOut({ departures, runTimes, percentile, holds }) {
  const standing = []
  for (const [departure, goBack] of departuresInOrder(departures)) {
    const vehicle = waitingLongest(standing, goBack, departure) ?? newVehicle(standing, goBack, departure)
    const trip = { ...plan(runTimes, percentile, goBack, departure), typed: false, original: departure }
    vehicle.trips.push(trip)
    vehicle.position = OTHER_END[goBack]
    vehicle.available = trip.arrival + holds[goBack]
  }
  return standing.map(({ number, trips }) => ({ number, trips }))
}

// Every departure as [minute of the day, direction], sorted so equal minutes
// take direction 0 first.
function departuresInOrder(departures) {
  const all = []
  for (const goBack of [0, 1]) {
    ;(departures[goBack] ?? []).forEach((count, hour) => {
      for (const minute of minutesInHour(count)) all.push([hour * MINUTES_PER_HOUR + minute, goBack])
    })
  }
  return all.sort((a, b) => a[0] - b[0] || a[1] - b[1])
}

// The vehicle standing at the departure's end that has waited longest, the
// lower number at equal times; null when none is available in time.
function waitingLongest(standing, goBack, departure) {
  const candidates = standing.filter((vehicle) => vehicle.position === goBack && vehicle.available <= departure)
  candidates.sort((a, b) => a.available - b.available || a.number - b.number)
  return candidates[0] ?? null
}

function newVehicle(standing, goBack, departure) {
  const vehicle = { number: standing.length + 1, position: goBack, available: departure, trips: [] }
  standing.push(vehicle)
  return vehicle
}
