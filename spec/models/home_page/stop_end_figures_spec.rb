require "rails_helper"

RSpec.describe HomePage::StopEndFigures, type: :model do
  # A stored day of the route with the last stop of each direction, 戊站 for
  # direction 0 and 甲站 for direction 1, and layovers of the given minutes
  # ending in each direction.
  def store_day(route_id, day, layovers: {})
    create(:route_day, route_id:, day: Date.iso8601(day)).tap do |route_day|
      route_day.stops.create!([ { go_back: 0, seq: 4, stop_name: "戊站" }, { go_back: 1, seq: 9, stop_name: "甲站" } ])
      end_time = Time.zone.parse("#{day} 08:00")
      layovers.each { |go_back, minutes| minutes.each { route_day.layovers.create!(bus_id: "TEST-0001", go_back:, end_time:, next_start_time: end_time + it.minutes) } }
    end
  end

  # Every row's values, in the order of the row's members.
  def values(route_days) = described_class.new(route_days).rows.map { it.to_h.values }

  # The rows read twice from one object, with the SQL statements issued while
  # building and reading it, schema queries left out.
  def rows_and_statements(route_days)
    statements = []
    collect = ->(*, payload) { statements << payload[:sql] unless payload[:name] == "SCHEMA" }
    rows = ActiveSupport::Notifications.subscribed(collect, "sql.active_record") { described_class.new(route_days).then { |figures| figures.rows.then { figures.rows } } }
    [ rows, statements ]
  end

  it "每個 route day 每個有站序的方向一列，依 route day 與方向排序；沒有折返停留的方向筆數 0、比例 nil" do
    day_9001 = store_day(9001, "2026-10-20", layovers: { 1 => [ 10, 20, 30 ] })
    day_15373 = store_day(15373, "2026-10-21", layovers: { 0 => [ 5 ] })
    expect(values([ day_15373, day_9001 ])).to eq(
      [ [ day_9001.id, 0, "戊站", 0, nil ], [ day_9001.id, 1, "甲站", 3, 1.0 / 3 ], [ day_15373.id, 0, "戊站", 1, 1.0 ], [ day_15373.id, 1, "甲站", 0, nil ] ]
    )
  end

  it "那一天另有成員路線 9050 的站序時不讀它：9050 的去程多一站己站，去程的末站仍是 9001 的戊站" do
    route_day = store_day(9001, "2026-10-20").tap { it.stops.create!(route_id: 9050, go_back: 0, seq: 5, stop_name: "己站") }
    expect(values([ route_day ]).map { it[1..2] }).to eq([ [ 0, "戊站" ], [ 1, "甲站" ] ])
  end

  it "沒有站序的 route day 沒有列" do
    expect(values([ create(:route_day, day: Date.new(2026, 10, 20)) ])).to eq([])
  end

  it "整個物件只發一句 SQL，rows 讀兩次也一樣，SQL 不讀 route_days" do
    route_days = [ store_day(9001, "2026-10-20", layovers: { 1 => [ 10 ] }), store_day(15373, "2026-10-21", layovers: { 1 => [ 20 ] }) ]
    statements = rows_and_statements(route_days).last
    expect([ statements.size, statements.grep(/\broute_days\b/) ]).to eq([ 1, [] ])
  end

  it "沒有任何 route day 時是空的，也不發 SQL" do
    expect(rows_and_statements([])).to eq([ [], [] ])
  end

  it "同一個 route day 的末站、筆數與比例，等於路線頁 LayoverStats 那一天的列；剛好 15 分鐘不算不到 15 分鐘" do
    route_day = store_day(9001, "2026-10-20", layovers: { 0 => [ 5, 14.5, 15, 40 ], 1 => [ 10, 20, 30 ] })
    expected = RoutePage::LayoverStats.new(RouteDay.where(id: route_day.id)).rows.map { [ it.go_back, it.stop_name, it.n_layovers, it.short_share ] }
    expect([ values([ route_day ]).map { it.drop(1) }, expected.first.last ]).to eq([ expected, 0.5 ])
  end
end
