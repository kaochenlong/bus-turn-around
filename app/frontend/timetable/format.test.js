import { describe, expect, it } from "vitest"

import { clock, fieldClock, parseClock, stopText } from "./format.js"

describe("parseClock：營運日的 HH:MM，時 00 到 29、分 00 到 59", () => {
  // The spec's example "Typed times", plus the shapes the page can receive.
  it.each([
    ["06:00", 360],
    ["24:45", 1485],
    ["25:70", null],
    ["6:00", null],
    ["30:00", null],
    ["", null],
    ["ab:cd", null],
    ["0600", null],
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
