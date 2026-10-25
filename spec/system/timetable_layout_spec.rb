require "rails_helper"

# The timetable page as a phone shows it: sizes measured in the browser, since
# component specs see no CSS.
RSpec.describe "班表頁在 390 寬的手機上", :js, type: :system do
  # The spec's four-departure day, laid out into three vehicles.
  before do
    route_day = create(:route_day, day: Date.new(2026, 10, 19))
    route_day.stops.create!([ { go_back: 0, seq: 0, stop_name: "甲站" }, { go_back: 1, seq: 5, stop_name: "乙站" } ])
    [ [ "06:00", 50, 0 ], [ "06:30", 50, 0 ], [ "07:00", 45, 1 ], [ "07:30", 45, 1 ] ].each do |start, minutes, go_back|
      start_time = Time.zone.parse("2026-10-19 #{start}")
      route_day.trips.create!(bus_id: "TEST-0001", path_attribute_id: 9001, go_back:, band: "other", start_time:, end_time: start_time + minutes.minutes,
                              first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5, completeness: "complete",
                              start_from_arrival: false, end_from_departure: false)
    end
  end

  # Headless Chrome keeps its window at least 500 px wide, so the phone screen
  # is emulated. A mobile viewport's scrollbars take no width, as on a phone.
  def phone = { width: 390, height: 844, deviceScaleFactor: 1, mobile: true }

  # Opens the timetable page on a phone, waits for the sheets, and returns what
  # `script` evaluates to there. The browser is shared with the other
  # examples, so the emulation is cleared afterwards.
  def on_phone(script)
    browser = page.driver.browser
    browser.execute_cdp("Emulation.setDeviceMetricsOverride", **phone)
    visit route_timetable_path(9001)
    find("[data-sheets] [data-vehicle='3']")
    page.evaluate_script(script)
  ensure
    browser&.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  # Whether every sheet's table and the departures table of the controls sit
  # in an ancestor that scrolls sideways.
  def scroll_boxes = <<~JS
    (() => {
      const scrolls = (node) => {
        for (let parent = node.parentElement; parent; parent = parent.parentElement) {
          if (getComputedStyle(parent).overflowX === "auto") return true
        }
        return false
      }
      const tables = [...document.querySelectorAll("[data-sheets] [data-vehicle] table, [data-timetable-controls] table")]
      return { count: tables.length, every: tables.every(scrolls) }
    })()
  JS

  it "頁面本身不橫向捲動" do
    expect(on_phone("document.documentElement.scrollWidth")).to be <= 390
  end

  it "三張單的表與控制項的發車數表各自在可以橫向捲動的框裡" do
    expect(on_phone(scroll_boxes)).to eq("count" => 4, "every" => true)
  end
end
