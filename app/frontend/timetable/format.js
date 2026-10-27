// Times of the timetable as text. Times are minutes of the day and may pass
// 1440 after midnight; typed times are of the service day, so a return trip
// after midnight reads 24:45.

const MINUTES_PER_DAY = 24 * 60
// One or two digits of hours, then two of minutes, with or without a colon
// between them: 5:30, 05:30, 530 and 0530 are all 05:30.
const TIME = /^(\d{1,2}):?(\d{2})$/
// The last hour a typed time of the service day may name: the layout runs
// past 24:00 when the last departures are late.
const LAST_HOUR = 29
// U+2212, so a stop that does not connect prints as −5.
const MINUS = "−"

const twoDigits = (number) => String(number).padStart(2, "0")

// "HH:MM" within the day; from 24:00 on, nextDayLabel with %{time} filled in.
export function clock(minutes, nextDayLabel = "%{time}") {
  const time = `${twoDigits(Math.floor((minutes % MINUTES_PER_DAY) / 60))}:${twoDigits(minutes % 60)}`
  return minutes >= MINUTES_PER_DAY ? nextDayLabel.replace("%{time}", time) : time
}

// "HH:MM" of the service day for an editable field: 1485 is 24:45.
export function fieldClock(minutes) {
  return `${twoDigits(Math.floor(minutes / 60))}:${twoDigits(minutes % 60)}`
}

// Minutes of the service day from a typed time, or null when the text is not
// one: written as TIME, spaces around it ignored, hours up to LAST_HOUR,
// minutes up to 59.
export function parseClock(text) {
  const match = TIME.exec((text ?? "").trim())
  if (!match) return null
  const [hour, minute] = [Number(match[1]), Number(match[2])]
  if (hour > LAST_HOUR || minute > 59) return null
  return hour * 60 + minute
}

// A label with its %{name} placeholders filled. The values go in as text, so
// a typed reason is never read as a pattern; a placeholder without a value
// stays as it is.
export function fill(text, values) {
  return text.replace(/%\{(\w+)\}/g, (placeholder, name) => (Object.hasOwn(values, name) ? String(values[name]) : placeholder))
}

// A stop's minutes as shown: nothing without a value, and a typographic minus
// when the trips do not connect.
export function stopText(minutes) {
  if (minutes === null || minutes === undefined) return ""
  return minutes < 0 ? `${MINUS}${Math.abs(minutes)}` : String(minutes)
}

// A YYYY-MM-DD date with its weekday, as the site writes days: labels holds
// the site's dayLabel and its weekdays from Sunday.
export function formatDay(labels, date) {
  return fill(labels.dayLabel, { date, weekday: labels.weekdays[new Date(Date.parse(date)).getUTCDay()] })
}

// The rest in the tightest four hours in words: the minutes filled into
// minutesLabel, or shorterLabel for a sheet shorter than four hours, which
// has none.
export function minutesText(minutes, shorterLabel, minutesLabel) {
  return minutes === null ? shorterLabel : fill(minutesLabel, { minutes })
}
