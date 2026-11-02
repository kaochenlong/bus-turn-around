# frozen_string_literal: true

require "rails_helper"

RSpec.describe MonthCardSummaryComponent, type: :component do
  let(:coverage) do
    { "calendar_weekdays" => 20, "calendar_holidays" => 11, "loaded_weekdays" => 7, "loaded_holidays" => 3,
      "missing" => [ { "from" => "2026-10-01", "to" => "2026-10-18", "day_type" => nil, "reason" => "還沒開始收資料" },
                     { "from" => "2026-10-23", "to" => "2026-10-24", "day_type" => nil, "reason" => "颱風停駛" },
                     { "from" => "2026-10-30", "to" => "2026-10-30", "day_type" => "weekday", "reason" => "原始檔不齊" } ] }
  end

  def route_card(route_id: 9001, month: Date.new(2026, 10, 1), **attributes) = create(:route_card, route_id:, month:, coverage:, **attributes)

  def render_card(card = route_card) = render_inline(described_class.new(month_card: RoutePage::MonthCard.new(card)))

  def store(day, route_id: 9001, **attributes)
    create(:route_day, route_id:, day: Date.iso8601(day), rest_windows_loaded: true, published_schedule_day: Date.iso8601(day), **attributes)
  end

  # The last stop of each direction and one layover per length at the end of direction 1.
  def fill_layovers(route_day, *minutes, go_back: 1)
    route_day.stops.create!([ { go_back: 0, seq: 4, stop_name: "戊站" }, { go_back: 1, seq: 9, stop_name: "甲站" } ]) if route_day.stops.none?
    end_time = Time.zone.parse("#{route_day.day} 08:00")
    minutes.each_with_index { |length, index| create(:layover, route_day:, go_back:, bus_id: "TEST-#{index}", end_time:, next_start_time: end_time + length.minutes) }
  end

  def cell(row, set) = page.find("tr[data-row='#{row}'] td[data-set='#{set}']").text

  describe "頁首" do
    it "路線名、起迄、路線 Id 與業者一行" do
      route_day = store("2026-10-19", route_name: "測試幹線", departure: "天母", destination: "青年公園")
      create(:route_day_depot, route_day:, provider_name: "光華巴士")
      render_card
      expect([ page.find("h1").text, page.find("[data-route-line]").text ]).to eq([ "測試幹線", "天母－青年公園｜路線 Id 9001・9050｜光華巴士" ])
    end

    it "沒有存任何一天：名字用路線 Id，起迄與業者不寫" do
      render_card
      expect([ page.find("h1").text, page.find("[data-route-line]").text ]).to eq([ "9001", "路線 Id 9001・9050" ])
    end

    it "年月" do
      render_card
      expect(page.find("[data-month]").text).to eq("2026 年 10 月")
    end
  end

  describe "涵蓋那一句" do
    before { render_card }

    let(:sentence) { page.find("[data-coverage]").text }

    it "這個月有幾天、載入幾天" do
      expect(sentence).to include("涵蓋 7 個平日（這個月有 20 個）、3 個假日（這個月有 11 個）")
    end

    it "少的日子與原因：一段、相鄰兩天、一天各有寫法" do
      expect(sentence).to include("少的日子：10-01 到 10-18 還沒開始收資料；10-23、10-24 颱風停駛；10-30 原始檔不齊。")
    end

    it "產出日期與分析程式的版本" do
      expect(sentence).to include("產出日期 #{Date.current.iso8601}，分析程式 #{ProgramVersion.current}")
    end
  end

  it "沒有少的日子：不寫那一段" do
    render_card(create(:route_card))
    expect(page.find("[data-coverage]").text).not_to include("少的日子")
  end

  describe "停車端的組" do
    it "兩個停車端：各一組，用末站命名" do
      fill_layovers(store("2026-10-19"), 10)
      render_card
      expect(page.all("[data-group^='end-']").map(&:text)).to eq([ "折返停留：停車端（戊站）", "折返停留：停車端（甲站）" ])
    end

    it "一個停車端：一組" do
      fill_layovers(store("2026-10-19", route_id: 15373), 10)
      render_card(route_card(route_id: 15373))
      expect(page.all("[data-group^='end-']").map(&:text)).to eq([ "折返停留：停車端（甲站）" ])
    end

    it "一天都沒有存：照樣一組，只寫停車端" do
      render_card(route_card(route_id: 15373))
      expect(page.all("[data-group^='end-']").map(&:text)).to eq([ "折返停留：停車端" ])
    end

    it "不到 15 分鐘的比例、逐日範圍、p10／p50" do
      fill_layovers(store("2026-10-19"), 10, 20)
      fill_layovers(store("2026-10-20"), 10, 10, 20, 20)
      render_card
      expect([ cell("short_share-1", "weekday"), cell("short_range-1", "weekday"), cell("percentiles-1", "weekday") ]).to eq([ "50.0%", "50%–50%", "10.0／15.0 分" ])
    end
  end

  describe "兩條規則" do
    it "比例帶分子分母" do
      route_day = store("2026-10-19")
      [ true, true, false ].each_with_index { |flagged, index| create(:route_day_rest_window, route_day:, bus_id: "TEST-#{index}", flagged:) }
      render_card
      expect(cell("four_hours", "weekday")).to eq("66.7%（2／3）")
    end

    it "沒有視窗：—" do
      store("2026-10-19")
      render_card
      expect(cell("six_hours", "weekday")).to eq("—")
    end
  end

  describe "班表的三列" do
    def add_period(route_day, from, to, low, high)
      create(:route_day_published_headway, route_day:, date_value: route_day.day.wday + 1, start_minute: from, end_minute: to, low_minutes: low, high_minutes: high)
    end

    # Two trips of direction 0 and one of direction 1 starting in the morning
    # period, and one of direction 0 in the evening one.
    def store_two_peaks
      route_day = store("2026-10-19")
      [ [ 390, 480, 4, 6 ], [ 480, 960, 10, 15 ], [ 960, 1050, 4, 6 ] ].each { |period| add_period(route_day, *period) }
      { "06:30" => [ "A", 0 ], "06:40" => [ "B", 0 ], "06:50" => [ "C", 1 ], "16:10" => [ "D", 0 ] }.each do |clock, (bus_id, go_back)|
        start_time = Time.zone.parse("2026-10-19 #{clock}")
        create(:trip, route_day:, bus_id:, go_back:, start_time:, end_time: start_time + 2.hours)
      end
    end

    it "尖峰是下界最小的時段：公告班距" do
      store_two_peaks
      render_card
      expect(cell("peak_headway", "weekday")).to eq("4–6 分一班")
    end

    it "兩個尖峰：標早與晚" do
      store_two_peaks
      render_card
      expect(cell("peak_departures", "weekday")).to eq("早 1.3／0.7、晚 0.7／0.0")
    end

    it "路上的車與照公告要幾台，沒有週期時要幾台是 —" do
      store_two_peaks
      render_card
      expect(cell("peak_road", "weekday")).to match(/\A早 \d+／—、晚 \d+／—\z/)
    end

    it "只有一個尖峰：不標早晚" do
      add_period(store("2026-10-19"), 360, 480, 5, 10)
      render_card
      expect(cell("peak_departures", "weekday")).to eq("0.0／0.0")
    end

    it "沒有時段：三列都是 —" do
      store("2026-10-19")
      render_card
      expect(%w[peak_headway peak_departures peak_road].map { cell(it, "weekday") }).to eq(%w[— — —])
    end
  end

  describe "假日那一欄" do
    it "這個月沒有存假日：每一格都是 —" do
      fill_layovers(store("2026-10-19"), 10)
      render_card
      expect(page.all("td[data-set='holiday']").map(&:text).uniq).to eq([ "—" ])
    end

    it "有存假日：讀假日的數字，不混平日" do
      fill_layovers(store("2026-10-19"), 10)
      fill_layovers(store("2026-10-25", day_type: "holiday"), 20)
      render_card
      expect([ cell("short_share-1", "weekday"), cell("short_share-1", "holiday") ]).to eq([ "100.0%", "0.0%" ])
    end
  end

  describe "上月平日那一欄" do
    it "上個月有卡：讀上個月平日重算的數字" do
      fill_layovers(store("2026-09-21"), 10, 10, 20, 20, 20)
      route_card(month: Date.new(2026, 9, 1))
      render_card
      expect(cell("short_share-1", "previous")).to eq("40.0%")
    end

    it "上個月沒有卡：每一格都是 —" do
      fill_layovers(store("2026-10-19"), 10)
      render_card
      expect(page.all("td[data-set='previous']").map(&:text).uniq).to eq([ "—" ])
    end
  end

  describe "這個月看到的事" do
    it "每一句一項" do
      fill_layovers(store("2026-10-19"), 10)
      render_card
      expect(page.all("[data-findings] li").map(&:text)).to include("甲站的折返停留有 100% 不到 15 分鐘。")
    end

    it "一句都沒有：標題也不出現" do
      render_card(route_card(route_id: 15373))
      expect(page).to have_no_css("[data-findings]")
    end
  end

  it "區塊標記是 summary" do
    render_card
    expect(page).to have_css("section[data-card-section='summary']")
  end
end
