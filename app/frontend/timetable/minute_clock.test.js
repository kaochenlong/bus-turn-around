import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

import { startMinuteClock } from "./minute_clock.js"

// The clock the minute clock reads, set by each example; the timers are fake
// but Date is not, so a clock that read Date instead would be caught.
let current
const at = (time) => new Date(`2026-10-27T${time}+08:00`)
const now = () => current

describe("minute_clock：每到整分鐘叫一次", () => {
  beforeEach(() => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"] })
    current = at("17:30:40")
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it("17:30:40 開始，19.999 秒時還沒叫", () => {
    const onMinute = vi.fn()
    startMinuteClock({ now, onMinute })
    vi.advanceTimersByTime(19_999)
    expect(onMinute).not.toHaveBeenCalled()
  })

  it("17:30:40 開始，20 秒後的整分鐘叫第一次", () => {
    const onMinute = vi.fn()
    startMinuteClock({ now, onMinute })
    vi.advanceTimersByTime(20_000)
    expect(onMinute).toHaveBeenCalledTimes(1)
  })

  it("之後每 60 秒叫一次", () => {
    const onMinute = vi.fn(() => { current = new Date(current.getTime() + 60_000) })
    current = at("17:31:00")
    startMinuteClock({ now, onMinute })
    vi.advanceTimersByTime(180_000)
    expect(onMinute).toHaveBeenCalledTimes(3)
  })

  it("stop() 之後不再叫", () => {
    const onMinute = vi.fn()
    const stop = startMinuteClock({ now, onMinute })
    stop()
    vi.advanceTimersByTime(300_000)
    expect(onMinute).not.toHaveBeenCalled()
  })

  it("每次都照 now() 重算：17:31:00.250 叫完，下一次在 59.75 秒後", () => {
    const onMinute = vi.fn(() => { current = at("17:31:00.250") })
    startMinuteClock({ now, onMinute })
    vi.advanceTimersByTime(20_000 + 59_749)
    expect(onMinute).toHaveBeenCalledTimes(1)
  })

  it("每次都照 now() 重算：再過 0.001 秒叫第二次", () => {
    const onMinute = vi.fn(() => { current = at("17:31:00.250") })
    startMinuteClock({ now, onMinute })
    vi.advanceTimersByTime(20_000 + 59_750)
    expect(onMinute).toHaveBeenCalledTimes(2)
  })
})
