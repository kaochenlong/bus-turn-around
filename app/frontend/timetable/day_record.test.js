import { describe, expect, it } from "vitest"

import { changeDeparture, changeVehicle, currentDay, recordArrival, startDay, undoLast } from "./day.js"
import { changeLogCsv, csvFileName, marksFor, sheetHeader, sheetNotes, sheetsCsv } from "./day_record.js"
import { clock } from "./format.js"
import { at, runTimesTable, trip } from "./support.js"

// The words of the files as the day dispatch view hands them over, with the
// directions' names and the names of the ends trips leave from.
const LABELS = {
  changesHeader: ["記下時刻", "種類", "車", "那一趟", "換給", "時刻", "原因", "已復原"],
  sheetsHeader: ["車", "方向", "起站", "發車", "到達", "到達是記下的", "原排", "改過發車", "原本的發車"],
  kinds: { arrival: "記下回到", vehicle: "換車", departure: "改發車" },
  directions: { 0: "去程", 1: "返程" },
  stops: { 0: "福安居", 1: "台電大樓" },
  trip: "%{direction} %{departure}",
  yes: "是",
  no: "否",
}

const BOM = "﻿"
const CHANGES_HEADER = "記下時刻,種類,車,那一趟,換給,時刻,原因,已復原\r\n"
const SHEETS_HEADER = "車,方向,起站,發車,到達,到達是記下的,原排,改過發車,原本的發車\r\n"

// Route 11764's day of 2026-10-27: vehicle 8 leaves 台電大樓 at 16:00 and is
// planned back at 福安居 at 17:14, then leaves 福安居 at 17:40; vehicle 10
// runs beside it, back at 福安居 at 17:34 and leaving it at 18:00.
function scenarioDay() {
  const legs = (first, ...texts) => texts.map((leg, i) => trip((first + i) % 2, leg))
  return startDay([
    { number: 8, trips: legs(1, "16:00-17:14", "17:40-18:45", "19:20-20:23") },
    { number: 10, trips: legs(1, "16:20-17:34", "18:00-18:57", "19:40-20:43") },
  ], {
    routeId: 11764,
    date: "2026-10-27",
    startedAt: "2026-10-26T21:30:00.000Z",
    basis: { days: ["2026-10-19", "2026-10-20", "2026-10-21", "2026-10-22"], dayType: "weekday", percentile: 85, buffer: 15 },
    stoppingEnds: [1],
    runTimes: runTimesTable({ 0: 65, 1: 63 }),
  })
}

// 福安居 is where direction 0 departs and direction 1 arrives.
const 福安居 = 0

// An instant of 2026-10-27 at a Taipei time.
const taipei = (time) => new Date(`2026-10-27T${time}:00+08:00`).toISOString()

const back = (day, time, reason = "", recordedAt = time) => recordArrival(day, { vehicle: 8, end: 福安居, time: at(time), reason, at: taipei(recordedAt) })
const give = (day, tripId, vehicle, recordedAt) => changeVehicle(day, { tripId, vehicle, at: taipei(recordedAt) })
const retime = (day, tripId, departure, recordedAt, reason = "") => changeDeparture(day, { tripId, departure: at(departure), reason, at: taipei(recordedAt) })

// The rows after the header, without their line ends.
const rowsOf = (text) => text.slice(BOM.length).split("\r\n").slice(1, -1)

describe("csvFileName：檔名帶路線 Id 與日期", () => {
  it.each([
    ["changes", "day-dispatch-11764-2026-10-27-changes.csv"],
    ["sheets", "day-dispatch-11764-2026-10-27-sheets.csv"],
  ])("%s 的檔名是 %s", (kind, name) => {
    expect(csvFileName(scenarioDay(), kind)).toBe(name)
  })

  it("不認得的檔案種類：丟錯，不給一個錯的檔名", () => {
    expect(() => csvFileName(scenarioDay(), "change")).toThrow(/kind/)
  })
})

describe("changeLogCsv：修改清單一筆一列", () => {
  it("規格的兩筆修改匯出：開頭是 BOM 與表頭，第一列是 17:52 記下回到、塞車、沒有復原，第二列是已復原的換車", () => {
    const day = undoLast(give(back(scenarioDay(), "17:52", "塞車"), "8-2", 10, "17:53"))
    expect(changeLogCsv(day, LABELS)).toBe(`${BOM}${CHANGES_HEADER}2026-10-27 17:52,記下回到,8,返程 16:00,,17:52,塞車,否\r\n2026-10-27 17:53,換車,8,去程 17:40,10,,,是\r\n`)
  })

  it("改發車那一列：車是那一趟的車，那一趟寫改之前的發車，時刻寫新的發車", () => {
    expect(rowsOf(changeLogCsv(retime(scenarioDay(), "8-2", "17:50", "17:30", "司機用餐"), LABELS))).toEqual(["2026-10-27 17:30,改發車,8,去程 17:40,,17:50,司機用餐,否"])
  })

  it("記下回到的那一趟寫記下當時的發車：先改成 16:05 再記下，寫 16:05；改過又復原的不算，寫 16:00", () => {
    const typed = retime(scenarioDay(), "8-1", "16:05", "15:50")
    const lines = [back(typed, "17:52"), back(undoLast(typed), "17:52")].map((day) => rowsOf(changeLogCsv(day, LABELS)).at(-1))
    expect(lines).toEqual(["2026-10-27 17:52,記下回到,8,返程 16:05,,17:52,,否", "2026-10-27 17:52,記下回到,8,返程 16:00,,17:52,,否"])
  })

  it("記下時刻寫台北的日期與時刻：台北 10-28 00:15 記下的寫 2026-10-28 00:15", () => {
    const day = recordArrival(scenarioDay(), { vehicle: 8, end: 福安居, time: at("24:10"), at: "2026-10-27T16:15:00.000Z" })
    expect(rowsOf(changeLogCsv(day, LABELS))[0].split(",").slice(0, 1)).toEqual(["2026-10-28 00:15"])
  })

  it("規格的原因帶逗號：塞車,事故 寫成 \"塞車,事故\"", () => {
    expect(rowsOf(changeLogCsv(back(scenarioDay(), "17:52", "塞車,事故"), LABELS))[0]).toBe('2026-10-27 17:52,記下回到,8,返程 16:00,,17:52,"塞車,事故",否')
  })

  it("原因帶雙引號或換行：整格包起來，雙引號寫兩次", () => {
    const reasons = ['說 "塞車"', "塞車\n事故"].map((reason) => rowsOf(changeLogCsv(back(scenarioDay(), "17:52", reason), LABELS)).join("\r\n").split(",")[6])
    expect(reasons).toEqual(['"說 ""塞車"""', '"塞車\n事故"'])
  })

  it("每一列用 CRLF 結尾，最後一列也是", () => {
    const text = changeLogCsv(give(back(scenarioDay(), "17:52"), "8-2", 10, "17:53"), LABELS)
    expect([text.split("\r\n").length, text.replaceAll("\r\n", "").includes("\n"), text.endsWith("\r\n")]).toEqual([4, false, true])
  })

  it("沒有修改時只有 BOM 與表頭", () => {
    expect(changeLogCsv(scenarioDay(), LABELS)).toBe(`${BOM}${CHANGES_HEADER}`)
  })
})

describe("sheetsCsv：最後的單一趟一列", () => {
  it("規格的換過車的那一趟：17:40 那班換給 10 號車，10 號車那一列寫 17:40、原排 8；一趟一列，照車號與單子上的順序", () => {
    const day = give(scenarioDay(), "8-2", 10, "17:38")
    expect(sheetsCsv(day, currentDay(day), LABELS)).toBe(`${BOM}${SHEETS_HEADER}${[
      "8,返程,台電大樓,16:00,17:14,否,8,否,16:00",
      "8,去程,福安居,18:00,18:57,否,10,否,18:00",
      "8,返程,台電大樓,19:40,20:43,否,10,否,19:40",
      "10,返程,台電大樓,16:20,17:34,否,10,否,16:20",
      "10,去程,福安居,17:40,18:45,否,8,否,17:40",
      "10,返程,台電大樓,19:20,20:23,否,8,否,19:20",
    ].join("\r\n")}\r\n`)
  })

  it("記下的到達與改過的發車寫是，原本的發車寫計畫的", () => {
    const day = retime(back(scenarioDay(), "17:52"), "8-2", "17:55", "17:53")
    expect(rowsOf(sheetsCsv(day, currentDay(day), LABELS)).slice(0, 2)).toEqual(["8,返程,台電大樓,16:00,17:52,是,8,否,16:00", "8,去程,福安居,17:55,19:00,否,8,是,17:40"])
  })

  it("過了午夜的時刻照營運日寫：19:20 那一趟改成 23:04 發，24:07 到", () => {
    const day = retime(scenarioDay(), "8-3", "23:04", "17:53")
    expect(rowsOf(sheetsCsv(day, currentDay(day), LABELS))[2]).toBe("8,返程,台電大樓,23:04,24:07,否,8,是,19:20")
  })

  it("車照車號排，不照當天調度裡車的順序", () => {
    const day = scenarioDay()
    const current = currentDay(day)
    const reversed = { ...current, vehicles: [...current.vehicles].reverse() }
    expect(rowsOf(sheetsCsv(day, reversed, LABELS)).map((row) => row.split(",")[0])).toEqual(["8", "8", "8", "10", "10", "10"])
  })
})

describe("sheetHeader：印出來的單子標題下那一行，寫當天的日期與計畫依據", () => {
  // The words of the line and how the site writes a day and a day type.
  const WORDS = {
    sheetHeader: "%{date}當天調度的單・依 %{days} 的實測鋪排・p%{percentile}・停車端休息 %{buffer} 分",
    sheetDaysOne: "%{day} %{dayType}",
    sheetDaysRange: "%{first} 到 %{last}（%{dayType} %{count} 天）",
    dayLabel: "%{date}（%{weekday}）",
    weekdays: ["日", "一", "二", "三", "四", "五", "六"],
    dayTypes: { weekday: "平日", holiday: "假日" },
  }

  it("涵蓋四個平日：寫從哪一天到哪一天、幾天", () => {
    expect(sheetHeader(scenarioDay(), WORDS)).toBe("2026-10-27（二）當天調度的單・依 2026-10-19（一） 到 2026-10-22（四）（平日 4 天） 的實測鋪排・p85・停車端休息 15 分")
  })

  it("只涵蓋一天：寫那一天與日型別", () => {
    const day = { ...scenarioDay(), basis: { days: ["2026-10-25"], dayType: "holiday", percentile: 50, buffer: 10 } }
    expect(sheetHeader(day, WORDS)).toBe("2026-10-27（二）當天調度的單・依 2026-10-25（日） 假日 的實測鋪排・p50・停車端休息 10 分")
  })
})

describe("marksFor 與 sheetNotes：單子上時刻後面的記號，與單子下面一行一條的註記", () => {
  // The words of the marks and the notes, and how the view names a vehicle,
  // writes a time past midnight and writes no value.
  const WORDS = {
    marks: { swapped: "＊", recorded: "†", typed: "‡" },
    notes: {
      swapped: "%{mark} %{departures} 原排 %{vehicle}",
      recorded: "%{mark} %{arrival} 是記下的回到時刻，原定 %{planned}",
      typed: "%{mark} %{departure} 改過，原本 %{from}",
      separator: "、",
    },
    vehicle: "%{number} 號車",
    nextDay: "隔日 %{time}",
    none: "—",
  }

  // The spec's example "Grouped notes": vehicle 8 leaves 台電大樓 at 16:00
  // and is planned back at 福安居 at 17:14, then leaves at 17:40, 19:20,
  // 21:00 and 22:45; vehicle 10 leaves 福安居 at 18:00, then 19:40, 21:20
  // and 23:00. The 17:40 is given to vehicle 10, vehicle 8 is recorded back
  // at 17:52, and its 18:00 from vehicle 10 is typed as 18:10.
  function groupedDay() {
    const legs = (first, ...texts) => texts.map((leg, i) => trip((first + i) % 2, leg))
    const day = startDay([
      { number: 8, trips: legs(1, "16:00-17:14", "17:40-18:45", "19:20-20:23", "21:00-21:46", "22:45-23:40") },
      { number: 10, trips: legs(1, "16:20-17:34", "18:00-18:57", "19:40-20:43", "21:20-22:06", "23:00-24:07") },
    ], { ...scenarioDay(), routeId: 11764, date: "2026-10-27", startedAt: "2026-10-26T21:30:00.000Z", runTimes: runTimesTable({ 0: 57, 1: 63 }) })
    return retime(back(give(day, "8-2", 10, "17:38"), "17:52", "塞車", "17:52"), "10-2", "18:10", "17:55")
  }

  const vehicleOf = (day, number) => currentDay(day).vehicles.find((vehicle) => vehicle.number === number)

  it("規格的註記合成一條：8 號車的發車格是 18:10＊‡、19:40＊、21:20＊、23:00＊，到達格 17:52†", () => {
    const vehicle = vehicleOf(groupedDay(), 8)
    const { departureMark, arrivalMark } = marksFor(vehicle, WORDS)
    expect([vehicle.trips.map((t) => clock(t.departure) + departureMark(t)), vehicle.trips.map((t) => arrivalMark(t))])
      .toEqual([["16:00", "18:10＊‡", "19:40＊", "21:20＊", "23:00＊"], ["†", "", "", "", ""]])
  })

  it("規格的註記合成一條：先＊、再†、再‡，原排 10 號車的四班合成一條", () => {
    const day = groupedDay()
    expect(sheetNotes(day, vehicleOf(day, 8), WORDS)).toEqual(["＊ 18:10、19:40、21:20、23:00 原排 10 號車", "† 17:52 是記下的回到時刻，原定 17:14", "‡ 18:10 改過，原本 18:00"])
  })

  it("沒有記號的單沒有註記", () => {
    const day = scenarioDay()
    expect(sheetNotes(day, vehicleOf(day, 8), WORDS)).toEqual([])
  })

  it("原排兩台不同的車：照第一班的發車時刻各一條", () => {
    const vehicle = { number: 8, trips: [[at("16:00"), 8], [at("18:00"), 10], [at("19:40"), 10], [at("21:20"), 3]].map(([departure, plannedVehicle]) => ({ departure, plannedVehicle, recorded: false, typed: false })) }
    expect(sheetNotes(scenarioDay(), vehicle, WORDS)).toEqual(["＊ 18:00、19:40 原排 10 號車", "＊ 21:20 原排 3 號車"])
  })

  it("改了兩次的發車，原本寫計畫的：17:40 改成 17:50 再改成 17:55", () => {
    const day = retime(retime(scenarioDay(), "8-2", "17:50", "17:30"), "8-2", "17:55", "17:31")
    expect(sheetNotes(day, vehicleOf(day, 8), WORDS)).toEqual(["‡ 17:55 改過，原本 17:40"])
  })

  // day.js has no planned arrival for a recorded trip whose departure was
  // then typed into an hour without a run time.
  it("記下的那一趟算不出原定到達時，原定寫—", () => {
    const vehicle = { number: 8, trips: [{ departure: at("16:00"), arrival: at("17:52"), plannedArrival: null, plannedVehicle: 8, recorded: true, typed: false }] }
    expect(sheetNotes(scenarioDay(), vehicle, WORDS)).toEqual(["† 17:52 是記下的回到時刻，原定 —"])
  })
})
