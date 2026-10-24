require "rails_helper"

RSpec.describe RoutePage::RouteShape, type: :model do
  let(:outbound_points) { [ [ 25.05, 121.5 ], [ 25.055, 121.5 ], [ 25.06, 121.5 ] ] }
  let(:inbound_points) { [ [ 25.06, 121.5003 ], [ 25.05, 121.5003 ] ] }

  # A stored day of route 9001. `stops` gives each direction's stops in
  # sequence order as [name, latitude, longitude]; `shapes` gives each
  # direction's [update time, points].
  def route_day(day, stops: {}, shapes: {})
    create(:route_day, day:).tap do |route_day|
      stops.each do |go_back, rows|
        rows.each_with_index { |(stop_name, latitude, longitude), index| route_day.stops.create!(go_back:, seq: (go_back * 50) + index, stop_name:, latitude:, longitude:) }
      end
      shapes.each { |go_back, (updated_at, points)| create(:route_day_shape, route_day:, go_back:, shape_updated_at: Time.zone.parse(updated_at), points:) }
    end
  end

  def fixture_stops
    { 0 => [ [ "甲站", 25.05, 121.5 ], [ "丙站", 25.055, 121.5 ], [ "戊站", 25.06, 121.5 ] ],
      1 => [ [ "戊站對面", 25.06, 121.5003 ], [ "甲站", 25.05, 121.5003 ] ] }
  end

  def fixture_shapes = { 0 => [ "2023-12-29 09:46:21", outbound_points ], 1 => [ "2023-12-29 09:48:24", inbound_points ] }

  # Ordered by day like RoutePage::Coverage#route_days, which the page passes in.
  def route_shape(*days) = described_class.new(RouteDay.where(id: days.map(&:id)).order(:day))

  def summary(end_stops) = end_stops.map { [ it.go_back, it.first.name, it.last.name ] }

  it "涵蓋 10-19 與 10-20、由舊到新傳進來，10-20 沒有路線軌跡：用 10-19 的兩條線，公運處更新日 2023-12-29" do
    route_shape = route_shape(route_day(Date.new(2026, 10, 19), shapes: fixture_shapes), route_day(Date.new(2026, 10, 20)))
    expect([ route_shape.lines.map { [ it.go_back, it.points ] }, route_shape.updated_on ])
      .to eq([ [ [ 0, outbound_points ], [ 1, inbound_points ] ], Date.new(2023, 12, 29) ])
  end

  it "起站與末站取畫出來的那一天：10-20 的站牌不同、沒有軌跡，起站末站仍是 10-19 的甲站、戊站與戊站對面、甲站" do
    older = route_day(Date.new(2026, 10, 19), stops: fixture_stops, shapes: fixture_shapes)
    newer = route_day(Date.new(2026, 10, 20), stops: { 0 => [ [ "乙站", 25.0525, 121.5 ], [ "丁站", 25.0575, 121.5 ] ] })
    expect(summary(route_shape(older, newer).end_stops)).to eq([ [ 0, "甲站", "戊站" ], [ 1, "戊站對面", "甲站" ] ])
  end

  it "起站與末站帶名稱與座標" do
    end_stops = route_shape(route_day(Date.new(2026, 10, 19), stops: fixture_stops, shapes: fixture_shapes)).end_stops
    stop = described_class::Stop
    expect(end_stops.first).to eq(described_class::EndStops.new(go_back: 0, first: stop.new(name: "甲站", lat: 25.05, lon: 121.5), last: stop.new(name: "戊站", lat: 25.06, lon: 121.5)))
  end

  it "只有方向 0 有軌跡時，線與起站末站都只有方向 0，方向 1 有站牌也不列" do
    route_shape = route_shape(route_day(Date.new(2026, 10, 19), stops: fixture_stops, shapes: fixture_shapes.slice(0)))
    expect([ route_shape.lines.map(&:go_back), summary(route_shape.end_stops) ]).to eq([ [ 0 ], [ [ 0, "甲站", "戊站" ] ] ])
  end

  it "兩個方向的更新時間不同天時取較晚的，以台北日算：2024-01-02 00:10 是 1 月 2 日" do
    shapes = { 0 => [ "2023-12-29 23:30:00", outbound_points ], 1 => [ "2024-01-02 00:10:00", inbound_points ] }
    expect(route_shape(route_day(Date.new(2026, 10, 19), shapes:)).updated_on).to eq(Date.new(2024, 1, 2))
  end

  it "涵蓋的日子都沒有路線軌跡：available? 為假，沒有線也沒有起站末站" do
    route_shape = route_shape(route_day(Date.new(2026, 10, 19), stops: fixture_stops), route_day(Date.new(2026, 10, 20)))
    expect([ route_shape.available?, route_shape.lines, route_shape.end_stops ]).to eq([ false, [], [] ])
  end

  it "有路線軌跡時 available? 為真" do
    expect(route_shape(route_day(Date.new(2026, 10, 19), shapes: fixture_shapes)).available?).to be(true)
  end

  it "同一個物件把每樣資料各取兩次，全部不超過三次查詢" do
    day = route_day(Date.new(2026, 10, 19), stops: fixture_stops, shapes: fixture_shapes)
    queries = []
    record = ->(*, payload) { queries << payload[:sql] }
    ActiveSupport::Notifications.subscribed(record, "sql.active_record") { route_shape(day).then { |shape| 2.times { [ shape.available?, shape.updated_on, shape.lines, shape.end_stops ] } } }
    expect(queries.size).to be <= 3
  end
end
