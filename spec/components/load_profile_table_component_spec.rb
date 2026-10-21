# frozen_string_literal: true

require "rails_helper"

RSpec.describe LoadProfileTableComponent, type: :component do
  let(:route_day) do
    RouteDay.create!(route_id: 9001, day: Date.new(2026, 10, 19), route_name: "測試幹線", departure: "甲站",
                     destination: "戊站", static_day: Date.new(2026, 10, 19), loaded_at: Time.current).tap do |route_day|
      route_day.stops.create!(go_back: 0, seq: 3, stop_name: "丁站")
    end
  end

  # Three morning-peak trips with counts 10, 12 and 20 at seq 3.
  before do
    [ [ "07:00", 10 ], [ "07:10", 12 ], [ "08:00", 20 ] ].each do |start, count|
      start_time = Time.zone.parse("2026-10-19 #{start}")
      trip = route_day.trips.create!(bus_id: "TEST-0001", path_attribute_id: 9001, go_back: 0, band: "morning_peak", start_time:,
                                     end_time: start_time + 50.minutes, first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5,
                                     completeness: "complete", start_from_arrival: false, end_from_departure: false)
      trip.trip_stop_counts.create!(seq: 3, on_board: count)
    end
  end

  it "每站一列，早尖峰那一格是中位數 / p90（趟數），其他時段顯示 —" do
    rendered = render_inline(described_class.new(load_profile: RoutePage::LoadProfile.new(RouteDay.where(id: route_day.id))))
    expect(rendered.css("tbody tr").map { |row| row.css("td").map { it.text.squish } }).to eq([ [ "去程", "3", "丁站", "12.0 / 18.4（3）", "—", "—", "—" ] ])
  end
end
