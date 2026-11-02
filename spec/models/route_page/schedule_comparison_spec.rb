require "rails_helper"

RSpec.describe RoutePage::ScheduleComparison, type: :model do
  # All-day cycle p50 as RoutePage::Cycles#total reports it.
  def cycles_with(p50)
    row = RoutePage::Cycles::Row.new(hour: nil, n_round_trips: 0, round_trip_percentiles: [ nil, nil ], n_cycles: 0, cycle_percentiles: [ nil, p50 ])
    instance_double(RoutePage::Cycles, total: row)
  end

  def comparison(days = RouteDay.all, route_id: 9001, cycle_p50: 182.2) = described_class.new(days, route_id:, cycles: cycles_with(cycle_p50))

  def minute(clock)
    hour, minute = clock.split(":").map { Integer(it, 10) }
    hour * 60 + minute
  end

  def store_day(day, day_type: "weekday", **attributes)
    create(:route_day, day: Date.iso8601(day), day_type:, published_schedule_day: Date.iso8601(day), **attributes)
  end

  def add_period(route_day, from, to, low, high, date_value: 2, route_id: 9001, path_attribute_id: route_id)
    create(:route_day_published_headway, route_day:, route_id:, path_attribute_id:, date_value:, start_minute: minute(from), end_minute: minute(to),
                                         low_minutes: low, high_minutes: high)
  end

  def period_values(period) = [ period.start_minute, period.end_minute, period.low_minutes, period.high_minutes ]

  # A trip of the day between two clock times; 24:10 is ten past midnight.
  def add_trip(route_day, from, to, bus_id: "TEST-0001", go_back: 0, route_id: 9001, completeness: "complete")
    midnight = Time.zone.local(route_day.day.year, route_day.day.month, route_day.day.day)
    route_day.trips.create!(bus_id:, path_attribute_id: route_id, route_id:, go_back:, band: "other", start_time: midnight + minute(from).minutes,
                            end_time: midnight + minute(to).minutes, first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5, completeness:,
                            start_from_arrival: false, end_from_departure: false)
  end

  # `count` trips of a direction starting in the 06 hour, one minute apart.
  def add_departures(route_day, count, go_back: 0, route_id: 9001)
    count.times { add_trip(route_day, format("06:%02d", it), "06:50", bus_id: "TEST-#{go_back}-#{route_id}", go_back:, route_id:) }
  end

  def first_period(days = RouteDay.all, **options) = comparison(days, **options).versions.first.periods.first

  # A Monday with the period 06:00 to 07:00.
  def monday_with_hour_period(day = "2026-10-19") = store_day(day).tap { add_period(it, "06:00", "07:00", 5, 10) }

  describe ".date_value" do
    [ [ "2026-10-19", "weekday", 2 ],
      [ "2026-10-23", "weekday", 6 ],
      [ "2026-10-25", "holiday", 1 ],
      [ "2026-10-26", "holiday", 1 ],
      [ "2026-10-31", "holiday", 7 ],
      [ "2026-11-07", "weekday", 2 ] ].each do |day, day_type, date_value|
      it "#{day} #{day_type} 用 #{date_value}" do
        expect(described_class.date_value(Date.iso8601(day), day_type)).to eq(date_value)
      end
    end

    it "不認得的日型別直接失敗，不猜" do
      expect { described_class.date_value(Date.iso8601("2026-10-19"), "typhoon") }.to raise_error(ArgumentError, /typhoon/)
    end
  end

  describe "時段列" do
    it "只讀那一天用的 DateValue：週日假日讀 1，不讀 2" do
      route_day = store_day("2026-10-25", day_type: "holiday")
      add_period(route_day, "06:00", "22:00", 20, 30, date_value: 1)
      add_period(route_day, "06:00", "08:00", 5, 10, date_value: 2)
      expect(comparison.versions.first.periods.map { period_values(it) }).to eq([ [ 360, 1320, 20, 30 ] ])
    end

    it "同一條路線兩條附屬路線內容相同：只有一列" do
      route_day = store_day("2026-10-19")
      [ 157462, 157463 ].each { add_period(route_day, "06:00", "07:30", 4, 6, path_attribute_id: it) }
      expect(comparison.versions.first.periods.map { period_values(it) }).to eq([ [ 360, 450, 4, 6 ] ])
    end

    it "兩條附屬路線內容不同：兩邊的列都出現，照起點排序" do
      route_day = store_day("2026-10-19")
      add_period(route_day, "08:00", "09:00", 10, 15, path_attribute_id: 157463)
      add_period(route_day, "06:00", "07:30", 4, 6, path_attribute_id: 157462)
      expect(comparison.versions.first.periods.map(&:start_minute)).to eq([ 360, 480 ])
    end

    it "別條路線 Id 的列不算" do
      route_day = store_day("2026-10-19")
      add_period(route_day, "06:00", "07:30", 4, 6, route_id: 9050)
      expect(comparison.versions.first.periods).to eq([])
    end

    it "公告換算的每小時班數：班距 5 到 10 分是 6.0 到 12.0" do
      add_period(store_day("2026-10-19"), "06:00", "08:00", 5, 10)
      period = comparison.versions.first.periods.first
      expect([ period.per_hour_low, period.per_hour_high ]).to eq([ 6.0, 12.0 ])
    end
  end

  describe "量到的每小時發車" do
    it "週一 06:00 到 08:00，去程 6 趟、返程 3 趟：每小時 3.0 與 1.5" do
      route_day = store_day("2026-10-19").tap { add_period(it, "06:00", "08:00", 5, 10) }
      add_departures(route_day, 6)
      add_departures(route_day, 3, go_back: 1)
      expect(first_period.departures_per_hour).to eq(0 => 3.0, 1 => 1.5)
    end

    it "兩個平日，去程各 6 趟與 2 趟：每小時 2.0" do
      [ [ "2026-10-19", 6 ], [ "2026-10-20", 2 ] ].each do |day, count|
        add_departures(store_day(day).tap { add_period(it, "06:00", "08:00", 5, 10, date_value: it.day.wday + 1) }, count)
      end
      expect(first_period.departures_per_hour.fetch(0)).to eq(2.0)
    end

    it "不四捨五入：一小時半裡 1 趟是 2/3" do
      route_day = store_day("2026-10-19").tap { add_period(it, "06:00", "07:30", 4, 6) }
      add_departures(route_day, 1)
      expect(first_period.departures_per_hour.fetch(0)).to eq(1 / 1.5)
    end

    it "不分完整性" do
      route_day = monday_with_hour_period
      add_trip(route_day, "06:10", "06:50", completeness: "missing_both")
      expect(first_period.departures_per_hour.fetch(0)).to eq(1.0)
    end

    it "起點落在時段開始算，落在時段結束不算" do
      route_day = monday_with_hour_period
      add_trip(route_day, "06:00", "06:50")
      add_trip(route_day, "07:00", "07:50", bus_id: "TEST-0002")
      expect(first_period.departures_per_hour.fetch(0)).to eq(1.0)
    end

    it "只算頁面路線的趟次，成員路線的不算" do
      route_day = monday_with_hour_period
      add_departures(route_day, 2, route_id: 9050)
      expect(first_period.departures_per_hour.fetch(0)).to eq(0.0)
    end

    it "時刻照台北時間：台北 06:30（前一天 UTC 22:30）的趟次落在 06:00 到 07:00" do
      add_trip(monday_with_hour_period, "06:30", "06:50")
      expect(first_period.departures_per_hour.fetch(0)).to eq(1.0)
    end
  end

  describe "路上的車" do
    it "06:00 到 07:00，A、B 全程在跑，C 從 06:40 到 08:00：兩格 2 與 3，平均 2.5" do
      route_day = monday_with_hour_period
      add_trip(route_day, "05:50", "07:10", bus_id: "A")
      add_trip(route_day, "05:55", "07:20", bus_id: "B")
      add_trip(route_day, "06:40", "08:00", bus_id: "C")
      expect(first_period.on_road).to eq(2.5)
    end

    it "06:30 剛好到站、沒有別的趟次：只算 06:00 到 06:30 那一格" do
      add_trip(monday_with_hour_period, "06:00", "06:30")
      expect(first_period.on_road).to eq(0.5)
    end

    it "06:30 才發車：只算 06:30 到 07:00 那一格" do
      add_trip(monday_with_hour_period, "06:30", "06:50")
      expect(first_period.on_road).to eq(0.5)
    end

    it "同一台車在同一格跑兩趟只算一台" do
      route_day = monday_with_hour_period
      add_trip(route_day, "06:00", "06:10")
      add_trip(route_day, "06:15", "06:25")
      expect(first_period.on_road).to eq(0.5)
    end

    it "在折返停留裡的車不算：兩趟之間整格沒有趟次的那一格是 0" do
      route_day = store_day("2026-10-19").tap { add_period(it, "06:00", "07:30", 5, 10) }
      add_trip(route_day, "06:00", "06:20")
      add_trip(route_day, "07:10", "07:30")
      expect(first_period.on_road).to eq(2.0 / 3)
    end

    it "所有天所有格取平均：一天 2 台、一天沒有車是 1.0" do
      add_trip(monday_with_hour_period, "06:00", "07:00")
      add_trip(RouteDay.first, "06:00", "07:00", bus_id: "TEST-0002")
      store_day("2026-10-26", day_type: "weekday").tap { add_period(it, "06:00", "07:00", 5, 10) }
      expect(first_period.on_road).to eq(1.0)
    end

    it "時段長度不是 30 分鐘的倍數：最後一格短一點，超過時段的不算" do
      route_day = store_day("2026-10-19").tap { add_period(it, "06:00", "06:45", 5, 10) }
      add_trip(route_day, "06:40", "07:00")
      add_trip(route_day, "06:50", "07:00", bus_id: "TEST-0002")
      expect(first_period.on_road).to eq(0.5)
    end

    it "只算頁面路線的車，成員路線的不算" do
      add_trip(monday_with_hour_period, "06:00", "07:00", route_id: 9050)
      expect(first_period.on_road).to eq(0.0)
    end

    it "到午夜的時段：跨午夜那一趟算到 24:00 為止" do
      route_day = store_day("2026-10-19").tap { add_period(it, "23:00", "24:00", 30, 30) }
      add_trip(route_day, "23:40", "24:50")
      expect(first_period.on_road).to eq(0.5)
    end
  end

  describe "照公告要幾台" do
    it "週期中位數 182.2 分，班距 4 到 6 分：30 到 46 台" do
      store_day("2026-10-19").tap { add_period(it, "06:30", "08:00", 4, 6) }
      period = first_period
      expect([ period.needed_low, period.needed_high ]).to eq([ 30, 46 ])
    end

    it "沒有週期：兩個都是 nil" do
      store_day("2026-10-19").tap { add_period(it, "06:30", "08:00", 4, 6) }
      period = first_period(cycle_p50: nil)
      expect([ period.needed_low, period.needed_high ]).to eq([ nil, nil ])
    end
  end

  describe "#needs_reload?" do
    it "有一天沒有 published_schedule_day：要重算" do
      store_day("2026-10-19")
      store_day("2026-10-20", published_schedule_day: nil)
      expect(comparison).to be_needs_reload
    end

    it "每一天都有：不用" do
      store_day("2026-10-19")
      expect(comparison).not_to be_needs_reload
    end

    it "沒有路線日：不用" do
      expect(comparison).not_to be_needs_reload
    end
  end

  describe "版本" do
    # Three days of a week, the periods given per day; each day reads its own date value.
    def store_weekday(day, low, high)
      store_day(day).tap { add_period(it, "06:00", "08:00", low, high, date_value: it.day.wday + 1) }
    end

    it "2026-11-02、03 班距 4 到 6，11-04 改 8 到 10：兩個版本，各寫哪幾天" do
      [ [ "2026-11-02", 4, 6 ], [ "2026-11-03", 4, 6 ], [ "2026-11-04", 8, 10 ] ].each { |day, low, high| store_weekday(day, low, high) }
      expect(comparison.versions.map { it.days.map(&:iso8601) }).to eq([ %w[2026-11-02 2026-11-03], %w[2026-11-04] ])
    end

    it "每個版本只用自己那幾天的趟次" do
      add_departures(store_weekday("2026-11-02", 4, 6), 4)
      add_departures(store_weekday("2026-11-03", 4, 6), 2)
      add_departures(store_weekday("2026-11-04", 8, 10), 30)
      expect(comparison.versions.map { it.periods.first.departures_per_hour.fetch(0) }).to eq([ 1.5, 15.0 ])
    end

    it "週一、週二用 DateValue 2、3，內容相同：同一個版本" do
      store_weekday("2026-10-19", 4, 6)
      store_weekday("2026-10-20", 4, 6)
      expect(comparison.versions.map { it.days.size }).to eq([ 2 ])
    end

    it "改過又改回來：三個版本，只有相鄰的才併" do
      [ [ "2026-11-02", 4, 6 ], [ "2026-11-03", 8, 10 ], [ "2026-11-04", 4, 6 ] ].each { |day, low, high| store_weekday(day, low, high) }
      expect(comparison.versions.map { it.days.size }).to eq([ 1, 1, 1 ])
    end

    it "只有定時班次改了也分開" do
      store_weekday("2026-10-19", 4, 6).tap { create(:route_day_published_departure, route_day: it, date_value: 2, minute: 1350) }
      store_weekday("2026-10-20", 4, 6).tap { create(:route_day_published_departure, route_day: it, date_value: 3, minute: 1380) }
      expect(comparison.versions.size).to eq(2)
    end
  end

  describe "其餘時段" do
    def add_departure_times(route_day, *clocks, route_id: 9001, date_value: 2)
      clocks.each { create(:route_day_published_departure, route_day:, route_id:, date_value:, minute: minute(it)) }
    end

    def others = comparison.versions.first.others

    # A Monday whose last period ends at 21:00, with four later scheduled departures and five trips after 21:00.
    def store_late_evening(day)
      route_day = store_day(day).tap { add_period(it, "06:00", "21:00", 10, 15) }
      add_departure_times(route_day, "21:00", "21:30", "22:00", "23:00")
      5.times { add_trip(route_day, format("21:%02d", it), "21:50", bus_id: "TEST-#{it}") }
    end

    it "最後一個時段到 21:00，定時班次 21:00、21:30、22:00、23:00，兩天去程 10 趟在 21:00 之後：列 4 班，去程每天 5.0 趟" do
      [ "2026-10-19", "2026-10-26" ].each { store_late_evening(it) }
      expect([ others.departures, others.trips_per_day ]).to eq([ [ 1260, 1290, 1320, 1380 ], { 0 => 5.0, 1 => 0.0 } ])
    end

    # The clock of the n-th of a day's departures: every ten minutes from 06:00.
    def nth_clock(index) = format("%02d:%02d", 6 + index / 6, index % 6 * 10)

    # A day with 37 scheduled departures and `n_trips` trips of direction 0.
    def store_scheduled_only(day, n_trips)
      route_day = store_day(day)
      add_departure_times(route_day, *Array.new(37) { nth_clock(it) }, date_value: route_day.day.wday + 1)
      n_trips.times { add_trip(route_day, nth_clock(it), "23:50", bus_id: "TEST-#{it}") }
    end

    it "只有定時班次：沒有時段列，37 班定時班次，7 天去程 260 趟是每天約 37.1 趟" do
      [ 38, 37, 37, 37, 37 ].each_with_index { |n_trips, index| store_scheduled_only("2026-10-#{19 + index}", n_trips) }
      [ 37, 37 ].each_with_index { |n_trips, index| store_scheduled_only("2026-10-#{26 + index}", n_trips) }
      version = comparison.versions.sole
      expect([ version.periods, version.others.departures.size, version.others.trips_per_day.fetch(0).round(1) ]).to eq([ [], 37, 37.1 ])
    end

    it "時段裡的定時班次與趟次不列在這裡" do
      route_day = store_day("2026-10-19").tap { add_period(it, "06:00", "21:00", 10, 15) }
      add_departure_times(route_day, "07:00", "21:30")
      add_trip(route_day, "07:00", "07:50")
      expect([ others.departures, others.trips_per_day.fetch(0) ]).to eq([ [ 1290 ], 0.0 ])
    end

    it "同一個定時班次在兩條附屬路線上只算一班" do
      route_day = store_day("2026-10-19")
      [ 161407, 161408 ].each { create(:route_day_published_departure, route_day:, path_attribute_id: it, minute: 420) }
      expect(others.departures).to eq([ 420 ])
    end

    it "沒有定時班次也沒有時段外的趟次：nil" do
      route_day = store_day("2026-10-19").tap { add_period(it, "06:00", "21:00", 10, 15) }
      add_trip(route_day, "07:00", "07:50")
      expect(others).to be_nil
    end

    it "沒有定時班次但有時段外的趟次：照樣列趟次" do
      route_day = store_day("2026-10-19").tap { add_period(it, "06:00", "21:00", 10, 15) }
      add_trip(route_day, "05:40", "06:30")
      expect([ others.departures, others.trips_per_day.fetch(0) ]).to eq([ [], 1.0 ])
    end

    describe "路上的車：時段外有車在跑的格子取平均" do
      it "21:00 之後 A 跑到 21:40、B 跑到 22:10：三格 2、2、1，平均 5/3，沒有車的格子不算" do
        route_day = store_day("2026-10-19").tap { add_period(it, "00:00", "21:00", 10, 15) }
        add_trip(route_day, "21:00", "21:40", bus_id: "A")
        add_trip(route_day, "21:10", "22:10", bus_id: "B")
        expect(others.on_road).to eq(5.0 / 3)
      end

      it "時段前與時段後的格子都算，時段裡的不算" do
        route_day = store_day("2026-10-19").tap { add_period(it, "06:00", "21:00", 10, 15) }
        add_trip(route_day, "05:40", "20:00", bus_id: "A")
        add_trip(route_day, "05:45", "06:10", bus_id: "B")
        add_trip(route_day, "21:00", "21:20", bus_id: "C")
        expect(others.on_road).to eq(1.5)
      end

      it "只有定時班次的路線整天都是：一趟 08:00 到 08:40 是兩格各 1 台" do
        route_day = store_day("2026-10-19")
        add_departure_times(route_day, "08:00")
        add_trip(route_day, "08:00", "08:40")
        expect(others.on_road).to eq(1.0)
      end

      it "定時班次有列、卻完全沒有趟次：0.0" do
        add_departure_times(store_day("2026-10-19"), "08:00")
        expect(others.on_road).to eq(0.0)
      end

      it "跟時段重疊的時段不會重複切格：兩段 06:00 到 08:00 與 07:00 到 09:00 之外才算" do
        route_day = store_day("2026-10-19")
        add_period(route_day, "06:00", "08:00", 5, 10, path_attribute_id: 157462)
        add_period(route_day, "07:00", "09:00", 5, 10, path_attribute_id: 157463)
        add_trip(route_day, "05:30", "09:30")
        expect(others.on_road).to eq(1.0)
      end
    end
  end

  describe "成員路線" do
    def store_member_day(day = "2026-10-19", date_value: 2)
      store_day(day, member_names: { "9050" => "測試幹線經己站" }).tap do |route_day|
        add_period(route_day, "06:00", "21:00", 10, 15, date_value:)
        [ 420, 510 ].each { create(:route_day_published_departure, route_day:, route_id: 9050, date_value:, minute: it) }
      end
    end

    def member_rows = comparison.member_rows

    it "定時班次 07:00、08:30、當天 2 趟：一列寫 9050 的名字與那 2 班，當天 2 趟" do
      route_day = store_member_day
      [ "07:00", "08:30" ].each { add_trip(route_day, it, "09:00", route_id: 9050, bus_id: "TEST-#{it}") }
      row = member_rows.sole
      expect([ row.route_id, row.route_name, row.others.departures, row.others.trips_per_day.fetch(0) ]).to eq([ 9050, "測試幹線經己站", [ 420, 510 ], 2.0 ])
    end

    it "那 2 趟不算進路線 9001 的列" do
      route_day = store_member_day
      [ "07:00", "08:30" ].each { add_trip(route_day, it, "09:00", route_id: 9050, bus_id: "TEST-#{it}") }
      period = comparison.versions.first.periods.first
      expect([ period.departures_per_hour.fetch(0), period.on_road ]).to eq([ 0.0, 0.0 ])
    end

    it "成員路線有班距：時段列只用自己的趟次，照公告要幾台用同一個週期" do
      route_day = store_day("2026-10-19").tap { add_period(it, "06:00", "07:00", 4, 6, route_id: 9050) }
      add_trip(route_day, "06:10", "06:50", route_id: 9050)
      add_trip(route_day, "06:20", "06:50", bus_id: "TEST-0002")
      period = member_rows.sole.periods.sole
      expect([ period.departures_per_hour.fetch(0), period.needed_low, period.needed_high ]).to eq([ 1.0, 30, 46 ])
    end

    it "成員路線沒有公告的列：沒有這一列" do
      route_day = store_day("2026-10-19", member_names: { "9050" => "測試幹線經己站" })
      add_trip(route_day, "07:00", "07:50", route_id: 9050)
      expect(member_rows).to eq([])
    end

    it "那幾天用的 DateValue 沒有成員路線的列：也沒有這一列" do
      route_day = store_day("2026-10-25", day_type: "holiday", member_names: { "9050" => "測試幹線經己站" })
      create(:route_day_published_departure, route_day:, route_id: 9050, date_value: 2, minute: 420)
      expect(member_rows).to eq([])
    end

    it "成員路線的公告中途改了：兩列，各寫哪幾天，各用自己那幾天的趟次" do
      add_trip(store_member_day("2026-10-19"), "07:00", "07:50", route_id: 9050)
      create(:route_day_published_departure, route_day: store_day("2026-10-20"), route_id: 9050, date_value: 3, minute: 540)
      rows = member_rows.map { [ it.days.map(&:iso8601), it.others.departures, it.others.trips_per_day.fetch(0) ] }
      expect(rows).to eq([ [ %w[2026-10-19], [ 420, 510 ], 1.0 ], [ %w[2026-10-20], [ 540 ], 0.0 ] ])
    end

    it "頁面路線自己的列不會變成成員路線" do
      store_member_day
      expect(member_rows.map(&:route_id)).to eq([ 9050 ])
    end
  end

  describe "#hours" do
    it "一趟 06:40 到 08:10：三個小時都有，路上的車照格子平均" do
      add_trip(store_day("2026-10-19"), "06:40", "08:10")
      expect(comparison.hours.map { [ it.hour, it.on_road ] }).to eq([ [ 6, 0.5 ], [ 7, 1.0 ], [ 8, 0.5 ] ])
    end

    it "發車只算起點那一小時，方向分開" do
      add_trip(store_day("2026-10-19"), "06:40", "08:10", go_back: 1)
      expect(comparison.hours.map(&:departures)).to eq([ { 0 => 0.0, 1 => 1.0 }, { 0 => 0.0, 1 => 0.0 }, { 0 => 0.0, 1 => 0.0 } ])
    end

    it "兩天：沒有趟次的那天也算一天，平均進去" do
      add_trip(store_day("2026-10-19"), "07:00", "08:00")
      store_day("2026-10-20")
      expect(comparison.hours.map { [ it.hour, it.departures.fetch(0), it.on_road ] }).to eq([ [ 7, 0.5, 0.5 ] ])
    end

    it "成員路線的趟次不算" do
      add_trip(store_day("2026-10-19"), "07:00", "08:00", route_id: 9050)
      expect(comparison.hours).to eq([])
    end

    it "跨午夜的趟次只到 23 時" do
      add_trip(store_day("2026-10-19"), "23:40", "24:50")
      expect(comparison.hours.map(&:hour)).to eq([ 23 ])
    end

    it "沒有路線日：空的" do
      expect(comparison.hours).to eq([])
    end
  end

  it "沒有路線日：沒有版本，也沒有成員路線" do
    expect([ comparison.versions, comparison.member_rows ]).to eq([ [], [] ])
  end

  it "回傳的東西裡沒有車牌" do
    route_day = store_day("2026-10-19").tap { add_period(it, "06:00", "07:00", 5, 10) }
    add_trip(route_day, "06:00", "06:50", bus_id: "TEST-0009")
    add_trip(route_day, "21:00", "21:50", bus_id: "TEST-0009")
    expect(comparison.versions.inspect + comparison.hours.inspect).not_to include("TEST-0009")
  end
end
