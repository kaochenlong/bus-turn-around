import { describe, expect, it } from "vitest"

import { districtFromSearch, matches } from "./district_filter.js"

describe("districtFromSearch", () => {
  const options = ["士林區", "測試區", "新北市甲區"]

  it("網址帶的區是選項之一就回它，中文經過百分比編碼也一樣", () => {
    expect([
      districtFromSearch("?district=%E6%96%B0%E5%8C%97%E5%B8%82%E7%94%B2%E5%8D%80", options),
      districtFromSearch("?district=測試區&range=day", options),
    ]).toEqual(["新北市甲區", "測試區"])
  })

  it("不在選項裡、或沒有參數，回空字串，元件再退回伺服器選的預設", () => {
    expect([districtFromSearch("?district=天母", options), districtFromSearch("", options), districtFromSearch("?district=", options)]).toEqual(["", "", ""])
  })
})

describe("matches", () => {
  it("沒有任何選項時（空字串）每張卡都符合，包含沒有行政區的卡", () => {
    expect([matches("", ""), matches("士林區 中山區", "")]).toEqual([true, true])
  })

  it("選了一區：卡的 data-districts 含那個名稱才符合，沒有行政區的卡不符合，部分相同的名稱不算", () => {
    expect([matches("測試區 新北市甲區", "新北市甲區"), matches("士林區", "新北市甲區"), matches("", "士林區"), matches("新北市甲區", "甲區")]).toEqual([
      true,
      false,
      false,
      false,
    ])
  })
})
