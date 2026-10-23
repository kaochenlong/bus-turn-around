require "rails_helper"

RSpec.describe "Routes", type: :request do
  def store_days(*days, route_id: 9001)
    days.each do |day|
      create(:route_day, route_id:, day: Date.iso8601(day))
    end
  end

  def store_holiday(day, note: nil) = create(:route_day, day: Date.iso8601(day), day_type: "holiday", day_note: note)

  # The last stop of each direction, so the layover table has a row per direction.
  def add_last_stops(route_day) = route_day.stops.create!([ { go_back: 0, seq: 4, stop_name: "戊站" }, { go_back: 1, seq: 9, stop_name: "甲站" } ])

  # One morning-peak trip per direction, with an on-board count at each of the
  # given sequence numbers.
  def add_counts(route_day, seqs_by_direction)
    seqs_by_direction.each do |go_back, seqs|
      start_time = Time.zone.parse("2026-10-19 07:00") + go_back.hours
      trip = route_day.trips.create!(bus_id: "TEST-0001", path_attribute_id: 9001, go_back:, band: "morning_peak", start_time:,
                                     end_time: start_time + 50.minutes, first_seq: 0, last_seq: 9, n_events: 10, n_stops_observed: 5,
                                     completeness: "complete", start_from_arrival: false, end_from_departure: false)
      seqs.each { trip.trip_stop_counts.create!(seq: it, on_board: 5) }
    end
  end

  def page = response.parsed_body

  def buffer_minutes = page.at_css("[data-section=buffer-trade] [data-value=minutes]")&.text

  def covered_days = page.css("[data-covered-days] [data-day]").map { it["data-day"] }

  def covered_labels = page.css("[data-covered-days] [data-day]").map { it.text.squish }

  def covered_day_type = page.at_css("header [data-day-type]")&.[]("data-day-type")

  # The link to the other day type: which type it names, where it goes, and whether it names the day.
  def other_type_link(day_label) = page.at_css("a[data-other-day-type]")&.then { [ it["data-other-day-type"], it["href"], it.text.include?(day_label) ] }

  def layover_natures = page.css("[data-section=layovers] tr[data-direction]").map { it["data-end-nature"] }

  def pass_through_layovers = page.css("[data-section=buffer-trade] [data-value=pass-through-layovers]")

  # The data-section of every block inside the element a fragment names, that
  # element included; nil when the page has no such element.
  def sections_at(fragment) = page.at_css(fragment)&.xpath("descendant-or-self::*[@data-section]")&.map { it["data-section"] }

  def key_number_targets = page.css("[data-key-number]").to_h { [ it["data-key-number"], sections_at(it["href"]) ] }

  def section_links = page.css("nav[data-section-nav] a").map { [ it["href"], sections_at(it["href"]) ] }

  # What would hide an element, or one of its ancestors in main, before any
  # script runs: a hiding class, an inline display: none, or x-cloak.
  def hidden_marks(node)
    [ node, *node.ancestors.take_while { it.name != "main" } ].flat_map do |element|
      [ *(element.classes & %w[hidden max-sm:hidden]), *("display: none" if element["style"].to_s.delete(" ").include?("display:none")),
        *("x-cloak" if element.key?("x-cloak")) ]
    end
  end

  it "路線不在路線清單裡回 404" do
    get route_path(9999)
    expect(response).to have_http_status(:not_found)
  end

  it "沒給 day、range 與 buffer 時，顯示最新一天、範圍是一天、緩衝 15 分鐘" do
    store_days("2026-10-19", "2026-10-20")
    get route_path(9001)
    expect([ response.status, covered_days, page.at_css("[data-range]")["data-range"], buffer_minutes ]).to eq([ 200, [ "2026-10-20" ], "day", "15" ])
  end

  it "緩衝分鐘數從網址來，拉桿表單帶著目前的日期與範圍" do
    store_days("2026-10-19")
    get route_path(9001), params: { day: "2026-10-19", range: "7d", buffer: "10" }
    hidden = %w[day range].map { page.at_css("#buffer-trade form input[name=#{it}]")["value"] }
    expect([ buffer_minutes, hidden ]).to eq([ "10", %w[2026-10-19 7d] ])
  end

  [ { range: "30d" }, { day: "2026-13-40" }, { day: "20261019" }, { buffer: "21" }, { buffer: [ "1" ] } ].each do |params|
    it "#{params.inspect} 回 400" do
      get route_path(9001), params: params
      expect(response).to have_http_status(:bad_request)
    end
  end

  it "最近 7 天只涵蓋已寫入的日子，列出日期與星期，標成平日" do
    store_days("2026-10-15", "2026-10-19", "2026-10-20", "2026-10-22")
    get route_path(9001), params: { day: "2026-10-22", range: "7d" }
    expect([ covered_day_type, covered_labels ]).to eq([ "weekday", [ "2026-10-19（一）", "2026-10-20（二）", "2026-10-22（四）" ] ])
  end

  describe "10-19 到 10-23 是平日、10-24 到 10-26 是假日、10-26 是補假時" do
    before do
      store_days("2026-10-19", "2026-10-20", "2026-10-21", "2026-10-22", "2026-10-23")
      %w[2026-10-24 2026-10-25].each { store_holiday(it) }
      store_holiday("2026-10-26", note: "補假")
    end

    it "選 10-26、最近 7 天：標成假日，只涵蓋 10-24 到 10-26，10-26 帶著補假，連到 10-23 為止的平日" do
      get route_path(9001), params: { day: "2026-10-26", range: "7d" }
      expect([ covered_day_type, covered_labels, other_type_link("2026-10-23（五）") ]).to eq(
        [ "holiday", [ "2026-10-24（六）", "2026-10-25（日）", "2026-10-26（一）補假" ], [ "weekday", "/routes/9001?day=2026-10-23&range=7d", true ] ]
      )
    end

    it "選 10-23、最近 7 天：標成平日，涵蓋 10-19 到 10-23，10-23 以前沒有假日所以沒有連結" do
      get route_path(9001), params: { day: "2026-10-23", range: "7d" }
      expect([ covered_day_type, covered_days, other_type_link("") ]).to eq([ "weekday", %w[2026-10-19 2026-10-20 2026-10-21 2026-10-22 2026-10-23], nil ])
    end
  end

  it "沒帶參數時是最新的 10-26：標成假日、帶著補假，連到 10-23 那一天" do
    store_days("2026-10-23").then { store_holiday("2026-10-26", note: "補假") }
    get route_path(9001)
    expect([ covered_day_type, covered_labels, other_type_link("2026-10-23（五）") ]).to eq(
      [ "holiday", [ "2026-10-26（一）補假" ], [ "weekday", "/routes/9001?day=2026-10-23&range=day", true ] ]
    )
  end

  it "有資料的那一天，頁面依序是摘要、折返停留分佈圖、折返停留、來回與週期、折返點設施、試算、行駛時間、沿線人數圖、捷運重疊、載客剖面、資料限制" do
    store_days("2026-10-19")
    get route_path(9001), params: { day: "2026-10-19" }
    expect(page.css("[data-section]").map { it["data-section"] })
      .to eq(%w[summary layover-chart layovers cycles facilities buffer-trade run-times load-chart mrt-overlap load-profile limitations])
  end

  it "涵蓋的日子沒有兩端的列時，折返點設施那一區說要重新載入，也沒有地圖容器" do
    store_days("2026-10-19")
    get route_path(9001), params: { day: "2026-10-19" }
    expect([ page.css("[data-section=facilities] [data-needs-reload]").size, page.css("[data-end-map]").size ]).to eq([ 1, 0 ])
  end

  describe "涵蓋的日子有兩端的列時" do
    before do
      route_day = create(:route_day, day: Date.new(2026, 10, 19))
      create(:route_day_end, route_day:, go_back: 0)
      create(:route_day_end, route_day:, go_back: 1, end_seq: 9, end_stop_name: "甲站", latitude: 25.0497, longitude: 121.5006)
      get route_path(9001), params: { day: "2026-10-19" }
    end

    it "每一端各一個地圖容器，各帶一段地圖資料，狀態是 pending" do
      maps = page.css("[data-section=facilities] [data-end-map]")
      expect(maps.map { [ it["data-end"], it["data-map"], it.css("script[data-end-map-data]").size ] }).to eq([ [ "0", "pending", 1 ], [ "1", "pending", 1 ] ])
    end

    it "沒有腳本時，兩個容器裡都是那一句，設施兩端的數字都在" do
      expect([ page.css("[data-end-map] [data-map-note]").size, page.css("[data-section=facilities] [data-value=toilets-300]").size ]).to eq([ 2, 2 ])
    end
  end

  it "重點數字連到的區塊：兩個折返停留的數字連到折返停留那張卡，捷運重疊連到捷運重疊那一區" do
    store_days("2026-10-19")
    get route_path(9001), params: { day: "2026-10-19" }
    expect(key_number_targets).to eq("layover-p50" => %w[layover-chart layovers], "short-share" => %w[layover-chart layovers], "mrt-share" => %w[mrt-overlap])
  end

  it "摘要後面的區塊導覽依頁面順序連到八個區塊，每個 fragment 都對得到包住那一區的元素" do
    store_days("2026-10-19")
    get route_path(9001), params: { day: "2026-10-19" }
    expect(section_links).to eq([ [ "#layovers", %w[layover-chart layovers] ], [ "#cycles", %w[cycles] ], [ "#facilities", %w[facilities] ], [ "#buffer", %w[buffer-trade] ],
                                  [ "#runtimes", %w[run-times] ], [ "#load", %w[load-chart mrt-overlap load-profile] ], [ "#mrt", %w[mrt-overlap] ],
                                  [ "#limits", %w[limitations] ] ])
  end

  it "逐站的載客剖面表收在預設關閉的 details 裡，每一站有人數的列都在回應裡" do
    store_days("2026-10-19").then { add_counts(RouteDay.sole, 0 => [ 1, 2 ], 1 => [ 6 ]) }
    get route_path(9001), params: { day: "2026-10-19" }
    details = page.at_css("[data-section=load-profile] details[data-load-profile]")
    expect([ details&.key?("open"), details&.css("tbody tr")&.count { it.at_css("td") } ]).to eq([ false, 3 ])
  end

  it "沒有 JS 時，兩個方向的行駛時間表都在回應裡、都沒有標成藏起來，方向切換藏著" do
    store_days("2026-10-19").then { add_counts(RouteDay.sole, 0 => [], 1 => []) }
    get route_path(9001), params: { day: "2026-10-19" }
    directions = page.css("[data-section=run-times] [data-direction]").map { [ it["data-direction"], it.css("table").size, hidden_marks(it) ] }
    expect([ directions, page.at_css("[data-section=run-times] [data-direction-switch]")&.key?("x-cloak") ]).to eq([ [ [ "0", 1, [] ], [ "1", 1, [] ] ], true ])
  end

  it "沒有 JS 時，兩個方向的每站一列都在回應裡、預設時段那一組沒有標成藏起來，方向切換藏著" do
    store_days("2026-10-19").then { add_last_stops(RouteDay.sole) }
    get route_path(9001), params: { day: "2026-10-19" }
    groups = page.css("[data-section=load-chart] [data-row-band=morning_peak]").map { [ it.css("[data-row-seq]").size, hidden_marks(it) ] }
    expect([ groups, page.at_css("[data-section=load-chart] [data-direction-switch]")&.key?("x-cloak") ]).to eq([ [ [ 1, [] ], [ 1, [] ] ], true ])
  end

  it "那一天沒有資料時回 200，沒有區塊導覽" do
    store_days("2026-10-19")
    get route_path(9001), params: { day: "2026-10-25" }
    expect([ response.status, page.css("nav[data-section-nav]").size ]).to eq([ 200, 0 ])
  end

  describe "fixture 寫入的 9001（兩端都停車）", :duckdb do
    before do
      RouteDayLoader.new(route_id: 9001, day: Date.new(2026, 10, 19), data_root: DuckdbHelpers::FIXTURE_DATA, duckdb: "duckdb").call
      get route_path(9001), params: { day: "2026-10-19" }
    end

    # The number of each line of a key number, by end or direction.
    def key_numbers(key, by) = page.css("[data-key-number=#{key}] [#{by}]").map { [ it[by], it.at_css("[data-number]").text ] }

    # The text of the cell at `index` in each row, by direction.
    def cells(rows, index) = page.css(rows).map { [ it["data-direction"], it.css("td")[index].text.squish ] }

    it "停車端折返停留 p50 與不到 15 分鐘，每一端的數字跟折返停留表那一列的格子一字不差，而且都是數字" do
      table = [ 5, 7 ].map { cells("[data-section=layovers] tr[data-direction]", it) }
      expect([ key_numbers("layover-p50", "data-end"), key_numbers("short-share", "data-end"), table.flatten(1).count { it.last.match?(/\d/) } ])
        .to eq([ *table, 4 ])
    end

    it "捷運重疊兩個方向的數字跟捷運重疊表 500 公尺那一欄一字不差，而且都是數字" do
      table = cells("[data-shares] tr[data-direction]", 3)
      expect([ key_numbers("mrt-share", "data-direction"), table.count { it.last.match?(/\d/) } ]).to eq([ table, 2 ])
    end
  end

  it "兩端都停車的 9001，折返停留兩列都標停車" do
    store_days("2026-10-19")
    add_last_stops(RouteDay.sole)
    get route_path(9001), params: { day: "2026-10-19" }
    expect(layover_natures).to eq(%w[stop stop])
  end

  it "15373 的兩端照設定標示：去程結束那列開過去就走、返程結束那列停車" do
    store_days("2026-10-21", route_id: 15373)
    add_last_stops(RouteDay.sole)
    get route_path(15373), params: { day: "2026-10-21" }
    expect(layover_natures).to eq(%w[pass_through stop])
  end

  it "兩端都停車的 9001，試算沒有開過去就走那一端的筆數" do
    store_days("2026-10-19")
    get route_path(9001), params: { day: "2026-10-19" }
    expect(pass_through_layovers.size).to eq(0)
  end

  it "15373 有開過去就走的一端，試算另外報那一端的筆數" do
    store_days("2026-10-21", route_id: 15373)
    get route_path(15373), params: { day: "2026-10-21" }
    expect(pass_through_layovers.size).to eq(1)
  end

  it "站牌還沒有到捷運的距離（之前寫入的資料）時，捷運重疊那一塊提示重算" do
    store_days("2026-10-19")
    get route_path(9001), params: { day: "2026-10-19" }
    expect(page.css("[data-section=mrt-overlap] [data-needs-reload]").size).to eq(1)
  end

  it "那一天沒有資料時回 200，標出沒有資料並列出已寫入的日子" do
    store_days("2026-10-19", "2026-10-20")
    get route_path(9001), params: { day: "2026-10-25" }
    expect([ response.status, page.at_css("[data-no-data]").present?, page.css("[data-stored-day]").map { it["data-stored-day"] } ])
      .to eq([ 200, true, [ "2026-10-19", "2026-10-20" ] ])
  end
end
