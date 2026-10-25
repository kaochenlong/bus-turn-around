require "rails_helper"

RSpec.describe RoutePage::MeasuredDepartures, type: :model do
  # A stored day with the given number of direction 0 trips starting in the
  # 07 hour, five minutes apart; every trip is complete unless attributes say
  # otherwise.
  def route_day(day, n_trips, **attributes)
    create(:route_day, day:).tap do |route_day|
      n_trips.times { add_trip(route_day, Time.zone.parse("#{day} 07:00") + (it * 5).minutes, **attributes) }
    end
  end

  def add_trip(route_day, start_time, go_back: 0, **attributes)
    route_day.trips.create!({ bus_id: "TEST-0001", path_attribute_id: 9001, go_back:, band: "other", start_time:, end_time: start_time + 50.minutes,
                              first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5, completeness: "complete",
                              start_from_arrival: false, end_from_departure: false }.merge(attributes))
  end

  def counts(*days) = described_class.new(RouteDay.where(id: days.map(&:id))).counts

  # The rows of the spec's example "Rounding of the average": direction 0
  # trips in the 07 hour on each covered day, and the default that comes out.
  [ [ [ 5, 6, 5, 5 ], 5 ], [ [ 4, 5, 5, 5 ], 5 ], [ [ 4, 5 ], 5 ], [ [ 0, 0, 1 ], 0 ] ].each do |per_day, default|
    it "涵蓋 #{per_day.size} 天、07 時各 #{per_day.join('、')} 趟：平均四捨五入是 #{default}" do
      days = per_day.each_with_index.map { |n_trips, index| route_day(Date.new(2026, 10, 19) + index, n_trips) }
      expect(counts(*days).dig(0, 7)).to eq(default)
    end
  end

  it "兩個方向都有 0 到 23 共 24 個小時的鍵，沒有趟次的小時是 0" do
    day = route_day(Date.new(2026, 10, 19), 1)
    expect(counts(day).transform_values { [ it.keys, it.values.sum ] }).to eq(0 => [ (0..23).to_a, 1 ], 1 => [ (0..23).to_a, 0 ])
  end

  it "每一種完整度都算：完整、缺終點、起點用到站時刻的三趟都在 07 時，返程一趟在 22 時" do
    day = route_day(Date.new(2026, 10, 19), 1)
    add_trip(day, Time.zone.parse("2026-10-19 07:20"), completeness: "missing_end")
    add_trip(day, Time.zone.parse("2026-10-19 07:40"), start_from_arrival: true)
    add_trip(day, Time.zone.parse("2026-10-19 22:10"), go_back: 1)
    expect([ counts(day).dig(0, 7), counts(day).dig(1, 22) ]).to eq([ 3, 1 ])
  end

  it "23:50 發車、隔天到站的趟次算在 23 時" do
    day = create(:route_day)
    add_trip(day, Time.zone.parse("2026-10-19 23:50"))
    expect(counts(day).dig(0, 23)).to eq(1)
  end
end
