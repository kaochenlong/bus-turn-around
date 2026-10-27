import { describe, expect, it } from "vitest"

import { clock, fieldClock, formatDay, minutesText, parseClock, stopText } from "./format.js"

describe("parseClock：營運日的時刻，冒號可打可不打，時 00 到 29、分 00 到 59", () => {
  // The spec's example "Typed times", plus the shapes the page can receive.
  // How an accepted time is shown is fieldClock's table below.
  it.each([
    ["06:00", 360],
    ["6:00", 360],
    ["0600", 360],
    ["600", 360],
    ["24:45", 1485],
    ["2445", 1485],
    ["23:70", null],
    ["25:70", null],
    ["2370", null],
    ["30:00", null],
    ["60", null],
    ["06:0", null],
    ["12345", null],
    [" 0600 ", 360],
    ["", null],
    ["ab:cd", null],
  ])("%j → %j", (text, minutes) => {
    expect(parseClock(text)).toBe(minutes)
  })
})

describe("clock：當天的 HH:MM，24 點以後用隔日的寫法", () => {
  it("410 是 06:50", () => {
    expect(clock(410)).toBe("06:50")
  })

  it("1470 是隔日 00:30，隔日的寫法由呼叫端給", () => {
    expect(clock(1470, "隔日 %{time}")).toBe("隔日 00:30")
  })
})

describe("fieldClock：輸入框裡用營運日的時刻", () => {
  it.each([
    [360, "06:00"],
    [1485, "24:45"],
  ])("%j → %j", (minutes, text) => {
    expect(fieldClock(minutes)).toBe(text)
  })
})

describe("stopText：停留的分鐘數，沒有值空白，負數用 U+2212 的減號", () => {
  it.each([
    [40, "40"],
    [0, "0"],
    [-5, "−5"],
    [null, ""],
  ])("%j → %j", (minutes, text) => {
    expect(stopText(minutes)).toBe(text)
  })
})

describe("formatDay：網站寫日期的樣子，帶星期", () => {
  const labels = { dayLabel: "%{date}（%{weekday}）", weekdays: ["日", "一", "二", "三", "四", "五", "六"] }

  it.each([
    ["2026-10-27", "2026-10-27（二）"],
    ["2026-10-25", "2026-10-25（日）"],
  ])("%s → %s", (date, text) => {
    expect(formatDay(labels, date)).toBe(text)
  })
})

describe("minutesText：四小時休息的分鐘數，單子不到四小時（null）時寫另一句", () => {
  it.each([
    [43, "43 分"],
    [0, "0 分"],
    [null, "不到 4 小時"],
  ])("%j → %s", (minutes, text) => {
    expect(minutesText(minutes, "不到 4 小時", "%{minutes} 分")).toBe(text)
  })
})
