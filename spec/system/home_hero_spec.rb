require "rails_helper"

RSpec.describe "Home hero animation", :js, type: :system do
  # Seconds to wait for the animation, which lasts 5.5 once its script has loaded.
  def played_within = 15

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

  # Waits for the hero to reach `state`, then returns its canvases and the
  # picture's visibility.
  def hero_state(state, wait: 5)
    find("[data-section=hero][data-hero=#{state}]", wait:)
    [ all("[data-section=hero] canvas").size, picture_visibility ]
  end

  # The picture's visibility once it stops being hidden, or after `seconds`.
  def picture_visibility_within(seconds)
    deadline = Time.current + seconds
    sleep 0.1 while picture_visibility == "hidden" && Time.current < deadline
    picture_visibility
  end

  def store_route_day
    RouteDay.create!(route_id: 9001, day: Date.new(2026, 10, 20), route_name: "測試幹線", departure: "甲站",
                     destination: "戊站", static_day: Date.new(2026, 10, 20), loaded_at: Time.current)
  end

  # Waits for the animation to finish, keeps a handle on its canvas in the
  # window (Turbo keeps the window across visits) and notes the hero's state
  # in the page Turbo renders from its cache, then opens 9001's route page
  # from its card and goes back.
  def leave_and_come_back
    find("[data-section=hero][data-hero=done]", wait: played_within)
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

  # Visits the home page with the frame counter and waits for the animation
  # to finish.
  def play_to_done
    visit_counting_frames root_path
    find("[data-section=hero][data-hero=done]", wait: played_within)
  end

  # The canvases in the hero, the picture's visibility, and the animation
  # frames requested in the half second after the animation reported done.
  def state_after_done
    find("[data-section=hero][data-hero=done]", wait: played_within)
    before = frames
    sleep 0.5
    [ all("[data-section=hero] canvas").size, picture_visibility, frames - before ]
  end

  it "允許動態、有 WebGL 時，canvas 取代靜態圖，播一次就停止重繪" do
    visit_counting_frames root_path
    expect(state_after_done).to eq([ 1, "hidden", 0 ])
  end

  it "設定減少動態效果時，維持靜態圖、不加 canvas、不抓動畫的 chunk" do
    with_reduced_motion do
      visit root_path
      expect([ *hero_state("static"), requested?(runtime_chunk) ]).to eq([ 0, "visible", false ])
    end
  end

  it "沒有 WebGL 時，維持靜態圖", :without_webgl do
    visit root_path
    expect(hero_state("static")).to eq([ 0, "visible" ])
  end

  it "動畫的 chunk 載不到時，退回靜態圖" do
    with_blocked(runtime_chunk) do
      visit root_path
      expect(hero_state("static")).to eq([ 0, "visible" ])
    end
  end

  it "頁面的 script 沒有接手時，靜態圖先藏著，3 秒內自己出現" do
    with_blocked(built("app/frontend/entrypoints/application.js")) do
      visit root_path
      expect([ picture_visibility, picture_visibility_within(4) ]).to eq(%w[hidden visible])
    end
  end

  it "路線頁不抓動畫的 chunk" do
    visit route_path(9001)
    expect(requested?(runtime_chunk)).to be(false)
  end

  it "首頁 → 路線頁 → 上一頁：先前的 canvas 已釋放，快取裡是伺服器輸出的狀態，沒有殘留，動畫重播到結束" do
    store_route_day
    visit root_path
    leave_and_come_back
    replayed = hero_state("done", wait: played_within)
    expect([ first_canvas_released, cached_hero_state, *replayed ]).to eq([ true, "pending", 1, "hidden" ])
  end

  it "畫面窄於 640 px 時用直式鏡頭，播放中放寬就換成全景" do
    resize_window(500)
    visit root_path
    tall_first = framed?("tall")
    resize_window(1400)
    expect([ tall_first, framed?("wide"), find("[data-section=hero]")["data-hero"] ]).to eq([ true, true, "playing" ])
  end

  it "播完之後畫面變窄，換成直式鏡頭重畫，不重新播" do
    play_to_done
    before = frames
    resize_window(500)
    expect([ framed?("tall"), frames - before ]).to eq([ true, 0 ])
  end
end
