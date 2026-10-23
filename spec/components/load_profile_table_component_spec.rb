# frozen_string_literal: true

require "rails_helper"

RSpec.describe LoadProfileTableComponent, type: :component do
  let(:route_day) do
    create(:route_day).tap do |route_day|
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

  def render_table = render_inline(described_class.new(load_profile: RoutePage::LoadProfile.new(RouteDay.where(id: route_day.id))))

  # A daytime trip in direction 1 counted at sequence 5 and 6.
  def add_inbound_trip
    start_time = Time.zone.parse("2026-10-19 12:00")
    trip = route_day.trips.create!(bus_id: "TEST-0002", path_attribute_id: 9001, go_back: 1, band: "daytime", start_time:,
                                   end_time: start_time + 50.minutes, first_seq: 5, last_seq: 9, n_events: 10, n_stops_observed: 5,
                                   completeness: "complete", start_from_arrival: false, end_from_departure: false)
    trip.trip_stop_counts.create!([ { seq: 5, on_board: 4 }, { seq: 6, on_board: 7 } ])
  end

  it "表格收在預設關閉的 details 裡：每一站的列都在，收合列寫出站列數" do
    add_inbound_trip
    details = render_table.at_css("[data-section=load-profile] details[data-load-profile]")
    expect([ details&.key?("open"), details&.css("tbody tr")&.size, details&.at_css("summary [data-stop-rows]")&.[]("data-stop-rows") ]).to eq([ false, 5, "3" ])
  end

  it "每個方向一組，分組標題列寫方向，之後每站一列：早尖峰那一格是中位數 / p90（趟數），其他時段顯示 —" do
    rendered = render_table
    group = rendered.at_css("tbody[data-direction='0']")
    stop_rows = group&.css("tr")&.filter_map { |row| row.css("td").map { it.text.squish }.presence }
    expect([ group&.at_css("th")&.text&.squish, stop_rows ]).to eq([ "去程", [ [ "3", "丁站", "12.0 / 18.4（3）", "—", "—", "—" ] ] ])
  end
end
