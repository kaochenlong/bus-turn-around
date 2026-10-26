require "rails_helper"

RSpec.describe RoutePage::StopSpeeds, type: :model do
  # A stored day of route 9001. `positions` gives each direction's stops in
  # sequence order by their metres along the shape, nil for a stop without a
  # position; stop names are "<direction>-<index>".
  def route_day(day = "2026-10-19", positions: { 0 => [ 0.0, 300.0, 600.0 ] })
    create(:route_day, day: Date.parse(day)).tap do |route_day|
      positions.each do |go_back, metres|
        metres.each_with_index { |shape_meters, index| route_day.stops.create!(go_back:, seq: (go_back * 5) + index, stop_name: "#{go_back}-#{index}", shape_meters:) }
      end
    end
  end

  # One new trip of `route_day` per [seq, band, metres, seconds], each with
  # that one stop speed row; every trip gets its own vehicle.
  def speeds(route_day, rows, go_back: 0)
    rows.each do |seq, band, meters, seconds|
      number = Trip.count + 1
      start_time = Time.zone.parse("#{route_day.day} 06:00")
      route_day.trips.create!(bus_id: "TEST-#{number}", path_attribute_id: 9001, go_back:, band:, start_time:, end_time: start_time + 1.hour,
                              first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5, completeness: "complete",
                              start_from_arrival: false, end_from_departure: false).stop_speeds.create!(seq:, band:, meters:, seconds:)
    end
  end

  # Five rows of the same seq, band, metres and seconds per band.
  def five_each(seq, seconds_by_band, meters: 100.0) = seconds_by_band.flat_map { |band, seconds| [ [ seq, band, meters, seconds ] ] * 5 }

  # Ordered by day like RoutePage::Coverage#route_days, which the page passes in.
  def stop_speeds(*days) = described_class.new(RouteDay.where(id: days.map(&:id)).order(:day))

  def direction(days, go_back = 0) = stop_speeds(*days).directions.find { it.go_back == go_back }

  def cells(days, seq, go_back = 0) = direction(days, go_back).legs.find { it.seq == seq }.cells

  describe "一格的時速" do
    it "兩天合起來算：一天兩趟 300 公尺 60 秒、另一天一趟 300 公尺 180 秒，日間是 10.8 公里、3 趟、樣本少，沒有級數" do
      days = [ route_day("2026-10-19"), route_day("2026-10-20") ]
      speeds(days[0], [ [ 1, "daytime", 300.0, 60 ] ] * 2).then { speeds(days[1], [ [ 1, "daytime", 300.0, 180 ] ]) }
      expect(cells(days, 1).fetch("daytime").to_h.values_at(:kmh, :n_trips, :small_sample, :level)).to eq([ 10.8, 3, true, nil ])
    end

    it "沒有列的格子沒有時速、0 趟，不算樣本少" do
      day = route_day.tap { speeds(it, [ [ 0, "daytime", 300.0, 60 ] ]) }
      expect(cells([ day ], 0).fetch("other").to_h.values_at(:kmh, :n_trips, :small_sample, :level)).to eq([ nil, 0, false, nil ])
    end
  end

  describe "深淺的級數與時速範圍" do
    let(:day) { route_day.tap { speeds(it, five_each(0, { "morning_peak" => 72, "daytime" => 48, "evening_peak" => 36, "other" => 18 })) } }

    it "5.0、7.5、10.0、20.0 公里的四格是 4、3、2、1 級，剛好落在邊界的 10.0 與 20.0 歸較淺的級" do
      expect(%w[morning_peak daytime evening_peak other].map { cells([ day ], 0).fetch(it).level }).to eq([ 4, 3, 2, 1 ])
    end

    it "範圍照最慢那一格的 5.0 公里算：20.0 以上、10.0 到 20.0、6.7 到 10.0、6.7 以下" do
      expect(direction([ day ]).level_ranges).to eq([ [ 20.0, nil ], [ 10.0, 20.0 ], [ 6.7, 10.0 ], [ nil, 6.7 ] ])
    end

    it "樣本少的格子不決定刻度：4 趟 3.0 公里的那格沒有級數，6.0 與 12.0 公里是 4 級與 2 級，最淺從 24.0 起" do
      day = route_day.tap { speeds(it, [ [ 0, "morning_peak", 100.0, 120 ] ] * 4 + five_each(0, { "daytime" => 60, "evening_peak" => 30 })) }
      levels = %w[morning_peak daytime evening_peak].map { cells([ day ], 0).fetch(it).level }
      expect([ levels, direction([ day ]).level_ranges.first ]).to eq([ [ nil, 4, 2 ], [ 24.0, nil ] ])
    end

    it "沒有夠樣本的格子時，每一格都沒有級數，也沒有時速範圍" do
      day = route_day.tap { speeds(it, [ [ 0, "daytime", 100.0, 60 ] ] * 4) }
      expect([ cells([ day ], 0).values.map(&:level).uniq, direction([ day ]).level_ranges ]).to eq([ [ nil ], [] ])
    end

    it "0 公尺的格子是最深的一級、時速 0.0，不決定刻度：另一格 10.0 公里也是最深，範圍從 40.0 起" do
      day = route_day.tap { speeds(it, five_each(0, { "morning_peak" => 20 }, meters: 0.0) + five_each(0, { "daytime" => 36 })) }
      morning, daytime = cells([ day ], 0).values_at("morning_peak", "daytime")
      expect([ morning.kmh, morning.level, daytime.level, direction([ day ]).level_ranges.first ]).to eq([ 0.0, 4, 4, [ 40.0, nil ] ])
    end
  end

  describe "兩站之間" do
    it "每個方向接到下一個有位置的站，沒有位置的站被跨過，距離是兩站的位置相減" do
      day = route_day(positions: { 0 => [ 0.0, nil, 600.0, 850.0 ] })
      expect(direction([ day ]).legs.map { it.to_h.values_at(:seq, :from_name, :to_name, :meters) }).to eq([ [ 0, "0-0", "0-2", 600.0 ], [ 2, "0-2", "0-3", 250.0 ] ])
    end

    it "最新一天那個方向沒有位置時，用更早一天的站" do
      days = [ route_day("2026-10-19"), route_day("2026-10-20", positions: { 0 => [ nil, nil, nil ] }) ]
      expect(direction(days).legs.map { it.to_h.values_at(:seq, :meters) }).to eq([ [ 0, 300.0 ], [ 1, 300.0 ] ])
    end

    it "最新一天那個方向有位置時，用最新一天的站" do
      days = [ route_day("2026-10-19"), route_day("2026-10-20", positions: { 0 => [ 0.0, 250.0, 600.0 ] }) ]
      expect(direction(days).legs.map { it.to_h.values_at(:seq, :meters) }).to eq([ [ 0, 250.0 ], [ 1, 350.0 ] ])
    end

    it "一個方向沒有任何有位置的站時，那個方向沒有 leg" do
      expect(direction([ route_day ], 1).legs).to eq([])
    end

    it "成員路線的站不算 leg：返程只有成員 9050 兩個有位置的站時，返程沒有 leg" do
      day = route_day.tap { |d| [ 0.0, 300.0 ].each_with_index { |m, i| d.stops.create!(go_back: 1, seq: 5 + i, stop_name: "成員站#{i}", route_id: 9050, shape_meters: m) } }
      expect(direction([ day ], 1).legs).to eq([])
    end
  end

  describe "有沒有資料" do
    it "涵蓋的日子沒有任何站間車速的列時 available? 是 false" do
      expect(stop_speeds(route_day).available?).to be(false)
    end

    it "有一列就是 true" do
      expect(stop_speeds(route_day.tap { speeds(it, [ [ 0, "daytime", 100.0, 20 ] ]) }).available?).to be(true)
    end
  end

  # The queries of reading everything the page reads from these days.
  def query_count(days)
    queries = []
    ActiveSupport::Notifications.subscribed(->(*, payload) { queries << payload[:sql] }, "sql.active_record") { stop_speeds(*days).then { [ it.available?, it.directions ] } }
    queries.size
  end

  it "查詢次數不隨天數增加：一天與三天、兩個方向，取全部資料的查詢次數一樣，不超過三次" do
    days = %w[2026-10-19 2026-10-20 2026-10-21].map { route_day(it, positions: { 0 => [ 0.0, 300.0 ], 1 => [ 0.0, 300.0 ] }).tap { |d| speeds(d, [ [ 0, "daytime", 100.0, 20 ] ]) } }
    expect([ query_count(days.first(1)), query_count(days) ]).to eq([ 3, 3 ])
  end
end
