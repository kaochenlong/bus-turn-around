import { describe, expect, it } from "vitest"

import { changesOn, stopsAtText } from "./day_timeline_view.js"
import { at } from "./support.js"

describe("changesOn：一台車從哪一班起開別台車的班", () => {
  // A vehicle's trips as [departure, planned vehicle].
  const vehicle = (number, ...trips) => ({ number, trips: trips.map(([time, plannedVehicle]) => ({ departure: at(time), plannedVehicle })) })

  it("沒換過車的車沒有", () => {
    expect(changesOn(vehicle(1, ["06:00", 1], ["07:20", 1]))).toEqual([])
  })

  it("規格的例子：8 號車 18:00 起開 10 號車的班，後面幾班也是 10 號車的，只記 18:00 那一次", () => {
    expect(changesOn(vehicle(8, ["16:00", 8], ["18:00", 10], ["19:40", 10], ["21:20", 10]))).toEqual([{ departure: at("18:00"), from: 10 }])
  })

  it("換了兩次：18:00 起開 10 號車的、21:20 起開 3 號車的", () => {
    expect(changesOn(vehicle(8, ["16:00", 8], ["18:00", 10], ["19:40", 10], ["21:20", 3]))).toEqual([{ departure: at("18:00"), from: 10 }, { departure: at("21:20"), from: 3 }])
  })

  it("中間又開回自己的班：18:00 與 21:20 各記一次", () => {
    expect(changesOn(vehicle(8, ["16:00", 8], ["18:00", 10], ["19:40", 8], ["21:20", 10]))).toEqual([{ departure: at("18:00"), from: 10 }, { departure: at("21:20"), from: 10 }])
  })
})

describe("stopsAtText：空檔裡的數字是在哪一端停的", () => {
  const words = { stopsAt: "在%{stop}停", bothEnds: "兩端" }
  const endName = (end) => ["甲站", "乙站"][end]

  it("方向 1 的趟次回到停車端：停在甲站，方向 0 發車的那一端", () => {
    expect(stopsAtText([1], words, endName)).toBe("在甲站停")
  })

  it("方向 0 的趟次回到停車端：停在乙站", () => {
    expect(stopsAtText([0], words, endName)).toBe("在乙站停")
  })

  it("兩個方向都回到停車端：兩端", () => {
    expect(stopsAtText([0, 1], words, endName)).toBe("在兩端停")
  })

  it("兩端都不停車：沒有這一句", () => {
    expect(stopsAtText([], words, endName)).toBeNull()
  })
})
