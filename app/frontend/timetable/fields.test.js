import { describe, expect, it } from "vitest"

import { wholeInRange } from "./fields.js"

// A field as far as wholeInRange reads and writes it.
const field = (value) => ({ value })

describe("wholeInRange：數字欄位的整數值在範圍內才用，不然退回並寫回欄位", () => {
  it("範圍內的整數照用，欄位不動：0 到 20 打 10 就是 10", () => {
    const input = field("10")
    expect([wholeInRange(input, [0, 20], 15), input.value]).toEqual([10, "10"])
  })

  it("範圍的兩端都收：0 與 20", () => {
    expect([wholeInRange(field("0"), [0, 20], 15), wholeInRange(field("20"), [0, 20], 15)]).toEqual([0, 20])
  })

  it.each([["99"], ["-1"], [""], ["  "], ["7.5"], ["abc"]])("打 %j 就退回 15，欄位也寫回 15", (typed) => {
    const input = field(typed)
    expect([wholeInRange(input, [0, 20], 15), input.value]).toEqual([15, 15])
  })
})
