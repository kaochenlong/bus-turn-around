require "rails_helper"

RSpec.describe RoutePage::MonthDays, type: :model do
  let(:reason) { "原始檔不齊" }

  def missing(from, to, reason) = { "from" => from, "to" => to, "day_type" => nil, "reason" => reason }

  def route_card(*missing_entries)
    create(:route_card, coverage: { "calendar_weekdays" => 20, "calendar_holidays" => 11, "loaded_weekdays" => 0, "loaded_holidays" => 0, "missing" => missing_entries })
  end

  def rows(card = route_card, stop_go_backs: [ 1 ]) = described_class.new(card, stop_go_backs:).rows

  def store(day, **attributes) = create(:route_day, day: Date.iso8601(day), **attributes)

  def row(day = "2026-10-19") = rows.find { it.day == Date.iso8601(day) }

  describe "哪幾天有一列" do
    it "從第一個載入的日子起到月底，每天一列" do
      store("2026-10-29")
      expect(rows.map { it.day.iso8601 }).to eq(%w[2026-10-29 2026-10-30 2026-10-31])
    end

    it "一天都沒有載入：沒有列" do
      expect(rows).to eq([])
    end

    it "別的月份與別條路線的日子不算" do
      store("2026-09-30")
      store("2026-10-30", route_id: 9100)
      expect(rows).to eq([])
    end
  end

  describe "少的日子" do
    before { store("2026-10-28") }

    let(:rows_with_gap) { rows(route_card(missing("2026-10-01", "2026-10-18", "還沒開始收資料"), missing("2026-10-29", "2026-10-30", reason))) }

    it "一段裡的每一天各一列，寫原因" do
      expect(rows_with_gap.map { [ it.day.iso8601, it.reason ] }).to eq([ [ "2026-10-28", nil ], [ "2026-10-29", reason ], [ "2026-10-30", reason ], [ "2026-10-31", nil ] ])
    end

    it "沒有數字" do
      gap = rows_with_gap.second
      expect([ gap.n_trips, gap.complete_share, gap.missing_stop_rate, gap.n_vehicles, gap.stopping, gap.four_hours_share ]).to eq([ nil, nil, nil, nil, {}, nil ])
    end

    it "第一個載入的日子之前的少的日子沒有列" do
      expect(rows_with_gap.map(&:day).min).to eq(Date.new(2026, 10, 28))
    end
  end

  describe "載入的日子的數字" do
    let(:route_day) { store("2026-10-19", day_note: "補假", day_type: "holiday") }

    it "日型別與備註" do
      route_day
      expect(row.to_h.values_at(:day_type, :day_note)).to eq([ "holiday", "補假" ])
    end

    it "趟次 4、完整 3、2 台車" do
      { "06:00" => "TEST-0001", "07:00" => "TEST-0001", "08:00" => "TEST-0002" }.each { |clock, bus_id| create(:trip, route_day:, bus_id:, start_time: Time.zone.parse("2026-10-19 #{clock}")) }
      create(:trip, route_day:, bus_id: "TEST-0002", start_time: Time.zone.parse("2026-10-19 09:00"), completeness: "missing_end")
      expect(row.to_h.values_at(:n_trips, :complete_share, :n_vehicles)).to eq([ 4, 0.75, 2 ])
    end

    it "沒有趟次：0 趟，比例是空的" do
      route_day
      expect(row.to_h.values_at(:n_trips, :complete_share, :missing_stop_rate, :n_vehicles)).to eq([ 0, nil, nil, 0 ])
    end

    describe "漏站率：完整趟次沒有事件的站，除以該方向的站" do
      def add_stops(route_day, count, route_id: 9001, go_back: 0)
        count.times { route_day.stops.create!(route_id:, go_back:, seq: it, stop_name: "站#{it}") }
      end

      it "5 站的方向，一趟觀測到 4 站、一趟 5 站：1／10" do
        add_stops(route_day, 5)
        create(:trip, route_day:, n_stops_observed: 4)
        create(:trip, route_day:, n_stops_observed: 5, start_time: Time.zone.parse("2026-10-19 08:00"))
        expect(row.missing_stop_rate).to eq(0.1)
      end

      it "不完整的趟次不算" do
        add_stops(route_day, 5)
        create(:trip, route_day:, n_stops_observed: 2, completeness: "missing_end")
        expect(row.missing_stop_rate).to be_nil
      end

      it "成員路線的趟次用自己的站數：10 站的成員路線一趟觀測到 8 站，5 站的頁面路線一趟 5 站：2／15" do
        add_stops(route_day, 5)
        add_stops(route_day, 10, route_id: 9050)
        create(:trip, route_day:, route_id: 9050, n_stops_observed: 8)
        create(:trip, route_day:, n_stops_observed: 5, start_time: Time.zone.parse("2026-10-19 08:00"))
        expect(row.missing_stop_rate).to eq(2.0 / 15)
      end
    end

    it "停車端的筆數與不到 15 分鐘的比例，只算給的那一端" do
      end_time = Time.zone.parse("2026-10-19 08:00")
      create(:layover, route_day:, bus_id: "TEST-0001", go_back: 1, end_time:, next_start_time: end_time + 10.minutes)
      create(:layover, route_day:, bus_id: "TEST-0002", go_back: 1, end_time:, next_start_time: end_time + 20.minutes)
      create(:layover, route_day:, bus_id: "TEST-0003", go_back: 0, end_time:, next_start_time: end_time + 1.minute)
      expect(row.stopping.transform_values(&:to_h)).to eq(1 => { n_layovers: 2, short_share: 0.5 })
    end

    it "停車端沒有折返停留：0 筆，比例是空的" do
      route_day
      expect(row.stopping.fetch(1).to_h).to eq(n_layovers: 0, short_share: nil)
    end

    it "連續 4 小時的比例只看 4 小時的視窗" do
      [ [ "TEST-0001", true ], [ "TEST-0002", false ] ].each { |bus_id, flagged| create(:route_day_rest_window, route_day:, bus_id:, flagged:) }
      create(:route_day_rest_window, route_day:, bus_id: "TEST-0003", rule: "six_hours", flagged: true)
      expect(row.four_hours_share).to eq(0.5)
    end

    it "沒有視窗：空的" do
      route_day
      expect(row.four_hours_share).to be_nil
    end
  end

  describe "#short_range" do
    def add_layover(route_day, bus_id, minutes)
      end_time = Time.zone.parse("#{route_day.day} 08:00")
      create(:layover, route_day:, bus_id:, end_time:, next_start_time: end_time + minutes.minutes)
    end

    it "同一種日型別逐日的最小與最大比例，另一種與沒有折返停留的日子不算" do
      store("2026-10-19").tap { |day| [ [ "A", 10 ], [ "B", 20 ] ].each { |bus_id, minutes| add_layover(day, bus_id, minutes) } }
      add_layover(store("2026-10-20"), "A", 10)
      store("2026-10-21")
      add_layover(store("2026-10-25", day_type: "holiday"), "A", 20)
      expect(described_class.new(route_card, stop_go_backs: [ 1 ]).short_range("weekday", 1)).to eq([ 0.5, 1.0 ])
    end

    it "沒有資料：nil" do
      store("2026-10-19")
      expect(described_class.new(route_card, stop_go_backs: [ 1 ]).short_range("weekday", 1)).to be_nil
    end
  end

  # How many queries reading the rows of a card takes.
  def queries_for(card)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { described_class.new(card, stop_go_backs: [ 1 ]).rows }
    count
  end

  it "查詢次數不隨天數增加" do
    card = route_card
    create(:trip, route_day: store("2026-10-19"))
    one_day = queries_for(card)
    (20..22).each { create(:trip, route_day: store("2026-10-#{it}")) }
    expect(queries_for(card)).to eq(one_day)
  end
end
