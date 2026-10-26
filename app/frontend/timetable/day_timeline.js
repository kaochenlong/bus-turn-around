// The time axis of the day dispatch timeline, as in the day-dispatch-timeline
// spec: one range shared by every lane, a time's place on it as a
// percentage, the whole minute at a point of it and the lane under a drop.
// Times are minutes of the kept day and may pass 1440 after midnight.

const MINUTES_PER_HOUR = 60

// The whole hour at or before the earliest departure to the whole hour after
// the latest arrival, a recorded one included, as { start, end }. vehicles:
// the day's vehicles as they stand; a vehicle whose trips were all given away
// has none and adds nothing.
export function timelineRange(vehicles) {
  const trips = vehicles.flatMap((vehicle) => vehicle.trips)
  if (trips.length === 0) throw new Error("a timeline needs at least one trip")
  const earliest = Math.min(...trips.map((trip) => trip.departure))
  const latest = Math.max(...trips.map((trip) => trip.arrival))
  return { start: Math.floor(earliest / MINUTES_PER_HOUR) * MINUTES_PER_HOUR, end: (Math.floor(latest / MINUTES_PER_HOUR) + 1) * MINUTES_PER_HOUR }
}

// A time's place on the range as a percentage, held within 0 and 100.
export function positionOf(minutes, { start, end }) {
  return clamp(((minutes - start) / (end - start)) * 100, 0, 100)
}

// The whole minute nearest to a fraction of the range, held within the
// range.
export function minuteAt(fraction, { start, end }) {
  return clamp(Math.round(start + fraction * (end - start)), start, end)
}

// Whether a stretch of the given minutes, drawn on a time axis axisPx wide,
// holds a label needing that many pixels.
export function fitsLabel(minutes, { start, end }, axisPx, needed) {
  return (minutes / (end - start)) * axisPx >= needed
}

// The lane under a vertical position, from lanes given as { top, bottom }
// boxes: a lane holds its top edge and not its bottom one, so a position on
// the line between two lanes falls on the lower one. Null outside every lane.
export function laneAt(lanes, y) {
  return lanes.find((lane) => lane.top <= y && y < lane.bottom) ?? null
}

function clamp(value, low, high) {
  return Math.min(Math.max(value, low), high)
}
