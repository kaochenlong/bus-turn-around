require "rails_helper"

RSpec.describe RoutePage::LayoverDistribution, type: :model do
  # A stored day whose direction 0 runs 甲站 to 戊站 and direction 1 己站 to
  # 甲站, with layovers of the given minutes ending in direction 0.
  def route_day(day, layover_minutes)
    RouteDay.create!(route_id: 9001, day:, route_name: "測試幹線", departure: "甲站", destination: "戊站",
                     static_day: day, loaded_at: Time.current).tap do |route_day|
      route_day.stops.create!([ { go_back: 0, seq: 0, stop_name: "甲站" }, { go_back: 0, seq: 4, stop_name: "戊站" },
                                { go_back: 1, seq: 5, stop_name: "己站" }, { go_back: 1, seq: 9, stop_name: "甲站" } ])
      end_time = Time.zone.parse("#{day} 08:00")
      layover_minutes.each do |minutes|
        route_day.layovers.create!(bus_id: "TEST-0001", go_back: 0, end_time:, next_start_time: end_time + minutes.minutes)
      end
    end
  end

  def directions(*days) = described_class.new(RouteDay.where(id: days.map(&:id))).directions

  it "每組含下界、不含下一個下界，最後一組不設上限：4.9、5.0、14.9、15.0、75.0 分鐘得 1、1、1、1、0、1" do
    direction = directions(route_day(Date.new(2026, 10, 19), [ 4.9, 5.0, 14.9, 15.0, 75.0 ])).first
    expect(direction.counts).to eq([ 1, 1, 1, 1, 0, 1 ])
  end

  it "每個方向標出自己的末站，以及下一趟出發的另一個方向的起站" do
    result = directions(route_day(Date.new(2026, 10, 19), [ 10 ]))
    expect(result.map { [ it.go_back, it.last_stop, it.next_first_stop ] }).to eq([ [ 0, "戊站", "己站" ], [ 1, "甲站", "甲站" ] ])
  end

  it "沒有折返停留的方向仍有一筆，每組都是 0" do
    expect(directions(route_day(Date.new(2026, 10, 19), [ 10 ])).last.counts).to eq([ 0, 0, 0, 0, 0, 0 ])
  end

  it "兩天的折返停留合在一起數" do
    days = [ route_day(Date.new(2026, 10, 19), [ 3, 20 ]), route_day(Date.new(2026, 10, 20), [ 4 ]) ]
    expect(directions(*days).first.counts).to eq([ 2, 0, 0, 1, 0, 0 ])
  end
end
