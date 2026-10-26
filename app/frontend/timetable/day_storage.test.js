import { describe, expect, it } from "vitest"

import { dayKey, discardDay, loadDay, saveDay } from "./day_storage.js"

// A storage like the browser's local storage, keeping strings by key; it can
// refuse reads or writes, as a private window, blocked storage or a full
// quota does.
function fakeStorage({ refuseReads = false, refuseWrites = false } = {}) {
  const items = new Map()
  return {
    getItem(key) {
      if (refuseReads) throw new Error("SecurityError")
      return items.has(key) ? items.get(key) : null
    },
    setItem(key, value) {
      if (refuseWrites) throw new Error("QuotaExceededError")
      items.set(key, String(value))
    },
    removeItem(key) {
      if (refuseWrites) throw new Error("SecurityError")
      items.delete(key)
    },
  }
}

// A kept day of route 9001 on 2026-10-27, cut down to what the storage reads.
const DAY = { version: 1, routeId: 9001, date: "2026-10-27", plan: [{ vehicle: 1, trips: [] }], changes: [] }

// A storage with the day already kept, and the text kept under its key.
function keeping(text) {
  const storage = fakeStorage()
  storage.setItem("turnaround.day-dispatch.v1.9001.2026-10-27", text)
  return storage
}

describe("dayKey", () => {
  it("鍵是 turnaround.day-dispatch.v1.<路線 Id>.<YYYY-MM-DD>", () => {
    expect(dayKey(9001, "2026-10-27")).toBe("turnaround.day-dispatch.v1.9001.2026-10-27")
  })
})

describe("saveDay 與 loadDay：存進去、讀回來", () => {
  it("存了讀得回同一個當天調度", () => {
    const storage = fakeStorage()
    expect([saveDay(storage, DAY), loadDay(storage, 9001, "2026-10-27")]).toEqual([true, { day: DAY }])
  })

  it("存在路線與日期的鍵底下：同一條路線的前一天、別條路線的同一天都讀成沒有", () => {
    const storage = fakeStorage()
    saveDay(storage, DAY)
    expect([loadDay(storage, 9001, "2026-10-26"), loadDay(storage, 307, "2026-10-27")]).toEqual([null, null])
  })

  it("setItem 丟例外時回傳 false", () => {
    expect(saveDay(fakeStorage({ refuseWrites: true }), DAY)).toBe(false)
  })

  it.each([
    ["不是 JSON", "{"],
    ["格式版本 2", JSON.stringify({ ...DAY, version: 2 })],
    ["不是當天調度", "42"],
  ])("存著的%s：讀成讀不出來", (_, text) => {
    expect(loadDay(keeping(text), 9001, "2026-10-27")).toEqual({ unreadable: true })
  })

  it("存著的修改套不上（不是在這一頁改的）：讀成讀不出來", () => {
    const altered = { ...DAY, changes: [{ kind: "vehicle", tripId: "1-1", vehicle: 9, at: "2026-10-27T09:52:00.000Z", undone: false }] }
    expect(loadDay(keeping(JSON.stringify(altered)), 9001, "2026-10-27")).toEqual({ unreadable: true })
  })

  it("沒有存的讀成 null", () => {
    expect(loadDay(fakeStorage(), 9001, "2026-10-27")).toBeNull()
  })

  it("getItem 丟例外時讀成 null", () => {
    expect(loadDay(fakeStorage({ refuseReads: true }), 9001, "2026-10-27")).toBeNull()
  })
})

describe("discardDay：丟掉存著的那一天", () => {
  it("丟掉之後讀成 null，回傳 true", () => {
    const storage = keeping(JSON.stringify(DAY))
    expect([discardDay(storage, 9001, "2026-10-27"), loadDay(storage, 9001, "2026-10-27")]).toEqual([true, null])
  })

  it("removeItem 丟例外時回傳 false", () => {
    expect(discardDay(fakeStorage({ refuseWrites: true }), 9001, "2026-10-27")).toBe(false)
  })
})

describe("瀏覽器不給 storage（null）", () => {
  it("存不了、讀成沒有、丟不掉", () => {
    expect([saveDay(null, DAY), loadDay(null, 9001, "2026-10-27"), discardDay(null, 9001, "2026-10-27")]).toEqual([false, null, false])
  })
})
