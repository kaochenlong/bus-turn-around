require "rails_helper"

# Printing the timetable in the browser: the print control appears once the
# script runs and calls the browser's print; under the print styles the
# controls and the site bar are gone, the times are text and the footer stays;
# and the browser's own print-to-PDF starts every vehicle after the first on
# a new page.
RSpec.describe "班表的列印", :js, type: :system do
  # The spec's four-departure day: direction 0 at 06:00 and 06:30 running 50
  # minutes, direction 1 at 07:00 and 07:30 running 45. Laid out with 15 rest
  # minutes they take three vehicles.
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

  def open_timetable
    visit route_timetable_path(9001)
    find("[data-sheets] [data-vehicle='3']")
  end

  def browser = page.driver.browser

  # What `script` evaluates to while the browser applies the print styles.
  # The browser is shared with the other examples, so the emulation is
  # cleared afterwards.
  def under_print_styles(script)
    browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    page.evaluate_script(script)
  ensure
    browser.execute_cdp("Emulation.setEmulatedMedia", media: "")
  end

  # For the first element each selector matches: "none" when it or an ancestor
  # is not displayed, else its own computed display.
  def displays = <<~JS
    (() => {
      const selectors = { site_bar: "[data-site-bar]", header: "[data-timetable-header]", controls: "[data-timetable-controls]", notice: "[data-regeneration-notice]",
                          needs_script: "[data-needs-script]", print: "button[data-print]", add_vehicle: "[data-add-vehicle]", delete: "button[data-delete-row]",
                          add_row: "[data-add-row]", departure_input: "[data-departure] input", departure_text: "[data-departure] span",
                          sheet_header: "[data-sheet-form-header]", screen_title: "[data-vehicle] [data-slot=title]", filler: "tr[data-filler]",
                          overruns: "[data-section=overruns]", footer: "footer[data-attribution]", limitations: "[data-section=limitations]" }
      const display = (element) => {
        for (let node = element; node; node = node.parentElement) {
          if (getComputedStyle(node).display === "none") return "none"
        }
        return getComputedStyle(element).display
      }
      return Object.fromEntries(Object.entries(selectors).map(([name, selector]) => [name, display(document.querySelector(selector))]))
    })()
  JS

  # Where each sheet breaks under the print styles, in sheet order.
  def sheet_breaks = '[...document.querySelectorAll("[data-sheets] [data-vehicle]")].map((sheet) => getComputedStyle(sheet).breakAfter)'

  # What each sheet is headed by when printed.
  def sheet_headers = '[...document.querySelectorAll("[data-sheets] [data-vehicle] [data-sheet-form-header]")].map((block) => block.textContent)'

  # How many rows each sheet prints, trips and blank ones together.
  def printed_rows = '[...document.querySelectorAll("[data-sheets] [data-vehicle]")].map((sheet) => [...sheet.querySelectorAll("tbody tr")].filter((tr) => getComputedStyle(tr).display === "table-row").length)'

  # The ruled lines: the top border of the first printed cell.
  def first_cell_border = 'getComputedStyle(document.querySelector("[data-sheets] [data-vehicle] tbody td")).borderTopWidth'

  # Whether the browser's print-to-PDF has a page of that number: asking for a
  # page past the end is an error.
  def printed_page?(number)
    browser.execute_cdp("Page.printToPDF", pageRanges: number.to_s)
    true
  rescue Selenium::WebDriver::Error::WebDriverError
    false
  end

  it "列印鈕在腳本跑過後可見，按一下呼叫瀏覽器的列印一次" do
    open_timetable
    page.execute_script("window.printCalls = 0; window.print = () => { window.printCalls += 1 }")
    find("button[data-print]").click
    expect(page.evaluate_script("window.printCalls")).to eq(1)
  end

  it "列印樣式下：名稱列、頁首、控制項、提醒、需要 JavaScript 那一句、列印鈕、再加一台車、刪除鈕、加一列與時刻輸入框都不印；時刻印成文字，每張單的抬頭、超時表、資料限制與頁尾照印" do
    open_timetable
    expect(under_print_styles(displays)).to eq("site_bar" => "none", "header" => "none", "controls" => "none", "notice" => "none", "needs_script" => "none", "print" => "none",
                                                "add_vehicle" => "none", "delete" => "none", "add_row" => "none", "departure_input" => "none", "departure_text" => "inline",
                                                "sheet_header" => "block", "screen_title" => "none", "filler" => "table-row", "overruns" => "block", "footer" => "block", "limitations" => "block")
  end

  it "一車一頁：三張單各自印完就換頁；印出來至少四頁（最後一頁是超時表、資料限制與頁尾）" do
    open_timetable
    expect([ under_print_styles(sheet_breaks), [ 1, 2, 3, 4 ].map { printed_page?(it) } ]).to eq([ %w[page page page], [ true, true, true, true ] ])
  end

  it "印出來像紙本：每張單的抬頭有公司與站的空格、路線名、車次、車號與年月日星期的空格、資料依據（2026-10-19 平日、p85、休息 15 分）；每張至少 14 列、格子有框線" do
    open_timetable
    headers = under_print_styles(sheet_headers)
    expect([ headers.map { |text| %w[公司 站 測試幹線 車號 星期 2026-10-19 平日 p85 15].all? { text.include?(it) } }.uniq, headers.first.include?("車次 1"), under_print_styles(printed_rows).min,
             under_print_styles(first_cell_border) ]).to eq([ [ true ], true, 14, "1px" ])
  end

  # The width inside the page's own margins of an A4 landscape page, in CSS
  # pixels: 297 mm less 8 mm each side, at 96 dpi. The sheet's padding comes
  # out of this.
  def printable_width = 1062

  # Whether every sheet's table fits inside its sheet when the page is as wide
  # as the paper allows.
  def tables_fit = '[...document.querySelectorAll("[data-sheets] [data-vehicle]")].every((sheet) => sheet.querySelector("table").getBoundingClientRect().right <= sheet.getBoundingClientRect().right + 0.5)'

  # Runs the block with the viewport as wide as the paper's printable area.
  # The browser is shared with the other examples, so the emulation is
  # cleared afterwards.
  def as_wide_as_the_paper
    browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: printable_width, height: 900, deviceScaleFactor: 1, mobile: false)
    yield
  ensure
    browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  it "長站名也印得進一頁的寬度：表格不超出單子的右邊" do
    RouteDayStop.where(go_back: 1).update_all(stop_name: "臺北客運板橋前站(藝文)")
    as_wide_as_the_paper do
      open_timetable
      expect(under_print_styles(tables_fit)).to be(true)
    end
  end

  it "螢幕上看不到印刷用的表單抬頭與空白列：它們只為了印" do
    open_timetable
    expect([ page.has_no_css?("[data-sheet-form-header]", visible: :visible), page.has_no_css?("tr[data-filler]", visible: :visible) ]).to eq([ true, true ])
  end
end
