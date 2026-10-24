require "rails_helper"

# The covered days are passed ordered by day, the way RoutePage::Coverage
# gives them, so a latest-day lookup that only appends its own order fails here.
RSpec.describe RoutePage::Depots, type: :model do
  def depots = described_class.new(RouteDay.order(:day))

  # A stored day with the given depots, each [station name, vehicles] of 測試客運, or a hash of a row's columns.
  def store_day(day, *rows)
    create(:route_day, day: Date.iso8601(day)).tap do |route_day|
      rows.each.with_index(19001) do |row, station_id|
        attributes = row.is_a?(Hash) ? row : { station_name: row.first, n_buses: row.last }
        create(:route_day_depot, route_day:, station_id:, **attributes)
      end
    end
  end

  it "三種狀態照設定的 test 區分，車數多的在前：測試站有分數、測試二站不在名單、測試三站還沒對" do
    store_day("2026-10-19", [ "測試三站", 1 ], [ "測試站", 4 ], [ "測試二站", 2 ])
    expect(depots.rows.map { [ it.station_name, it.n_buses, it.status ] }).to eq([ [ "測試站", 4, :scored ], [ "測試二站", 2, :not_in_appendix ], [ "測試三站", 1, :unchecked ] ])
  end

  it "有分數的列帶那一站的查核：印的名稱、檢查日期、頁碼；其他兩種沒有" do
    store_day("2026-10-19", [ "測試站", 4 ], [ "測試二站", 2 ], [ "測試三站", 1 ])
    expect(depots.rows.map { it.inspection&.to_h&.values_at(:printed_as, :inspected_on, :printed_page) }).to eq([ [ "測試 測試站", "12月2日", "A-99" ], nil, nil ])
  end

  it "車數相同時照 StationID 由小到大" do
    store_day("2026-10-19", [ "測試二站", 2 ], [ "測試三站", 2 ])
    expect(depots.rows.map(&:station_id)).to eq([ 19001, 19002 ])
  end

  it "名稱是空的列還沒對過，帶著 StationID" do
    store_day("2026-10-19", { provider_name: "", station_name: "", n_buses: 3 })
    expect(depots.rows.map { [ it.station_id, it.status ] }).to eq([ [ 19001, :unchecked ] ])
  end

  describe "涵蓋好幾天" do
    it "用最新一天的列，並記下是哪一天" do
      store_day("2026-10-19", [ "測試站", 4 ])
      store_day("2026-10-20", [ "測試二站", 2 ])
      expect([ depots.day, depots.rows.map(&:station_name) ]).to eq([ Date.new(2026, 10, 20), [ "測試二站" ] ])
    end

    it "最新一天是調度站表建立之前載入的、沒有列時，用有列的最新一天" do
      store_day("2026-10-19", [ "測試站", 4 ])
      store_day("2026-10-20")
      expect([ depots.day, depots.needs_reload? ]).to eq([ Date.new(2026, 10, 19), false ])
    end
  end

  it "涵蓋的日子都沒有調度站的列時要重新載入，沒有列" do
    store_day("2026-10-19")
    expect([ depots.needs_reload?, depots.day, depots.rows ]).to eq([ true, nil, [] ])
  end

  it "只看涵蓋的日子：涵蓋外的日子有列也不用" do
    store_day("2026-10-19")
    store_day("2026-10-20", [ "測試站", 4 ])
    expect(described_class.new(RouteDay.where(day: Date.new(2026, 10, 19)).order(:day)).needs_reload?).to be(true)
  end
end
