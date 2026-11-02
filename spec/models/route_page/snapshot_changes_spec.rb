require "rails_helper"

RSpec.describe RoutePage::SnapshotChanges, type: :model do
  def snapshot_changes(days = RouteDay.all) = described_class.new(days)

  def changes = snapshot_changes.changes.map { [ it.day.iso8601, it.kinds ] }

  def add_headway(route_day, high: 10, **attributes)
    create(:route_day_published_headway, route_day:, high_minutes: high, **attributes)
  end

  def add_stop(route_day, seq, stop_name: "甲站", go_back: 0, route_id: 9001, stop_location_id: 81000 + seq)
    route_day.stops.create!(go_back:, seq:, stop_name:, route_id:, stop_location_id:)
  end

  # Three days in a row; the block fills each with what makes it what it is.
  def store_three_days(days = %w[2026-10-19 2026-10-20 2026-10-21])
    days.each_with_index do |day, index|
      yield create(:route_day, day: Date.iso8601(day), published_schedule_day: Date.iso8601(day)), index
    end
  end

  # A published row, a stop and a route shape, all the same on every day unless `changed`.
  def fill(route_day, changed: false)
    add_headway(route_day, high: changed ? 15 : 10)
    add_stop(route_day, 0, stop_name: changed ? "己站" : "甲站")
    create(:route_day_shape, route_day:, shape_updated_at: Time.zone.parse(changed ? "2026-10-20 09:00" : "2024-11-29 09:00"))
  end

  it "三天的公告、站序與軌跡都相同：沒有改動，3 天" do
    store_three_days { |route_day, _| fill(route_day) }
    expect([ changes, snapshot_changes.n_days ]).to eq([ [], 3 ])
  end

  describe "公告" do
    it "第二天一個時段的上界不同、第三天跟第二天相同：只報第二天" do
      store_three_days { |route_day, index| add_headway(route_day, high: index.zero? ? 10 : 15) }
      expect(changes).to eq([ [ "2026-10-20", [ :published_schedule ] ] ])
    end

    it "第二天改了、第三天又改回來：兩天都報" do
      store_three_days { |route_day, index| add_headway(route_day, high: index == 1 ? 15 : 10) }
      expect(changes.map(&:first)).to eq(%w[2026-10-20 2026-10-21])
    end

    it "定時班次不同也算" do
      store_three_days { |route_day, index| create(:route_day_published_departure, route_day:, minute: index.zero? ? 1350 : 1380) }
      expect(changes).to eq([ [ "2026-10-20", [ :published_schedule ] ] ])
    end

    it "成員路線的列不同也算" do
      store_three_days { |route_day, index| create(:route_day_published_departure, route_day:, route_id: 9050, minute: index.zero? ? 420 : 480) }
      expect(changes).to eq([ [ "2026-10-20", [ :published_schedule ] ] ])
    end

    it "這一天沒用到的 DateValue 不同也算" do
      store_three_days { |route_day, index| add_headway(route_day, date_value: 7, high: index.zero? ? 10 : 15) }
      expect(changes).to eq([ [ "2026-10-20", [ :published_schedule ] ] ])
    end

    it "列的順序不同不算" do
      store_three_days do |route_day, index|
        minutes = index.zero? ? [ 1350, 1380 ] : [ 1380, 1350 ]
        minutes.each { create(:route_day_published_departure, route_day:, minute: it) }
      end
      expect(changes).to eq([])
    end

    describe "中間一天沒有 published_schedule_day" do
      def store_days_around_gap(third_high)
        create(:route_day, day: Date.iso8601("2026-10-19"), published_schedule_day: Date.iso8601("2026-10-19")).tap { add_headway(it) }
        create(:route_day, day: Date.iso8601("2026-10-20"), published_schedule_day: nil)
        create(:route_day, day: Date.iso8601("2026-10-21"), published_schedule_day: Date.iso8601("2026-10-21")).tap { add_headway(it, high: third_high) }
      end

      it "前後兩天相同：不算改動" do
        store_days_around_gap(10)
        expect(changes).to eq([])
      end

      it "前後兩天不同：報在第三天" do
        store_days_around_gap(15)
        expect(changes).to eq([ [ "2026-10-21", [ :published_schedule ] ] ])
      end
    end
  end

  describe "站序" do
    it "第三天去程多一站：報第三天" do
      store_three_days do |route_day, index|
        add_stop(route_day, 0)
        add_stop(route_day, 1, stop_name: "乙站") if index == 2
      end
      expect(changes).to eq([ [ "2026-10-21", [ :stops ] ] ])
    end

    it "站名不同算" do
      store_three_days { |route_day, index| add_stop(route_day, 0, stop_name: index == 1 ? "甲站（新）" : "甲站") }
      expect(changes.map(&:last)).to eq([ [ :stops ], [ :stops ] ])
    end

    it "站位不同算" do
      store_three_days { |route_day, index| add_stop(route_day, 0, stop_location_id: index.zero? ? 81000 : 81999) }
      expect(changes).to eq([ [ "2026-10-20", [ :stops ] ] ])
    end

    it "返程不同也算" do
      store_three_days { |route_day, index| add_stop(route_day, 5, go_back: 1, stop_name: index.zero? ? "戊站" : "戊站對面") }
      expect(changes).to eq([ [ "2026-10-20", [ :stops ] ] ])
    end

    it "成員路線的站序不同不算" do
      store_three_days { |route_day, index| add_stop(route_day, 0, route_id: 9050, stop_name: index.zero? ? "甲站" : "己站") }
      expect(changes).to eq([])
    end
  end

  describe "路線軌跡" do
    def add_shape(route_day, at, go_back: 0) = create(:route_day_shape, route_day:, go_back:, shape_updated_at: Time.zone.parse(at))

    it "更新時間不同：報那一天" do
      store_three_days { |route_day, index| add_shape(route_day, index.zero? ? "2024-11-29 09:00" : "2026-10-20 09:00") }
      expect(changes).to eq([ [ "2026-10-20", [ :shape ] ] ])
    end

    it "第二天少了一個方向的軌跡也算" do
      store_three_days do |route_day, index|
        add_shape(route_day, "2024-11-29 09:00")
        add_shape(route_day, "2024-11-29 09:00", go_back: 1) if index != 1
      end
      expect(changes.map(&:last)).to eq([ [ :shape ], [ :shape ] ])
    end

    it "shape_updated_at 是最新一天兩個方向裡較新的那一個，不看舊的日子" do
      store_three_days do |route_day, index|
        add_shape(route_day, index == 2 ? "2024-11-29 09:00" : "2026-01-01 09:00")
        add_shape(route_day, "2024-11-30 09:00", go_back: 1)
      end
      expect(snapshot_changes.shape_updated_at).to eq(Time.zone.parse("2024-11-30 09:00"))
    end

    it "最新一天沒有軌跡：nil" do
      store_three_days { |route_day, index| add_shape(route_day, "2024-11-29 09:00") if index < 2 }
      expect(snapshot_changes.shape_updated_at).to be_nil
    end
  end

  it "同一天改了三樣：kinds 照公告、站序、軌跡的順序" do
    store_three_days { |route_day, index| fill(route_day, changed: !index.zero?) }
    expect(changes).to eq([ [ "2026-10-20", [ :published_schedule, :stops, :shape ] ] ])
  end

  it "第一天不算改動，不管它有什麼" do
    create(:route_day, published_schedule_day: Date.iso8601("2026-10-19")).tap { add_headway(it) }
    expect([ changes, snapshot_changes.n_days ]).to eq([ [], 1 ])
  end

  it "照日期比，不照傳進來的順序" do
    store_three_days { |route_day, index| add_headway(route_day, high: index.zero? ? 10 : 15) }
    expect(snapshot_changes(RouteDay.order(day: :desc)).changes.map { it.day.iso8601 }).to eq(%w[2026-10-20])
  end

  it "沒有路線日：沒有改動、0 天、沒有軌跡時間" do
    described = snapshot_changes
    expect([ described.changes, described.n_days, described.shape_updated_at ]).to eq([ [], 0, nil ])
  end
end
