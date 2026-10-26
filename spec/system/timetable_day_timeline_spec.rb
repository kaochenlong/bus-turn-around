require "rails_helper"

# The timeline of the day dispatch: every vehicle's day on one time axis, the
# main view of the day dispatch page, drawn from the day as it stands, with
# the departures of one end below it.
RSpec.describe "當天調度的時間軸", :js, type: :system do
  # A complete trip of the day starting at `start` that runs for `minutes`.
  def add_trip(route_day, start, minutes, go_back, bus_id: "TEST-0001")
    start_time = Time.zone.parse("#{route_day.day} #{start}")
    route_day.trips.create!(bus_id:, path_attribute_id: 9001, go_back:, band: "other", start_time:, end_time: start_time + minutes.minutes,
                            first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5, completeness: "complete",
                            start_from_arrival: false, end_from_departure: false)
  end

  # Three departures from 甲站 in the 06 hour running 50 minutes and three
  # from 乙站 in the 07 hour running 45. Laid out with 15 rest minutes:
  # vehicle 1 runs 06:00–06:50 and 07:20–08:05, vehicle 2 06:20–07:10 and
  # 07:40–08:25, vehicle 3 06:40–07:30 and vehicle 4 07:00–07:45, so the
  # time axis runs from 06:00 to 09:00. Vehicles stop at both ends.
  before do
    route_day = create(:route_day, day: Date.new(2026, 10, 19))
    route_day.stops.create!([ { go_back: 0, seq: 0, stop_name: "甲站" }, { go_back: 1, seq: 5, stop_name: "乙站" } ])
    %w[06:00 06:20 06:40].each { add_trip(route_day, it, 50, 0) }
    %w[07:00 07:20 07:40].each { add_trip(route_day, it, 45, 1) }
  end

  # The browser is shared with the other examples: each keeps its own days.
  after { page.execute_script("window.localStorage.clear()") if page.current_url.start_with?("http") }

  # The words of a component, with the values filled in.
  def component_text(component, *keys, **values)
    format(YAML.load_file(Rails.root.join("app/components/#{component}.yml"), aliases: true).dig("tw", *keys.map(&:to_s)), **values)
  end

  def day_text(*keys, **values) = component_text("day_dispatch_component", *keys, **values)

  def timeline_text(*keys, **values) = component_text("day_timeline_component", :labels, *keys, **values)

  # Starts today's plan of 9001, laid out from weekdays, and waits for the timeline.
  def start_day
    visit "/routes/9001/dispatch?type=weekday"
    find("[data-day-start] [data-plan-summary] [data-slot=vehicles]", text: /\d/)
    click_button component_text("day_start_component", :start)
    find("[data-day-timeline] [data-lane]", match: :first)
  end

  # Opens the day dispatch page again and waits for the timeline of the day kept.
  def continue_day = visit("/routes/9001/dispatch").then { find("[data-day-timeline] [data-lane]", match: :first) }

  # Sets the clock of the page to `time` of today in Taipei and draws the day
  # again by pressing the end already selected.
  def set_clock(time)
    page.execute_script(<<~JS)
      const today = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Taipei" }).format(new Date())
      Alpine.$data(document.querySelector("main[x-data]")).now = () => new Date(`${today}T#{time}:00+08:00`)
      document.querySelector("[data-day-dispatch]:not([hidden]) [data-end][aria-pressed=true]")?.click()
    JS
  end

  # Three more trips of the stored day in each of the 08 to 11 hours, so
  # every sheet runs past four hours: vehicle 1 runs 06:00–06:50,
  # 07:20–08:05, 08:20–09:10, 09:40–10:25 and 10:40–11:30, and rests 60
  # minutes in its tightest four hours.
  def store_longer_day
    route_day = RouteDay.find_by!(route_id: 9001, day: Date.new(2026, 10, 19))
    { "08" => 0, "09" => 1, "10" => 0, "11" => 1 }.each { |hour, go_back| %w[00 20 40].each { add_trip(route_day, "#{hour}:#{it}", go_back.zero? ? 50 : 45, go_back) } }
  end

  def show_end(stop, direction) = click_button(day_text(:end, stop:, direction:)).then { find("[data-end][aria-pressed=true]", text: stop) }

  # HH:MM as minutes of the day.
  def minutes(time) = time.split(":").map(&:to_i).then { |hour, minute| (hour * 60) + minute }

  def departure_row(time) = find("[data-day-dispatch] tr[data-trip][data-departure='#{minutes(time)}']")

  def give(time, vehicle) = departure_row(time).find("[data-control=vehicle]").select("#{vehicle} 號車")

  def retype(time, typed) = departure_row(time).find("[data-control=departure]").set(typed).send_keys(:tab)

  # Records a vehicle back at the end listed, at a typed time.
  def record_back(vehicle, typed)
    within("[data-day-dispatch] form[data-record]") { select("#{vehicle} 號車", from: day_text(:record, :vehicle)).then { fill_in(day_text(:record, :time), with: typed) } }
    click_button day_text(:record, :submit)
  end

  # Every lane of the timeline, in order, as what the script reads from `lane`.
  def lanes(script) = page.evaluate_script("[...document.querySelectorAll('[data-day-timeline] [data-lane]')].map((lane) => #{script})")

  # Each lane's marks matching the selector, as their texts.
  def marks(selector) = lanes("[...lane.querySelectorAll(#{selector.to_json})].map((mark) => mark.textContent)")

  def lane_vehicles = lanes("lane.querySelector('[data-slot=vehicle]').textContent")

  # Opens today's plan, sets the page's clock to `time` and starts the day,
  # so the day shows first at that time.
  def start_day_at(time)
    visit "/routes/9001/dispatch?type=weekday"
    find("[data-day-start] [data-plan-summary] [data-slot=vehicles]", text: /\d/)
    set_clock(time).then { click_button component_text("day_start_component", :start) }
    find("[data-day-timeline] [data-lane]", match: :first)
  end

  # The trip of a vehicle leaving at `time` on the timeline.
  def trip_on(vehicle, time) = find("[data-day-timeline] button[data-timeline-trip][aria-label^='#{vehicle} 號車 #{time} ']")

  def click_trip(vehicle, time) = trip_on(vehicle, time).click

  def lane(vehicle) = find("[data-day-timeline] [data-lane='#{vehicle}']")

  # Drags the trip of a vehicle leaving at `time` with the mouse and drops
  # it on another vehicle's lane.
  def drop(vehicle, time, onto) = trip_on(vehicle, time).drag_to(lane(onto))

  # Holds the trip with the mouse over another vehicle's lane, not dropping it.
  def hold(vehicle, time, over) = page.driver.browser.action.click_and_hold(trip_on(vehicle, time).native).move_to(lane(over).native).perform

  def release = page.driver.browser.action.release.perform

  # The pixels of `minutes` on the time axis as drawn, which runs 180 minutes
  # from 06:00 to 09:00.
  def axis_pixels(minutes) = (minutes * page.evaluate_script("document.querySelector('[data-day-timeline] [data-slot=ticks]').clientWidth") / 180.0).round

  # Holds the trip with the mouse and moves it sideways along its lane by
  # `minutes` of the axis, not dropping it.
  def slide(vehicle, time, minutes) = page.driver.browser.action.click_and_hold(trip_on(vehicle, time).native).move_by(axis_pixels(minutes), 0).perform

  def drag_time = find("[data-day-timeline] [data-drag-time]").text

  # The vehicle and departure of the focused trip, as its name starts.
  def focused_trip = page.evaluate_script("document.activeElement.getAttribute('aria-label')")&.[](/\A\d+ 號車 \S+/)

  # Puts the focus on the first trip and presses Tab until it reaches the
  # trip of a vehicle leaving at `time`.
  def tab_to(vehicle, time)
    page.execute_script("arguments[0].focus()", trip_on(1, "06:00"))
    page.send_keys(:tab) until focused_trip == "#{vehicle} 號車 #{time}" || focused_trip.nil?
  end

  # Taps the element's middle with a finger, by the touch events Chrome
  # takes from DevTools.
  def tap_on(element)
    point = page.evaluate_script("arguments[0].getBoundingClientRect().toJSON()", element).then { { x: it["x"] + (it["width"] / 2), y: it["y"] + (it["height"] / 2) } }
    [ [ "touchStart", [ point ] ], [ "touchEnd", [] ] ].each { |type, points| page.driver.browser.execute_cdp("Input.dispatchTouchEvent", type:, touchPoints: points) }
  end

  def actions_bar = find("[data-day-dispatch] [data-slot=trip-actions] section")

  def action(name) = actions_bar.find("button[data-action=#{name}]")

  # What the focused element is: its control or field and the departure of
  # its row, if any.
  def focused = page.evaluate_script("[document.activeElement.dataset.control ?? document.activeElement.dataset.recordTime ?? '', document.activeElement.closest('tr[data-trip]')?.dataset.departure]")

  def row_message = find("[data-day-dispatch] tr[data-row-message]").text

  # The pointer events of a finger pressing a trip, moving onto a lane and
  # lifting, as a touch screen sends them when it does not take the move for
  # scrolling (Chrome cancels a real finger's drag as soon as it scrolls).
  def finger_drag(from, to)
    page.execute_script(<<~JS, from, to)
      const [trip, lane] = arguments
      const middle = (element) => { const rect = element.getBoundingClientRect(); return { clientX: rect.x + rect.width / 2, clientY: rect.y + rect.height / 2 } }
      const send = (type, element) => trip.dispatchEvent(new PointerEvent(type, { bubbles: true, pointerId: 9, pointerType: "touch", isPrimary: true, button: 0, ...middle(element) }))
      send("pointerdown", trip)
      send("pointermove", lane)
      send("pointerup", lane)
    JS
  end

  # What the change log lists, as the text of each change.
  def change_log = all("[data-day-dispatch] [data-slot=changes] > li [data-slot=text]", visible: :all).map(&:text)

  def pressed_end = find("[data-day-dispatch] [data-end][aria-pressed=true]")["data-end"]

  # Whether the departure at `time` shows inside the departures' frame, below
  # its header, and whether it is the selected one.
  def departure_shown(time)
    page.evaluate_script(<<~JS)
      (() => {
        const frame = document.querySelector("[data-departures-frame]")
        const row = frame.querySelector(`tr[data-trip][data-departure="#{minutes(time)}"]`)
        const [top, bottom, rect] = [frame.querySelector("thead").getBoundingClientRect().bottom, frame.getBoundingClientRect().bottom, row.getBoundingClientRect()]
        return [rect.top >= top - 1 && rect.bottom <= bottom + 1, row.hasAttribute("data-selected")]
      })()
    JS
  end

  # The mark of now on the time axis and the line of now across the lanes,
  # each as its text and place, null when it is not drawn.
  def now_marks = page.evaluate_script("['[data-now]', '[data-now-line]'].map((selector) => document.querySelector(`[data-day-timeline] ${selector}`)).map((mark) => mark.hidden ? null : [mark.textContent, mark.style.left])")

  it "開始當天之後主畫面是時間軸：每台車一條，照車號排" do
    start_day
    expect(lane_vehicles).to eq(%w[1 2 3 4].map { "#{it} 號車" })
  end

  it "重新打開繼續那一天，主畫面照樣是時間軸" do
    start_day.then { continue_day }
    expect(lane_vehicles).to eq(%w[1 2 3 4].map { "#{it} 號車" })
  end

  it "規格的時間軸上的晚回與換車：1 號車 07:25 才回到乙站、07:20 那班給 2 號車；1 號車那一條從 06:50 延伸到 07:25 寫晚 35 分，07:40 起換自 2 號車，2 號車那一條 07:20 起換自 1 號車，換過車的兩趟加框" do
    start_day.then { show_end("乙站", "返程") }.then { record_back(1, "0725") }.then { give("07:20", 2) }
    expect([ marks("[data-late-label]")[0], lanes("[...lane.querySelectorAll('[data-late]')].map((mark) => [mark.style.left, mark.style.width])")[0], marks("[data-slot=notes]"), marks("[data-timeline-trip][data-swapped]") ])
      .to eq([ [ timeline_text(:late, minutes: 35) ], [ %w[27.7778% 19.4444%] ], [ [ timeline_text(:note, time: "07:40", vehicle: "2 號車") ], [ timeline_text(:note, time: "07:20", vehicle: "1 號車") ], [ "" ], [ "" ] ],
               [ [ "07:40" ], [ "07:20" ], [], [] ] ])
  end

  it "規格的短停留一定標出來：乙站 07:20 那班給 2 號車，2 號車 07:10 回到乙站、07:20 又發車，那一條標停 10 分" do
    start_day.then { show_end("乙站", "返程") }.then { give("07:20", 2) }
    expect(marks("[data-short-stop]")[1]).to eq([ timeline_text(:short_stop, minutes: 10) ])
  end

  it "停車端停超過 15 分的寫在兩段之間：1 號車 06:50 回到乙站、07:20 發，寫 30" do
    start_day
    expect(marks("[data-stop]")[0]).to eq([ "30" ])
  end

  it "圖例寫出在哪裡停：9001 兩端都停車，寫兩端" do
    start_day
    expect(find("[data-day-timeline] [data-slot=legend-stops]").text).to eq(timeline_text(:stops_at, stop: timeline_text(:both_ends)))
  end

  it "刻度上的「現在」與條裡的線畫在注入的時刻：07:15 在 06:00 到 09:00 的 41.6667%" do
    start_day.then { set_clock("07:15") }
    expect(now_marks).to eq([ [ day_text(:labels, :now_line, time: "07:15"), "41.6667%" ], [ "", "41.6667%" ] ])
  end

  it "現在不在時間軸的範圍裡就不畫：05:30 在 06:00 之前" do
    start_day.then { set_clock("05:30") }
    expect(now_marks).to eq([ nil, nil ])
  end

  it "每一條尾端是四小時休息，跟計畫不同時附計畫值：單子拉長之後 1 號車 07:25 才回到乙站，休息從 60 分變 45 分" do
    store_longer_day
    start_day.then { show_end("乙站", "返程") }.then { record_back(1, "0725") }
    expect(lanes("[...lane.querySelectorAll('[data-slot=credit], [data-slot=planned]')].map((slot) => slot.textContent)")[0])
      .to eq([ day_text(:labels, :credit_minutes, minutes: 45), day_text(:labels, :credit_planned, minutes: 60) ])
  end

  it "在側欄改過發車時刻的那一趟標成改過：06:00 打成 06:10" do
    start_day.then { retype("06:00", "0610") }
    expect(marks("[data-timeline-trip][data-typed]")[0]).to eq([ "06:10" ])
  end

  describe "側欄跟著時間軸" do
    # The stored day runs from 06:00 to 12:25: 甲站 lists nine departures and
    # 乙站 nine, more than the departures' frame shows at once.
    before { store_longer_day }

    it "打開時側欄在預設端的下一班：時鐘 10:30 開始當天，甲站捲到 10:40" do
      start_day_at("10:30")
      expect([ pressed_end, departure_shown("10:40") ]).to eq([ "0", [ true, false ] ])
    end

    it "規格的點一趟側欄移過去：側欄列著甲站時點 4 號車 11:40 從乙站發的那一趟，側欄換到乙站、捲到 11:40 並標成選取的那一班，頁面不跟著捲" do
      page.driver.browser.manage.window.resize_to(1400, 700)
      start_day.then { click_trip(4, "11:40") }
      expect([ pressed_end, departure_shown("11:40"), page.evaluate_script("window.scrollY") ]).to eq([ "1", [ true, true ], 0 ])
    end

    it "選了的那一趟在時間軸上也標成選取" do
      start_day.then { click_trip(4, "11:40") }
      expect(marks("[data-timeline-trip][data-selected]")[3]).to eq([ "11:40" ])
    end

    it "規格的點現在回到預設端：選了乙站的一趟之後，時鐘 08:10 點刻度上的現在，側欄回到甲站、捲到 08:20" do
      start_day.then { click_trip(4, "11:40") }.then { set_clock("08:10") }
      listed = pressed_end
      find("[data-day-timeline] [data-now]").click
      expect([ listed, pressed_end, departure_shown("08:20") ]).to eq([ "1", "0", [ true, false ] ])
    end

    it "側欄裡的操作照樣能用：選了乙站 11:40 之後，在側欄把那一班派給 11:30 回到乙站收班的 1 號車" do
      start_day.then { click_trip(4, "11:40") }.then { give("11:40", 1) }
      expect(departure_row("11:40").find("[data-control=vehicle]").value).to eq("1")
    end
  end

  describe "拖到別台車那一條" do
    it "規格的拖到同一端的車：1 號車 07:20 從乙站發的那一趟拖到 2 號車那一條，跟在側欄改派相同，修改清單多一筆" do
      start_day.then { drop(1, "07:20", 2) }
      expect([ marks("[data-slot=notes]"), change_log ])
        .to eq([ [ [ timeline_text(:note, time: "07:40", vehicle: "2 號車") ], [ timeline_text(:note, time: "07:20", vehicle: "1 號車") ], [ "" ], [ "" ] ],
                 [ day_text(:labels, :change_vehicle, departure: "07:20", stop: "乙站", vehicle: "2 號車", from: "1 號車") ] ])
    end

    it "規格的拖到另一端的車：1 號車 06:00 從甲站發的那一趟拖到 4 號車那一條，回到原位，4 號車那一條下面說它接下來從乙站發車，修改清單沒變" do
      start_day.then { drop(1, "06:00", 4) }
      message = page.evaluate_script("document.querySelector(\"[data-day-timeline] [data-lane='4']\").nextElementSibling?.textContent")
      expect([ marks("[data-timeline-trip]")[0], message, change_log ]).to eq([ %w[06:00 07:20], day_text(:labels, :elsewhere, vehicle: "4 號車", stop: "乙站"), [] ])
    end

    it "拖到別台車上方時：2 號車那一條標成目標，會換走的 07:40 加框，旁邊寫給 2 號車、07:20 起兩台車後面的班互換" do
      start_day.then { hold(1, "07:20", 2) }
      held = [ lane(2)["data-drop-target"], marks("[data-timeline-trip][data-exchanged]")[1], find("[data-day-timeline] [data-drag-hint]").text ]
      release
      expect(held).to eq([ "", [ "07:40" ], timeline_text(:drag_hint, vehicle: "2 號車", time: "07:20") ])
    end

    it "拖完放開不算點選，放回原位也不算改時刻：1 號車 06:00 拖到 4 號車那一條再拖回原位放開，那一趟沒有被選取，修改清單沒變" do
      start_day.then { trip_on(1, "06:00") }.then { page.driver.browser.action.click_and_hold(it.native).move_to(lane(4).native).move_to(it.native).release.perform }
      expect([ page.has_no_css?("[data-day-timeline] [data-timeline-trip][data-selected]"), change_log ]).to eq([ true, [] ])
    end

    it "手指不啟動拖拉：手指把 1 號車 07:20 那一趟拖到 2 號車那一條，什麼都沒改" do
      start_day.then { finger_drag(trip_on(1, "07:20"), lane(2)) }
      expect([ marks("[data-slot=notes]").flatten.uniq, change_log ]).to eq([ [ "" ], [] ])
    end
  end

  describe "沿著自己那一條拖" do
    it "規格的拖晚十分：方向 0 每小時都跑 50 分，1 號車 06:00 那一趟往右拖到 06:10 放開，06:10 發、07:00 到、標成改過，別的不動" do
      start_day.then { slide(1, "06:00", 10) }.then { release }
      expect([ trip_on(1, "06:10")["aria-label"], marks("[data-timeline-trip][data-typed]"), change_log ])
        .to eq([ timeline_text(:trip, vehicle: "1 號車", time: "06:10", stop: "甲站", direction: "去程", arrival: "07:00"), [ [ "06:10" ], [], [], [] ],
                 [ day_text(:labels, :change_departure, vehicle: "1 號車", from: "06:00", departure: "06:10") ] ])
    end

    it "拖的時候指標上方寫指到的整分鐘：2 號車 06:20 往右拖 15 分是 06:35" do
      start_day.then { slide(2, "06:20", 15) }
      shown = drag_time
      release
      expect(shown).to eq("06:35")
    end

    it "拖出時間軸的範圍就停在邊上：2 號車 06:20 往左拖 45 分，停在 06:00" do
      start_day.then { slide(2, "06:20", -45) }
      shown = drag_time
      release
      expect(shown).to eq("06:00")
    end
  end

  describe "選一趟、叫出三個動作" do
    it "Tab 照發車時刻走過每一趟：從 1 號車 06:00 起依序是 2 號車 06:20、3 號車 06:40、4 號車 07:00、1 號車 07:20、2 號車 07:40" do
      start_day.then { page.execute_script("arguments[0].focus()", trip_on(1, "06:00")) }
      expect(Array.new(5) { page.send_keys(:tab).then { focused_trip } }).to eq([ "2 號車 06:20", "3 號車 06:40", "4 號車 07:00", "1 號車 07:20", "2 號車 07:40" ])
    end

    it "規格的用鍵盤換車：Tab 到 1 號車 07:20、按 Enter、選派車、挑 2 號車，跟拖到 2 號車那一條一樣" do
      start_day.then { tab_to(1, "07:20") }.then { page.send_keys(:enter) }.then { page.send_keys(:enter) }
      Selenium::WebDriver::Support::Select.new(page.driver.browser.switch_to.active_element).select_by(:text, "2 號車")
      expect([ marks("[data-slot=notes]").first(2), change_log ])
        .to eq([ [ [ timeline_text(:note, time: "07:40", vehicle: "2 號車") ], [ timeline_text(:note, time: "07:20", vehicle: "1 號車") ] ], [ day_text(:labels, :change_vehicle, departure: "07:20", stop: "乙站", vehicle: "2 號車", from: "1 號車") ] ])
    end

    it "按 Enter 選了一趟之後焦點在派車，派車把焦點交給側欄那一班的派車" do
      start_day.then { tab_to(1, "07:20") }.then { page.send_keys(:enter) }
      on_action = page.evaluate_script("document.activeElement.dataset.action")
      page.send_keys(:enter)
      expect([ on_action, focused ]).to eq([ "vehicle", [ "vehicle", minutes("07:20").to_s ] ])
    end

    it "用手指點一下叫出同樣三個動作與取消選取：1 號車 07:20 開往甲站" do
      start_day.then { tap_on(trip_on(1, "07:20")) }
      expect(actions_bar.all("button[data-action]").map(&:text))
        .to eq([ day_text(:columns, :vehicle), day_text(:actions, :departure), day_text(:labels, :record_action, vehicle: "1 號車", stop: "甲站"), day_text(:actions, :deselect) ])
    end

    it "動作被拒絕時的說明跟側欄相同：1 號車 06:00 用派車挑 4 號車，說它接下來從乙站發車" do
      start_day.then { click_trip(1, "06:00") }.then { action(:vehicle).click }
      departure_row("06:00").find("[data-control=vehicle]").select("4 號車")
      expect(row_message).to eq(day_text(:labels, :elsewhere, vehicle: "4 號車", stop: "乙站"))
    end

    it "改發車時刻：焦點在側欄那一班的發車那一格" do
      start_day.then { click_trip(1, "06:00") }.then { action(:departure).click }
      expect(focused).to eq([ "departure", minutes("06:00").to_s ])
    end

    it "記下回到：1 號車 06:00 開往乙站，側欄換到乙站、表單選好 1 號車，焦點在回到的時刻" do
      start_day.then { click_trip(1, "06:00") }.then { action(:record).click }
      expect([ pressed_end, find("[data-record-vehicle]").value, page.evaluate_script("document.activeElement.hasAttribute('data-record-time')") ]).to eq([ "1", "1", true ])
    end

    it "用鍵盤取消選取：焦點回到那一趟" do
      start_day.then { tab_to(1, "07:20") }.then { page.send_keys(:enter) }
      page.send_keys(:tab, :tab, :tab, :enter)
      expect(focused_trip).to eq("1 號車 07:20")
    end

    it "選了之後側欄切到另一端，再按派車：側欄回到那一班出發的甲站，焦點在那一班的派車" do
      start_day.then { click_trip(1, "06:00") }.then { show_end("乙站", "返程") }.then { action(:vehicle).click }
      expect([ pressed_end, focused ]).to eq([ "0", [ "vehicle", minutes("06:00").to_s ] ])
    end

    it "取消選取：那一條收起來，時間軸上沒有選取的一趟" do
      start_day.then { click_trip(1, "06:00") }.then { action(:deselect).click }
      expect([ page.has_no_css?("[data-day-dispatch] [data-slot=trip-actions] section"), page.has_no_css?("[data-day-timeline] [data-selected]") ]).to eq([ true, true ])
    end
  end

  describe "車多的時候" do
    # More departures from 甲站 in the 06 hour, so the day lays out `count`
    # vehicles: none of them is back at 甲站 within the hour, and none has
    # rested at 乙站 by the 07:00 departure from there, which takes one more.
    def store_vehicles(count)
      route_day = RouteDay.find_by!(route_id: 9001, day: Date.new(2026, 10, 19))
      (count - 4).times { add_trip(route_day, format("06:%02d", it * 3), 50, 0, bus_id: "TEST-0002") }
    end

    # Where the last lane and the time axis are once the frame is scrolled to
    # the bottom: whether the last lane shows inside the frame, and whether
    # the axis is still at the frame's top.
    def scrolled_to_last_lane = page.evaluate_script(<<~JS)
      (() => {
        const frame = document.querySelector("[data-timeline-frame]")
        frame.scrollTop = frame.scrollHeight
        const [box, axis, last] = [frame.getBoundingClientRect(), frame.querySelector("[data-axis]").getBoundingClientRect(), [...frame.querySelectorAll("[data-lane]")].at(-1).getBoundingClientRect()]
        return [last.bottom <= box.bottom + 1 && last.top >= axis.bottom - 1, Math.abs(axis.top - box.top) <= 1]
      })()
    JS

    it "規格的 22 條：捲到最後一條時，最後一條看得到，刻度仍在框的上緣" do
      store_vehicles(22)
      start_day
      expect([ lane_vehicles.size, scrolled_to_last_lane ]).to eq([ 22, [ true, true ] ])
    end

    it "11 台的條不壓扁" do
      store_vehicles(11)
      start_day
      expect([ lane_vehicles.size, find("[data-day-timeline]")["data-compact"] ]).to eq([ 11, nil ])
    end

    it "12 台以上的條壓扁" do
      store_vehicles(12)
      start_day
      expect([ lane_vehicles.size, find("[data-day-timeline]")["data-compact"] ]).to eq([ 12, "" ])
    end
  end

  describe "窄螢幕" do
    before { page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true) }

    after { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

    # Whether the mark of now shows inside the frame, right of the vehicle
    # numbers, and whether the first lane's vehicle number shows at the
    # frame's left.
    def now_and_numbers_shown = page.evaluate_script(<<~JS)
      (() => {
        const frame = document.querySelector("[data-timeline-frame]").getBoundingClientRect()
        const number = document.querySelector("[data-day-timeline] [data-lane] [data-slot=vehicle]").getBoundingClientRect()
        const now = document.querySelector("[data-day-timeline] [data-now]").getBoundingClientRect()
        return [now.left >= number.right && now.right <= frame.right, number.left >= frame.left && number.right <= frame.right]
      })()
    JS

    it "規格的窄螢幕打開時捲到現在：390 寬、時鐘 08:30，打開時看得到現在的標記與車號" do
      start_day_at("08:30")
      expect(now_and_numbers_shown).to eq([ true, true ])
    end
  end

  it "頁面上沒有任何車輛識別碼" do
    start_day
    expect(page.html.include?("TEST-0001")).to be(false)
  end
end
