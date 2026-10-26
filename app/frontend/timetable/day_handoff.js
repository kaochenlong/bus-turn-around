// The day started in this browser tab that this browser could not keep (a
// private window, blocked or full local storage). Turbo keeps the page's
// scripts across visits, so the day passes from the timetable page to the
// day dispatch page, and stays for the life of the tab: going back to
// planning and to the day dispatch again still finds it. Loading a page
// again forgets it, as the day dispatch says. It is newer than any day this
// tab kept for the route: there is one only while this tab's latest save
// failed.
let unkept = null

// The day handed over, in place of any day handed over before.
export function handOver(day) {
  unkept = day
}

// The day handed over for the route, or null; it stays handed over.
export function takeOver(routeId) {
  return unkept?.routeId === routeId ? unkept : null
}

// The route's day let go: it was started again, or kept after all.
export function release(routeId) {
  if (unkept?.routeId === routeId) unkept = null
}
