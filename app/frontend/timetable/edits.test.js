import { describe, expect, it } from "vitest"

import { addRow, addVehicle, changeDeparture, countEdited, countPushed, deleteRow, pushedMinutes, settle } from "./edits.js"
import { plan } from "./layout.js"
import { rows } from "./rows.js"
import { at, runTimesTable, trip } from "./support.js"

// Five measured trips in each hour the scenarios touch: direction 0 runs 50
// minutes in the 06 hour and 48 in the 11 hour, direction 1 runs 45 in the 07
// hour and 46 in the 12 hour.
const runTimes = runTimesTable({ 0: 50, 1: 45 }, { "0:11": 48, "1:12": 46 })
const planner = (goBack, departure, edited) => plan(runTimes, 85, goBack, departure, edited)
const holds = { 0: 15, 1: 15 }

// Vehicle 1's row of the spec: 06:00 out from 甲站, 07:30 back.
function vehicleOne() {
  return [{ number: 1, trips: [trip(0, "06:00-06:50"), trip(1, "07:30-08:15")] }]
}

function legs(vehicles) {
  return vehicles.map((vehicle) => [vehicle.number, vehicle.trips.map((t) => [t.departure, t.arrival, t.edited])])
}

// The spec's two-row sheet: 06:00 out and 07:30 back, then 09:30 out and
// 10:35 back, with direction 0 running 50 minutes and direction 1 45 in
// every hour and a hold of 15 at both ends.
const everyHour = runTimesTable({ 0: 50, 1: 45 })
const everyHourPlanner = (goBack, departure, edited) => plan(everyHour, 85, goBack, departure, edited)

function twoRowSheet() {
  return [trip(0, "06:00-06:50"), trip(1, "07:30-08:15"), trip(0, "09:30-10:20"), trip(1, "10:35-11:20")]
}

// That sheet with its first departure typed anew.
function typedFirst(leg) {
  return [trip(0, leg, { typed: true, edited: true }), ...twoRowSheet().slice(1)]
}

const departures = (trips) => trips.map((t) => t.departure)

// "HH:MM-HH:MM" legs as [departure, arrival] in minutes.
const asLegs = (texts) => texts.map((text) => text.split("-").map(at))

const timesOf = (trips) => trips.map((t) => [t.departure, t.arrival])

describe("changeDeparture：改一趟的發車，後面沒打過的接不上就往後推", () => {
  it("返回那趟 07:30 改成 07:20：到達 08:05、標改過；去程不動", () => {
    const changed = changeDeparture(vehicleOne(), { vehicle: 1, index: 1, departure: at("07:20") }, planner, holds)
    expect(legs(changed)).toEqual([[1, [[at("06:00"), at("06:50"), false], [at("07:20"), at("08:05"), true]]]])
  })

  it("不改傳進來的清單", () => {
    const before = vehicleOne()
    changeDeparture(before, { vehicle: 1, index: 1, departure: at("07:20") }, planner, holds)
    expect(legs(before)).toEqual([[1, [[at("06:00"), at("06:50"), false], [at("07:30"), at("08:15"), false]]]])
  })

  it("改成 06:45 也照改：接不接得上由列的停留去說", () => {
    const changed = changeDeparture(vehicleOne(), { vehicle: 1, index: 1, departure: at("06:45") }, planner, holds)
    expect(changed[0].trips[1].departure).toBe(at("06:45"))
  })

  // The spec's example "First departure typed": the typed time, the trips,
  // the rows' stops and the minutes each trip was pushed.
  it.each([
    ["06:10", ["06:10-07:00", "07:30-08:15", "09:30-10:20", "10:35-11:20"], [30, 75, 15], [0, 0, 0, 0]],
    ["05:30", ["05:30-06:20", "07:30-08:15", "09:30-10:20", "10:35-11:20"], [70, 75, 15], [0, 0, 0, 0]],
    ["07:00", ["07:00-07:50", "08:05-08:50", "09:30-10:20", "10:35-11:20"], [15, 40, 15], [0, 35, 0, 0]],
    ["08:00", ["08:00-08:50", "09:05-09:50", "10:05-10:55", "11:10-11:55"], [15, 15, 15], [0, 95, 35, 35]],
  ])("規格的兩列例子，第一趟打成 %s：趟次 %j、停留 %j、被推 %j 分", (typed, expectedLegs, stops, pushed) => {
    const [{ trips }] = changeDeparture([{ number: 1, trips: twoRowSheet() }], { vehicle: 1, index: 0, departure: at(typed) }, everyHourPlanner, holds)
    const [first, second] = rows(trips)
    expect([timesOf(trips), [first.stop, first.nextStop, second.stop], trips.map(pushedMinutes), trips[0].edited])
      .toEqual([asLegs(expectedLegs), stops, pushed, true])
  })

  it("打過的不被推：第二列的去程先打成 09:00，再把第一趟打成 08:00，09:00 照舊、前面停留 −50，只有 09:05 被推", () => {
    const once = changeDeparture([{ number: 1, trips: twoRowSheet() }], { vehicle: 1, index: 2, departure: at("09:00") }, everyHourPlanner, holds)
    const [{ trips }] = changeDeparture(once, { vehicle: 1, index: 0, departure: at("08:00") }, everyHourPlanner, holds)
    expect([departures(trips), rows(trips)[0].nextStop, trips.map((t) => t.edited), trips.map(pushedMinutes)])
      .toEqual([["08:00", "09:05", "09:00", "10:35"].map(at), -50, [true, false, true, false], [0, 95, 0, 0]])
  })

  it("去程打成 06:45：返程從 07:30 推到 07:50、08:35 到；再打回 06:00，返程回到 07:30", () => {
    const pushed = changeDeparture(vehicleOne(), { vehicle: 1, index: 0, departure: at("06:45") }, planner, holds)
    const back = changeDeparture(pushed, { vehicle: 1, index: 0, departure: at("06:00") }, planner, holds)
    expect([pushed, back].map(([{ trips }]) => [timesOf(trips), trips.map(pushedMinutes)]))
      .toEqual([[asLegs(["06:45-07:35", "07:50-08:35"]), [0, 20]], [asLegs(["06:00-06:50", "07:30-08:15"]), [0, 0]]])
  })
})

describe("deleteRow：刪掉那一列的趟次，那張單照推法重算", () => {
  const twoRows = () => [{ number: 1, trips: [trip(0, "06:00-06:50"), trip(1, "07:30-08:15"), trip(0, "08:30-09:20"), trip(1, "09:35-10:20")] }]

  it("刪第一列：06:00 與 07:30 不見，留下 08:30 與 09:35", () => {
    expect(deleteRow(twoRows(), { vehicle: 1, row: 1 }, planner, holds)[0].trips.map((t) => t.departure)).toEqual([at("08:30"), at("09:35")])
  })

  it("刪最後一列只剩一趟時，刪那一趟就好", () => {
    const vehicles = [{ number: 1, trips: [trip(0, "06:00-06:50"), trip(1, "07:30-08:15"), trip(0, "08:30-09:20")] }]
    expect(deleteRow(vehicles, { vehicle: 1, row: 2 }, planner, holds)[0].trips.map((t) => t.departure)).toEqual([at("06:00"), at("07:30")])
  })

  it("整張單的列都刪掉時那台車不見，其他車不動", () => {
    const vehicles = [...vehicleOne(), { number: 2, trips: [trip(0, "06:30-07:20")] }]
    expect(legs(deleteRow(vehicles, { vehicle: 1, row: 1 }, planner, holds))).toEqual([[2, [[at("06:30"), at("07:20"), false]]]])
  })

  it("規格的兩列例子：第一趟打成 08:00 被推過之後刪第一列，10:05、11:10 回到原本的 09:30、10:35", () => {
    const pushed = [{ number: 1, trips: settle(typedFirst("08:00-08:50"), everyHourPlanner, holds) }]
    const [{ trips }] = deleteRow(pushed, { vehicle: 1, row: 1 }, everyHourPlanner, holds)
    expect([timesOf(trips), trips.map(pushedMinutes)]).toEqual([asLegs(["09:30-10:20", "10:35-11:20"]), [0, 0]])
  })
})

describe("addRow：在那張單底下加一列", () => {
  it("規格的加列：11:00 發、11:48 到，停 15，12:03 返回、12:49 到站，兩趟都改過", () => {
    const added = addRow(vehicleOne(), { vehicle: 1, departure: at("11:00") }, planner, holds)
    expect(legs(added)[0][1].slice(2)).toEqual([[at("11:00"), at("11:48"), true], [at("12:03"), at("12:49"), true]])
  })

  it("照那張單第一趟的方向：第一趟是返程的單子，加的那列先返程再去程", () => {
    const vehicles = [{ number: 3, trips: [trip(1, "07:00-07:45")] }]
    expect(addRow(vehicles, { vehicle: 3, departure: at("12:00") }, planner, holds)[0].trips.slice(1).map((t) => t.goBack)).toEqual([1, 0])
  })

  it("加的那一列返程不是打的：去程改成 11:30，返程從 12:03 推到 12:33、13:19 到，兩格都改過，返程被推 30 分", () => {
    const added = addRow(vehicleOne(), { vehicle: 1, departure: at("11:00") }, planner, holds)
    const [{ trips }] = changeDeparture(added, { vehicle: 1, index: 2, departure: at("11:30") }, planner, holds)
    expect([timesOf(trips.slice(2)), trips.slice(2).map((t) => t.edited), pushedMinutes(trips[3])])
      .toEqual([asLegs(["11:30-12:18", "12:33-13:19"]), [true, true], 30])
  })
})

describe("addVehicle：在現有的單子之外再開一台車", () => {
  it("規格的加車：選返程 15:00，新的一張單一列 15:00 到 15:45、停 15、16:00 返回 16:50 到，兩趟都改過，編號接在後面", () => {
    const added = addVehicle(vehicleOne(), { goBack: 1, departure: at("15:00") }, planner, holds)
    expect(legs(added)).toEqual([
      [1, [[at("06:00"), at("06:50"), false], [at("07:30"), at("08:15"), false]]],
      [2, [[at("15:00"), at("15:45"), true], [at("16:00"), at("16:50"), true]]],
    ])
  })

  it("加的車第一趟是打的、返程不是，原本的發車時刻是打的 15:00 與加的當下算出的 16:00", () => {
    const [, added] = addVehicle(vehicleOne(), { goBack: 1, departure: at("15:00") }, planner, holds)
    expect(added.trips.map((t) => [t.typed, t.original])).toEqual([[true, at("15:00")], [false, at("16:00")]])
  })

  it("有車被刪光過時不重號：剩 1 號與 3 號車，新車是 4 號", () => {
    const vehicles = [...vehicleOne(), { number: 3, trips: [trip(1, "07:00-07:45")] }]
    expect(addVehicle(vehicles, { goBack: 0, departure: at("09:00") }, planner, holds).map((vehicle) => vehicle.number)).toEqual([1, 3, 4])
  })

  it("不改傳進來的清單", () => {
    const before = vehicleOne()
    addVehicle(before, { goBack: 1, departure: at("15:00") }, planner, holds)
    expect(before.length).toBe(1)
  })
})

describe("settle：沒打過的趟次接不上就往後推到停滿，不早於原本的發車時刻", () => {
  it("第一趟打成 08:00：發車 08:00、09:05、10:05、11:10，到達 08:50、09:50、10:55、11:55", () => {
    const settled = settle(typedFirst("08:00-08:50"), everyHourPlanner, holds)
    expect(timesOf(settled)).toEqual(asLegs(["08:00-08:50", "09:05-09:50", "10:05-10:55", "11:10-11:55"]))
  })

  it("第一趟打成 07:00：只有返程推到 08:05，第二列的 09:30 接得上、不動", () => {
    expect(departures(settle(typedFirst("07:00-07:50"), everyHourPlanner, holds))).toEqual(["07:00", "08:05", "09:30", "10:35"].map(at))
  })

  it("第一趟打成 05:30：後面都照原本的發車時刻，不往前拉", () => {
    expect(departures(settle(typedFirst("05:30-06:20"), everyHourPlanner, holds))).toEqual(["05:30", "07:30", "09:30", "10:35"].map(at))
  })

  it("停留看前一趟到的那一端：去程到達那一端停 2 分，07:50 到、07:52 返程，09:30 照舊", () => {
    expect(departures(settle(typedFirst("07:00-07:50"), everyHourPlanner, { 0: 2, 1: 15 }))).toEqual(["07:00", "07:52", "09:30", "10:35"].map(at))
  })

  it("被推到 08:05 的返程，前面改回 06:00 接得上時回到原本的 07:30", () => {
    const trips = [trip(0, "06:00-06:50", { typed: true, edited: true }), trip(1, "08:05-08:50", { original: at("07:30") })]
    expect(departures(settle(trips, everyHourPlanner, holds))).toEqual(["06:00", "07:30"].map(at))
  })

  it("打過的 09:00 不動：前面推到 09:05 發、09:50 回站，09:00 前的停留照實是 −50，10:35 接得上不動", () => {
    const trips = typedFirst("08:00-08:50").with(2, trip(0, "09:00-09:50", { typed: true, edited: true }))
    const settled = settle(trips, everyHourPlanner, holds)
    expect([departures(settled), rows(settled)[0].nextStop]).toEqual([["08:00", "09:05", "09:00", "10:35"].map(at), -50])
  })

  it("第一趟不是打的就從原本的發車時刻發：刪掉第一列之後，被推到 10:05 的去程回到 09:30", () => {
    const trips = [trip(0, "10:05-10:55", { original: at("09:30") }), trip(1, "11:10-11:55", { original: at("10:35") })]
    expect(departures(settle(trips, everyHourPlanner, holds))).toEqual(["09:30", "10:35"].map(at))
  })

  it("帶回原本的旗標：加列的返程被推到 12:35 之後，仍是手動改過、不是打的、原本 12:03", () => {
    const trips = [trip(0, "11:30-12:20", { typed: true, edited: true }), trip(1, "12:03-12:48", { edited: true })]
    const [, back] = settle(trips, everyHourPlanner, holds)
    expect([back.departure, back.edited, back.typed, back.original]).toEqual([at("12:35"), true, false, at("12:03")])
  })

  it("不改傳進來的陣列", () => {
    const before = typedFirst("08:00-08:50")
    settle(before, everyHourPlanner, holds)
    expect(departures(before)).toEqual(["08:00", "07:30", "09:30", "10:35"].map(at))
  })
})

describe("pushedMinutes、countPushed：被推過幾分、幾格", () => {
  it("被推的返程 08:05 比原本的 07:30 晚 35 分；鋪排的與打的趟次是 0", () => {
    const trips = [trip(1, "08:05-08:50", { original: at("07:30") }), trip(0, "06:00-06:50"), trip(0, "07:00-07:50", { typed: true, edited: true })]
    expect(trips.map(pushedMinutes)).toEqual([35, 0, 0])
  })

  it("第一趟打成 08:00 的那張單有 3 格被推過，另一張沒動的單不算", () => {
    const vehicles = [{ number: 1, trips: settle(typedFirst("08:00-08:50"), everyHourPlanner, holds) }, { number: 2, trips: twoRowSheet() }]
    expect(countPushed(vehicles)).toBe(3)
  })
})

describe("countEdited：手動改過的格數", () => {
  it("改一趟是 1，再加一列是 3", () => {
    const changed = changeDeparture(vehicleOne(), { vehicle: 1, index: 1, departure: at("07:20") }, planner, holds)
    expect([countEdited(changed), countEdited(addRow(changed, { vehicle: 1, departure: at("11:00") }, planner, holds))]).toEqual([1, 3])
  })
})
