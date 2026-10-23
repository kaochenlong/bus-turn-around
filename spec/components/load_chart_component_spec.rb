# frozen_string_literal: true

require "rails_helper"

RSpec.describe LoadChartComponent, type: :component do
  # A stored day whose direction 0 stops, at sequence 0 to 4, have the given
  # nearest-entrance distances.
  def route_day(distances)
    create(:route_day, mrt_exits_day: Date.new(2026, 10, 19)).tap do |route_day|
      distances.each_with_index do |meters, seq|
        route_day.stops.create!(go_back: 0, seq:, stop_name: %w[甲站 乙站 丙站 丁站 戊站][seq], nearest_exit_name: "出口", nearest_exit_meters: meters)
      end
    end
  end

  # A trip in direction 0 of the given band with on-board counts by sequence.
  def trip(route_day, band, counts)
    start_time = Time.zone.parse("2026-10-19 07:00") + route_day.trips.count.minutes
    trip = route_day.trips.create!(bus_id: "TEST-0001", path_attribute_id: 9001, go_back: 0, band:, start_time:,
                                   end_time: start_time + 50.minutes, first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5,
                                   completeness: "complete", start_from_arrival: false, end_from_departure: false)
    counts.each { |seq, on_board| trip.trip_stop_counts.create!(seq:, on_board:) }
  end

  def render_chart(route_day)
    route_days = RouteDay.where(id: route_day.id)
    render_inline(described_class.new(load_profile: RoutePage::LoadProfile.new(route_days), mrt_overlap: RoutePage::MrtOverlap.new(route_days)))
  end

  def points(rendered, band) = rendered.css("[data-direction='0'] [data-band='#{band}'] [data-seq]").map { [ it["data-seq"], it["data-median"] ] }

  let(:day) { route_day([ 900, 900, 400, 250, 450 ]).tap { trip(it, "morning_peak", 0 => 3, 1 => 8) }.tap { trip(it, "daytime", 0 => 5) } }

  it "每個時段一條線：早尖峰第 0、1 站是 3.0、8.0，日間只有第 0 站的 5.0" do
    rendered = render_chart(day)
    expect([ points(rendered, "morning_peak"), points(rendered, "daytime") ]).to eq([ [ %w[0 3.0], %w[1 8.0] ], [ %w[0 5.0] ] ])
  end

  it "沒有人數的站把線斷開：第 0、2 站有人數、第 1 站沒有時是兩段" do
    trip(day, "evening_peak", 0 => 4, 2 => 6)
    expect(render_chart(day).css("[data-direction='0'] [data-band='evening_peak'] [data-segment]").size).to eq(2)
  end

  it "同一個方向的時段共用縱軸，頂端是最大中位數 8.0 往上取到 10" do
    expect(render_chart(day).at_css("[data-direction='0']")["data-scale-top"]).to eq("10")
  end

  it "沒有任何人數的方向，縱軸頂端是 10" do
    expect(render_chart(route_day([ 900, 900, 900, 900, 900 ])).at_css("[data-direction='0']")["data-scale-top"]).to eq("10")
  end

  it "500 公尺內的第 2 到 4 站畫成一段底色帶，標出兩端站名" do
    span = render_chart(day).at_css("[data-direction='0'] [data-span-from]")
    expect([ span["data-span-from"], span["data-span-to"], span["data-first-stop"], span["data-last-stop"] ]).to eq(%w[2 4 丙站 戊站])
  end

  it "站牌沒有距離時，照樣畫線但沒有底色帶" do
    rendered = render_chart(route_day([ nil, nil, nil, nil, nil ]).tap { trip(it, "morning_peak", 0 => 3) })
    expect([ rendered.css("[data-span-from]").size, points(rendered, "morning_peak") ]).to eq([ 0, [ %w[0 3.0] ] ])
  end

  it "預設顯示早尖峰，其他時段在 Alpine 接手前藏起來" do
    groups = render_chart(day).css("[data-direction='0'] [data-band]")
    expect(groups.to_h { [ it["data-band"], it.key?("x-cloak") ] }).to eq("morning_peak" => false, "daytime" => true, "evening_peak" => true, "other" => true)
  end
end
