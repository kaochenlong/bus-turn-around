require "rails_helper"

RSpec.describe RoutePage::LayoverHours, type: :model do
  # `count` layovers of `minutes` minutes, each with its own vehicle, ending at `clock`.
  def add_layovers(route_day, clock, count, minutes, go_back: 1)
    count.times do |index|
      end_time = Time.zone.parse("#{route_day.day} #{clock}")
      create(:layover, route_day:, go_back:, bus_id: "TEST-#{clock}-#{minutes}-#{index}", end_time:, next_start_time: end_time + minutes.minutes)
    end
  end

  def rows(go_back = 1, days: RouteDay.all) = described_class.new(days).rows(go_back).map { [ it.hour, it.n_layovers, it.short_share ] }

  it "08 時回來 10 筆、8 筆不到 15 分鐘，23 時回來 6 筆都不到：80% 與 100%" do
    route_day = create(:route_day)
    add_layovers(route_day, "08:10", 8, 10)
    add_layovers(route_day, "08:40", 2, 20)
    add_layovers(route_day, "23:10", 6, 5)
    expect(rows).to eq([ [ 8, 10, 0.8 ], [ 23, 6, 1.0 ] ])
  end

  it "剛好 15 分鐘不算不到 15 分鐘" do
    add_layovers(create(:route_day), "08:10", 1, 15)
    expect(rows).to eq([ [ 8, 1, 0.0 ] ])
  end

  it "小時照車回來的台北時間，不看下一趟發車" do
    add_layovers(create(:route_day), "08:55", 1, 10)
    expect(rows.map(&:first)).to eq([ 8 ])
  end

  it "兩個方向分開" do
    route_day = create(:route_day)
    add_layovers(route_day, "08:10", 1, 10, go_back: 0)
    add_layovers(route_day, "09:10", 1, 10, go_back: 1)
    expect([ rows(0).map(&:first), rows(1).map(&:first) ]).to eq([ [ 8 ], [ 9 ] ])
  end

  it "只算給的那幾天" do
    add_layovers(create(:route_day), "08:10", 1, 10)
    other = create(:route_day, day: Date.new(2026, 10, 20))
    add_layovers(other, "09:10", 1, 10)
    expect(rows(days: RouteDay.where(id: other.id)).map(&:first)).to eq([ 9 ])
  end

  it "那一端沒有折返停留：空的" do
    add_layovers(create(:route_day), "08:10", 1, 10, go_back: 0)
    expect(rows(1)).to eq([])
  end
end
