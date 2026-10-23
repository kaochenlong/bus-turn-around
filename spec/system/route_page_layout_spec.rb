require "rails_helper"
require_relative "../support/duckdb"

# The route page of the fixture day as a phone shows it: sizes measured in the
# browser, since component specs see no CSS.
RSpec.describe "路線頁在 390 寬的手機上", :duckdb, :js, type: :system do
  # Headless Chrome keeps its window at least 500 px wide, so the phone screen
  # is emulated. A mobile viewport's scrollbars take no width, as on a phone.
  def phone = { width: 390, height: 844, deviceScaleFactor: 1, mobile: true }

  # Opens the route page of the fixture day on a phone and returns what
  # `script` evaluates to there. The browser is shared with the other
  # examples, so the emulation is cleared afterwards.
  def on_phone(script)
    browser = page.driver.browser
    browser.execute_cdp("Emulation.setDeviceMetricsOverride", **phone)
    visit route_path(9001, day: "2026-10-19")
    page.evaluate_script(script)
  ensure
    browser&.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  # The size the first bin label of the layover chart is shown at: its font
  # size in user units, scaled by the drawn width over the viewBox width.
  def label_size = <<~JS
    (() => {
      const svg = document.querySelector("[data-section=layover-chart] svg")
      const fontSize = parseFloat(getComputedStyle(svg.querySelector("text")).fontSize)
      return fontSize * svg.getBoundingClientRect().width / svg.viewBox.baseVal.width
    })()
  JS

  # For each kind of wide table or chart, whether every one of them on the
  # page has an ancestor that scrolls sideways.
  def scroll_boxes = <<~JS
    (() => {
      const scrolls = (node) => {
        for (let parent = node.parentElement; parent; parent = parent.parentElement) {
          if (getComputedStyle(parent).overflowX === "auto") return true
        }
        return false
      }
      const wide = { layovers: "[data-section=layovers] table", load_profile: "[data-section=load-profile] table",
                     load_chart: "[data-section=load-chart] svg" }
      return Object.fromEntries(Object.entries(wide).map(([name, selector]) => {
        const nodes = [...document.querySelectorAll(selector)]
        return [name, nodes.length > 0 && nodes.every(scrolls)]
      }))
    })()
  JS

  def range_link_heights = '[...document.querySelectorAll("nav[data-range] a")].map((link) => link.getBoundingClientRect().height)'

  before do
    RouteDayLoader.new(route_id: 9001, day: Date.new(2026, 10, 19), data_root: DuckdbHelpers::FIXTURE_DATA, duckdb: "duckdb").call
  end

  it "頁面本身不橫向捲動" do
    expect(on_phone("document.documentElement.scrollWidth")).to be <= 390
  end

  it "內文是 17px" do
    expect(on_phone('getComputedStyle(document.querySelector("main")).fontSize')).to eq("17px")
  end

  it "分佈圖的組別標籤實際顯示不小於 14px" do
    expect(on_phone(label_size)).to be >= 14
  end

  it "折返停留表、載客剖面表與沿線人數圖各自在可以橫向捲動的框裡" do
    expect(on_phone(scroll_boxes)).to eq("layovers" => true, "load_profile" => true, "load_chart" => true)
  end

  it "範圍切換的每個連結高度不小於 44px" do
    expect(on_phone(range_link_heights)).to contain_exactly(be >= 44, be >= 44)
  end
end
