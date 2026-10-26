// Builders shared by the timetable tests: the data shapes the server embeds in
// the page, filled from a few numbers.

export const PERCENTILES = [50, 55, 60, 65, 70, 75, 80, 85, 90, 95]

// "HH:MM" as minutes of the day; 24:30 is the next day's 00:30.
export function at(text) {
  const [hour, minute] = text.split(":").map(Number)
  return hour * 60 + minute
}

// The run times table the server embeds: for both directions and every hour,
// the same whole minutes at every percentile, unless byHour gives
// "goBack:hour" its own; a direction left out of byDirection has no run time
// in the hours byHour does not name. fallback marks every entry.
export function runTimesTable(byDirection, byHour = {}, fallback = false) {
  const build = (goBack) => Array.from({ length: 24 }, (_, hour) => {
    const minutes = byHour[`${goBack}:${hour}`] ?? byDirection[goBack]
    if (minutes === undefined) return null
    return Object.fromEntries(PERCENTILES.map((percentile) => [String(percentile), [minutes, fallback]]))
  })
  return { 0: build(0), 1: build(1) }
}

// Departures per hour for both directions from "goBack:hour" => count.
export function departuresTable(cells) {
  const table = { 0: new Array(24).fill(0), 1: new Array(24).fill(0) }
  for (const [key, count] of Object.entries(cells)) {
    const [goBack, hour] = key.split(":").map(Number)
    table[goBack][hour] = count
  }
  return table
}

// A planned trip from a direction and a "HH:MM-HH:MM" leg; as laid out, not
// typed and with its departure as its original one, unless told otherwise.
export function trip(goBack, leg, { fallback = false, edited = false, typed = false, original } = {}) {
  const [departure, arrival] = leg.split("-").map(at)
  return { goBack, departure, arrival, fallback, edited, typed, original: original ?? departure }
}
