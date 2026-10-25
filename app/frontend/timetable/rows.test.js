import { describe, expect, it } from "vitest"

import { rows } from "./rows.js"
import { trip } from "./support.js"

describe("rows：連續兩趟一列，單趟一列", () => {
  it("規格的 1 號車：去程 06:00–06:50、返程 07:30–08:15 是一列，停留 40，最後一列沒有回站後停留", () => {
    const [first, second] = [trip(0, "06:00-06:50"), trip(1, "07:30-08:15")]
    expect(rows([first, second])).toEqual([{ number: 1, first, second, stop: 40, nextStop: null }])
  })

  it("兩列：第一列的回站後停留是下一列發車減這一列返站，08:15 到 08:30 是 15；第二列單趟", () => {
    const trips = [trip(0, "06:00-06:50"), trip(1, "07:30-08:15"), trip(0, "08:30-09:20")]
    expect(rows(trips).map((row) => [row.number, row.stop, row.nextStop, row.second === null])).toEqual([[1, 40, 15, false], [2, null, null, true]])
  })

  it("規格的 3 號車只有一趟：一列，沒有第二趟與停留", () => {
    const only = trip(1, "07:00-07:45")
    expect(rows([only])).toEqual([{ number: 1, first: only, second: null, stop: null, nextStop: null }])
  })

  it("接不上時停留是負的：返回那趟 06:45 發、去程 06:50 到，停留 −5", () => {
    expect(rows([trip(0, "06:00-06:50"), trip(1, "06:45-07:30")])[0].stop).toBe(-5)
  })
})
