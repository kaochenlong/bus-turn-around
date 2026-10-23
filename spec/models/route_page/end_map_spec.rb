require "rails_helper"

RSpec.describe RoutePage::EndMap, type: :model do
  # The covered days as the page passes them, oldest first.
  def end_map(ends: RoutePage.ends(9001)) = described_class.new(RouteDay.order(:day), ends:)

  def end_of(go_back, **options) = end_map(**options).ends.find { it.go_back == go_back }

  # A stored day of route 9001 whose direction 0 ends at 戊站 (25.06, 121.5)
  # and direction 1 at 甲站, with the given standstill-report counts. Returns
  # both ends.
  def stored_day(day, reports: [ 29, 8 ], **direction0)
    route_day = create(:route_day, day: Date.iso8601(day))
    [ create(:route_day_end, route_day:, go_back: 0, n_standstill_records: reports[0], **direction0),
      create(:route_day_end, route_day:, go_back: 1, end_seq: 9, end_stop_name: "甲站", end_latitude: 25.05, end_longitude: 121.5003,
                             latitude: 25.0497, longitude: 121.5006, n_standstill_records: reports[1]) ]
  end

  # Stores cells of an end, each [cell latitude, cell longitude, reports].
  def cells(route_day_end, *rows)
    rows.each { |lat, lon, n_records| create(:route_day_end_cell, route_day_end:, cell_latitude: lat, cell_longitude: lon, n_records:) }
  end

  def cell_rows(map_end) = map_end.cells.map { [ it.lat, it.lon, it.records, it.days ] }

  describe "10-20 與 10-21 的格子" do
    before do
      cells(stored_day("2026-10-20", reports: [ 29, 8 ])[0], [ 25.0604, 121.5002, 25 ])
      cells(stored_day("2026-10-21", reports: [ 31, 8 ])[0], [ 25.0604, 121.5002, 15 ], [ 25.0606, 121.5002, 9 ])
    end

    it "同一格跨天合計筆數、數出現幾天：25.0604 那一格 40 筆 2 天，25.0606 那一格 9 筆 1 天" do
      expect(cell_rows(end_of(0))).to eq([ [ 25.0604, 121.5002, 40, 2 ], [ 25.0606, 121.5002, 9, 1 ] ])
    end

    it "涵蓋 49 筆、分母 60 筆，比例 0.817" do
      map_end = end_of(0)
      expect([ map_end.records_shown, map_end.records_total, map_end.coverage_share.round(3) ]).to eq([ 49, 60, 0.817 ])
    end
  end

  describe "四格在末站 1 公里內、兩格在 3 公里外時" do
    before do
      cells(stored_day("2026-10-20", reports: [ 100, 8 ])[0], [ 25.0602, 121.5000, 10 ], [ 25.0604, 121.5000, 10 ], [ 25.0606, 121.5000, 10 ],
            [ 25.0608, 121.5000, 10 ], [ 25.0870, 121.5000, 20 ], [ 25.0872, 121.5000, 20 ])
    end

    it "只列四格，記 2 格在範圍外" do
      map_end = end_of(0)
      expect([ map_end.cells.size, map_end.cells_beyond_extent ]).to eq([ 4, 2 ])
    end

    it "涵蓋比例只算那四格的 40 筆" do
      expect(end_of(0).records_shown).to eq(40)
    end
  end

  it "下一趟起站取另一個方向 seq 最小的站：方向 0 的末站是戊站，下一趟起站是戊站對面" do
    route_day = stored_day("2026-10-20")[0].route_day
    route_day.stops.create!([ { go_back: 0, seq: 4, stop_name: "戊站", latitude: 25.06, longitude: 121.5 },
                              { go_back: 1, seq: 5, stop_name: "戊站對面", latitude: 25.06, longitude: 121.5003 },
                              { go_back: 1, seq: 6, stop_name: "丁站對面", latitude: 25.0575, longitude: 121.5003 } ])
    expect([ end_of(0).last_stop.name, end_of(0).next_first_stop.to_h ]).to eq([ "戊站", { name: "戊站對面", lat: 25.06, lon: 121.5003 } ])
  end

  it "末站與下一趟起站取涵蓋日子裡最新的一天：10-19 是舊站名，10-20 是戊站與戊站對面" do
    stored_day("2026-10-19", end_stop_name: "舊末站")[0].route_day.stops.create!(go_back: 1, seq: 5, stop_name: "舊起站", latitude: 25.06, longitude: 121.5003)
    stored_day("2026-10-20")[0].route_day.stops.create!(go_back: 1, seq: 5, stop_name: "戊站對面", latitude: 25.06, longitude: 121.5003)
    expect([ end_of(0).last_stop.name, end_of(0).next_first_stop.name ]).to eq(%w[戊站 戊站對面])
  end

  it "涵蓋的日子沒有任何靜止回報時：沒有格子、沒有比例，仍有末站與位置" do
    stored_day("2026-10-20", reports: [ 0, 0 ], location_source: "end_stop", latitude: 25.06, longitude: 121.5, n_located_layovers: nil, end_stop_meters: 0.0)
    map_end = end_of(0, ends: RoutePage::Ends.from_config({ 0 => "pass_through", 1 => "stop" }, route_id: 9001))
    expect([ map_end.cells, map_end.coverage_share, map_end.last_stop.name, map_end.location.to_h ])
      .to eq([ [], nil, "戊站", { lat: 25.06, lon: 121.5, source: "end_stop", day: Date.new(2026, 10, 20) } ])
  end

  it "涵蓋的日子都沒有兩端的列時沒有地圖" do
    create(:route_day)
    expect(end_map.available?).to be(false)
  end

  # Stores toilets of an end, each [name, address, metres, latitude], all at longitude 121.5003.
  def toilets(route_day_end, *rows)
    rows.each { |name, address, meters, latitude| create(:route_day_end_toilet, route_day_end:, name:, address:, meters:, latitude:, longitude: 121.5003) }
  end

  it "公廁照處給：同地址的 251.7 與 253.3 公尺兩間是一處 2 間、帶最近那一間的座標，451.9 公尺另一處" do
    toilets(stored_day("2026-10-20")[0], [ "戊站公園-女廁", "戊路2號", 253.3, 25.0627 ], [ "戊站公園-男廁", "戊路2號", 251.7, 25.062686 ],
            [ "戊站加油站-混合廁所", "戊路1號", 451.9, 25.064486 ])
    expect(end_of(0).places.map { it.to_h.values_at(:name, :n_toilets, :latitude, :longitude) })
      .to eq([ [ "戊站公園-男廁", 2, 25.062686, 121.5003 ], [ "戊站加油站-混合廁所", 1, 25.064486, 121.5003 ] ])
  end

  describe "深淺分級" do
    def levels(*records)
      cells(stored_day("2026-10-20", reports: [ records.sum, 0 ])[0], *records.each_with_index.map { |n, i| [ 25.0600 + (0.0002 * i), 121.5000, n ] })
      end_of(0).cells.map(&:level)
    end

    it "40、20、11、9 筆得 4、2、2、1" do
      expect(levels(40, 20, 11, 9)).to eq([ 4, 2, 2, 1 ])
    end

    it "佔最大格的比例 1.0、0.75、0.5、0.26、0.25 得 4、3、2、2、1" do
      expect(levels(100, 75, 50, 26, 25)).to eq([ 4, 3, 2, 2, 1 ])
    end
  end

  it "格子邊長跟 analysis/params.sql 的 standstill_cell_degrees 是同一個值" do
    param = Rails.root.join("analysis/params.sql").read[/^SET VARIABLE standstill_cell_degrees = (\S+);$/, 1]
    expect(described_class::CELL_DEGREES.to_s).to eq(param)
  end
end
