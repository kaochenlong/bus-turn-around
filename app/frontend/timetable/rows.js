// The rows of a sheet: consecutive trips in pairs, the last one alone when
// the count is odd. A row carries the stop between its two trips and the
// stop from its second trip's arrival to the next row's departure, null on
// the last row or on a single-trip row.

export function rows(trips) {
  const result = []
  for (let i = 0; i < trips.length; i += 2) {
    const first = trips[i]
    const second = trips[i + 1] ?? null
    const following = trips[i + 2] ?? null
    result.push({
      number: i / 2 + 1,
      first,
      second,
      stop: second ? second.departure - first.arrival : null,
      nextStop: second && following ? following.departure - second.arrival : null,
    })
  }
  return result
}
