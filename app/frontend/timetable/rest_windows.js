// The rest in the tightest four hours of one vehicle's sheet, computed on the
// planned times by the window rule of the layover-metrics spec: for each trip
// i, the earliest trip j whose arrival is at least 240 minutes after trip i's
// departure closes a window, whose credit is the sum of the stops after trips
// i through j−1 that last at least 15 minutes. The smallest credit is
// reported as a number only: the sheet is a vehicle, and one person may not
// drive all of it.

export const WINDOW_MINUTES = 240
export const SHORT_STOP_MINUTES = 15

// trips: objects with departure and arrival as minutes of the day, in sheet
// order. Null when no trip opens a window: the sheet is shorter than four
// hours. A negative stop, where the trips do not connect, counts nothing.
export function minimumCredit(trips) {
  const credits = []
  trips.forEach((first, i) => {
    const last = trips.findIndex((trip, j) => j >= i && trip.arrival - first.departure >= WINDOW_MINUTES)
    if (last === -1) return
    let credit = 0
    for (let k = i; k < last; k += 1) {
      const stop = trips[k + 1].departure - trips[k].arrival
      if (stop >= SHORT_STOP_MINUTES) credit += stop
    }
    credits.push(credit)
  })
  return credits.length > 0 ? Math.min(...credits) : null
}
