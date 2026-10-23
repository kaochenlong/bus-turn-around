require "rails_helper"

RSpec.describe RoutePage::Facilities, type: :model do
  # The covered days as the page passes them, oldest first.
  def facilities = described_class.new(RouteDay.order(:day), ends: RoutePage.ends(9001))

  def end_of(go_back) = facilities.ends.find { it.go_back == go_back }

  # A stored day with both ends of route 9001, loaded with the toilet snapshot
  # of `snapshot`; `located` lists the directions that carry a location that day.
  def stored_day(day, located: [ 0, 1 ], n_layovers: 10, snapshot: day)
    route_day = create(:route_day, day: Date.iso8601(day), public_toilets_day: Date.iso8601(snapshot))
    [ 0, 1 ].to_h do |go_back|
      [ go_back, create(:route_day_end, *(located.include?(go_back) ? [] : [ :unlocated ]), route_day:, go_back:, n_layovers:) ]
    end
  end

  # Stores the given toilets, each [name, address, metres], for one end.
  def toilets(route_day_end, *rows)
    rows.each { |name, address, meters| create(:route_day_end_toilet, route_day_end:, name:, address:, meters:) }
  end

  describe "涵蓋 10-19 到 10-21，方向 1 只有前兩天有位置，10-19 與 10-20 用 10-15 的公廁快照、10-21 用 10-21 的時" do
    before do
      toilets(stored_day("2026-10-19", snapshot: "2026-10-15")[1], [ "十九日公廁", "甲路1號", 100.0 ])
      toilets(stored_day("2026-10-20", snapshot: "2026-10-15")[1], [ "二十日公廁", "甲路2號", 120.0 ])
      stored_day("2026-10-21", located: [ 0 ], snapshot: "2026-10-21")
    end

    it "方向 1 用 2026-10-20 的位置，並報 1 天沒有位置" do
      expect(end_of(1).to_h.values_at(:located_day, :n_days_without_location)).to eq([ Date.new(2026, 10, 20), 1 ])
    end

    it "方向 1 的公廁來自 2026-10-20 那一列" do
      expect(end_of(1).places.map(&:name)).to eq(%w[二十日公廁])
    end

    it "方向 0 每天都有位置，用最新的 2026-10-21" do
      expect(end_of(0).to_h.values_at(:located_day, :n_days_without_location)).to eq([ Date.new(2026, 10, 21), 0 ])
    end

    it "每一端標的公廁快照日是那一端位置那天用的：方向 1 是 2026-10-15、方向 0 是 2026-10-21" do
      expect([ end_of(1).public_toilets_day, end_of(0).public_toilets_day ]).to eq([ Date.new(2026, 10, 15), Date.new(2026, 10, 21) ])
    end
  end

  describe "停車端在涵蓋的日子裡都沒有位置時" do
    before do
      stored_day("2026-10-19", located: [ 0 ], n_layovers: 7)
      stored_day("2026-10-20", located: [ 0 ], n_layovers: 8)
    end

    it "那一端量不到：沒有位置的日子與公廁快照日、報最新一天的 8 筆折返停留、沒有處數、最近一處與清單" do
      expect(end_of(1).to_h.values_at(:nature, :located_day, :public_toilets_day, :location_source, :n_layovers, :counts, :nearest, :places))
        .to eq([ :stop, nil, nil, nil, 8, nil, nil, [] ])
    end

    it "另一端照常，用最新的 2026-10-20" do
      expect(end_of(0).located_day).to eq(Date.new(2026, 10, 20))
    end
  end

  describe "涵蓋的日子" do
    it "都沒有兩端的列時要重新載入" do
      create(:route_day)
      expect(facilities.needs_reload?).to be(true)
    end

    it "有兩端的列時不用重新載入" do
      stored_day("2026-10-19")
      expect(facilities.needs_reload?).to be(false)
    end
  end

  describe "公廁按地址併成處" do
    let(:route_day_end) { stored_day("2026-10-19")[0] }

    it "同地址的 250.0 與 251.0 公尺兩間是一處：300 公尺內 1 處、500 公尺內 2 處" do
      toilets(route_day_end, [ "甲公園-男廁", "甲路1號", 250.0 ], [ "甲公園-女廁", "甲路1號", 251.0 ], [ "乙加油站-男廁", "乙路1號", 450.0 ])
      expect(end_of(0).counts).to eq(300 => 1, 500 => 2)
    end

    it "最近一處是 250.0 公尺那一間的名稱，帶 2 間" do
      toilets(route_day_end, [ "甲公園-女廁", "甲路1號", 251.0 ], [ "甲公園-男廁", "甲路1號", 250.0 ], [ "乙加油站-男廁", "乙路1號", 450.0 ])
      expect(end_of(0).nearest.to_h.except(:latitude, :longitude)).to eq(name: "甲公園-男廁", category: "公園", address: "甲路1號", meters: 250.0, n_toilets: 2)
    end

    it "一處的經緯度是最近那一間的" do
      create(:route_day_end_toilet, route_day_end:, name: "甲公園-女廁", address: "甲路1號", meters: 251.0, latitude: 25.0623, longitude: 121.5004)
      create(:route_day_end_toilet, route_day_end:, name: "甲公園-男廁", address: "甲路1號", meters: 250.0, latitude: 25.0622, longitude: 121.5003)
      expect(end_of(0).nearest.to_h.values_at(:latitude, :longitude)).to eq([ 25.0622, 121.5003 ])
    end

    it "兩處都是 120.0 公尺時照名稱排，乙公廁在甲公廁前，最近一處是乙公廁" do
      toilets(route_day_end, [ "甲公廁", "甲路1號", 120.0 ], [ "乙公廁", "乙路1號", 120.0 ])
      expect([ end_of(0).places.map(&:name), end_of(0).nearest.name ]).to eq([ %w[乙公廁 甲公廁], "乙公廁" ])
    end

    it "沒有地址的兩間各算一處：100.0 與 200.0 公尺是 300 公尺內 2 處" do
      toilets(route_day_end, [ "無地址公廁一", nil, 100.0 ], [ "無地址公廁二", nil, 200.0 ])
      expect(end_of(0).counts[300]).to eq(2)
    end
  end

  describe "跟 analysis/params.sql 一致" do
    # The value a SET VARIABLE statement of analysis/params.sql gives.
    def param(name) = Rails.root.join("analysis/params.sql").read[/^SET VARIABLE #{name} = (\S+);$/, 1]

    it "清單的 500 公尺是 toilet_radius_meters，位置附近的 150 公尺是 located_radius_meters" do
      expect([ described_class::THRESHOLDS.max, described_class::LOCATED_RADIUS_METERS ].map(&:to_s)).to eq([ param("toilet_radius_meters"), param("located_radius_meters") ])
    end
  end
end
