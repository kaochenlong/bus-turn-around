require "rails_helper"
require_relative "../support/duckdb"

# The route map of the stop sequence block, drawn in the browser over the
# fixture day written by the real loader. The test basemap is a blank data
# URI, so the map never reaches the network.
RSpec.describe "站序卡的路線圖", :duckdb, :js, type: :system do
  # Seconds to wait for the map chunks to load and the map to be drawn.
  def drawn_within = 10

  def store_fixture_day
    RouteDayLoader.new(route_id: 9001, day: Date.new(2026, 10, 19), data_root: DuckdbHelpers::FIXTURE_DATA, duckdb: "duckdb", out: StringIO.new).call
  end

  def visit_fixture_day = visit(route_path(9001, day: "2026-10-19"))

  def manifest = JSON.parse(Rails.root.join("public/vite/.vite/manifest.json").read)

  # The URL the build gave a module or chunk, from the Vite manifest.
  def built(key) = "/vite/#{manifest.fetch(key).fetch('file')}"

  def route_map_chunk = built("app/frontend/route_map/runtime.js")

  def end_map_chunk = built("app/frontend/end_map/runtime.js")

  # The chunk both drawing chunks import, which holds Leaflet and maps/base_map.js.
  def shared_chunk
    keys = %w[app/frontend/route_map/runtime.js app/frontend/end_map/runtime.js].map { manifest.fetch(it).fetch("imports") }.reduce(:&)
    shared = keys - [ "app/frontend/entrypoints/application.js" ]
    raise "the drawing chunks share #{shared.inspect}, not one chunk" unless shared.size == 1

    built(shared.first)
  end

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

  def with_touch(&) = with_cdp("Emulation.setTouchEmulationEnabled", { enabled: true, maxTouchPoints: 5 }, { enabled: false }, &)

  # Runs the block with navigator.platform reporting `platform` (MacIntel or
  # Win32), then sets the user agent back: the browser is shared.
  def with_platform(platform, &)
    user_agent = page.driver.browser.execute_cdp("Browser.getVersion").fetch("userAgent")
    with_cdp("Emulation.setUserAgentOverride", { userAgent: user_agent, platform: }, { userAgent: user_agent }, &)
  end

  # The middle of the first element `selector` matches, in window pixels.
  def middle_of(selector)
    page.evaluate_script("(() => { const box = document.querySelector(#{selector.to_json}).getBoundingClientRect(); return [box.x + box.width / 2, box.y + box.height / 2] })()")
  end

  def scroll_y = page.evaluate_script("window.scrollY")

  # The distance between direction 0's first and last stop marks, which grows
  # as the map zooms in; marks are never cut at the edge of the map.
  def stop_distance
    page.evaluate_script("(() => { const middle = (selector) => { const box = document.querySelector(selector).getBoundingClientRect(); " \
                         "return [box.x + box.width / 2, box.y + box.height / 2] }; " \
                         "const [a, b] = ['.route-map-stop-first', '.route-map-stop-last'].map((mark) => middle('[data-route-map] ' + mark)); " \
                         "return Math.hypot(a[0] - b[0], a[1] - b[1]) })()")
  end

  # The top of the route map's direction 0 line below the top of the map, which changes only when the map moves.
  def line_offset
    page.evaluate_script("(() => { const top = (selector) => document.querySelector(selector).getBoundingClientRect().top; " \
                         "return top('[data-route-map] .route-map-line-0') - top('[data-route-map]') })()")
  end

  # Whether the route map shows the note of `kind` (wheel or touch) within half a second.
  def note_shown?(kind) = page.has_css?("[data-route-map] .map-gesture-note[data-shown=#{kind}]", visible: :all, wait: 0.5)

  # The zoom key the route map's wheel note names once it shows, or nil when it does not show.
  def wheel_note_key = (find("[data-route-map] .map-gesture-note", visible: :all).text(:all)[/⌘|Ctrl/] if note_shown?("wheel"))

  # Turns the wheel one notch over the drawn route map, in the direction that
  # zooms in, with `key` held (nil, :ctrl or :meta).
  def wheel_notch(key)
    x, y = middle_of("[data-route-map]")
    page.driver.browser.execute_cdp("Input.dispatchMouseEvent", type: "mouseWheel", x:, y:, deltaX: 0, deltaY: -120, modifiers: { nil => 0, ctrl: 2, meta: 4 }.fetch(key))
  end

  # Turns the wheel one notch over the drawn route map with `key` held and
  # returns whether the page scrolled, whether the map zoomed in and the zoom
  # key the note names, nil without a note. Raises when the page cannot
  # scroll up, which would make the scrolling meaningless.
  def wheel_outcome(key)
    scroll_to_route_map
    scroll_before, distance_before = scroll_y, stop_distance
    raise "the page cannot scroll up from the route map" unless scroll_before.positive?

    wheel_notch(key)
    note_key = wheel_note_key
    sleep 1
    [ scroll_y < scroll_before, stop_distance > distance_before * 1.2, note_key ]
  end

  # How many times as far apart direction 0's first and last stop marks are
  # after one notch of the wheel with `key` held.
  def notch_zoom_ratio(key)
    scroll_to_route_map
    distance_before = stop_distance
    wheel_notch(key)
    sleep 1
    stop_distance.fdiv(distance_before)
  end

  # Runs the block in a browser whose document says it cannot show an element
  # on the whole screen, as Safari on an iPhone does; the script is removed
  # afterwards, the browser being shared.
  def without_fullscreen_support
    browser = page.driver.browser
    script = browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument",
                                 source: "Object.defineProperty(Document.prototype, 'fullscreenEnabled', { configurable: true, get: () => false })")
    yield
  ensure
    browser.execute_cdp("Page.removeScriptToEvaluateOnNewDocument", identifier: script.fetch("identifier")) if script
  end

  def route_map_on_whole_screen? = page.evaluate_script("document.fullscreenElement === document.querySelector('[data-route-map]')")

  def route_map_size = page.evaluate_script("(() => { const box = document.querySelector('[data-route-map]').getBoundingClientRect(); return [box.width, box.height] })()")

  def window_size = page.evaluate_script("[window.innerWidth, window.innerHeight]")

  # Presses the route map's full screen button and waits for the browser to
  # switch, in or out.
  def press_fullscreen_button
    on_whole_screen = route_map_on_whole_screen?
    find("[data-route-map] .map-fullscreen a", visible: :all).click
    Timeout.timeout(5) { sleep 0.1 until route_map_on_whole_screen? != on_whole_screen }
    sleep 0.5
  end

  # On the whole screen, turns the wheel one notch without a key and returns
  # whether the map zoomed in and whether the note showed.
  def whole_screen_wheel_outcome
    distance_before = stop_distance
    wheel_notch(nil)
    shown = note_shown?("wheel")
    sleep 1
    [ stop_distance > distance_before * 1.2, shown ]
  end

  def touch(type, x = nil, y = nil) = page.driver.browser.execute_cdp("Input.dispatchTouchEvent", type:, touchPoints: x ? [ { x:, y: } ] : [])

  # Drags one finger up across the drawn route map and returns whether the
  # map moved and whether the note saying to use two fingers showed.
  def one_finger_outcome
    scroll_to_route_map
    offset_before = line_offset
    x, y = middle_of("[data-route-map]")
    touch("touchStart", x, y)
    [ 30, 60, 90 ].each { touch("touchMove", x, y - it) }
    touch("touchEnd")
    [ (line_offset - offset_before).abs > 1, note_shown?("touch") ]
  end

  # Scrolls the route map container to the middle of the window, waits for it
  # to reach `state` and returns it.
  def scroll_to_route_map(state: "ready")
    page.execute_script("document.querySelector('[data-route-map]').scrollIntoView({ block: 'center', behavior: 'instant' })")
    find("[data-route-map][data-map=#{state}]", wait: drawn_within)
  end

  # How many elements of each class the route map holds, wherever they fall
  # inside or outside the view.
  def drawn(*classes) = within("[data-route-map]") { classes.map { all(".#{it}", visible: :all).size } }

  def note_visible? = find("[data-route-map] [data-map-note]", visible: :all).visible?

  def stop_rows = all("details[data-stop-sequence] li", visible: :all).size

  # How far below the bottom of the window the first end map container
  # starts, in pixels; raises when it is already in view, which would make a
  # test about not loading the end map's chunk meaningless.
  def end_map_below_the_window
    gap = page.evaluate_script("document.querySelector('[data-end-map]').getBoundingClientRect().top - window.innerHeight")
    raise "the first end map container starts #{-gap}px inside the window" unless gap.positive?

    gap
  end

  describe "fixture 日的兩個方向都有路線軌跡" do
    before { store_fixture_day }

    it "捲到路線圖之後畫好：兩條線、兩個方向的起站與末站、圖例，那一句藏起來" do
      visit_fixture_day
      scroll_to_route_map
      expect([ *drawn("route-map-line-0", "route-map-line-1", "route-map-stop-first", "route-map-stop-last", "route-map-legend"), note_visible? ])
        .to eq([ 1, 1, 2, 2, 1, false ])
    end

    it "滑鼠停在去程起站的標記上時，提示寫站名甲站與去程起站" do
      visit_fixture_day
      scroll_to_route_map
      page.execute_script("arguments[0].dispatchEvent(new MouseEvent('mouseover', { bubbles: true }))", all("[data-route-map] .route-map-stop-first", visible: :all).first)
      expect(find("[data-route-map] .leaflet-tooltip", visible: :all).all(":scope > div > *", visible: :all).map { it.text(:all) }).to eq(%w[甲站 去程起站])
    end

    it "路線圖的繪圖 chunk 載不到時，容器是 static、那一句看得到，站序清單的 10 站都在" do
      with_blocked(route_map_chunk) do
        visit_fixture_day
        scroll_to_route_map(state: "static")
        expect([ note_visible?, stop_rows ]).to eq([ true, 10 ])
      end
    end

    it "只捲到站序卡時，請求了共用 chunk 與路線圖的繪圖 chunk，沒有請求端點地圖的繪圖 chunk" do
      visit_fixture_day
      scroll_to_route_map.then { end_map_below_the_window }
      expect([ requested?(shared_chunk), requested?(route_map_chunk), requested?(end_map_chunk) ]).to eq([ true, true, false ])
    end

    it "設定減少動態效果時，畫出來的路線圖關掉動畫並標在容器上" do
      with_reduced_motion do
        visit_fixture_day
        expect(scroll_to_route_map["data-animations"]).to eq("off")
      end
    end

    # turnaround-map's Map gestures example: Ctrl zooms on a Mac too, because a trackpad pinch sends it.
    {
      [ "MacIntel", nil ] => [ true, false, "⌘" ], [ "MacIntel", :meta ] => [ false, true, nil ], [ "MacIntel", :ctrl ] => [ false, true, nil ],
      [ "Win32", nil ] => [ true, false, "Ctrl" ], [ "Win32", :ctrl ] => [ false, true, nil ], [ "Win32", :meta ] => [ true, false, "Ctrl" ]
    }.each do |(platform, key), (scrolls, zooms, note_key)|
      it "#{platform} 往放大的方向滾動、按著 #{key || '沒有按鍵'}：頁面#{scrolls ? '捲動' : '不捲'}、路線圖#{zooms ? '放大' : '不縮放'}、#{note_key ? "提示寫 #{note_key}" : '沒有提示'}" do
        with_platform(platform) do
          visit_fixture_day
          expect(wheel_outcome(key)).to eq([ scrolls, zooms, note_key ])
        end
      end
    end

    { "MacIntel" => :meta, "Win32" => :ctrl }.each do |platform, key|
      it "#{platform} 按著縮放鍵滾一格：地圖放大，但不到一級（兩個站牌標記的距離不到兩倍）" do
        with_platform(platform) do
          visit_fixture_day
          expect(notch_zoom_ratio(key)).to be_between(1.2, 1.9)
        end
      end
    end

    describe "全螢幕" do
      before do
        visit_fixture_day
        scroll_to_route_map
      end

      after { page.execute_script("document.fullscreenElement && document.exitFullscreen()") }

      it "按全螢幕按鈕：路線圖的容器全螢幕，大小等於視窗" do
        press_fullscreen_button
        expect([ route_map_on_whole_screen?, route_map_size ]).to eq([ true, window_size ])
      end

      it "全螢幕時不按鍵滾動：地圖放大，沒有提示" do
        press_fullscreen_button
        expect(whole_screen_wheel_outcome).to eq([ true, false ])
      end

      it "再按一次回到頁面：容器回到原本的大小，不按鍵滾動又是捲頁並出現提示" do
        size_before = route_map_size
        2.times { press_fullscreen_button }
        expect([ route_map_on_whole_screen?, route_map_size, wheel_outcome(nil).values_at(0, 1) ]).to eq([ false, size_before, [ true, false ] ])
      end
    end

    it "瀏覽器不支援讓元素全螢幕時，路線圖沒有全螢幕按鈕" do
      without_fullscreen_support do
        visit_fixture_day
        expect(scroll_to_route_map.all(".map-fullscreen", visible: :all).size).to eq(0)
      end
    end

    it "觸控螢幕單指拖過路線圖：地圖不動，出現用兩根手指的提示" do
      with_touch do
        visit_fixture_day
        expect(one_finger_outcome).to eq([ false, true ])
      end
    end

    it "Turbo 快取前，畫好的路線圖還原成伺服器輸出的 pending，畫布裡沒有東西" do
      visit_fixture_day
      scroll_to_route_map
      page.execute_script("document.dispatchEvent(new Event('turbo:before-cache'))")
      expect(find("[data-route-map]", visible: :all).then { [ it["data-map"], it.all("[data-map-canvas] > *", visible: :all).size ] }).to eq([ "pending", 0 ])
    end
  end

  it "首頁不請求共用 chunk，也不請求路線圖的繪圖 chunk" do
    visit root_path
    expect([ requested?(shared_chunk), requested?(route_map_chunk) ]).to eq([ false, false ])
  end
end
