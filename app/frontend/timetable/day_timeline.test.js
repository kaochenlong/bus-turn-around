import { describe, expect, it } from "vitest"

import { fitsLabel, laneAt, minuteAt, positionOf, timelineRange } from "./day_timeline.js"
import { at } from "./support.js"

// The day's vehicles as they stand, each with its trips from "HH:MM-HH:MM"
// legs; recorded legs carry the recorded arrival, as the day has them.
function vehicles(...sheets) {
  return sheets.map((legs, i) => ({
    number: i + 1,
    trips: legs.map((leg) => {
      const [departure, arrival] = leg.split("-").map(at)
      return { departure, arrival }
    }),
  }))
}

const DAY = { start: at("06:00"), end: at("25:00") }

describe("timelineRange：最早發車那一小時到最晚到達的下一個整點", () => {
  it("規格的一天：05:00 發、最晚 24:56 到，時間軸從 05:00 到 25:00", () => {
    expect(timelineRange(vehicles(["05:00-05:57", "06:20-07:22"], ["21:40-22:45", "23:50-24:56"]))).toEqual({ start: at("05:00"), end: at("25:00") })
  })

  it("251區 的一天：06:00 發、最晚 24:07 到，時間軸從 06:00 到 25:00", () => {
    expect(timelineRange(vehicles(["06:00-06:59", "07:20-08:36"], ["23:00-24:07"]))).toEqual({ start: at("06:00"), end: at("25:00") })
  })

  it("最早發車不在整點：06:12 發，從 06:00 畫起", () => {
    expect(timelineRange(vehicles(["06:12-07:11", "07:40-08:56"])).start).toBe(at("06:00"))
  })

  it("最晚到達 23:40，畫到 24:00", () => {
    expect(timelineRange(vehicles(["21:40-22:35", "22:45-23:40"])).end).toBe(at("24:00"))
  })

  it("記下的晚回比最晚的計畫到達還晚：計畫 23:40 到、記下 24:10 回到，畫到 25:00", () => {
    expect(timelineRange(vehicles(["21:40-22:35", "22:45-24:10"])).end).toBe(at("25:00"))
  })

  it("最晚到達剛好在整點，畫到下一個整點：24:00 到，畫到 25:00", () => {
    expect(timelineRange(vehicles(["22:50-24:00"])).end).toBe(at("25:00"))
  })

  it("班都給出去的車不影響範圍", () => {
    expect(timelineRange(vehicles([], ["07:20-08:23", "09:00-10:02"]))).toEqual({ start: at("07:00"), end: at("11:00") })
  })

  it("一趟都沒有時丟錯", () => {
    expect(() => timelineRange(vehicles([], []))).toThrow(/at least one trip/)
  })
})

describe("positionOf：時刻在時間軸上的百分比", () => {
  it.each([
    ["06:00", 0],
    ["25:00", 100],
    ["15:30", 50],
    ["17:55", 62.719298],
  ])("06:00 到 25:00 的時間軸上，%s 在 %d%%", (time, expected) => {
    expect(positionOf(at(time), DAY)).toBeCloseTo(expected, 5)
  })

  it.each([
    ["05:00", 0],
    ["26:00", 100],
  ])("範圍外停在邊上：%s 在 %d%%", (time, expected) => {
    expect(positionOf(at(time), DAY)).toBe(expected)
  })
})

describe("minuteAt：指到的比例換成整分鐘", () => {
  it.each([
    [0, "06:00"],
    [1, "25:00"],
    [0.5, "15:30"],
    [0.0005, "06:01"],
    [0.0004, "06:00"],
  ])("06:00 到 25:00 的時間軸上，比例 %s 是 %s", (fraction, time) => {
    expect(minuteAt(fraction, DAY)).toBe(at(time))
  })

  it.each([
    [-0.2, "06:00"],
    [1.3, "25:00"],
  ])("比例在範圍外時停在邊上：%s 是 %s", (fraction, time) => {
    expect(minuteAt(fraction, DAY)).toBe(at(time))
  })
})

describe("fitsLabel：一段寬不寬得下它的字", () => {
  it.each([
    [61, 26, true],
    [60, 26, false],
    [31, 13, true],
    [30, 13, false],
  ])("06:00 到 25:00 的時間軸畫成 492px 寬：%i 分鐘的段要 %ipx 的字，寫得下是 %s", (minutes, needed, expected) => {
    expect(fitsLabel(minutes, DAY, 492, needed)).toBe(expected)
  })

  it("剛好一樣寬就寫得下：06:00 到 07:00 畫成 120px，13 分鐘是 26px", () => {
    expect(fitsLabel(13, { start: at("06:00"), end: at("07:00") }, 120, 26)).toBe(true)
  })
})

describe("laneAt：放開時落在哪一條", () => {
  const lanes = [{ number: 1, top: 100, bottom: 148 }, { number: 2, top: 148, bottom: 196 }, { number: 3, top: 196, bottom: 244 }]

  it("落在一條的中間：y 120 是 1 號車那一條", () => {
    expect(laneAt(lanes, 120)).toBe(lanes[0])
  })

  it("兩條的交界算下面那一條：y 148 是 2 號車那一條", () => {
    expect(laneAt(lanes, 148)).toBe(lanes[1])
  })

  it("最後一條的底邊不算：y 244 落在條外，是 null", () => {
    expect(laneAt(lanes, 244)).toBeNull()
  })

  it("第一條上面：y 99 是 null", () => {
    expect(laneAt(lanes, 99)).toBeNull()
  })
})
