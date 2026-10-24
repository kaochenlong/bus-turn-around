require "rails_helper"

RSpec.describe RoutePage::LoadProfile, type: :model do
  def route_day(day, names)
    create(:route_day, day:).tap do |route_day|
      names.each { |(go_back, seq), stop_name| route_day.stops.create!(go_back:, seq:, stop_name:) }
    end
  end

  # One complete direction 0 trip of the route day with an on-board count at `seq`.
  def count_at(route_day, seq, on_board)
    trip = route_day.trips.create!(bus_id: "TEST-0001", path_attribute_id: 9001, go_back: 0, band: "other", start_time: Time.zone.parse("2026-10-19 06:00"),
                                   end_time: Time.zone.parse("2026-10-19 06:50"), first_seq: 0, last_seq: 4, n_events: 5, n_stops_observed: 5,
                                   completeness: "complete", start_from_arrival: false, end_from_departure: false)
    trip.trip_stop_counts.create!(seq:, on_board:)
  end

  it "成員路線的站序不進來：最新那一天另有 9050 的己站時，站序只列 9001 的，剖面的站名是 9001 的丙站" do
    day = route_day(Date.new(2026, 10, 19), [ 0, 2 ] => "丙站").tap { it.stops.create!(route_id: 9050, go_back: 0, seq: 2, stop_name: "己站") }
    count_at(day, 2, 5)
    profile = described_class.new(RouteDay.where(id: day.id))
    expect([ profile.stops.map(&:stop_name), profile.rows.map { [ it.seq, it.stop_name, it.n_trips ] } ]).to eq([ [ "丙站" ], [ [ 2, "丙站", 1 ] ] ])
  end

  it "站序取最新那一天的站牌，依方向與站序排" do
    days = [ route_day(Date.new(2026, 10, 19), [ 0, 0 ] => "舊站"),
             route_day(Date.new(2026, 10, 20), [ 1, 2 ] => "丙站", [ 0, 1 ] => "乙站", [ 0, 0 ] => "甲站") ]
    stops = described_class.new(RouteDay.where(id: days.map(&:id))).stops
    expect(stops.map { [ it.go_back, it.seq, it.stop_name ] }).to eq([ [ 0, 0, "甲站" ], [ 0, 1, "乙站" ], [ 1, 2, "丙站" ] ])
  end
end
