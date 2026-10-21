require "rails_helper"

RSpec.describe RoutePage::LayoverStats, type: :model do
  def route_day(day, layover_minutes)
    RouteDay.create!(route_id: 9001, day:, route_name: "測試幹線", departure: "甲站", destination: "戊站",
                     static_day: day, loaded_at: Time.current).tap do |route_day|
      route_day.stops.create!([ { go_back: 0, seq: 4, stop_name: "戊站" }, { go_back: 1, seq: 9, stop_name: "甲站" } ])
      layover_minutes.each do |minutes|
        end_time = Time.zone.parse("#{day} 08:00")
        route_day.layovers.create!(bus_id: "TEST-0001", go_back: 0, end_time:, next_start_time: end_time + minutes.minutes)
      end
    end
  end

  let(:days) { [ route_day(Date.new(2026, 10, 19), [ 10, 20 ]), route_day(Date.new(2026, 10, 20), [ 30 ]) ] }

  it "兩天的折返停留合在一起算百分位數：去程 3 筆、p50 20.0，不是兩天各自的值再合" do
    row = described_class.new(RouteDay.where(id: days.map(&:id))).rows.find { it.go_back.zero? }
    expect([ row.n_layovers, row.percentiles[1] ]).to eq([ 3, 20.0 ])
  end

  it "每個方向都有一列，標出那個方向的末站站名；沒有折返停留的方向筆數是 0" do
    rows = described_class.new(RouteDay.where(id: days.map(&:id))).rows
    expect(rows.map { [ it.go_back, it.stop_name, it.n_layovers ] }).to eq([ [ 0, "戊站", 3 ], [ 1, "甲站", 0 ] ])
  end
end
