import { describe, expect, it } from "vitest"

import { minimumCredit } from "./rest_windows.js"
import { at } from "./support.js"

// A sheet's trips from "HH:MM-HH:MM" legs, in sheet order.
function sheet(...legs) {
  return legs.map((leg) => {
    const [departure, arrival] = leg.split("-").map(at)
    return { departure, arrival }
  })
}

describe("minimumCredit：連續四小時裡最少休幾分鐘", () => {
  it("規格的四趟單：06:00–06:50、07:30–08:15、08:30–09:20、09:35–10:20 休 70 分鐘（40、15、15）", () => {
    expect(minimumCredit(sheet("06:00-06:50", "07:30-08:15", "08:30-09:20", "09:35-10:20"))).toBe(70)
  })

  it("不到 15 分鐘的停留不算：06:00–06:50、07:30–08:15、08:25–09:15、09:25–10:10 休 40 分鐘", () => {
    expect(minimumCredit(sheet("06:00-06:50", "07:30-08:15", "08:25-09:15", "09:25-10:10"))).toBe(40)
  })

  it("整張單不到四小時時是 null：06:00–06:50 與 07:30–08:15", () => {
    expect(minimumCredit(sheet("06:00-06:50", "07:30-08:15"))).toBeNull()
  })

  it("視窗從每一趟起算，取最小的：第一趟起算 70、第二趟 30、第三趟 15，整張單報 15", () => {
    expect(minimumCredit(sheet("06:00-06:50", "07:30-08:15", "08:30-09:20", "09:35-10:20", "10:30-11:20", "11:30-12:30"))).toBe(15)
  })

  it("剛好 240 分鐘就成一個視窗：06:00 發、10:00 到", () => {
    expect(minimumCredit(sheet("06:00-07:50", "08:10-10:00"))).toBe(20)
  })

  it("接不上的負停留不算休息", () => {
    expect(minimumCredit(sheet("06:00-06:50", "06:45-07:40", "08:00-08:50", "09:10-10:05"))).toBe(40)
  })

  it("沒有趟次是 null", () => {
    expect(minimumCredit([])).toBeNull()
  })
})
