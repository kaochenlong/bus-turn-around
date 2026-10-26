import { describe, expect, it } from "vitest"

import {
  arrivingAt, changeDeparture, changeVehicle, currentDay, defaultEnd, departuresAt, minutesOfDay, previousDate, recordArrival, startDay, taipeiDate, undoLast, vehiclesAt,
} from "./day.js"
import { at, runTimesTable, trip } from "./support.js"

// What the timetable page hands over when the dispatcher starts the day on
// 2026-10-27 at 05:30 Taipei time: route 9001 laid out from the weekdays
// 2026-10-19 to 2026-10-22 at p85 with 15 rest minutes, trips of direction 1
// ending at the stopping end, and the page's run times at every percentile.
function meta(overrides = {}) {
  return {
    routeId: 9001,
    date: "2026-10-27",
    startedAt: "2026-10-26T21:30:00.000Z",
    basis: { days: ["2026-10-19", "2026-10-20", "2026-10-21", "2026-10-22"], dayType: "weekday", percentile: 85, buffer: 15 },
    stoppingEnds: [1],
    runTimes: runTimesTable({ 0: 57, 1: 60 }),
    ...overrides,
  }
}

// The planning view's sheets: vehicle 1's first departure typed as 06:45,
// which pushed its return from 07:30 to 07:50; vehicle 2 as laid out, its
// trip in an hour that fell back to the whole day.
function planningSheets() {
  return [
    { number: 1, trips: [trip(0, "06:45-07:35", { typed: true, edited: true }), trip(1, "07:50-08:35", { original: at("07:30") })] },
    { number: 2, trips: [trip(1, "07:00-07:45", { fallback: true })] },
  ]
}

// One vehicle's trips from "HH:MM-HH:MM" legs, the directions alternating
// from the first one given.
const legs = (first, ...texts) => texts.map((leg, i) => trip((first + i) % 2, leg))

// A day started from the trips of each vehicle number.
function dayOf(sheets, overrides = {}) {
  return startDay(Object.entries(sheets).map(([number, trips]) => ({ number: Number(number), trips })), meta(overrides))
}

// The ends of the scenarios, named like every end by the direction that
// departs there: 甲站 is where direction 0 departs and direction 1 arrives.
const 甲站 = 0

// When a change is recorded: 17:52 Taipei time on the day.
const RECORDED_AT = "2026-10-27T09:52:00.000Z"

// Vehicle 1 of the spec's scenarios leaves 乙站 at 16:00 and is planned at
// 甲站 at 17:14, then leaves 甲站 at 17:40; vehicle 2 runs beside it.
function scenarioDay() {
  return dayOf({
    1: legs(0, "14:20-15:17", "16:00-17:14", "17:40-18:45", "19:20-20:23"),
    2: legs(1, "16:20-17:34", "18:00-18:57"),
  })
}

// The spec's two vehicles back at 甲站 before 17:40, and vehicles that
// stand elsewhere: 3 leaves 乙站 next, 4 ends its day at 甲站 and 5 ends it
// at 乙站, both before 17:40.
function swapDay() {
  return dayOf({
    1: legs(1, "16:00-17:14", "17:40-18:45", "19:20-20:23", "21:00-21:46"),
    2: legs(1, "16:20-17:34", "18:00-18:57", "19:40-20:43", "21:20-22:06"),
    3: legs(0, "17:00-17:57", "18:30-19:30"),
    4: legs(1, "15:00-15:50"),
    5: legs(0, "15:00-15:50"),
  })
}

const give = (day, tripId, vehicle) => changeVehicle(day, { tripId, vehicle, reason: "1 號車塞車", at: RECORDED_AT })

const times = (vehicle) => vehicle.trips.map((t) => [t.departure, t.arrival])

// Run times in which each percentile has its own minutes: direction 0 runs
// 55 minutes at p50 and 57 at p85, the p85 hour falling back to the whole
// day; direction 1 has none.
const TWO_PERCENTILES = { 0: Array(24).fill({ 50: [55, false], 85: [57, true] }), 1: Array(24).fill(null) }

describe("startDay：開始當天時把單子存成快照", () => {
  it("快照保留手動打過的 06:45，不帶改過、打過、原本的發車與退回全天的標記；代號是車號加序號", () => {
    expect(startDay(planningSheets(), meta()).plan).toEqual([
      { vehicle: 1, trips: [{ id: "1-1", goBack: 0, departure: at("06:45"), arrival: at("07:35") }, { id: "1-2", goBack: 1, departure: at("07:50"), arrival: at("08:35") }] },
      { vehicle: 2, trips: [{ id: "2-1", goBack: 1, departure: at("07:00"), arrival: at("07:45") }] },
    ])
  })

  it("格式版本 1，路線、台北日期、開始的時刻、計畫依據與停車端原樣帶著，還沒有修改", () => {
    const day = startDay(planningSheets(), meta())
    expect([day.version, day.routeId, day.date, day.startedAt, day.basis, day.stoppingEnds, day.changes])
      .toEqual([1, 9001, "2026-10-27", "2026-10-26T21:30:00.000Z", meta().basis, [1], []])
  })

  // The spec's scenario "Run times of the day's percentile kept".
  it.each([
    [85, { 85: [57, true] }],
    [50, { 50: [55, false] }],
  ])("p%i 開始的當天調度只存那個百分位數的行駛時間，沒有行駛時間的小時照舊是 null", (percentile, kept) => {
    const day = startDay(planningSheets(), meta({ basis: { ...meta().basis, percentile }, runTimes: TWO_PERCENTILES }))
    expect([day.runTimes[0][18], day.runTimes[0][0], day.runTimes[1][18]]).toEqual([kept, kept, null])
  })

  it("不改傳入的車與參數", () => {
    const [sheets, given] = [planningSheets(), meta()]
    startDay(sheets, given)
    expect([sheets, given]).toEqual([planningSheets(), meta()])
  })
})

describe("currentDay：快照套上還有效的修改", () => {
  it("沒有修改時就是快照的車：時刻與代號照快照，每一趟的車是原排、沒有記下、沒有打過", () => {
    const { vehicles } = currentDay(startDay(planningSheets(), meta()))
    expect(vehicles.map((vehicle) => [vehicle.number, vehicle.trips.map((t) => [t.id, t.departure, t.arrival, t.plannedVehicle, t.recorded, t.typed])])).toEqual([
      [1, [["1-1", at("06:45"), at("07:35"), 1, false, false], ["1-2", at("07:50"), at("08:35"), 1, false, false]]],
      [2, [["2-1", at("07:00"), at("07:45"), 2, false, false]]],
    ])
  })

  it("沒有修改時頁首的換車、改過發車、等車都是 0", () => {
    const { figures } = currentDay(startDay(planningSheets(), meta()))
    expect([figures.swaps, figures.typed, figures.waiting]).toEqual([0, 0, 0])
  })

  // A kept day altered outside the page: every change in effect applied when
  // it was recorded, so one that no longer applies is not a day to show.
  it.each([
    ["套不上的換車", { kind: "vehicle", tripId: "1-2", vehicle: 2 }, /no longer applies: day-ended/],
    ["不認得的修改", { kind: "constructor" }, /unknown change kind "constructor"/],
  ])("存著的修改%s：丟錯，不算出一天", (_, change, message) => {
    const day = startDay(planningSheets(), meta())
    expect(() => currentDay({ ...day, changes: [{ ...change, at: RECORDED_AT, undone: false }] })).toThrow(message)
  })
})

describe("recordArrival：記下一台車回到某一端的時刻", () => {
  const record = (day, vehicle, time, extra = {}) => recordArrival(day, { vehicle, end: 甲站, time: at(time), at: RECORDED_AT, ...extra })

  it("規格的記下回到時刻：16:00 從乙站發、原定 17:14 到甲站，記下 1 號車 17:52 回到甲站，那一趟 17:52 到、標記下，修改清單多一筆", () => {
    const day = record(scenarioDay(), 1, "17:52", { reason: "塞車" })
    const { id, arrival, recorded } = currentDay(day).vehicles[0].trips[1]
    expect([id, arrival, recorded, day.changes.map((c) => [c.kind, c.vehicle, c.end, c.time, c.tripId, c.reason, c.at, c.undone])])
      .toEqual(["1-2", at("17:52"), true, [["arrival", 1, 甲站, at("17:52"), "1-2", "塞車", RECORDED_AT, false]]])
  })

  it("改的是開往那一端、發車不晚於記下時刻的最後一趟：20:30 記下的是 19:20 那一趟", () => {
    const { trips } = currentDay(record(scenarioDay(), 1, "20:30")).vehicles[0]
    expect(trips.map((t) => [t.arrival, t.recorded])).toEqual([[at("15:17"), false], [at("17:14"), false], [at("18:45"), false], [at("20:30"), true]])
  })

  it("規格的沒有那一趟：第一趟開往甲站的 06:00 才發，05:00 記下被拒絕，傳入的當天調度沒有多一筆", () => {
    const day = dayOf({ 1: legs(1, "06:00-06:50", "07:10-08:00") })
    expect([record(day, 1, "05:00"), day.changes]).toEqual([{ refused: { kind: "no-trip" } }, []])
  })

  it("規格的晚回標出下一班：17:52 才回到甲站，17:40 那一班照舊 17:40、標車還沒回來、停留 −12，其他趟次都不動，頁首等車 1 班", () => {
    const { vehicles, figures } = currentDay(record(scenarioDay(), 1, "17:52"))
    expect([vehicles[0].trips.map((t) => [t.departure, t.arrival, t.stop, t.waiting]), times(vehicles[1]), figures.waiting]).toEqual([
      [[at("14:20"), at("15:17"), null, false], [at("16:00"), at("17:52"), 43, false], [at("17:40"), at("18:45"), -12, true], [at("19:20"), at("20:23"), 35, false]],
      [[at("16:20"), at("17:34")], [at("18:00"), at("18:57")]],
      1,
    ])
  })

  it("同一趟記兩次：17:52 之後再記 17:50，到達取後面那筆 17:50，兩筆都留在修改裡", () => {
    const day = record(record(scenarioDay(), 1, "17:52"), 1, "17:50")
    expect([currentDay(day).vehicles[0].trips[1].arrival, day.changes.map((c) => c.time)]).toEqual([at("17:50"), [at("17:52"), at("17:50")]])
  })

  it("不改傳入的當天調度", () => {
    const day = scenarioDay()
    record(day, 1, "17:52")
    expect(day).toEqual(scenarioDay())
  })

  it.each([
    ["沒有的車", { vehicle: 9 }, /vehicle 9/],
    ["端不是 0 或 1", { end: "0" }, /end/],
    ["時刻不是整數分鐘", { time: Number.NaN }, /time/],
  ])("%s：丟錯，不當成找不到那一趟", (_, wrong, message) => {
    expect(() => recordArrival(scenarioDay(), { vehicle: 1, end: 甲站, time: at("17:52"), at: RECORDED_AT, ...wrong })).toThrow(message)
  })
})

describe("changeVehicle：一班改派另一台車，就是兩台車從那一班起後面的班互換", () => {
  // Each vehicle's trips as [identifier, departure, planned vehicle].
  const runs = (day, ...numbers) => currentDay(day).vehicles.filter((v) => numbers.includes(v.number)).map((v) => v.trips.map((t) => [t.id, t.departure, t.plannedVehicle]))

  it("規格的兩台互換：17:40 那班給 2 號車，2 號車開 17:40 到 21:00 那幾班，1 號車開 18:00 到 21:20 那幾班，每一趟記得原排，頁首換車 1 次", () => {
    const day = give(swapDay(), "1-2", 2)
    expect([runs(day, 1, 2), currentDay(day).figures.swaps]).toEqual([
      [
        [["1-1", at("16:00"), 1], ["2-2", at("18:00"), 2], ["2-3", at("19:40"), 2], ["2-4", at("21:20"), 2]],
        [["2-1", at("16:20"), 2], ["1-2", at("17:40"), 1], ["1-3", at("19:20"), 1], ["1-4", at("21:00"), 1]],
      ],
      1,
    ])
  })

  it("換過去的趟次時刻不變：1 號車原本的 17:40 到 21:46 那幾趟在 2 號車上照舊", () => {
    const [, two] = currentDay(give(swapDay(), "1-2", 2)).vehicles
    expect(times(two).slice(1)).toEqual([[at("17:40"), at("18:45")], [at("19:20"), at("20:23")], [at("21:00"), at("21:46")]])
  })

  it("修改清單記下哪一班、幾點發、從哪台改給哪台與原因", () => {
    const [change] = give(swapDay(), "1-2", 2).changes
    expect([change.kind, change.tripId, change.departure, change.from, change.vehicle, change.reason, change.undone])
      .toEqual(["vehicle", "1-2", at("17:40"), 1, 2, "1 號車塞車", false])
  })

  it("規格的那台車不在那一端：3 號車 17:40 之後先從乙站發，被拒絕並說它接下來從乙站發，傳入的當天調度沒有多一筆", () => {
    const day = swapDay()
    expect([give(day, "1-2", 3), day.changes]).toEqual([{ refused: { kind: "elsewhere", vehicle: 3, end: 1 } }, []])
  })

  it("那台車之後沒有班、最後一趟回到甲站：照收，4 號車接 1 號車 17:40 之後的班，1 號車只剩 16:00 那一趟", () => {
    expect(runs(give(swapDay(), "1-2", 4), 1, 4).map((trips) => trips.map(([id]) => id))).toEqual([["1-1"], ["4-1", "1-2", "1-3", "1-4"]])
  })

  it("那台車之後沒有班、最後一趟停在乙站：被拒絕並說它在乙站收班", () => {
    expect(give(swapDay(), "1-2", 5)).toEqual({ refused: { kind: "day-ended", vehicle: 5, end: 1 } })
  })

  it("換過去再換回來：17:40 給 2 號車之後再給回 1 號車，兩台都回到原排，頁首換車 2 次", () => {
    const day = give(give(swapDay(), "1-2", 2), "1-2", 1)
    expect([runs(day, 1, 2), currentDay(day).figures.swaps]).toEqual([runs(swapDay(), 1, 2), 2])
  })

  it("整天的班都給出去的車沒有班了：1 號車第一班 16:00 給在乙站收班的 3 號車之後，再派給 1 號車被拒絕", () => {
    const day = dayOf({ 1: legs(1, "16:00-17:14", "17:40-18:45"), 3: legs(0, "12:00-12:57") })
    expect(give(give(day, "1-1", 3), "3-1", 1)).toEqual({ refused: { kind: "no-trips", vehicle: 1 } })
  })

  it.each([
    ["給自己那台車", "1-2", 1, /already runs on vehicle 1/],
    ["沒有的趟次", "9-9", 2, /no trip 9-9/],
    ["沒有的車", "1-2", 9, /no vehicle 9/],
  ])("%s：丟錯", (_, tripId, vehicle, message) => {
    expect(() => give(swapDay(), tripId, vehicle)).toThrow(message)
  })
})

describe("changeDeparture：改一班的發車時刻，只改那一趟", () => {
  // Vehicle 1 leaves 乙站 at 16:00, 甲站 at 18:00 and 乙站 again at 19:40.
  // Direction 0 runs 50 minutes except in the 18 hour, where it runs 57;
  // direction 1 runs 45.
  function retimeDay(overrides = {}) {
    return dayOf({ 1: legs(1, "16:00-17:14", "18:00-18:57", "19:40-20:43") }, { runTimes: runTimesTable({ 0: 50, 1: 45 }, { "0:18": 57 }), ...overrides })
  }

  const retype = (day, tripId, departure) => changeDeparture(day, { tripId, departure: at(departure), reason: "等乘客", at: RECORDED_AT })
  const recordOne = (day, time) => recordArrival(day, { vehicle: 1, end: 甲站, time: at(time), at: RECORDED_AT })

  it("規格的改晚：18 時方向 0 計畫行駛 57 分，18:00 那班打成 18:10，18:10 發、19:07 到、標打過，頁首改過發車 1 班", () => {
    const { vehicles, figures } = currentDay(retype(retimeDay(), "1-2", "18:10"))
    const { departure, arrival, typed } = vehicles[0].trips[1]
    expect([departure, arrival, typed, figures.typed]).toEqual([at("18:10"), at("19:07"), true, 1])
  })

  // The page embeds every percentile; the day planned with one of them.
  it.each([
    [85, "19:07"],
    [50, "19:10"],
  ])("到達用當天調度存下的那個百分位數：頁面上 18 時 p85 是 57 分、p50 是 60 分，p%i 開始的當天 18:10 發、%s 到", (percentile, arrival) => {
    const runTimes = { 0: Array(24).fill({ 50: [60, false], 85: [57, false] }), 1: Array(24).fill({ 50: [45, false], 85: [45, false] }) }
    const day = retimeDay({ runTimes, basis: { ...meta().basis, percentile } })
    expect(currentDay(retype(day, "1-2", "18:10")).vehicles[0].trips[1].arrival).toBe(at(arrival))
  })

  it("其他趟次都不動：18:00 那班改成 19:00，19:50 才到，19:40 那班照舊、標車還沒回來、停留 −10", () => {
    const { trips } = currentDay(retype(retimeDay(), "1-2", "19:00")).vehicles[0]
    expect(trips.map((t) => [t.departure, t.arrival, t.stop, t.waiting])).toEqual([
      [at("16:00"), at("17:14"), null, false], [at("19:00"), at("19:50"), 106, false], [at("19:40"), at("20:43"), -10, true],
    ])
  })

  it("已經記下回到時刻的那一趟改發車：到達維持記下的 17:52", () => {
    const { arrival, recorded, typed } = currentDay(retype(recordOne(retimeDay(), "17:52"), "1-1", "16:10")).vehicles[0].trips[0]
    expect([arrival, recorded, typed]).toEqual([at("17:52"), true, true])
  })

  it("先改發車再記下回到時刻：到達是記下的 17:52", () => {
    const { departure, arrival } = currentDay(recordOne(retype(retimeDay(), "1-1", "16:10"), "17:52")).vehicles[0].trips[0]
    expect([departure, arrival]).toEqual([at("16:10"), at("17:52")])
  })

  it("修改清單記下哪台車的哪一班、原本幾點、改成幾點與原因", () => {
    const [change] = retype(retimeDay(), "1-2", "18:10").changes
    expect([change.kind, change.tripId, change.vehicle, change.from, change.departure, change.reason]).toEqual(["departure", "1-2", 1, at("18:00"), at("18:10"), "等乘客"])
  })

  it.each([
    ["沒有的趟次", { tripId: "9-9" }, /no trip 9-9/],
    ["時刻不是整數分鐘", { departure: Number.NaN }, /departure/],
  ])("%s：丟錯", (_, wrong, message) => {
    expect(() => changeDeparture(retimeDay(), { tripId: "1-2", departure: at("18:10"), at: RECORDED_AT, ...wrong })).toThrow(message)
  })
})

describe("currentDay 的頁首數字與每台車的四小時休息", () => {
  // The spec's example "251區 vehicles 8 and 10": both alternate from
  // direction 0, and trips of direction 1 end at the stopping end, 甲站.
  function day251() {
    return dayOf({
      8: legs(0, "07:00-08:03", "08:45-09:47", "10:40-11:36", "12:20-13:19", "14:20-15:17", "16:00-17:14", "17:40-18:45", "19:20-20:23", "21:00-21:46", "22:45-23:40"),
      10: legs(0, "07:20-08:23", "09:00-10:02", "11:00-11:58", "12:40-13:39", "14:40-15:37", "16:20-17:34", "18:00-18:57", "19:40-20:43", "21:20-22:06", "23:00-24:07"),
    })
  }

  // Vehicle 8 recorded back at 17:52 and its 17:40 departure given to vehicle 10.
  const dispatched = () => give(recordArrival(day251(), { vehicle: 8, end: 甲站, time: at("17:52"), at: RECORDED_AT }), "8-7", 10)

  it("規格的例子：計畫的四小時休息 8 號車 61、10 號車 69，沒有修改時現在的一樣", () => {
    expect(currentDay(day251()).credits).toEqual([{ vehicle: 8, now: 61, planned: 61 }, { vehicle: 10, now: 69, planned: 69 }])
  })

  it("規格的例子：8 號車 17:52 回到、17:40 那班派給 10 號車，8 號車 16:00 之後開 18:00、19:40、21:20、23:00，10 號車 16:20 之後開 17:40、19:20、21:00、22:45", () => {
    const { vehicles } = currentDay(dispatched())
    expect(vehicles.map((v) => v.trips.slice(6).map((t) => t.departure))).toEqual([["18:00", "19:40", "21:20", "23:00"].map(at), ["17:40", "19:20", "21:00", "22:45"].map(at)])
  })

  it("規格的例子：四小時休息 8 號車 43 附計畫 61、10 號車 35 附計畫 69，最短停留 6 分在 10 號車 17:40 之前，沒有等車的班", () => {
    const { credits, figures } = currentDay(dispatched())
    expect([credits, figures.shortestStop, figures.waiting]).toEqual([
      [{ vehicle: 8, now: 43, planned: 61 }, { vehicle: 10, now: 35, planned: 69 }],
      { minutes: 6, vehicle: 10, departure: at("17:40") },
      0,
    ])
  })

  // Vehicle 1 stops 5 minutes at 乙站, where direction 0 arrives, and then
  // 15 at 甲站.
  it.each([
    [[1], { minutes: 15, vehicle: 1, departure: at("08:00") }],
    [[0, 1], { minutes: 5, vehicle: 1, departure: at("06:55") }],
    [[], null],
  ])("最短停留只算停車端：趟次結束在停車端的方向 %j", (stoppingEnds, shortest) => {
    const day = dayOf({ 1: legs(0, "06:00-06:50", "06:55-07:45", "08:00-08:50") }, { stoppingEnds })
    expect(currentDay(day).figures.shortestStop).toEqual(shortest)
  })

  it("最短停留不算負的：17:52 才回到甲站，17:40 那班停留 −12 不算，最短是 2 號車 18:00 之前的 26 分", () => {
    const day = recordArrival(scenarioDay(), { vehicle: 1, end: 甲站, time: at("17:52"), at: RECORDED_AT })
    expect(currentDay(day).figures.shortestStop).toEqual({ minutes: 26, vehicle: 2, departure: at("18:00") })
  })

  it("一樣短的停留取比較早的那一班：1 號車 17:40 與 2 號車 18:00 之前都停 26 分，報 1 號車 17:40", () => {
    expect(currentDay(scenarioDay()).figures.shortestStop).toEqual({ minutes: 26, vehicle: 1, departure: at("17:40") })
  })
})

describe("undoLast：復原最新一筆還有效的修改", () => {
  const ids = (day) => currentDay(day).vehicles.map((v) => v.trips.map((t) => t.id))
  const recordOne = (day) => recordArrival(day, { vehicle: 1, end: 甲站, time: at("17:30"), at: RECORDED_AT })

  it("規格的復原換車：17:40 給 2 號車之後復原，兩台都回到換車之前，修改留著標已復原，頁首換車 0 次", () => {
    const day = undoLast(give(swapDay(), "1-2", 2))
    expect([ids(day), day.changes.map((c) => [c.kind, c.undone]), currentDay(day).figures.swaps]).toEqual([
      [["1-1", "1-2", "1-3", "1-4"], ["2-1", "2-2", "2-3", "2-4"], ["3-1", "3-2"], ["4-1"], ["5-1"]],
      [["vehicle", true]],
      0,
    ])
  })

  it("再復原一次是更早那一筆：記下 1 號車 17:30 回到、再換車，復原兩次之後兩筆都標已復原，16:00 那一趟回到原定的 17:14", () => {
    const day = undoLast(undoLast(give(recordOne(swapDay()), "1-2", 2)))
    expect([day.changes.map((c) => [c.kind, c.undone]), currentDay(day).vehicles[0].trips[0].arrival]).toEqual([[["arrival", true], ["vehicle", true]], at("17:14")])
  })

  it("沒有還有效的修改時原樣回傳：已復原的不會再被復原或重做", () => {
    const [fresh, undone] = [swapDay(), undoLast(give(swapDay(), "1-2", 2))]
    expect([undoLast(fresh) === fresh, undoLast(undone) === undone]).toEqual([true, true])
  })

  it("復原之後再改的接在後面", () => {
    const day = give(undoLast(give(swapDay(), "1-2", 2)), "1-2", 4)
    expect(day.changes.map((c) => [c.vehicle, c.undone])).toEqual([[2, true], [4, false]])
  })

  it("不改傳入的當天調度", () => {
    const day = give(swapDay(), "1-2", 2)
    undoLast(day)
    expect(day.changes.map((c) => c.undone)).toEqual([false])
  })
})

describe("departuresAt：一端的發車表", () => {
  // Departures from 甲站 around 17:55: 17:40 on vehicle 2, 18:00 on vehicle
  // 1 and 18:20 on vehicle 3, each vehicle back before its departure.
  function aroundNow() {
    return dayOf({
      1: legs(1, "16:00-17:14", "18:00-18:57"),
      2: legs(1, "16:20-17:34", "17:40-18:45"),
      3: legs(1, "16:40-17:50", "18:20-19:20"),
    })
  }

  const rowsAt = (day, end, now) => departuresAt(currentDay(day), end, at(now))
  const lateOne = () => recordArrival(scenarioDay(), { vehicle: 1, end: 甲站, time: at("17:52"), at: RECORDED_AT })

  it("規格的現在前後：17:55 時 17:40 已發車、18:00 下一班、18:20 照計畫", () => {
    expect(rowsAt(aroundNow(), 甲站, "17:55").map((r) => [r.departure, r.status])).toEqual([[at("17:40"), "departed"], [at("18:00"), "next"], [at("18:20"), "planned"]])
  })

  it("每一班帶代號、原排、現在的車、那台車回到這一端的時刻與停留", () => {
    expect(rowsAt(aroundNow(), 甲站, "17:55").map((r) => [r.id, r.plannedVehicle, r.vehicle, r.arrival, r.recorded, r.stop]))
      .toEqual([["2-2", 2, 2, at("17:34"), false, 6], ["1-2", 1, 1, at("17:14"), false, 46], ["3-2", 3, 3, at("17:50"), false, 30]])
  })

  it("那台車當天第一趟的班沒有回到的時刻與停留：乙站 16:00、16:20、16:40 那三班", () => {
    expect(rowsAt(aroundNow(), 1, "17:55").map((r) => [r.departure, r.arrival, r.stop])).toEqual([[at("16:00"), null, null], [at("16:20"), null, null], [at("16:40"), null, null]])
  })

  it("換過車的班帶現在的車與原排，回到的時刻與停留是現在那台車的", () => {
    const swapped = rowsAt(give(swapDay(), "1-2", 2), 甲站, "17:55").filter((r) => r.vehicle !== r.plannedVehicle)
    expect(swapped.map((r) => [r.departure, r.vehicle, r.plannedVehicle, r.arrival, r.stop]))
      .toEqual([[at("17:40"), 2, 1, at("17:34"), 6], [at("18:00"), 1, 2, at("17:14"), 46], [at("21:00"), 2, 1, at("20:23"), 37], [at("21:20"), 1, 2, at("20:43"), 37]])
  })

  it("車還沒回來的班不論現在幾點都標車還沒回來，回到的時刻標記下：18:30 時 17:40 那班等車、停留 −12", () => {
    expect(rowsAt(lateOne(), 甲站, "18:30").map((r) => [r.departure, r.arrival, r.recorded, r.stop, r.status])).toEqual([
      [at("14:20"), null, false, null, "departed"], [at("17:40"), at("17:52"), true, -12, "waiting"], [at("18:00"), at("17:34"), false, 26, "departed"],
    ])
  })

  it("現在之後第一班在等車時它標車還沒回來，後面的照計畫：17:30 時 17:40 等車、18:00 照計畫", () => {
    expect(rowsAt(lateOne(), 甲站, "17:30").map((r) => r.status)).toEqual(["departed", "waiting", "planned"])
  })

  // The spec's scenario "Stopping end listed first", and the other cases.
  it.each([
    [[1], 0],
    [[0], 1],
    [[0, 1], 0],
    [[], 1],
  ])("先列哪一端：趟次結束在停車端的方向 %j 時先列方向 %i 發車的那一端", (stoppingEnds, end) => {
    expect(defaultEnd(dayOf({ 1: legs(0, "06:00-06:50") }, { stoppingEnds }))).toBe(end)
  })
})

describe("vehiclesAt 與 arrivingAt：現在在這一端的車、接下來會回到的車", () => {
  // At 17:55: vehicle 1 back at 甲站 at 17:52, recorded, for 18:00; vehicle
  // 2 left 甲站 at 17:40; vehicle 3 back at 17:50 for 18:20; vehicle 4 ended
  // its day at 甲站 at 15:50; vehicle 5 stands at 乙站.
  function standingDay() {
    const day = dayOf({
      1: legs(1, "16:00-17:14", "18:00-18:57"),
      2: legs(1, "16:20-17:34", "17:40-18:45"),
      3: legs(1, "16:40-17:50", "18:20-19:20"),
      4: legs(1, "15:00-15:50"),
      5: legs(0, "17:00-17:45", "18:10-19:00"),
    })
    return recordArrival(day, { vehicle: 1, end: 甲站, time: at("17:52"), at: RECORDED_AT })
  }

  const standing = (day, now) => vehiclesAt(currentDay(day), 甲站, at(now))
  const arriving = (day, now) => arrivingAt(currentDay(day), 甲站, at(now)).map((row) => [row.vehicle, row.arrival, row.next])

  it("規格的剛回來的車：17:55 時 1 號車 17:52 回到甲站（記下的）、停了 3 分、排 18:00", () => {
    expect(standing(standingDay(), "17:55").find((row) => row.vehicle === 1)).toEqual({ vehicle: 1, arrival: at("17:52"), recorded: true, stood: 3, next: at("18:00") })
  })

  it("17:55 在甲站的車照回到的先後：4 號車 15:50 回到後收班、3 號車 17:50、1 號車 17:52；已經開走的 2 號車與在乙站的 5 號車不列", () => {
    expect(standing(standingDay(), "17:55").map((row) => [row.vehicle, row.stood, row.next])).toEqual([[4, 125, null], [3, 5, at("18:20")], [1, 3, at("18:00")]])
  })

  it("下一班在等它的車照樣在這一端：17:40 那班的車 17:52 才回到，17:55 時列在甲站、排 17:40", () => {
    const day = recordArrival(scenarioDay(), { vehicle: 1, end: 甲站, time: at("17:52"), at: RECORDED_AT })
    expect(standing(day, "17:55").map((row) => [row.vehicle, row.arrival, row.next])).toEqual([[2, at("17:34"), at("18:00")], [1, at("17:52"), at("17:40")]])
  })

  it("發車那一刻車還在：1 號車 18:00 時還列在甲站，18:01 就不列", () => {
    expect(["18:00", "18:01"].map((now) => standing(standingDay(), now).some((row) => row.vehicle === 1))).toEqual([true, false])
  })

  it("接下來會回到甲站的車取最早的四台，每台帶回到的時刻與下一班", () => {
    const day = dayOf({
      1: legs(1, "17:00-18:10", "18:30-19:20"),
      2: legs(1, "17:10-18:20", "18:40-19:30"),
      3: legs(1, "17:20-18:30", "18:50-19:40"),
      4: legs(1, "17:30-18:40", "19:00-19:50"),
      5: legs(1, "17:40-18:50", "19:10-20:00"),
    })
    expect(arriving(day, "17:55")).toEqual([[1, at("18:10"), at("18:30")], [2, at("18:20"), at("18:40")], [3, at("18:30"), at("18:50")], [4, at("18:40"), at("19:00")]])
  })

  it("每台車只列下一次回到：1 號車 18:10 與 20:40 都回到甲站，只列 18:10；當天最後一趟回到的沒有下一班", () => {
    const day = dayOf({ 1: legs(1, "17:00-18:10", "18:30-19:20", "19:40-20:40"), 2: legs(0, "18:00-18:40", "19:00-19:50") })
    expect(arriving(day, "17:55")).toEqual([[1, at("18:10"), at("18:30")], [2, at("19:50"), null]])
  })

  it("剛好現在回到的車算在這一端，不算接下來會回到：18:10 時的 1 號車", () => {
    const day = dayOf({ 1: legs(1, "17:00-18:10", "18:30-19:20") })
    expect([standing(day, "18:10").map((row) => row.vehicle), arriving(day, "18:10")]).toEqual([[1], []])
  })
})

describe("現在：瀏覽器的時鐘換成台北時間，算成當天的分鐘數", () => {
  it.each([
    ["2026-10-27T09:55:00.000Z", "2026-10-27", 1075],
    ["2026-10-27T16:30:00.000Z", "2026-10-28", 1470],
  ])("%s 是台北 %s，當天 2026-10-27 的第 %i 分鐘：過了午夜從 24:00 接著算", (instant, date, minutes) => {
    expect([taipeiDate(new Date(instant)), minutesOfDay("2026-10-27", new Date(instant))]).toEqual([date, minutes])
  })

  it.each([
    ["2026-10-27", "2026-10-26"],
    ["2026-11-01", "2026-10-31"],
    ["2027-03-01", "2027-02-28"],
  ])("%s 的前一天是 %s：繼續當天時也找它", (date, previous) => {
    expect(previousDate(date)).toBe(previous)
  })
})
