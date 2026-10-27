// A clock calling back at every whole minute of a given clock, which the day
// dispatch view follows now by, as in the requirement "Day dispatch view
// follows the clock". Every wait is worked out again from now(), so the calls
// stay on the minute however late a timer fires, and a clock that the system
// specs put in place of the browser's is followed too.

const MINUTE_MS = 60 * 1000

// Calls onMinute at the next whole minute of now() and at every one after;
// returns the function that stops it.
export function startMinuteClock({ now, onMinute }) {
  let timer = null
  const schedule = () => {
    timer = setTimeout(tick, MINUTE_MS - (now().getTime() % MINUTE_MS))
  }
  const tick = () => {
    onMinute()
    schedule()
  }
  schedule()
  return () => clearTimeout(timer)
}
