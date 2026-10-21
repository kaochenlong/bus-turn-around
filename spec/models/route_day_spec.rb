require "rails_helper"

# == Schema Information
#
# Table name: route_days
#
#  id          :bigint           not null, primary key
#  day         :date             not null
#  departure   :string           not null
#  destination :string           not null
#  loaded_at   :timestamptz      not null
#  route_name  :string           not null
#  static_day  :date             not null
#  route_id    :integer          not null
#
# Indexes
#
#  index_route_days_on_route_id_and_day  (route_id,day) UNIQUE
#
RSpec.describe RouteDay, type: :model do
  def create_route_day(day: Date.new(2026, 10, 19))
    described_class.create!(route_id: 9001, day:, route_name: "測試幹線", departure: "甲站", destination: "戊站",
                            static_day: day, loaded_at: Time.current)
  end

  # One stop, one trip with one count, and one layover on the route day.
  def fill(route_day)
    route_day.stops.create!(go_back: 0, seq: 0, stop_name: "甲站")
    trip = route_day.trips.create!(bus_id: "TEST-0001", path_attribute_id: 9001, go_back: 0, band: "other",
                                   start_time: Time.zone.parse("2026-10-19 06:00"), end_time: Time.zone.parse("2026-10-19 06:50"),
                                   first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5, completeness: "complete",
                                   start_from_arrival: false, end_from_departure: false)
    trip.trip_stop_counts.create!(seq: 0, on_board: 3)
    route_day.layovers.create!(bus_id: "TEST-0001", go_back: 0, end_time: trip.end_time, next_start_time: trip.end_time + 10.minutes)
  end

  def row_counts = [ RouteDayStop, Trip, TripStopCount, Layover ].map(&:count)

  it "刪掉一天時，那一天的站序、趟次、趟次站人數與折返停留都跟著刪掉" do
    route_day = create_route_day.tap { fill(it) }
    expect { route_day.delete }.to change { row_counts }.from([ 1, 1, 1, 1 ]).to([ 0, 0, 0, 0 ])
  end

  it "同一路線同一天只能有一列" do
    create_route_day
    expect { create_route_day }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
