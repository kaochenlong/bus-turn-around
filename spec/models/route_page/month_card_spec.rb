require "rails_helper"

RSpec.describe RoutePage::MonthCard, type: :model do
  let(:route_card) { create(:route_card) }
  let(:month_card) { described_class.new(route_card) }

  def store(day, **attributes) = create(:route_day, day: Date.iso8601(day), rest_windows_loaded: true, published_schedule_day: Date.iso8601(day), **attributes)

  describe "一個月就是一組路線日" do
    before do
      store("2026-10-19")
      store("2026-10-25", day_type: "holiday")
      store("2026-09-30")
      store("2026-11-02")
      store("2026-10-20", route_id: 9100)
    end

    it "平日：這個月這條路線的平日" do
      expect(month_card.weekdays.map { it.day.iso8601 }).to eq(%w[2026-10-19])
    end

    it "假日：這個月這條路線的假日" do
      expect(month_card.holidays.map { it.day.iso8601 }).to eq(%w[2026-10-25])
    end
  end

  it "認得 :weekday 與 :holiday，其他的直接失敗" do
    expect { month_card.layover_stats(:typhoon) }.to raise_error(KeyError)
  end

  it "stop_go_backs 是設定裡的停車端" do
    expect(month_card.stop_go_backs).to eq(RoutePage.ends(9001).stopping_go_backs)
  end

  describe "把一組路線日交給既有物件" do
    let(:weekday) { store("2026-10-19") }
    let(:holiday) { store("2026-10-25", day_type: "holiday") }

    # A layover of 10 minutes on a weekday, and of 20 on a holiday.
    before do
      create(:layover, route_day: weekday, go_back: 1)
      create(:layover, route_day: holiday, go_back: 1, end_time: Time.zone.parse("2026-10-25 08:00"), next_start_time: Time.zone.parse("2026-10-25 08:20"))
      weekday.stops.create!(go_back: 1, seq: 5, stop_name: "甲站")
      holiday.stops.create!(go_back: 1, seq: 5, stop_name: "甲站")
    end

    it "layover_stats 平日假日分開" do
      expect([ :weekday, :holiday ].map { |set| month_card.layover_stats(set).rows.sole.percentiles[1] }).to eq([ 10.0, 20.0 ])
    end

    it "同一個物件只建一次" do
      first = month_card.layover_stats(:weekday)
      expect(month_card.layover_stats(:weekday)).to be(first)
    end

    it "layover_hours 只算平日" do
      expect(month_card.layover_hours.rows(1).map(&:n_layovers)).to eq([ 1 ])
    end

    it "buffer_trades 是 10、15、20 分鐘三個試算" do
      expect(month_card.buffer_trades(:weekday).map(&:minutes)).to eq([ 10, 15, 20 ])
    end

    it "days 從第一個載入的日子起，含假日" do
      expect(month_card.days.rows.filter_map { it.day_type }).to eq(%w[weekday holiday])
    end

    it "snapshot_changes 看平日與假日全部的日子" do
      expect(month_card.snapshot_changes.n_days).to eq(2)
    end
  end

  describe "#schedule" do
    it "公告對量到的，只用這個日型別的日子" do
      day = store("2026-10-19")
      create(:route_day_published_headway, route_day: day)
      store("2026-10-25", day_type: "holiday")
      expect(month_card.schedule(:weekday).versions.sole.days).to eq([ day.day ])
    end
  end

  describe "#peak_periods" do
    def add_period(route_day, from, to, low, high)
      create(:route_day_published_headway, route_day:, start_minute: from, end_minute: to, low_minutes: low, high_minutes: high)
    end

    it "下界最小的時段，照時間排" do
      day = store("2026-10-19")
      [ [ 390, 480, 4, 6 ], [ 480, 960, 10, 15 ], [ 960, 1050, 4, 6 ] ].each { |period| add_period(day, *period) }
      expect(month_card.peak_periods(:weekday).map(&:start_minute)).to eq([ 390, 960 ])
    end

    it "公告改過：看最新的版本" do
      add_period(store("2026-10-19"), 390, 480, 4, 6)
      add_period(store("2026-10-20").tap { it.published_headways.delete_all }, 390, 480, 8, 10).update!(date_value: 3)
      expect(month_card.peak_periods(:weekday).map(&:low_minutes)).to eq([ 8 ])
    end

    it "沒有時段：空的" do
      store("2026-10-19")
      expect(month_card.peak_periods(:weekday)).to eq([])
    end

    it "這個月沒有這個日型別的日子：空的" do
      expect(month_card.peak_periods(:holiday)).to eq([])
    end
  end

  describe "#operators" do
    def add_depot(route_day, provider_name, n_buses, station_id)
      create(:route_day_depot, route_day:, provider_name:, n_buses:, station_id:, station_name: "站#{station_id}")
    end

    it "最新一個涵蓋日的業者，車多的在前，同一家只列一次" do
      add_depot(store("2026-10-19"), "舊客運", 9, 1)
      latest = store("2026-10-20")
      { "乙客運" => [ 3, 2 ], "甲客運" => [ 5, 3 ] }.each { |name, (n_buses, station_id)| add_depot(latest, name, n_buses, station_id) }
      add_depot(latest, "甲客運", 1, 4)
      expect(month_card.operators).to eq(%w[甲客運 乙客運])
    end

    it "業者名稱空的不列" do
      add_depot(store("2026-10-19"), "", 9, 1)
      expect(month_card.operators).to eq([])
    end

    it "沒有路線日：空的" do
      expect(month_card.operators).to eq([])
    end
  end

  describe "路線的名字與 Id" do
    it "名字與起迄取最新一個涵蓋日" do
      store("2026-10-19", route_name: "舊名")
      store("2026-10-20", route_name: "新名", departure: "天母", destination: "青年公園")
      expect([ month_card.route_name, month_card.departure, month_card.destination ]).to eq([ "新名", "天母", "青年公園" ])
    end

    it "這個月一天都沒有：名字用路線 Id" do
      expect(month_card.route_name).to eq("9001")
    end

    it "route_ids 含成員路線" do
      expect(month_card.route_ids).to eq([ 9001, 9050 ])
    end
  end

  describe "#summary" do
    # Four weekday layovers ending in direction 1 of 10, 10, 20 and 20 minutes
    # stored, with windows of each rule and a morning period.
    before do
      day = store("2026-10-19")
      day.stops.create!([ { go_back: 0, seq: 0, stop_name: "戊站" }, { go_back: 1, seq: 5, stop_name: "甲站" } ])
      [ 10, 10, 20, 20 ].each_with_index do |minutes, index|
        create(:layover, route_day: day, bus_id: "TEST-#{index}", next_start_time: Time.zone.parse("2026-10-19 08:00") + minutes.minutes)
      end
      [ true, true, false ].each_with_index { |flagged, index| create(:route_day_rest_window, route_day: day, bus_id: "TEST-#{index}", flagged:) }
      create(:route_day_rest_window, route_day: day, rule: "six_hours", flagged: false)
    end

    it "存得進 jsonb：鍵都是字串，讀回來一樣" do
      summary = month_card.summary
      route_card.update!(summary:)
      expect(route_card.reload.summary).to eq(summary)
    end

    it "平日天數與兩條規則的比例，百分比取一位小數" do
      expect(month_card.summary.values_at("weekdays", "four_hours_share", "six_hours_share")).to eq([ 1, 66.7, 0.0 ])
    end

    it "不到 15 分鐘的比例與 p10，鍵是停車端的方向" do
      expect(month_card.summary.values_at("short_share", "p10")).to eq([ { "0" => nil, "1" => 50.0 }, { "0" => nil, "1" => 10.0 } ])
    end

    it "早尖峰路上的車是整數" do
      create(:route_day_published_headway, route_day: RouteDay.first, start_minute: 360, end_minute: 420)
      create(:trip, route_day: RouteDay.first, start_time: Time.zone.parse("2026-10-19 06:00"), end_time: Time.zone.parse("2026-10-19 07:00"))
      expect(month_card.summary["morning_on_road"]).to eq(1)
    end

    it "沒有時段：早尖峰路上的車是空的" do
      expect(month_card.summary["morning_on_road"]).to be_nil
    end
  end

  describe "#needs_reload?" do
    it "每一天都重算過：不用" do
      store("2026-10-19")
      expect(month_card).not_to be_needs_reload
    end

    it "有一天沒有視窗：要" do
      store("2026-10-19", rest_windows_loaded: false)
      expect(month_card).to be_needs_reload
    end

    it "有一個假日沒有公告：要" do
      store("2026-10-25", day_type: "holiday", published_schedule_day: nil)
      expect(month_card).to be_needs_reload
    end

    it "沒有路線日：不用" do
      expect(month_card).not_to be_needs_reload
    end
  end
end
