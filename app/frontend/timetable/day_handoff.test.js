import { beforeEach, describe, expect, it } from "vitest"

import { handOver, release, takeOver } from "./day_handoff.js"

// Days of route 9001 and 307 as startDay makes them, cut down to what the
// handover looks at.
const day = (routeId, date = "2026-10-27") => ({ version: 1, routeId, date, plan: [], changes: [] })

describe("day_handoff：存不進這台電腦的那一天，在同一個分頁裡交給當天調度頁", () => {
  beforeEach(() => {
    release(9001)
    release(307)
  })

  it("交了取得到同一天", () => {
    const started = day(9001)
    handOver(started)
    expect(takeOver(9001)).toBe(started)
  })

  it("取了還在：回到排班再進當天調度頁，那一天也還在", () => {
    handOver(day(9001))
    takeOver(9001)
    expect(takeOver(9001)).toEqual(day(9001))
  })

  it("別條路線取不到", () => {
    handOver(day(9001))
    expect(takeOver(307)).toBeNull()
  })

  it("重新開始清掉之後取不到；清別條路線不影響它", () => {
    handOver(day(9001))
    release(307)
    const kept = takeOver(9001)
    release(9001)
    expect([kept, takeOver(9001)]).toEqual([day(9001), null])
  })

  it("再開始一天就換掉前一天", () => {
    handOver(day(9001, "2026-10-26"))
    handOver(day(9001, "2026-10-27"))
    expect(takeOver(9001).date).toBe("2026-10-27")
  })

  it("沒有交過時取不到", () => {
    expect(takeOver(9001)).toBeNull()
  })
})
