// The day dispatch kept in this browser, as in the requirement "Day dispatch
// kept in this browser": the whole day as JSON under a key of the route and
// the Taipei date, with the format version in the key and in the day; the
// server receives nothing. The storage is the caller's: window.localStorage,
// or null when the browser denies access to it. A private window, blocked
// storage or a full quota makes it throw, and each function says so in what
// it returns.

import { VERSION, currentDay } from "./day.js"

export function dayKey(routeId, date) {
  return `turnaround.day-dispatch.v${VERSION}.${routeId}.${date}`
}

// Whether the day is now kept in the storage.
export function saveDay(storage, day) {
  try {
    storage.setItem(dayKey(day.routeId, day.date), JSON.stringify(day))
    return true
  } catch {
    return false
  }
}

// The day kept for the route and date: { day } when it reads, { unreadable:
// true } when what is kept is not JSON, not a day of this format version, or
// a day whose changes no longer apply (altered outside the page), and null
// when nothing is kept or the storage cannot be read.
export function loadDay(storage, routeId, date) {
  let text
  try {
    text = storage.getItem(dayKey(routeId, date))
  } catch {
    return null
  }
  if (text === null) return null
  try {
    const day = JSON.parse(text)
    if (day?.version !== VERSION) return { unreadable: true }
    currentDay(day)
    return { day }
  } catch {
    return { unreadable: true }
  }
}

// Whether the day kept for the route and date is gone from the storage.
export function discardDay(storage, routeId, date) {
  try {
    storage.removeItem(dayKey(routeId, date))
    return true
  } catch {
    return false
  }
}
