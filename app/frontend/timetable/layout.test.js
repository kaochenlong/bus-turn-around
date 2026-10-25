import { describe, expect, it } from "vitest"

import { layOut, minutesInHour, plan } from "./layout.js"
import { at, departuresTable, runTimesTable } from "./support.js"

const bothStop = { 0: 15, 1: 15 }

function layout(cells, runTimes, holds = bothStop) {
  return layOut({ departures: departuresTable(cells), runTimes, percentile: 85, holds })
}

// Each vehicle's trips as [direction, departure, arrival].
function runs(vehicles) {
  return vehicles.map((vehicle) => vehicle.trips.map((trip) => [trip.goBack, trip.departure, trip.arrival]))
}

describe("minutesInHour：一小時 n 班的發車分鐘", () => {
  // The spec's example "Spacing for other counts" and the seven of the scenario.
  it.each([
    [1, [0]],
    [2, [0, 30]],
    [5, [0, 12, 24, 36, 48]],
    [7, [0, 8, 17, 25, 34, 42, 51]],
    [0, []],
  ])("%j 班 → %j", (count, minutes) => {
    expect(minutesInHour(count)).toEqual(minutes)
  })
})

describe("layOut：發車交給在那一端等最久的車，沒有車就多開一台", () => {
  it("07 時七班、沒有車回得來：七台車依序 07:00、07:08、07:17、07:25、07:34、07:42、07:51 發車", () => {
    const vehicles = layout({ "0:7": 7 }, runTimesTable({ 0: 50, 1: 45 }))
    expect(vehicles.map((vehicle) => vehicle.trips[0].departure)).toEqual(["07:00", "07:08", "07:17", "07:25", "07:34", "07:42", "07:51"].map(at))
  })

  it("規格的四班例子：三台車，1 號車 06:00 到 06:50 再 07:30 到 08:15，2 號車 06:30 到 07:20，3 號車 07:00 到 07:45", () => {
    const vehicles = layout({ "0:6": 2, "1:7": 2 }, runTimesTable({ 0: 50, 1: 45 }))
    expect(runs(vehicles)).toEqual([
      [[0, at("06:00"), at("06:50")], [1, at("07:30"), at("08:15")]],
      [[0, at("06:30"), at("07:20")]],
      [[1, at("07:00"), at("07:45")]],
    ])
  })

  it("車號照開車順序從 1 起；鋪出來的趟次都沒有退回全天、都不是手動改的", () => {
    const vehicles = layout({ "0:6": 2, "1:7": 2 }, runTimesTable({ 0: 50, 1: 45 }))
    const marks = vehicles.flatMap((vehicle) => vehicle.trips.map((trip) => [trip.fallback, trip.edited]))
    expect([vehicles.map((vehicle) => vehicle.number), new Set(marks.map(String))]).toEqual([[1, 2, 3], new Set(["false,false"])])
  })

  it("在那一端等最久的車先發：1 號車 07:05 可用、2 號車 07:35 可用，08 時的兩班返程先給 1 號再給 2 號", () => {
    const vehicles = layout({ "0:6": 2, "1:8": 2 }, runTimesTable({ 0: 50, 1: 45 }))
    expect(runs(vehicles).map((trips) => trips.map(([, departure]) => departure))).toEqual([[at("06:00"), at("08:00")], [at("06:30"), at("08:30")]])
  })

  it("同時可用時取車號小的：06:00 開 80 分鐘與 07:00 開 20 分鐘都 07:20 到、07:35 可用，08:00 的返程給 1 號車", () => {
    const vehicles = layout({ "0:6": 1, "0:7": 1, "1:8": 1 }, runTimesTable({}, { "0:6": 80, "0:7": 20, "1:8": 45 }))
    expect(runs(vehicles).map((trips) => trips.length)).toEqual([2, 1])
  })

  it("同一時刻兩個方向都發車時先處理去程：06:00 的去程是 1 號車，06:00 的返程是 2 號車", () => {
    const vehicles = layout({ "0:6": 1, "1:6": 1 }, runTimesTable({ 0: 50, 1: 45 }))
    expect(runs(vehicles).map((trips) => trips[0][0])).toEqual([0, 1])
  })

  it("停留照那一端的分鐘數：去程到達後只停 2 分鐘，06:52 就可用，接得上 07:00 的返程，一台車就夠", () => {
    const vehicles = layout({ "0:6": 1, "1:7": 1 }, runTimesTable({ 0: 50, 1: 45 }), { 0: 2, 1: 15 })
    expect(runs(vehicles)).toEqual([[[0, at("06:00"), at("06:50")], [1, at("07:00"), at("07:45")]]])
  })

  it("計畫行駛時間退回全天的趟次帶著標記", () => {
    const vehicles = layout({ "0:6": 1 }, runTimesTable({ 0: 50, 1: 45 }, {}, true))
    expect(vehicles[0].trips[0].fallback).toBe(true)
  })

  it("23 時三班、行駛 50 分鐘：23:40 那一趟的到達是隔天 00:30，用當天的分鐘數 1470 表示", () => {
    const vehicles = layout({ "0:23": 3 }, runTimesTable({ 0: 50, 1: 45 }))
    expect(vehicles.at(-1).trips[0].arrival).toBe(1470)
  })

  it("某方向有發車卻沒有行駛時間時失敗，說出是哪個方向", () => {
    expect(() => layout({ "1:7": 1 }, runTimesTable({ 0: 50 }))).toThrow(/1/)
  })
})

describe("plan：照計畫行駛時間排一趟，給手動微調用", () => {
  const runTimes = runTimesTable({ 0: 50, 1: 45 }, { "0:23": 50, "1:0": 45 })

  it("23:40 發的去程 1470 到；24:45 發的返程查的是 0 時，1530 到，帶著改過的旗標", () => {
    expect([plan(runTimes, 85, 0, at("23:40")), plan(runTimes, 85, 1, 1485, true)]).toEqual([
      { goBack: 0, departure: 1420, arrival: 1470, fallback: false, edited: false },
      { goBack: 1, departure: 1485, arrival: 1530, fallback: false, edited: true },
    ])
  })

  it("用的是選的百分位數那一格", () => {
    const table = runTimesTable({ 0: 50, 1: 45 })
    table[0][6]["50"] = [48, false]
    expect([plan(table, 50, 0, at("06:00")).arrival, plan(table, 85, 0, at("06:00")).arrival]).toEqual([at("06:48"), at("06:50")])
  })
})
