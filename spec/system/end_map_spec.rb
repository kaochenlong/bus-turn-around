require "rails_helper"
require_relative "../support/duckdb"

# The maps of the turnaround facilities block, drawn in the browser over the
# fixture day written by the real loader. The test basemap is a blank data
# URI, so the maps never reach the network.
RSpec.describe "折返點的地圖", :duckdb, :js, type: :system do
  # Seconds to wait for the map chunk to load and a map to be drawn.
  def drawn_within = 10

  def store_fixture_day
    RouteDayLoader.new(route_id: 9001, day: Date.new(2026, 10, 19), data_root: DuckdbHelpers::FIXTURE_DATA, duckdb: "duckdb").call
  end

  def visit_fixture_day = visit(route_path(9001, day: "2026-10-19"))

  # The URL the build gave a module, from the Vite manifest.
  def built(path) = "/vite/#{JSON.parse(Rails.root.join('public/vite/.vite/manifest.json').read).fetch(path).fetch('file')}"

  def map_chunk = built("app/frontend/end_map/runtime.js")

  # Whether the page has requested `url` half a second from now; a request
  # still in flight is not listed yet.
  def requested?(url)
    sleep 0.5
    page.evaluate_script('performance.getEntriesByType("resource").map((entry) => new URL(entry.name).pathname)').include?(url)
  end

  # Runs the block with the CDP `command` applied, then applies it again with
  # `reset`: the browser is shared with the other examples.
  def with_cdp(command, params, reset)
    browser = page.driver.browser
    browser.execute_cdp(command, **params)
    yield
  ensure
    browser.execute_cdp(command, **reset)
  end

  def with_reduced_motion(&) = with_cdp("Emulation.setEmulatedMedia", { features: [ { name: "prefers-reduced-motion", value: "reduce" } ] }, { features: [] }, &)

  def with_blocked(url, &)
    page.driver.browser.execute_cdp("Network.enable")
    with_cdp("Network.setBlockedURLs", { urls: [ "*#{url}" ] }, { urls: [] }, &)
  end

  def map_selector(go_back) = "[data-end-map][data-end='#{go_back}']"

  # Scrolls direction `go_back`'s map container to the middle of the window,
  # waits for it to reach `state` and returns it.
  def scroll_to_map(go_back, state: "ready")
    page.execute_script("document.querySelector(arguments[0]).scrollIntoView({ block: 'center', behavior: 'instant' })", map_selector(go_back))
    find("#{map_selector(go_back)}[data-map=#{state}]", wait: drawn_within)
  end

  # Opens the fixture day and scrolls to each map until it is drawn.
  def draw_both_maps
    visit_fixture_day
    [ 0, 1 ].each { scroll_to_map(it) }
  end

  # How many elements of each class direction `go_back`'s map holds, wherever
  # they fall inside or outside the view.
  def drawn(go_back, *classes) = within(map_selector(go_back)) { classes.map { all(".#{it}", visible: :all).size } }

  def note_visible?(go_back) = find("#{map_selector(go_back)} [data-map-note]", visible: :all).visible?

  def coverage_share(go_back) = find("#{map_selector(go_back)} + p[data-map-coverage] [data-value=coverage-share]").text

  # The lines of the tooltip that `event` (mouseover for a pointer resting on
  # the marker, click for a tap) on direction 0's first toilet marker opens.
  # The marker can lie outside the view, so the event is dispatched to it and
  # the tooltip is read wherever it is.
  def toilet_tooltip(event)
    page.execute_script("arguments[0].dispatchEvent(new MouseEvent(arguments[1], { bubbles: true }))", all("#{map_selector(0)} .end-map-toilet", visible: :all).first, event)
    find("#{map_selector(0)} .leaflet-tooltip", visible: :all).all(":scope > div > *", visible: :all).map { it.text(:all) }
  end

  # Turns the wheel one notch without a key over the middle of direction
  # `go_back`'s drawn map, in the direction that zooms in, and returns whether
  # the page scrolled, whether the standstill cell kept its size and whether
  # the note naming the key to hold showed.
  def plain_wheel_outcome(go_back)
    measure = "(() => { const box = (selector) => document.querySelector(selector).getBoundingClientRect(); " \
              "const map = box(arguments[0]); return [window.scrollY, box(arguments[0] + ' .end-map-cell').width, map.x + map.width / 2, map.y + map.height / 2] })()"
    scroll_before, width_before, x, y = page.evaluate_script(measure, map_selector(go_back))
    page.driver.browser.execute_cdp("Input.dispatchMouseEvent", type: "mouseWheel", x:, y:, deltaX: 0, deltaY: -120, modifiers: 0)
    shown = page.has_css?("#{map_selector(go_back)} .map-gesture-note[data-shown=wheel]", visible: :all, wait: 0.5)
    sleep 1
    scroll_after, width_after = page.evaluate_script(measure, map_selector(go_back))
    [ scroll_after < scroll_before, width_after == width_before, shown ]
  end

  # Presses direction `go_back`'s full screen button and returns whether its
  # container goes on the whole screen within five seconds; leaves the whole
  # screen again, the browser being shared.
  def on_whole_screen_after_pressing?(go_back)
    scroll_to_map(go_back).find(".map-fullscreen a", visible: :all).click
    script = "document.fullscreenElement === document.querySelector(arguments[0])"
    Timeout.timeout(5) { sleep 0.1 until page.evaluate_script(script, map_selector(go_back)) }
    true
  rescue Timeout::Error
    false
  ensure
    page.execute_script("document.fullscreenElement && document.exitFullscreen()")
  end

  # How far below the bottom of the window the first map container starts, in
  # pixels; raises when it is already in view, which would make a test about
  # not loading before scrolling meaningless.
  def first_map_below_the_window
    gap = page.evaluate_script("document.querySelector('[data-end-map]').getBoundingClientRect().top - window.innerHeight")
    raise "the first map container starts #{-gap}px inside the window" unless gap.positive?

    gap
  end

  describe "fixture 日，兩端都停車" do
    before { store_fixture_day }

    it "捲到兩張圖之後都畫好：請求了地圖的 chunk，那一句藏起來" do
      draw_both_maps
      expect([ requested?(map_chunk), note_visible?(0), note_visible?(1) ]).to eq([ true, false, false ])
    end

    it "方向 0：一個第 4 級的格子、末站、下一趟起站、位置、兩處公廁與圖例，涵蓋 86%" do
      draw_both_maps
      classes = %w[end-map-cell end-map-cell-4 end-map-stop-last end-map-stop-next end-map-location end-map-toilet end-map-legend]
      expect([ *drawn(0, *classes), coverage_share(0) ]).to eq([ 1, 1, 1, 1, 1, 2, 1, "86%" ])
    end

    it "方向 1：沒有格子也沒有圖例，有末站、下一趟起站、位置與兩處公廁，涵蓋 0%" do
      draw_both_maps
      classes = %w[end-map-cell end-map-legend end-map-stop-last end-map-stop-next end-map-location end-map-toilet]
      expect([ *drawn(1, *classes), coverage_share(1) ]).to eq([ 0, 0, 1, 1, 1, 2, "0%" ])
    end

    it "兩張圖的顯名控制項與頁尾都寫著設定的底圖顯名" do
      draw_both_maps
      expect([ *[ 0, 1 ].map { find("#{map_selector(it)} .leaflet-control-attribution").text }, find("footer").text.include?("測試用空白底圖") ]).to eq([ "測試用空白底圖", "測試用空白底圖", true ])
    end

    it "滑鼠停在公廁標記上時，提示寫最近那一間的名稱、類別、公尺與這一處的間數" do
      draw_both_maps
      expect(toilet_tooltip("mouseover")).to eq([ "戊站公園-男廁", "公園", "251.7 公尺，2 間" ])
    end

    it "點按公廁標記時，提示也打開" do
      draw_both_maps
      expect(toilet_tooltip("click")).to eq([ "戊站公園-男廁", "公園", "251.7 公尺，2 間" ])
    end

    it "地圖裡沒有任何能用 Tab 停留的元素：容器對輔助科技隱藏" do
      draw_both_maps
      focusable = page.evaluate_script("[...document.querySelectorAll('[data-end-map] :is(a[href], button, input, [tabindex])')].filter((element) => element.tabIndex >= 0).length")
      expect(focusable).to eq(0)
    end

    it "開頁不捲，地圖的 chunk 沒有被請求" do
      visit_fixture_day
      first_map_below_the_window
      expect([ requested?(map_chunk), all("[data-end-map][data-map=pending]", visible: :all).size ]).to eq([ false, 2 ])
    end

    it "地圖的 chunk 載不到時，容器是 static、那一句看得到，設施那一段的數字照舊" do
      with_blocked(map_chunk) do
        visit_fixture_day
        scroll_to_map(0, state: "static")
        expect([ note_visible?(0), find("[data-section=facilities] [data-end='0'] [data-value=toilets-300]").text ]).to eq([ true, "1" ])
      end
    end

    it "設定減少動態效果時，畫出來的地圖關掉動畫並標在容器上" do
      with_reduced_motion do
        visit_fixture_day
        expect(scroll_to_map(0)["data-animations"]).to eq("off")
      end
    end

    it "沒按 Ctrl 或 ⌘ 在端點地圖上滾動滑鼠滾輪：頁面捲動、地圖不縮放，出現要按哪個鍵的提示" do
      visit_fixture_day
      scroll_to_map(0)
      expect(plain_wheel_outcome(0)).to eq([ true, true, true ])
    end

    it "端點地圖也有全螢幕按鈕，按下時那一端的容器全螢幕" do
      visit_fixture_day
      expect(on_whole_screen_after_pressing?(0)).to be(true)
    end

    it "Turbo 快取前，畫好的地圖還原成伺服器輸出的 pending，畫布裡沒有東西" do
      draw_both_maps
      page.execute_script("document.dispatchEvent(new Event('turbo:before-cache'))")
      expect(all("[data-end-map]", visible: :all).map { [ it["data-map"], it.all("[data-map-canvas] > *", visible: :all).size, it["data-animations"] ] }).to eq([ [ "pending", 0, nil ] ] * 2)
    end
  end

  it "直接折返的那一端只畫末站，沒有另外的位置標記" do
    allow(RoutePage).to receive(:ends).and_return(RoutePage::Ends.from_config({ 0 => "pass_through", 1 => "stop" }, route_id: 9001))
    store_fixture_day
    visit_fixture_day
    scroll_to_map(0)
    expect(drawn(0, "end-map-stop-last", "end-map-location")).to eq([ 1, 0 ])
  end

  it "首頁不請求地圖的 chunk" do
    visit root_path
    expect(requested?(map_chunk)).to be(false)
  end
end
