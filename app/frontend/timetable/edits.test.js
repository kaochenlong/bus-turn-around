import { describe, expect, it } from "vitest"

import { addRow, addVehicle, changeDeparture, countEdited, deleteRow } from "./edits.js"
import { plan } from "./layout.js"
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

describe("changeDeparture：改一趟的發車，重算它的到達，其他趟不動", () => {
  it("返回那趟 07:30 改成 07:20：到達 08:05、標改過；去程不動", () => {
    const changed = changeDeparture(vehicleOne(), { vehicle: 1, index: 1, departure: at("07:20") }, planner)
    expect(legs(changed)).toEqual([[1, [[at("06:00"), at("06:50"), false], [at("07:20"), at("08:05"), true]]]])
  })

  it("不改傳進來的清單", () => {
    const before = vehicleOne()
    changeDeparture(before, { vehicle: 1, index: 1, departure: at("07:20") }, planner)
    expect(legs(before)).toEqual([[1, [[at("06:00"), at("06:50"), false], [at("07:30"), at("08:15"), false]]]])
  })

  it("改成 06:45 也照改：接不接得上由列的停留去說", () => {
    const changed = changeDeparture(vehicleOne(), { vehicle: 1, index: 1, departure: at("06:45") }, planner)
    expect(changed[0].trips[1].departure).toBe(at("06:45"))
  })
})

describe("deleteRow：刪掉那一列的趟次", () => {
  const twoRows = () => [{ number: 1, trips: [trip(0, "06:00-06:50"), trip(1, "07:30-08:15"), trip(0, "08:30-09:20"), trip(1, "09:35-10:20")] }]

  it("刪第一列：06:00 與 07:30 不見，留下 08:30 與 09:35", () => {
    expect(deleteRow(twoRows(), { vehicle: 1, row: 1 })[0].trips.map((t) => t.departure)).toEqual([at("08:30"), at("09:35")])
  })

  it("刪最後一列只剩一趟時，刪那一趟就好", () => {
    const vehicles = [{ number: 1, trips: [trip(0, "06:00-06:50"), trip(1, "07:30-08:15"), trip(0, "08:30-09:20")] }]
    expect(deleteRow(vehicles, { vehicle: 1, row: 2 })[0].trips.map((t) => t.departure)).toEqual([at("06:00"), at("07:30")])
  })

  it("整張單的列都刪掉時那台車不見，其他車不動", () => {
    const vehicles = [...vehicleOne(), { number: 2, trips: [trip(0, "06:30-07:20")] }]
    expect(legs(deleteRow(vehicles, { vehicle: 1, row: 1 }))).toEqual([[2, [[at("06:30"), at("07:20"), false]]]])
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
})

describe("addVehicle：在現有的單子之外再開一台車", () => {
  it("規格的加車：選返程 15:00，新的一張單一列 15:00 到 15:45、停 15、16:00 返回 16:50 到，兩趟都改過，編號接在後面", () => {
    const added = addVehicle(vehicleOne(), { goBack: 1, departure: at("15:00") }, planner, holds)
    expect(legs(added)).toEqual([
      [1, [[at("06:00"), at("06:50"), false], [at("07:30"), at("08:15"), false]]],
      [2, [[at("15:00"), at("15:45"), true], [at("16:00"), at("16:50"), true]]],
    ])
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

describe("countEdited：手動改過的格數", () => {
  it("改一趟是 1，再加一列是 3", () => {
    const changed = changeDeparture(vehicleOne(), { vehicle: 1, index: 1, departure: at("07:20") }, planner)
    expect([countEdited(changed), countEdited(addRow(changed, { vehicle: 1, departure: at("11:00") }, planner, holds))]).toEqual([1, 3])
  })
})
