require "rails_helper"

RSpec.describe "Home hero animation", :js, type: :system do
  # Seconds to wait for the animation's script to load and the hero to start playing.
  def started_within = 10

  # Seconds in one lap of the animation, which loops. It matches CYCLE in
  # app/frontend/hero/scene.js and has to change with it.
  def lap = 21

  # Counts the page's requestAnimationFrame calls in window.heroFrames.
  def frame_counter = <<~JS
    window.heroFrames = 0
    const requestFrame = window.requestAnimationFrame.bind(window)
    window.requestAnimationFrame = (callback) => { window.heroFrames += 1; return requestFrame(callback) }
  JS

  # Visits `path` with the frame counter installed before any of the page's
  # own scripts run.
  def visit_counting_frames(path)
    browser = page.driver.browser
    script = browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: frame_counter)["identifier"]
    visit path
  ensure
    browser.execute_cdp("Page.removeScriptToEvaluateOnNewDocument", identifier: script) if script
  end

  def frames = page.evaluate_script("window.heroFrames")

  # Whether the page requests animation frames in half a second, measured
  # once what was just done (a click, a scroll) has had a moment to take
  # effect.
  def rendering?
    sleep 0.2
    before = frames
    sleep 0.5
    frames > before
  end

  def hero_attribute = find("[data-section=hero]")["data-hero"]

  def picture_visibility = page.evaluate_script('getComputedStyle(document.querySelector("[data-section=hero] picture")).visibility')

  # The URL the build gave a module, from the Vite manifest.
  def built(path) = "/vite/#{JSON.parse(Rails.root.join('public/vite/.vite/manifest.json').read).fetch(path).fetch('file')}"

  def runtime_chunk = built("app/frontend/hero/runtime.js")

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

  def pause_button_shown? = page.has_css?("[data-hero-pause]", wait: 0)

  # Waits for the hero to reach `state`, then returns its canvases, the
  # picture's visibility and whether the pause button shows.
  def hero_state(state, wait: 5)
    find("[data-section=hero][data-hero=#{state}]", wait:)
    [ all("[data-section=hero] canvas").size, picture_visibility, pause_button_shown? ]
  end

  # The picture's visibility once it stops being hidden, or after `seconds`.
  def picture_visibility_within(seconds)
    deadline = Time.current + seconds
    sleep 0.1 while picture_visibility == "hidden" && Time.current < deadline
    picture_visibility
  end

  def store_route_day
    create(:route_day, day: Date.new(2026, 10, 20))
  end

  # Visits the home page with the frame counter and waits for the animation
  # to start.
  def play_home_page
    visit_counting_frames root_path
    find("[data-section=hero][data-hero=playing]", wait: started_within)
  end

  # Presses the pause button once the animation plays and waits for the hero
  # to report it paused.
  def pause_animation
    find("[data-section=hero][data-hero=playing]", wait: started_within)
    find("[data-hero-pause]").click
    find("[data-section=hero][data-hero=paused]")
  end

  # The hero's state, the label the pause button shows, the static picture's
  # visibility (it stays hidden under the canvas while paused) and whether
  # frames are being requested.
  def pause_state = [ hero_attribute, find("[data-hero-pause] [data-label]")["data-label"], picture_visibility, rendering? ]

  def press_pause_button
    find("[data-hero-pause]").click
    pause_state
  end

  # Scrolls the page until 40% of the illustration's box is left inside the
  # viewport, at its top edge, then tells whether frames are still requested.
  def rendering_once_mostly_scrolled_out
    share = page.evaluate_script(<<~JS)
      (() => {
        const stage = document.querySelector("[data-hero-stage]")
        window.scrollBy({ top: stage.getBoundingClientRect().top + stage.offsetHeight * 0.6, behavior: "instant" })
        const box = stage.getBoundingClientRect()
        return (Math.min(box.bottom, window.innerHeight) - Math.max(box.top, 0)) / box.height
      })()
    JS
    raise "the page scrolled only far enough to leave #{share.round(2)} of the illustration in view" if share >= 0.5

    rendering?
  end

  def rendering_once_back_at_top
    page.execute_script('window.scrollTo({ top: 0, behavior: "instant" })')
    rendering?
  end

  # Pauses the animation, keeps a handle on its canvas in the window (Turbo
  # keeps the window across visits) and notes the hero's state in the page
  # Turbo renders from its cache, then opens 9001's route page from its card
  # and goes back.
  def leave_and_come_back
    pause_animation
    page.execute_script('window.firstHeroCanvas = document.querySelector("[data-section=hero] canvas")')
    page.execute_script(<<~JS)
      document.addEventListener("turbo:before-render", (event) => {
        const hero = event.detail.newBody.querySelector("[data-section=hero]")
        if (hero) window.cachedHeroState = hero.dataset.hero
      })
    JS
    find("[data-route='9001']").click
    find("[data-section=summary]")
    page.go_back
  end

  # Whether the WebGL context of the canvas kept by leave_and_come_back has
  # been let go.
  def first_canvas_released = page.evaluate_script('window.firstHeroCanvas.getContext("webgl2").isContextLost()')

  def cached_hero_state = page.evaluate_script("window.cachedHeroState")

  def resize_window(width) = page.driver.browser.manage.window.resize_to(width, 1000)

  def framed?(shot) = page.has_css?("[data-section=hero][data-hero-shot=#{shot}]", wait: 3)

  it "允許動態、有 WebGL 時，canvas 取代靜態圖，過了一圈還在畫、沒有暫停" do
    play_home_page
    sleep lap + 2
    expect([ all("[data-section=hero] canvas").size, picture_visibility, hero_attribute, rendering? ]).to eq([ 1, "hidden", "playing", true ])
  end

  it "暫停鈕：播放中寫暫停；按了停在當下那一格、換成繼續播放；再按接著畫、換回暫停" do
    play_home_page
    states = [ pause_state, press_pause_button, press_pause_button ]
    expect(states).to eq([ [ "playing", "pause", "hidden", true ], [ "paused", "resume", "hidden", false ], [ "playing", "pause", "hidden", true ] ])
  end

  it "插圖捲到不到一半在畫面裡就停止重繪，捲回來接著畫" do
    play_home_page
    expect([ rendering?, rendering_once_mostly_scrolled_out, rendering_once_back_at_top ]).to eq([ true, false, true ])
  end

  it "設定減少動態效果時，維持靜態圖、不加 canvas、看不到暫停鈕、不抓動畫的 chunk" do
    with_reduced_motion do
      visit root_path
      expect([ *hero_state("static"), requested?(runtime_chunk) ]).to eq([ 0, "visible", false, false ])
    end
  end

  it "沒有 WebGL 時，維持靜態圖、看不到暫停鈕", :without_webgl do
    visit root_path
    expect(hero_state("static")).to eq([ 0, "visible", false ])
  end

  it "動畫的 chunk 載不到時，退回靜態圖、看不到暫停鈕" do
    with_blocked(runtime_chunk) do
      visit root_path
      expect(hero_state("static")).to eq([ 0, "visible", false ])
    end
  end

  it "頁面的 script 沒有接手時，靜態圖先藏著，3 秒內自己出現，看不到暫停鈕" do
    with_blocked(built("app/frontend/entrypoints/application.js")) do
      visit root_path
      expect([ picture_visibility, picture_visibility_within(4), pause_button_shown? ]).to eq([ "hidden", "visible", false ])
    end
  end

  it "路線頁不抓動畫的 chunk" do
    visit route_path(9001)
    expect(requested?(runtime_chunk)).to be(false)
  end

  it "暫停後 首頁 → 路線頁 → 上一頁：先前的 canvas 已釋放，快取裡是伺服器輸出的狀態，沒有殘留，動畫重新播、沒有暫停" do
    store_route_day
    visit root_path
    leave_and_come_back
    replayed = hero_state("playing", wait: started_within)
    expect([ first_canvas_released, cached_hero_state, *replayed ]).to eq([ true, "pending", 1, "hidden", true ])
  end

  it "畫面窄於 640 px 時用窄螢幕的鏡頭，播放中放寬就換成全景" do
    resize_window(500)
    visit root_path
    narrow_first = framed?("narrow")
    resize_window(1400)
    expect([ narrow_first, framed?("wide"), find("[data-section=hero]")["data-hero"] ]).to eq([ true, true, "playing" ])
  end

  it "暫停時畫面變窄，換成窄螢幕的鏡頭重畫一格，沒有恢復播放" do
    visit_counting_frames root_path
    pause_animation
    before = frames
    resize_window(500)
    expect([ framed?("narrow"), frames - before, hero_attribute ]).to eq([ true, 0, "paused" ])
  end
end
