require "rails_helper"

RSpec.describe HomePage::RouteList, type: :model do
  def store_days(route_id, *days)
    days.each do |day|
      create(:route_day, route_id:, day: Date.iso8601(day))
    end
  end

  # A stored day of the route with the last stop of each direction, 戊站 for
  # direction 0 and 甲站 for direction 1, and layovers of the given minutes
  # ending in each direction.
  def store_measured_day(route_id, day, layovers: {})
    create(:route_day, route_id:, day: Date.iso8601(day)).tap do |route_day|
      route_day.stops.create!([ { go_back: 0, seq: 4, stop_name: "戊站" }, { go_back: 1, seq: 9, stop_name: "甲站" } ])
      end_time = Time.zone.parse("#{day} 08:00")
      layovers.each { |go_back, minutes| minutes.each { route_day.layovers.create!(bus_id: "TEST-0001", go_back:, end_time:, next_start_time: end_time + it.minutes) } }
    end
  end

  def summary(entries) = entries.map { [ it.route_id, it.route_day&.day&.iso8601 ] }

  # Each entry's layover count per stopping end, with the SQL statements issued
  # while building and reading the entries, schema queries left out.
  def counts_and_statements
    statements = []
    collect = ->(*, payload) { statements << payload[:sql] unless payload[:name] == "SCHEMA" }
    counts = ActiveSupport::Notifications.subscribed(collect, "sql.active_record") { described_class.new.entries.map { it.figures.map(&:n_layovers) } }
    [ counts, statements ]
  end

  # The summary of the entries, with the number of SELECTs on route_days issued
  # while building and reading them.
  def summary_and_route_days_selects
    selects = 0
    counter = ->(*, payload) { selects += 1 if payload[:name] != "SCHEMA" && payload[:sql].match?(/\ASELECT\b.*\bFROM "route_days"/m) }
    summary = ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { summary(described_class.new.entries) }
    [ summary, selects ]
  end

  it "照設定的順序：15373 沒有資料是 nil，接著是 9001 最新的 2026-10-20" do
    allow(RoutePage).to receive(:route_ids).and_return([ 15373, 9001 ])
    store_days(9001, "2026-10-19", "2026-10-20")
    expect(summary(described_class.new.entries)).to eq([ [ 15373, nil ], [ 9001, "2026-10-20" ] ])
  end

  it "兩條路線各三天：只對 route_days 發一次 SELECT，15373 帶 2026-10-21、9001 帶 2026-10-20" do
    allow(RoutePage).to receive(:route_ids).and_return([ 15373, 9001 ])
    store_days(15373, "2026-10-19", "2026-10-20", "2026-10-21")
    store_days(9001, "2026-10-18", "2026-10-19", "2026-10-20")
    expect(summary_and_route_days_selects).to eq([ [ [ 15373, "2026-10-21" ], [ 9001, "2026-10-20" ] ], 1 ])
  end

  it "figures 只含停車端的列、依方向排序：15373 只有返程那一端，兩端都停車的 9001 兩端都有，沒有資料的 10712 是空的" do
    allow(RoutePage).to receive(:route_ids).and_return([ 15373, 9001, 10712 ])
    store_measured_day(15373, "2026-10-21").then { store_measured_day(9001, "2026-10-20") }
    expect(described_class.new.entries.map { [ it.route_id, it.figures.map(&:go_back) ] }).to eq([ [ 15373, [ 1 ] ], [ 9001, [ 0, 1 ] ], [ 10712, [] ] ])
  end

  it "兩條路線各有一天的折返停留：route_days 只查一次，讀 layovers 的也只有一句、不提 route_days，筆數是 2 與 3" do
    allow(RoutePage).to receive(:route_ids).and_return([ 15373, 9001 ])
    store_measured_day(15373, "2026-10-21", layovers: { 1 => [ 10, 20 ] }).then { store_measured_day(9001, "2026-10-20", layovers: { 1 => [ 10, 20, 30 ] }) }
    counts, statements = counts_and_statements
    layover_reads = statements.grep(/\blayovers\b/)
    expect([ statements.grep(/\ASELECT\b.*\bFROM "route_days"/m).size, layover_reads.size, layover_reads.grep(/\broute_days\b/), counts ]).to eq([ 1, 1, [], [ [ 2 ], [ 0, 3 ] ] ])
  end
end
