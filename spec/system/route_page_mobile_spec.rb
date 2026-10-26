require "rails_helper"
require_relative "../support/duckdb"

# The route page of the fixture day on a 390×844 phone and on the 1400×1400
# window the system specs use: what is displayed is decided by CSS and by
# Alpine, which component and request specs do not run, so it is measured in
# the browser.
RSpec.describe "路線頁的手機版", :duckdb, :js, type: :system do
  # Headless Chrome keeps its window at least 500 px wide, so the phone screen
  # is emulated. A mobile viewport's scrollbars take no width, as on a phone.
  def phone = { width: 390, height: 844, deviceScaleFactor: 1, mobile: true }

  # Opens the route page of the fixture day on a phone and returns what the
  # block returns. The browser is shared with the other examples, so the
  # emulation is cleared afterwards.
  def on_phone
    browser = page.driver.browser
    browser.execute_cdp("Emulation.setDeviceMetricsOverride", **phone)
    visit route_path(9001, day: "2026-10-19")
    yield
  ensure
    browser&.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  def on_wide_screen
    visit route_path(9001, day: "2026-10-19")
    yield
  end

  # The computed display of every element the selector matches.
  def displays(selector) = page.evaluate_script("[...document.querySelectorAll(#{selector.to_json})].map((node) => getComputedStyle(node).display)")

  # Whether each direction of a block is displayed, by direction.
  def directions_shown(section) = page.evaluate_script(<<~JS)
    Object.fromEntries([...document.querySelectorAll("[data-section=#{section}] [data-direction]")]
      .map((node) => [node.dataset.direction, node.getClientRects().length > 0]))
  JS

  # Whether each table of the round trip and cycle block is displayed, by measure.
  def measures_shown = page.evaluate_script(<<~JS)
    Object.fromEntries([...document.querySelectorAll("[data-section=cycles] [data-measure]")]
      .map((node) => [node.dataset.measure, node.getClientRects().length > 0]))
  JS

  # Alpine has started once the time band picker, cloaked until then, shows.
  def wait_for_alpine = find("[data-section=load-chart] [data-band-switch]")

  # The per-stop load rows displayed: direction, band, sequence and median.
  def shown_load_rows = page.evaluate_script(<<~JS)
    [...document.querySelectorAll("[data-section=load-chart] [data-row-seq]")].filter((row) => row.getClientRects().length > 0)
      .map((row) => [row.closest("[data-direction]").dataset.direction, row.closest("[data-row-band]").dataset.rowBand,
                     row.dataset.rowSeq, row.dataset.rowMedian ?? null])
  JS

  # On a phone, the per-stop load rows displayed once Alpine has started and
  # again after pressing the load chart's `button` (a band switch or a
  # direction switch button).
  def load_rows_around(button)
    on_phone do
      target = find("[data-section=load-chart] #{button}")
      before = shown_load_rows
      target.click
      [ before, shown_load_rows ]
    end
  end

  # On a phone, follows the section link to the run times and returns where
  # the section links and the run time card's title then are on screen.
  def jump_to_run_times
    on_phone do
      find("nav[data-section-nav] a[href='#runtimes']").click
      # Turbo scrolls to a same-page anchor a moment after the click, when it adds the fragment to the address.
      page.assert_current_path(/#runtimes\z/, url: true)
      page.evaluate_script('[document.querySelector("nav[data-section-nav]"), document.querySelector("#runtimes h2")].map((node) => node.getBoundingClientRect())')
    end
  end

  # On a phone, which run time directions are shown before and after
  # switching to inbound, each with the page address. The switch is cloaked
  # until Alpine starts, so finding it waits for Alpine.
  def switch_run_times_to_inbound
    on_phone do
      inbound = find("[data-section=run-times] [data-direction-switch] button[value='1']")
      before = [ directions_shown("run-times"), page.current_url ]
      inbound.click
      find("[data-section=run-times] [data-direction='1'] table")
      [ *before, directions_shown("run-times"), page.current_url ]
    end
  end

  # On a phone, which stop speed leg rows of each direction are displayed
  # before and after switching the stop speed block to inbound, with the
  # number of grids displayed and the page address.
  def switch_stop_speeds_to_inbound
    on_phone do
      inbound = find("[data-section=stop-speeds] [data-direction-switch] button[value='1']")
      before = [ leg_rows_shown, page.current_url ]
      inbound.click
      find("[data-section=stop-speeds] [data-direction='1'] [data-leg-row][data-seq='5']")
      [ *before, leg_rows_shown, displayed_count("[data-section=stop-speeds] figure svg"), page.current_url ]
    end
  end

  # The number of displayed stop speed leg rows per direction.
  def leg_rows_shown = page.evaluate_script(<<~JS)
    Object.fromEntries([...document.querySelectorAll("[data-section=stop-speeds] [data-direction]")]
      .map((node) => [node.dataset.direction, [...node.querySelectorAll("[data-leg-row]")].filter((row) => row.getClientRects().length > 0).length]))
  JS

  def displayed_count(selector) = page.evaluate_script("[...document.querySelectorAll(#{selector.to_json})].filter((node) => node.getClientRects().length > 0).length")

  # On a phone, which tables of the round trip and cycle block are shown
  # before and after switching to cycles, each with the page address.
  def switch_to_cycles
    on_phone do
      cycle = find("[data-section=cycles] [data-measure-switch] button[value=cycle]")
      before = [ measures_shown, page.current_url ]
      cycle.click
      find("[data-section=cycles] [data-measure=cycle] table")
      [ *before, measures_shown, page.current_url ]
    end
  end

  before do
    RouteDayLoader.new(route_id: 9001, day: Date.new(2026, 10, 19), data_root: DuckdbHelpers::FIXTURE_DATA, duckdb: "duckdb").call
  end

  it "折返停留表在手機上每一列是一張卡，640px 以上仍是表格的列" do
    layover_rows = "[data-section=layovers] tr[data-direction]"
    expect([ on_phone { displays(layover_rows) }, on_wide_screen { displays(layover_rows) } ]).to eq([ %w[grid grid], %w[table-row table-row] ])
  end

  it "手機上行駛時間預設只顯示去程，按返程之後只顯示返程，網址不變" do
    outbound_first, url_before, after_switch, url_after = switch_run_times_to_inbound
    expect([ outbound_first, after_switch, url_after ]).to eq([ { "0" => true, "1" => false }, { "0" => false, "1" => true }, url_before ])
  end

  it "1400 寬時行駛時間兩個方向都顯示，沒有方向切換" do
    shown = on_wide_screen do
      wait_for_alpine
      [ directions_shown("run-times"), displays("[data-section=run-times] [data-direction-switch]") ]
    end
    expect(shown).to eq([ { "0" => true, "1" => true }, [ "none" ] ])
  end

  it "手機上站間車速預設只顯示去程的每段一列，按返程之後只顯示返程的，看不到格子圖，網址不變" do
    outbound_first, url_before, after_switch, grids, url_after = switch_stop_speeds_to_inbound
    expect([ outbound_first, after_switch, grids, url_after ]).to eq([ { "0" => 4, "1" => 0 }, { "0" => 0, "1" => 4 }, 0, url_before ])
  end

  it "1400 寬時站間車速兩個方向的格子圖都顯示，沒有每段一列，也沒有方向切換" do
    shown = on_wide_screen do
      wait_for_alpine
      [ "figure svg", "[data-leg-row]", "[data-direction-switch]" ].map { displayed_count("[data-section=stop-speeds] #{it}") }
    end
    expect(shown).to eq([ 2, 0, 0 ])
  end

  it "手機上來回與週期預設只顯示來回一趟，按週期之後只顯示週期，網址不變" do
    round_trip_first, url_before, after_switch, url_after = switch_to_cycles
    expect([ round_trip_first, after_switch, url_after ]).to eq([ { "round_trip" => true, "cycle" => false }, { "round_trip" => false, "cycle" => true }, url_before ])
  end

  it "1400 寬時來回與週期兩張表都顯示，沒有切換" do
    shown = on_wide_screen do
      wait_for_alpine
      [ measures_shown, displays("[data-section=cycles] [data-measure-switch]") ]
    end
    expect(shown).to eq([ { "round_trip" => true, "cycle" => true }, [ "none" ] ])
  end

  # The rows carry x-show, whose inline display Alpine sets and clears;
  # sm:hidden still has to hide them once Alpine has run.
  it "1400 寬時沿線人數顯示 SVG 的圖，不顯示每站一列" do
    shown = on_wide_screen do
      wait_for_alpine
      [ displays("[data-section=load-chart] figure").uniq, shown_load_rows ]
    end
    expect(shown).to eq([ [ "block" ], [] ])
  end

  it "手機上沿線人數不顯示 SVG 的圖，改顯示去程早尖峰的每站一列" do
    shown = on_phone { wait_for_alpine && [ displays("[data-section=load-chart] figure").uniq, shown_load_rows.map { it.first(2) }.uniq ] }
    expect(shown).to eq([ [ "none" ], [ %w[0 morning_peak] ] ])
  end

  it "手機上切到日間，顯示的每站一列換成日間的，有站的數字跟著換" do
    morning, daytime = load_rows_around("[data-band-switch] button[value=daytime]")
    expect([ daytime.map { it.first(2) }.uniq, morning.map { it.values_at(2, 3) } == daytime.map { it.values_at(2, 3) } ]).to eq([ [ %w[0 daytime] ], false ])
  end

  it "手機上切到返程，只顯示返程的每站一列" do
    expect(load_rows_around("[data-direction-switch] button[value='1']").last.map { it.first(2) }.uniq).to eq([ %w[1 morning_peak] ])
  end

  it "手機的第一個畫面放得下四張重點數字卡的每一個數字（兩端都停車，第 2、3 張卡各兩行）" do
    bottoms = on_phone { page.evaluate_script('[...document.querySelectorAll("[data-section=summary] [data-number]")].map((node) => node.getBoundingClientRect().bottom)') }
    expect([ bottoms.size, bottoms.max ]).to match([ 7, be <= phone[:height] ])
  end

  it "手機上從導覽跳到行駛時間，導覽黏在畫面最上面，行駛時間卡的標題在導覽下緣之下" do
    nav, title = jump_to_run_times
    expect([ nav["top"], title["top"] >= nav["bottom"] ]).to eq([ 0, true ])
  end

  it "手機上行駛時間的每一列只有數字，沒有橫條" do
    cells = on_phone { [ "[data-bar-from]", "td:first-child" ].map { displays("[data-section=run-times] [data-direction='0'] tbody #{it}").uniq } }
    expect(cells).to eq([ [ "none" ], [ "table-cell" ] ])
  end
end
