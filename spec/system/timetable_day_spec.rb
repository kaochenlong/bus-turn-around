require "rails_helper"

# The day dispatch: today's plan laid out on the route's day dispatch page
# and started there, kept in this browser, shown again on that page, left
# for the plan's timetable and started again. The timetable page plans only.
RSpec.describe "當天調度", :js, type: :system do
  # A complete trip of the day starting at `start` that runs for `minutes`.
  def add_trip(route_day, start, minutes, go_back)
    start_time = Time.zone.parse("#{route_day.day} #{start}")
    route_day.trips.create!(bus_id: "TEST-0001", path_attribute_id: 9001, go_back:, band: "other", start_time:, end_time: start_time + minutes.minutes,
                            first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5, completeness: "complete",
                            start_from_arrival: false, end_from_departure: false)
  end

  # Three departures from 甲站 in the 06 hour running 50 minutes and three
  # from 乙站 in the 07 hour running 45. Laid out with 15 rest minutes:
  # vehicle 1 runs 06:00–06:50 and 07:20–08:05, vehicle 2 06:20–07:10 and
  # 07:40–08:25, vehicle 3 06:40–07:30 and vehicle 4 07:00–07:45.
  before do
    route_day = create(:route_day, day: Date.new(2026, 10, 19))
    route_day.stops.create!([ { go_back: 0, seq: 0, stop_name: "甲站" }, { go_back: 1, seq: 5, stop_name: "乙站" } ])
    %w[06:00 06:20 06:40].each { add_trip(route_day, it, 50, 0) }
    %w[07:00 07:20 07:40].each { add_trip(route_day, it, 45, 1) }
  end

  # The browser is shared with the other examples: each keeps its own days.
  after { page.execute_script("window.localStorage.clear()") if page.current_url.start_with?("http") }

  def open_timetable(**params)
    visit route_timetable_path(9001, **params)
    find("[data-sheets] [data-vehicle]", match: :first)
  end

  # Opens 9001's day dispatch page with today's plan laid out from weekdays,
  # whatever day of the week the examples run on.
  def open_dispatch(query = "?type=weekday") = visit("/routes/9001/dispatch#{query}")

  # Opens the day dispatch page and waits for today's plan to be laid out.
  def open_plan(query = "?type=weekday") = open_dispatch(query).then { find("[data-day-start] [data-plan-summary] [data-slot=vehicles]", text: /\d/) }

  # Opens the day dispatch page and waits for the day it shows.
  def open_day = open_dispatch.then { find("[data-day-dispatch] [data-slot=date]", text: /\S/) }

  # Starts the day from today's plan as it stands and waits for the day dispatch view.
  def click_start = click_button(plan_text(:start)).then { find("[data-day-dispatch] [data-slot=date]", text: /\S/) }

  def start_day = open_plan.then { click_start }


  # The words of the day dispatch component and of the start control, with
  # the values filled in.
  def day_text(*keys, **values) = format(YAML.load_file(Rails.root.join("app/components/day_dispatch_component.yml"), aliases: true).dig("tw", *keys.map(&:to_s)), **values)

  # The words of today's plan, with the values filled in.
  def plan_text(*keys, **values) = format(YAML.load_file(Rails.root.join("app/components/day_start_component.yml"), aliases: true).dig("tw", *keys.map(&:to_s)), **values)

  # How many vehicles, and departures from 甲站 and from 乙站, today's plan makes.
  def plan_numbers = %w[vehicles departures-0 departures-1].map { find("[data-day-start] [data-plan-summary] [data-slot=#{it}]").text }

  # Today's and yesterday's Taipei dates, as the page writes them.
  def today_label = RoutePage::Format.day_label(Time.zone.today)

  def yesterday_label = RoutePage::Format.day_label(Time.zone.yesterday)

  def day_key(date) = "turnaround.day-dispatch.v1.9001.#{date.iso8601}"

  # Keeps `text` in this browser as route 9001's day of today.
  def keep_today(text) = page.execute_script("localStorage.setItem(#{day_key(Time.zone.today).to_json}, #{text.to_json})")

  # Moves the day kept for today to yesterday, as if it had been started then.
  def move_kept_day_to_yesterday
    today, yesterday = [ Time.zone.today, Time.zone.yesterday ].map { day_key(it).to_json }
    page.execute_script(<<~JS)
      const day = JSON.parse(localStorage.getItem(#{today}))
      localStorage.removeItem(#{today})
      localStorage.setItem(#{yesterday}, JSON.stringify({ ...day, date: #{Time.zone.yesterday.iso8601.to_json} }))
    JS
  end

  # Sets the clock of the page showing to `time` of today in Taipei and, when
  # a day shows, draws it again by pressing the end already selected.
  def set_clock(time)
    page.execute_script(<<~JS)
      const today = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Taipei" }).format(new Date())
      Alpine.$data(document.querySelector("main[x-data]")).now = () => new Date(`${today}T#{time}:00+08:00`)
      document.querySelector("[data-day-dispatch]:not([hidden]) [data-end][aria-pressed=true]")?.click()
    JS
  end

  # Three more trips of the stored day in each of the 08 to 11 hours, from
  # 甲站 in the 08 and 10 hours and from 乙站 in the 09 and 11, running as
  # long as the others, so every sheet of today's plan runs past four hours:
  # vehicle 1 runs 06:00–06:50, 07:20–08:05, 08:20–09:10, 09:40–10:25 and
  # 10:40–11:30; vehicle 2 06:20–07:10, 07:40–08:25, 08:40–09:30 and
  # 11:00–11:45; vehicle 3 06:40–07:30, 09:00–09:45, 10:00–10:50 and
  # 11:20–12:05; vehicle 4 07:00–07:45, 08:00–08:50, 09:20–10:05, 10:20–11:10
  # and 11:40–12:25.
  def store_longer_day
    route_day = RouteDay.find_by!(route_id: 9001, day: Date.new(2026, 10, 19))
    { "08" => 0, "09" => 1, "10" => 0, "11" => 1 }.each { |hour, go_back| %w[00 20 40].each { add_trip(route_day, "#{hour}:#{it}", go_back.zero? ? 50 : 45, go_back) } }
  end

  def end_label(stop, direction) = day_text(:end, stop:, direction:)

  def pressed_end = find("[data-day-dispatch] [data-end][aria-pressed=true]").text

  # One column of the departures listed, as the page shows it.
  def column(name)
    selector = { departure: "[data-control=departure]", planned: "[data-slot=planned]", vehicle: "[data-control=vehicle]", arrival: "[data-slot=arrival]",
                 stop: "[data-slot=stop]", status: "[data-slot=status]" }.fetch(name)
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll("[data-day-dispatch] tr[data-trip] #{selector}")].map((cell) => cell.matches("input, select") ? cell.selectedOptions?.[0]?.text ?? cell.value : cell.textContent)
    JS
  end

  # The departures' rows and the line of now, in order, as their departures
  # and the line's text.
  def row_order = page.evaluate_script(<<~JS)
    [...document.querySelectorAll("[data-day-dispatch] [data-slot=departures] > tr")].map((row) => row.querySelector("[data-control=departure]")?.value ?? row.textContent.trim())
  JS

  # The site name bar's 班表 and 當天調度 links, as their aria-current.
  def nav_current = %w[timetable-link day-dispatch-link].map { find("[data-site-bar] [data-#{it}]")[:"aria-current"] }

  def follow_day_dispatch_link = find("[data-site-bar] [data-day-dispatch-link]").click

  def address = Rack::Utils.parse_query(URI(page.current_url).query)

  # The items of a list beside the departures, each as its texts. The items
  # of the lists laid out as grids have no box of their own (display:
  # contents), and an empty text has no size, so neither is left out.
  def list(slot) = all("[data-day-dispatch] [data-slot=#{slot}] > li", visible: :all).map { |item| item.all("[data-slot]", visible: :all).map(&:text) }

  def figures = %w[swaps typed waiting shortest].map { find("[data-day-dispatch] [data-figure=#{it}]").text } + [ find("[data-day-dispatch] [data-slot=shortest-detail]").text ]

  def basis = find("[data-day-dispatch] [data-slot=basis]").text

  # HH:MM as minutes of the day.
  def minutes(time) = time.split(":").map(&:to_i).then { |hour, minute| (hour * 60) + minute }

  # The row of the departure listed at `time`.
  def departure_row(time) = find("[data-day-dispatch] tr[data-trip][data-departure='#{minutes(time)}']")

  # One column of the row of the departure listed at `time`.
  def cell(time, name) = column(name)[column(:departure).index(time)]

  def give(time, vehicle) = departure_row(time).find("[data-control=vehicle]").select("#{vehicle} 號車")

  def retype(time, typed, key = :tab) = departure_row(time).find("[data-control=departure]").set(typed).send_keys(key)

  # Records a vehicle back at the end listed, at a typed time.
  def record_back(vehicle, typed)
    within("[data-day-dispatch] form[data-record]") { select("#{vehicle} 號車", from: day_text(:record, :vehicle)).then { fill_in(day_text(:record, :time), with: typed) } }
    click_button day_text(:record, :submit)
  end

  def show_end(stop, direction) = click_button(end_label(stop, direction)).then { find("[data-end][aria-pressed=true]", text: stop) }

  def row_message = find("[data-day-dispatch] tr[data-row-message]").text

  # The change log's entries, each as its time, what it did, its reason and
  # whether it is marked undone.
  def change_log
    all("[data-day-dispatch] [data-slot=changes] > li", visible: :all).map do |item|
      %w[at text reason].map { item.find("[data-slot=#{it}]", visible: :all).text } + [ !item[:"data-undone"].nil? ]
    end
  end

  # Three changes, at 07:52 on the clock: vehicle 1 recorded back at 乙站 at
  # 07:25 for traffic, the 07:20 from 乙站 given to vehicle 2 for the late
  # arrival, and vehicle 1's 06:00 from 甲站 retyped as 06:10.
  def make_three_changes
    start_day.then { set_clock("07:52") }
    show_end("乙站", "返程").then { find("[data-record-reason]").set("塞車") }.then { record_back(1, "0725") }
    find("[data-change-reason]").set("1 號車晚回").then { give("07:20", 2) }
    show_end("甲站", "去程").then { retype("06:00", "0610") }
  end

  # Makes this page's local storage refuse every write, as a full or blocked
  # storage does.
  # Makes writing to the local storage throw, as when it is full, and lets it
  # write again.
  def refuse_storage = page.execute_script("window.storageSetItem ??= Storage.prototype.setItem; Storage.prototype.setItem = () => { throw new DOMException('full', 'QuotaExceededError') }")

  def restore_storage = page.execute_script("Storage.prototype.setItem = window.storageSetItem")

  # Opens the plan's timetable from the day dispatch page, leaving it, and
  # waits for the sheets.
  def open_plan_timetable = click_link(day_text(:plan_timetable)).then { find("[data-sheets] [data-vehicle='1']") }

  it "規格的開始當天：今天的計畫選 p50 開始，存下 4 台車的趟次與計畫依據 2026-10-19 平日 p50 休息 15，同一頁換成當天調度" do
    open_plan.then { select("p50", from: "p") }.then { click_start }
    kept = page.evaluate_script("JSON.parse(localStorage.getItem(#{day_key(Time.zone.today).to_json}))")
    expect([ kept["plan"].map { it["vehicle"] }, kept["basis"], URI(page.current_url).path, basis ])
      .to eq([ [ 1, 2, 3, 4 ], { "days" => [ "2026-10-19" ], "dayType" => "weekday", "percentile" => 50, "buffer" => 15 }, "/routes/9001/dispatch",
               day_text(:labels, :basis_one, day: "2026-10-19（一）", dayType: "平日", percentile: 50, buffer: 15) ])
  end

  it "規格的重新開始：問過之後丟掉那一天，同一頁回到今天的計畫，這台電腦不再存著那一天" do
    start_day
    accept_confirm(day_text(:labels, :restart_confirm)) { click_button day_text(:restart) }
    find("[data-day-start] [data-plan-summary] [data-slot=vehicles]", text: /\d/)
    expect([ URI(page.current_url).path, page.evaluate_script("localStorage.getItem(#{day_key(Time.zone.today).to_json})") ]).to eq([ "/routes/9001/dispatch", nil ])
  end

  it "存不進這台電腦時重新開始：分頁裡交過來的也清掉，離開再按上一頁回來是今天的計畫" do
    open_plan.then { refuse_storage }.then { click_start }
    accept_confirm(day_text(:labels, :restart_confirm)) { click_button day_text(:restart) }
    find("[data-site-bar] a[href='/']").click.then { assert_no_selector("main[data-day-dispatch-page]") }
    page.go_back.then { find("[data-day-start] input[name=buffer]").set("0").send_keys(:tab) }
    expect(find("[data-day-start] [data-plan-summary] [data-slot=vehicles]", text: "3").text).to eq("3")
  end

  it "重新開始時按取消：留在當天調度頁" do
    open_timetable
    start_day
    dismiss_confirm { click_button day_text(:restart) }
    expect([ URI(page.current_url).path, page.has_css?("[data-day-dispatch] [data-slot=date]") ]).to eq([ "/routes/9001/dispatch", true ])
  end

  it "離開當天調度頁再按上一頁：Turbo 帶回來的當天調度頁照樣顯示那一天，也照樣能切到乙站" do
    start_day
    find("[data-site-bar] a[href='/']").click.then { assert_no_selector("main[data-day-dispatch-page]") }
    page.go_back.then { show_end("乙站", "返程") }
    expect([ find("[data-day-dispatch] [data-slot=date]").text, column(:departure) ]).to eq([ today_label, %w[07:00 07:20 07:40] ])
  end

  it "規格的存不進這台電腦的那一天：從今天的計畫開始，說沒有存在這台電腦；離開到班表頁再按名稱列的當天調度還在；重新載入就是今天的計畫" do
    open_plan.then { refuse_storage }.then { click_start }
    noted = find("[data-not-kept]").text
    open_plan_timetable.then { follow_day_dispatch_link }.then { find("[data-day-dispatch] [data-slot=date]", text: today_label) }
    open_plan
    expect([ noted, URI(page.current_url).path ]).to eq([ day_text(:not_kept), "/routes/9001/dispatch" ])
  end

  it "當天調度頁又存得進去之後就不再用分頁裡交過來的：恢復之後換車就存進這台電腦，離開再按上一頁回來是換過車、存著的那一天" do
    open_plan.then { refuse_storage }.then { click_start }.then { restore_storage }
    show_end("乙站", "返程").then { give("07:20", 2) }
    find("[data-site-bar] a[href='/']").click.then { assert_no_selector("main[data-day-dispatch-page]") }
    page.go_back.then { show_end("乙站", "返程") }
    expect([ cell("07:20", :vehicle), page.has_no_css?("[data-not-kept]") ]).to eq([ "2 號車", true ])
  end

  it "規格的分頁裡的那一天比存著的新：存進去之後才存不進去，06:00 打成 06:10，回到排班再進當天調度頁，看到 06:10、說沒有存在這台電腦" do
    start_day.then { refuse_storage }
    retype("06:00", "0610")
    open_plan_timetable.then { follow_day_dispatch_link }
    expect([ find("[data-day-dispatch] [data-control=departure]", match: :first).value, find("[data-not-kept]").text ]).to eq([ "06:10", day_text(:not_kept) ])
  end

  describe "一端的發車表、在這一端與接下來會回到的車、頁首與每台車的數字" do
    it "規格的現在前後：時鐘在 06:10，甲站的發車依序是已發車、下一班、照計畫，下一班前面畫著現在 06:10" do
      start_day
      set_clock("06:10")
      expect([ column(:status), row_order ]).to eq([ %w[departed next planned].map { day_text(:labels, :statuses, it) }, [ "06:00", day_text(:labels, :now_line, time: "06:10"), "06:20", "06:40" ] ])
    end

    it "預設列出停車那一端：9001 兩端都停車，先列甲站發車的去程；切到乙站列出返程的班" do
      start_day
      shown = [ pressed_end, column(:departure) ]
      click_button(end_label("乙站", "返程")).then { find("[data-end='1'][aria-pressed=true]") }
      expect([ shown, [ pressed_end, column(:departure) ] ]).to eq([ [ end_label("甲站", "去程"), %w[06:00 06:20 06:40] ], [ end_label("乙站", "返程"), %w[07:00 07:20 07:40] ] ])
    end

    it "每一班帶原排、派車、那台車回到這一端的時刻與停留：乙站 07:00 是 4 號車第一趟，沒有回到的時刻" do
      start_day
      click_button end_label("乙站", "返程")
      expect(%i[planned vehicle arrival stop].map { column(it) }).to eq([ %w[4 1 2].map { "#{it} 號車" }, %w[4 1 2].map { "#{it} 號車" }, [ "", "06:50", "07:10" ], [ "", "30", "30" ] ])
    end

    it "規格的剛回來的車：07:15 在乙站，1 號車 06:50 回到已停 25 分排 07:20，2 號車 07:10 回到已停 5 分排 07:40" do
      start_day
      set_clock("07:15").then { click_button end_label("乙站", "返程") }
      expect(list(:standing)).to eq([ [ "1 號車", day_text(:labels, :standing_next, arrival: "06:50", minutes: 25, next: "07:20") ],
                                      [ "2 號車", day_text(:labels, :standing_next, arrival: "07:10", minutes: 5, next: "07:40") ] ])
    end

    it "07:15 的甲站：沒有車停著；照計畫接下來回到的是 4 號車 07:45、1 號車 08:05、2 號車 08:25，都是當天最後一趟" do
      start_day
      set_clock("07:15")
      expect([ page.has_css?("[data-standing-none]"), list(:arriving) ]).to eq([ true, [ %w[4 07:45], %w[1 08:05], %w[2 08:25] ].map { [ "#{it[0]} 號車", it[1], day_text(:labels, :arriving_ended) ] } ])
    end

    it "頁首：換車 0 次、改過發車 0 班、車還沒回來 0 班，最短停留 30 分在 1 號車 07:20 發車前" do
      start_day
      expect(figures).to eq([ "0", "0", "0", "30", day_text(:labels, :shortest_detail, vehicle: "1 號車", departure: "07:20") ])
    end

    it "每台車的四小時休息：這一天的單都不到四小時" do
      start_day
      expect(list(:credits)).to eq((1..4).map { [ "#{it} 號車", day_text(:labels, :credit_shorter, hours: 4), "" ] })
    end

    it "每台車的四小時休息：08 到 11 時多了趟次、單子拉長之後 1 號車 60 分、2 號車 105 分、3 號車 105 分、4 號車 60 分，沒有修改所以不附計畫的數字" do
      store_longer_day
      start_day
      expect(list(:credits)).to eq([ [ 1, 60 ], [ 2, 105 ], [ 3, 105 ], [ 4, 60 ] ].map { |number, minutes| [ "#{number} 號車", day_text(:labels, :credit_minutes, minutes:), "" ] })
    end

    it "頁面上沒有任何車輛識別碼" do
      start_day
      expect(page.html.include?("TEST-0001")).to be(false)
    end
  end

  describe "記下回到時刻、換車、改發車時刻" do
    # 2026-10-20 runs direction 0 in 60 minutes instead of 50.
    def store_slower_day
      route_day = create(:route_day, day: Date.new(2026, 10, 20))
      route_day.stops.create!([ { go_back: 0, seq: 0, stop_name: "甲站" }, { go_back: 1, seq: 5, stop_name: "乙站" } ])
      %w[06:00 06:20 06:40].each { add_trip(route_day, it, 60, 0) }
      %w[07:00 07:20 07:40].each { add_trip(route_day, it, 45, 1) }
    end

    it "規格的晚回標出下一班：1 號車 07:25 才回到乙站，07:20 那一班照舊、標車還沒回來、停留 −5，回到的時刻標記下的" do
      start_day
      show_end("乙站", "返程").then { record_back(1, "0725") }
      expect([ cell("07:20", :arrival), departure_row("07:20").has_css?("[data-slot=recorded]"), cell("07:20", :stop), cell("07:20", :status) ])
        .to eq([ "07:25", true, "−5", day_text(:labels, :statuses, :waiting) ])
    end

    it "記下的那台車在那個時刻之前沒有開往這一端的班：表單旁說明，沒有記下" do
      start_day
      show_end("乙站", "返程").then { record_back(4, "0600") }
      expect([ find("[data-record-message]").text, figures.first(3) ]).to eq([ day_text(:labels, :no_trip, vehicle: "4 號車", time: "06:00", stop: "乙站"), %w[0 0 0] ])
    end

    it "記下的時刻讀不出來：時刻那一格標錯，表單旁引用打的字、寫出時刻可以怎麼打" do
      start_day
      record_back(1, "25:70")
      expect([ find("[data-record-time]")[:"aria-invalid"], find("[data-record-message]").text.include?("25:70") ]).to eq([ "true", true ])
    end

    it "規格的兩台互換：乙站 07:20 那班派給 2 號車，2 號車開 07:20、1 號車開 07:40，兩班都標出原排，頁首換車 1 次" do
      start_day
      show_end("乙站", "返程").then { give("07:20", 2) }
      expect([ column(:vehicle), column(:planned), departure_row("07:20").find("[data-slot=swapped]").text, figures.first ])
        .to eq([ %w[4 2 1].map { "#{it} 號車" }, %w[4 1 2].map { "#{it} 號車" }, day_text(:labels, :swapped, vehicle: "1 號車"), "1" ])
    end

    it "規格的換車之後的四小時休息：08 到 11 時多了趟次、單子拉長之後乙站 07:20 給 2 號車，1 號車 105 分附計畫 60 分、2 號車 45 分附計畫 105 分" do
      store_longer_day
      start_day.then { show_end("乙站", "返程") }.then { give("07:20", 2) }
      expect(list(:credits).first(2)).to eq([ [ "1 號車", day_text(:labels, :credit_minutes, minutes: 105), day_text(:labels, :credit_planned, minutes: 60) ],
                                             [ "2 號車", day_text(:labels, :credit_minutes, minutes: 45), day_text(:labels, :credit_planned, minutes: 105) ] ])
    end

    it "規格的那台車不在那一端：甲站 06:40 那班派給 1 號車被拒絕，說它接下來從乙站發車，派車那一格回到 3 號車" do
      start_day
      give("06:40", 1)
      expect([ row_message, cell("06:40", :vehicle), figures.first ]).to eq([ day_text(:labels, :elsewhere, vehicle: "1 號車", stop: "乙站"), "3 號車", "0" ])
    end

    it "班都給出去的車：乙站 07:00 那班給 3 號車之後 4 號車沒有班了，再把 07:20 派給 4 號車被拒絕並說不知道它在哪一端" do
      start_day
      show_end("乙站", "返程").then { give("07:00", 3) }
      give("07:20", 4)
      expect([ row_message, cell("07:20", :vehicle) ]).to eq([ day_text(:labels, :no_trips, vehicle: "4 號車"), "1 號車" ])
    end

    it "規格的打不出來的時刻：06:00 那班打 18:70，那一格回到 06:00、標錯，說明引用 18:70 並寫出時刻可以怎麼打" do
      start_day
      retype("06:00", "18:70")
      expect([ cell("06:00", :departure), departure_row("06:00").find("[data-control=departure]")[:"aria-invalid"], row_message ])
        .to eq([ "06:00", "true", I18n.t("times.rejected_typed", typed: "18:70", writings: I18n.t("times.accepted_writings")) ])
    end

    it "打合法的時刻之後到達重算：1 號車 06:00 那班打成 0610，乙站 07:20 那班前面的車 07:00 才回到、停留 20，頁首改過發車 1 班" do
      start_day
      retype("06:00", "0610").then { show_end("乙站", "返程") }
      expect([ cell("07:20", :arrival), cell("07:20", :stop), figures[1] ]).to eq([ "07:00", "20", "1" ])
    end

    it "發車打時刻按 Enter：焦點留在同一班的發車那一格" do
      start_day
      retype("06:00", "0610", :enter)
      expect(page.evaluate_script("document.activeElement.closest('tr[data-trip]')?.dataset.departure")).to eq(minutes("06:10").to_s)
    end

    it "規格的照開始時存下的行駛時間：10-19 鋪的今天開始之後，10-20（去程跑 60 分）的資料進來，重新打開繼續，06:00 打成 06:10 還是 07:00 到" do
      start_day.then { store_slower_day }
      open_day
      retype("06:00", "0610").then { show_end("乙站", "返程") }
      expect(cell("07:20", :arrival)).to eq("07:00")
    end

    it "規格的重新整理還在：記下 1 號車 07:25 回到乙站之後重新打開當天調度頁，看得到記下的回到時刻" do
      start_day
      show_end("乙站", "返程").then { record_back(1, "0725") }
      open_day
      expect(show_end("乙站", "返程") && cell("07:20", :arrival)).to eq("07:25")
    end
  end

  describe "修改清單、復原上一步、存不進這台電腦" do
    let(:three_changes) do
      [ [ "07:52", day_text(:labels, :change_arrival, vehicle: "1 號車", time: "07:25", stop: "乙站"), day_text(:labels, :change_reason, reason: "塞車"), false ],
        [ "07:52", day_text(:labels, :change_vehicle, departure: "07:20", stop: "乙站", vehicle: "2 號車", from: "1 號車"), day_text(:labels, :change_reason, reason: "1 號車晚回"), false ],
        [ "07:52", day_text(:labels, :change_departure, vehicle: "1 號車", from: "06:00", departure: "06:10"), "", false ] ]
    end

    it "還沒有修改：清單寫著還沒有修改，復原上一步按不了" do
      start_day
      expect([ find("[data-day-dispatch] [data-slot=changes-heading]").text, page.has_css?("[data-changes-none]"), find("[data-day-dispatch] [data-undo]").disabled? ])
        .to eq([ day_text(:labels, :changes_heading, count: 0), true, true ])
    end

    it "三筆修改依序列出：記下的時刻（台北時間）、做了什麼、原因；換車與改發車用的原因記下之後清空" do
      make_three_changes
      expect([ change_log, find("[data-change-reason]").value ]).to eq([ three_changes, "" ])
    end

    it "規格的復原：復原上一步之後最新那筆標成已復原，06:00 那班回到 06:00、頁首改過發車 0 班" do
      make_three_changes
      click_button day_text(:undo)
      expect([ change_log.map(&:last), column(:departure).first, figures[1] ]).to eq([ [ false, false, true ], "06:00", "0" ])
    end

    it "規格的復原換車：再復原一次換車也標成已復原，乙站 07:20 回到 1 號車開，頁首換車 0 次" do
      make_three_changes
      2.times { click_button day_text(:undo) }
      expect([ change_log.map(&:last), show_end("乙站", "返程") && cell("07:20", :vehicle), figures.first ]).to eq([ [ false, true, true ], "1 號車", "0" ])
    end

    it "復原之後再改的一筆接在後面" do
      make_three_changes
      click_button(day_text(:undo)).then { retype("06:20", "0625") }
      expect(change_log.map { [ it[1], it.last ] }.last(2)).to eq([ [ three_changes.last[1], true ], [ day_text(:labels, :change_departure, vehicle: "2 號車", from: "06:20", departure: "06:25"), false ] ])
    end

    it "規格的存不進這台電腦：localStorage 寫不進去時頁首附近說這一天沒有存在這台電腦，換車照樣生效" do
      start_day
      refuse_storage.then { show_end("乙站", "返程") }.then { give("07:20", 2) }
      expect([ find("[data-not-kept]").text, cell("07:20", :vehicle) ]).to eq([ day_text(:not_kept), "2 號車" ])
    end
  end

  describe "當天調度頁" do
    it "規格的存著的那一天在自己的一頁：開始當天之後重新打開 /routes/9001/dispatch，顯示那一天" do
      start_day
      expect(open_day.text).to eq(today_label)
    end

    it "規格的什麼都沒存著：打開當天調度頁就是今天的計畫，有開始當天，網址還是 /routes/9001/dispatch" do
      open_plan
      expect([ page.has_button?(plan_text(:start)), URI(page.current_url).path, find("[data-day-start] h1 [data-slot=date]").text ]).to eq([ true, "/routes/9001/dispatch", today_label ])
    end

    it "規格的還沒開始時的今天的計畫：2026-10-19 平日鋪成 4 台車，甲站 3 班、乙站 3 班" do
      open_plan
      expect(plan_numbers).to eq(%w[4 3 3])
    end

    it "休息改成 0：鋪成 3 台車，頁面沒有重新載入" do
      open_plan.then { page.execute_script("document.body.dataset.mark = 'same page'") }
      find("[data-day-start] input[name=buffer]").set("0").send_keys(:tab)
      find("[data-day-start] [data-plan-summary] [data-slot=vehicles]", text: "3")
      expect([ plan_numbers, find("body")["data-mark"] ]).to eq([ %w[3 3 3], "same page" ])
    end

    it "休息欄位按 Enter：在瀏覽器重鋪，不送出表單，頁面沒有重新載入" do
      open_plan.then { page.execute_script("document.body.dataset.mark = 'same page'") }
      find("[data-day-start] input[name=buffer]").set("0").send_keys(:enter)
      find("[data-day-start] [data-plan-summary] [data-slot=vehicles]", text: "3")
      expect([ find("body")["data-mark"], URI(page.current_url).query ]).to eq([ "same page", "type=weekday" ])
    end

    it "休息打 99：照班表頁退回 15，鋪成幾台車不變" do
      open_plan
      find("[data-day-start] input[name=buffer]").set("99").send_keys(:tab)
      expect([ page.has_field?("buffer", with: "15"), plan_numbers ]).to eq([ true, %w[4 3 3] ])
    end

    it "規格的選的日型別沒有資料：今天是換成假日，帶著 p 與休息重新打開，說鋪不出今天的計畫、沒有開始當天" do
      open_plan.then { select("p50", from: "p") }
      select(I18n.t("day_types.holiday"), from: plan_text(:type)).then { find("[data-day-start] [data-no-plan]") }
      expect([ address.slice("type", "p", "buffer"), page.has_no_button?(plan_text(:start)) ]).to eq([ { "type" => "holiday", "p" => "50", "buffer" => "15" }, true ])
    end

    it "規格的存著昨天的那一天：今天的計畫說這台電腦還存著昨天的，繼續那一天就顯示它" do
      start_day.then { move_kept_day_to_yesterday }
      line = open_plan.then { find("[data-day-start] [data-yesterday] [data-slot=yesterday]").text }
      click_button(plan_text(:continue)).then { find("[data-day-dispatch] [data-slot=date]", text: yesterday_label) }
      expect(line).to eq(plan_text(:labels, :yesterday, date: yesterday_label))
    end

    it "規格的讀不出來的那一天：今天的計畫裡說一句" do
      open_plan.then { keep_today("{") }
      open_plan
      expect(find("[data-day-start] [data-unreadable]").text).to eq(plan_text(:labels, :unreadable, date: today_label))
    end

    it "規格的計畫的班表：p50 開始的那一天，計畫的班表連到 day=2026-10-19、range=day、p=50、buffer=15 的班表頁" do
      open_plan.then { select("p50", from: "p") }.then { click_start }
      open_day.then { open_plan_timetable }
      expect(address).to eq({ "day" => "2026-10-19", "range" => "day", "p" => "50", "buffer" => "15" })
    end
  end

  describe "名稱列的當天調度" do
    it "規格的從路線頁打開存著的那一天：換到當天調度頁顯示那一天，名稱列標的是當天調度" do
      start_day
      visit route_path(9001)
      follow_day_dispatch_link.then { find("[data-day-dispatch] [data-slot=date]", text: today_label) }
      expect([ URI(page.current_url).path, nav_current ]).to eq([ "/routes/9001/dispatch", [ nil, "page" ] ])
    end

    it "還沒有存著：從路線頁按當天調度，換到當天調度頁看到今天的計畫，名稱列標的是當天調度" do
      visit(route_path(9001)).then { follow_day_dispatch_link }
      find("[data-day-start] h2")
      expect([ URI(page.current_url).path, nav_current ]).to eq([ "/routes/9001/dispatch", [ nil, "page" ] ])
    end

    it "班表頁上按名稱列的當天調度：換到當天調度頁，看到今天的計畫，名稱列標的是當天調度" do
      open_timetable.then { follow_day_dispatch_link }
      find("[data-day-start] h2")
      expect([ URI(page.current_url).path, nav_current ]).to eq([ "/routes/9001/dispatch", [ nil, "page" ] ])
    end

    it "班表頁上已經存著一天：按名稱列的當天調度換到當天調度頁顯示那一天" do
      start_day.then { open_plan_timetable }
      follow_day_dispatch_link
      expect([ find("[data-day-dispatch] [data-slot=date]").text, URI(page.current_url).path ]).to eq([ today_label, "/routes/9001/dispatch" ])
    end
  end
end
