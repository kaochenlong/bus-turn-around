# frozen_string_literal: true

require "rails_helper"

RSpec.describe BufferTradeComponent, type: :component do
  # One stored day with trips by vehicles A and B and layovers as ["HH:MM" end
  # time, minutes, direction of the ending trip], the direction 0 when left
  # out. By default they end at 08:00 (5 minutes) and 08:20 (20 minutes): at
  # 15 minutes the shortfall is 10.
  def route_day(day: Date.new(2026, 10, 19), layovers: [ [ "08:00", 5 ], [ "08:20", 20 ] ])
    create(:route_day, day:).tap do |route_day|
      %w[A B].each { add_trip(route_day, it) }
      layovers.each do |time, minutes, go_back = 0|
        end_time = Time.zone.parse("#{day} #{time}")
        route_day.layovers.create!(bus_id: "A", go_back:, end_time:, next_start_time: end_time + minutes.minutes)
      end
    end
  end

  # The four layovers of the buffer-trade spec's example over two days: 08:00
  # (5 minutes), 08:20 (20) and 09:10 (2) on 2026-10-19, 08:30 (10) on 10-20.
  def four_layovers
    [ route_day(layovers: [ [ "08:00", 5 ], [ "08:20", 20 ], [ "09:10", 2 ] ]), route_day(day: Date.new(2026, 10, 20), layovers: [ [ "08:30", 10 ] ]) ]
  end

  def add_trip(day, bus_id)
    day.trips.create!(bus_id:, path_attribute_id: 9001, go_back: 0, band: "morning_peak",
                      start_time: Time.zone.parse("2026-10-19 07:00"), end_time: Time.zone.parse("2026-10-19 07:50"),
                      first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5, completeness: "complete",
                      start_from_arrival: false, end_from_departure: false)
  end

  # The nature of the end where direction 0 trips end and of the one where
  # direction 1 trips end.
  def route_ends(outbound, inbound) = RoutePage::Ends.from_config({ 0 => outbound, 1 => inbound }, route_id: 9001)

  # The lateness, hours and end, when given, go to the estimate as they are.
  def render_trade(*days, range: "day", ends: route_ends("stop", "stop"), minutes: 15, **options)
    coverage = RoutePage::Coverage.new(route_id: 9001, day: "2026-10-19", range:)
    render_inline(described_class.new(buffer_trade: RoutePage::BufferTrade.new(RouteDay.where(id: days.map(&:id)), minutes:, ends:, **options), coverage:))
  end

  def values(rendered) = rendered.css("[data-value]").to_h { [ it["data-value"], it.text.squish ] }

  # The values a select offers and the one selected.
  def choices(rendered, name)
    options = rendered.css("select[name=#{name}] option")
    [ options.map { it["value"] }, options.find { it.key?("selected") }&.[]("value") ]
  end

  it "每個數字放在自己的欄位：緩衝、天數、折返停留、趟次、達成率、車時、最忙小時的車數、每天車數" do
    expect(values(render_trade(route_day))).to include(
      "minutes" => "15", "days" => "1", "layovers" => "2", "trips" => "2", "achieved" => "50.0%",
      "vehicle-hours-lower" => "0.2", "vehicle-hours-upper" => "0.5", "vehicles-per-day" => "2.0"
    )
  end

  it "有直接折返的一端時，停車端的筆數是試算的基礎，那一端的筆數另外報" do
    day = route_day(layovers: [ [ "07:00", 2, 0 ], [ "07:30", 2, 0 ], [ "09:00", 2, 0 ], [ "08:00", 5, 1 ], [ "08:20", 20, 1 ] ])
    expect(values(render_trade(day, ends: route_ends("pass_through", "stop")))).to include("layovers" => "2", "pass-through-layovers" => "3")
  end

  it "兩端都停車時沒有直接折返那一端的筆數" do
    expect(render_trade(route_day).css("[data-value=pass-through-layovers]").size).to eq(0)
  end

  it "只有直接折返那一端有折返停留時，說明沒有停車端的折返停留，仍報那一端的筆數" do
    rendered = render_trade(route_day(layovers: [ [ "08:00", 2, 0 ], [ "08:10", 2, 0 ], [ "08:20", 2, 0 ] ]), ends: route_ends("pass_through", "stop"))
    expect([ rendered.css("[data-no-layover]").size, values(rendered)["pass-through-layovers"] ]).to eq([ 1, "3" ])
  end

  it "最忙小時的車數標出是幾點" do
    peaks = render_trade(route_day).css("[data-peak]").map { [ it["data-peak"], it["data-hour"], it.at_css("[data-vehicles]").text.squish ] }
    expect(peaks).to eq([ %w[lower 8 0.2], %w[upper 8 0.5] ])
  end

  it "拉桿表單在 buffer-trade frame 裡，帶著目前的日期與範圍" do
    frame = render_trade(route_day, range: "7d").at_css("turbo-frame#buffer-trade")
    fields = %w[day range].to_h { [ it, frame.at_css("form input[type=hidden][name=#{it}]")["value"] ] }
    expect([ frame["data-turbo-action"], fields ]).to eq([ "advance", { "day" => "2026-10-19", "range" => "7d" } ])
  end

  it "拉桿是 0 到 20 分鐘，停在目前的緩衝分鐘數" do
    slider = render_trade(route_day).at_css("input[type=range][name=buffer]")
    expect(slider.attributes.slice("min", "max", "value").transform_values(&:value)).to eq("min" => "0", "max" => "20", "value" => "15")
  end

  it "沒有折返停留時顯示說明，不顯示達成率與增加量" do
    rendered = render_trade(route_day(layovers: []))
    expect([ rendered.css("[data-no-layover]").size, rendered.css("[data-value=achieved], [data-peak]").size ]).to eq([ 1, 0 ])
  end

  describe "表單" do
    it "休息與晚到的拉桿都是 0 到 20 分鐘，停在網址的值" do
      rendered = render_trade(route_day, late: 6)
      sliders = %w[buffer late].map { rendered.at_css("input[type=range][name=#{it}]").attributes.slice("min", "max", "value").transform_values(&:value) }
      expect(sliders).to eq([ { "min" => "0", "max" => "20", "value" => "15" }, { "min" => "0", "max" => "20", "value" => "6" } ])
    end

    it "開始 9 點、結束 12 點時，開始的選項是 0 到 11、結束的選項是 10 到 24，各自選在目前的值" do
      rendered = render_trade(route_day, hour_range: 9...12)
      expect([ choices(rendered, "from"), choices(rendered, "to") ]).to eq([ [ (0..11).map(&:to_s), "9" ], [ (10..24).map(&:to_s), "12" ] ])
    end

    it "兩端都停車時可以選加在哪一端：兩端與兩個停車端的末站；只有一端停車時沒有這個選項" do
      day = route_day.tap { it.stops.create!([ { go_back: 0, seq: 4, stop_name: "戊站" }, { go_back: 1, seq: 9, stop_name: "甲站" } ]) }
      both = render_trade(day, end_go_back: 1).css("select[name=end] option").map { [ it["value"], it.text.squish, it.key?("selected") ] }
      expect([ both.map { it.values_at(0, 2) }, both.drop(1).map { it[1] }, render_trade(day, ends: route_ends("pass_through", "stop")).css("select[name=end]").size ])
        .to eq([ [ [ "", false ], [ "0", false ], [ "1", true ] ], %w[戊站 甲站], 0 ])
    end

    it "伺服器輸出的重算按鈕沒有標成隱藏，沒有 JavaScript 也能送出" do
      button = render_trade(route_day).at_css("turbo-frame#buffer-trade form button[type=submit]")
      expect([ button.nil?, button&.key?("hidden") ]).to eq([ false, false ])
    end

    it "每次輸出這一塊的 data-rendered 都不一樣" do
      day = route_day
      marks = Array.new(2) { render_trade(day).at_css("section[data-section=buffer-trade]")["data-rendered"] }
      expect([ marks.compact.uniq.size, marks.first.to_s.length ]).to eq([ 2, 16 ])
    end
  end

  describe "數字" do
    it "休息 15、晚到 6 時：每次要留 21 分鐘，車時 0.4 與 0.7，現在的達成率 25.0%，車數不變的 0.0%" do
      values = values(render_trade(*four_layovers, late: 6))
      expect(values.values_at("hold", "minutes", "late", "vehicle-hours-lower", "vehicle-hours-upper", "achieved", "achieved-late"))
        .to eq(%w[21 15 6 0.4 0.7 25.0% 0.0%])
    end

    it "晚到 6 時顯示車數不變的達成率，晚到 0 時藏起來" do
      day = route_day
      shown = [ 6, 0 ].map { render_trade(day, late: it).at_css("[data-achieved-late]")&.key?("hidden") }
      expect(shown).to eq([ false, true ])
    end

    it "一天十二次停留（六次 10 分鐘、六次 30 分鐘）在要留 15 分鐘時，兩欄的再多留 1 分鐘是 0.1 與 0.2" do
      day = route_day(layovers: (8..19).map { [ format("%02d:00", it), it.even? ? 10 : 30 ] })
      expect(values(render_trade(day)).values_at("next-minute-lower", "next-minute-upper")).to eq(%w[0.1 0.2])
    end

    it "只看 9 點到 10 點時，涵蓋那一句報全天的 4 次，另外報試算用的 1 次" do
      expect(values(render_trade(*four_layovers, hour_range: 9...10)).values_at("layovers", "used-layovers")).to eq(%w[4 1])
    end

    it "沒選小時與端點時，涵蓋那一句沒有試算用的筆數" do
      expect(render_trade(route_day).css("[data-value=used-layovers]").size).to eq(0)
    end

    it "12 點到 13 點沒有折返停留：說明寫出這兩個小時，不出現任何車時，表單還在" do
      rendered = render_trade(*four_layovers, hour_range: 12...13)
      note = rendered.at_css("[data-no-layover]")&.text.to_s
      expect([ note.include?("12") && note.include?("13"), rendered.css("[data-value^=vehicle-hours]").size, rendered.css("form").size ]).to eq([ true, 0, 1 ])
    end
  end

  describe "曲線" do
    def curve_data(rendered) = JSON.parse(rendered.at_css("turbo-frame#buffer-trade script[type='application/json'][data-buffer-trade-curve]").text)

    def dot(rendered, bound) = rendered.at_css("svg[data-chart=buffer-curve] g[data-marker] [data-marker-dot=#{bound}]")

    it "回應裡的曲線資料有 41 點，第 h 點的要留分鐘數就是 h" do
      points = curve_data(render_trade(route_day))["points"]
      expect([ points.size, points.map { it["hold"] } ]).to eq([ 41, (0..40).to_a ])
    end

    it "休息 15、晚到 6 時，曲線資料第 21 點的字串跟伺服器輸出的數字一樣：0.4、0.7、0.0、0.0、0.0%" do
      rendered = render_trade(*four_layovers, late: 6)
      point = curve_data(rendered)["points"][21]
      shown = values(rendered).values_at("vehicle-hours-lower", "vehicle-hours-upper", "next-minute-lower", "next-minute-upper", "achieved-late")
      expect([ [ *point["vehicle_hours"], *point["next_minute"], point["achieved"] ], shown ]).to eq([ %w[0.4 0.7 0.0 0.0 0.0%] ] * 2)
    end

    it "下限與上限兩條線各 41 點，橫座標隨要留的分鐘數變大" do
      rendered = render_trade(route_day)
      xs = %w[lower upper].map { rendered.at_css("svg[data-chart=buffer-curve] polyline[data-bound=#{it}]")["points"].split.map { it.split(",").first.to_f } }
      expect(xs.map { [ it.size, it == it.sort, it.uniq.size ] }).to eq([ [ 41, true, 41 ] ] * 2)
    end

    it "目前的點畫在網址的要留分鐘數：休息 15、晚到 6 時橫座標是 178.8，座標跟曲線資料第 21 點的 marker 一樣" do
      rendered = render_trade(*four_layovers, late: 6)
      drawn = { "x" => dot(rendered, "lower")["cx"].to_f, "lower_y" => dot(rendered, "lower")["cy"].to_f, "upper_y" => dot(rendered, "upper")["cy"].to_f }
      expect([ drawn["x"], drawn ]).to eq([ 178.8, curve_data(rendered)["points"][21]["marker"] ])
    end

    it "沒有折返停留、或選的小時沒有折返停留時，沒有圖，也沒有曲線資料" do
      renders = [ render_trade(route_day(day: Date.new(2026, 10, 21), layovers: [])), render_trade(*four_layovers, hour_range: 12...13) ]
      expect(renders.map { it.css("svg[data-chart=buffer-curve], script[data-buffer-trade-curve]").size }).to eq([ 0, 0 ])
    end
  end

  describe "逐小時" do
    # Each hour's row: the hour and its lower and upper added vehicles.
    def hourly_rows(rendered) = rendered.css("details[data-hourly] tr[data-hour]").map { |row| [ row["data-hour"], *row.css("[data-hourly-bound]").map { it.text.squish } ] }

    it "四次停留、休息 15 時有 8 點與 9 點兩列：0.1／0.4、0.1／0.1" do
      expect(hourly_rows(render_trade(*four_layovers))).to eq([ %w[8 0.1 0.4], %w[9 0.1 0.1] ])
    end

    it "逐小時的表預設收起來" do
      details = render_trade(route_day).at_css("details[data-hourly]")
      expect([ details.nil?, details&.key?("open") ]).to eq([ false, false ])
    end

    it "只看 9 點到 10 點時只有 9 點一列" do
      expect(hourly_rows(render_trade(*four_layovers, hour_range: 9...10))).to eq([ %w[9 0.1 0.1] ])
    end

    it "每一列跟曲線資料的 hours 與目前那一點的 hourly 對得上" do
      rendered = render_trade(*four_layovers, late: 6)
      data = JSON.parse(rendered.at_css("script[data-buffer-trade-curve]").text)
      rows = rendered.css("details[data-hourly] tr[data-hour]").map { |row| [ row.at_css("td").text.squish, row.css("[data-hourly-bound]").map(&:text) ] }
      expect(rows).to eq(data["hours"].zip(data["points"][21]["hourly"]))
    end
  end
end
