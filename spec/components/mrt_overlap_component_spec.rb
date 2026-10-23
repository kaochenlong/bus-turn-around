# frozen_string_literal: true

require "rails_helper"

RSpec.describe MrtOverlapComponent, type: :component do
  # A stored day whose direction 0 stops have the given distances, with one
  # morning-peak trip counted at sequence 1 and 2.
  def route_day(distances)
    create(:route_day, mrt_exits_day: Date.new(2026, 10, 18)).tap do |day|
      distances.each_with_index { |meters, seq| day.stops.create!(go_back: 0, seq:, stop_name: "站#{seq}", nearest_exit_meters: meters) }
    end
  end

  def add_trip(day)
    trip = day.trips.create!(bus_id: "TEST-0001", path_attribute_id: 9001, go_back: 0, band: "morning_peak",
                             start_time: Time.zone.parse("2026-10-19 07:00"), end_time: Time.zone.parse("2026-10-19 07:50"),
                             first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5, completeness: "complete",
                             start_from_arrival: false, end_from_departure: false)
    trip.trip_stop_counts.create!([ { seq: 1, on_board: 10 }, { seq: 2, on_board: 20 } ])
  end

  def render_overlap(day) = render_inline(described_class.new(mrt_overlap: RoutePage::MrtOverlap.new(RouteDay.where(id: day.id))))

  def cells(nodes) = nodes.map { |row| row.css("td").map { it.text.squish } }

  it "每個方向一列：方向、站數、300、500、800 公尺的重疊度" do
    expect(cells(render_overlap(route_day([ 900, 400, 250, 450, 700 ])).css("[data-shares] tbody tr"))).to eq([ %w[去程 5 20.0% 60.0% 80.0%] ])
  end

  it "重疊路段帶起訖站序、站名與站數，以及各時段的趟數、中位數、p90" do
    day = route_day([ 900, 400, 250, 900 ]).tap { add_trip(it) }
    stretch = render_overlap(day).at_css("[data-stretch]")
    expect([ stretch["data-stretch"], cells(stretch.css("tbody tr")) ]).to eq([ "0:1-2", [ %w[早尖峰 1 15.0 19.0] ] ])
  end

  it "標出用的出入口快照日" do
    expect(render_overlap(route_day([ 400, 450 ])).at_css("[data-mrt-exits-day]")["data-mrt-exits-day"]).to eq("2026-10-18")
  end

  it "站牌沒有距離時提示重算，不顯示重疊度" do
    rendered = render_overlap(route_day([ nil, nil ]))
    expect([ rendered.css("[data-needs-reload]").size, rendered.css("[data-shares]").size ]).to eq([ 1, 0 ])
  end
end
