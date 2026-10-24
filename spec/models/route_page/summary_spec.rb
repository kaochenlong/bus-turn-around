require "rails_helper"

RSpec.describe RoutePage::Summary, type: :model do
  # A complete trip of the route day on the given route Id, starting at `start` on the day.
  def add_trip(route_day, route_id, start)
    start_time = Time.zone.parse("#{route_day.day} #{start}")
    route_day.trips.create!(route_id:, bus_id: "TEST-0005", path_attribute_id: route_id, go_back: 0, band: "other", start_time:,
                            end_time: start_time + 50.minutes, first_seq: 0, last_seq: 4, n_events: 5, n_stops_observed: 5,
                            completeness: "complete", start_from_arrival: false, end_from_departure: false)
  end

  it "每個路線 Id 的趟次：test 設定的 9001 掛 9050，照設定的順序，9001 一趟、9050 兩趟" do
    route_day = create(:route_day)
    [ [ 9050, "07:00" ], [ 9001, "08:00" ], [ 9050, "09:00" ] ].each { |route_id, start| add_trip(route_day, route_id, start) }
    expect(described_class.new(RouteDay.where(id: route_day.id)).trips_by_route).to eq([ [ 9001, 1 ], [ 9050, 2 ] ])
  end

  it "沒有趟次的 Id 也列出來，是 0 趟；沒有成員的路線只有自己那一列" do
    days = [ create(:route_day), create(:route_day, route_id: 10712, route_name: "251", departure: "深坑", destination: "臺北車站") ]
    add_trip(days.last, 10712, "07:00")
    expect(days.map { described_class.new(RouteDay.where(id: it.id)).trips_by_route }).to eq([ [ [ 9001, 0 ], [ 9050, 0 ] ], [ [ 10712, 1 ] ] ])
  end
end
