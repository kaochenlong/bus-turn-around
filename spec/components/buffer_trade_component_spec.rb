# frozen_string_literal: true

require "rails_helper"

RSpec.describe BufferTradeComponent, type: :component do
  # One stored day with trips by vehicles A and B and layovers as ["HH:MM" end
  # time, minutes, direction of the ending trip], the direction 0 when left
  # out. By default they end at 08:00 (5 minutes) and 08:20 (20 minutes): at
  # 15 minutes the shortfall is 10.
  def route_day(layovers: [ [ "08:00", 5 ], [ "08:20", 20 ] ])
    RouteDay.create!(route_id: 9001, day: Date.new(2026, 10, 19), route_name: "測試幹線", departure: "甲站", destination: "戊站",
                     static_day: Date.new(2026, 10, 19), loaded_at: Time.current).tap do |day|
      %w[A B].each { add_trip(day, it) }
      layovers.each do |time, minutes, go_back = 0|
        end_time = Time.zone.parse("2026-10-19 #{time}")
        day.layovers.create!(bus_id: "A", go_back:, end_time:, next_start_time: end_time + minutes.minutes)
      end
    end
  end

  def add_trip(day, bus_id)
    day.trips.create!(bus_id:, path_attribute_id: 9001, go_back: 0, band: "morning_peak",
                      start_time: Time.zone.parse("2026-10-19 07:00"), end_time: Time.zone.parse("2026-10-19 07:50"),
                      first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5, completeness: "complete",
                      start_from_arrival: false, end_from_departure: false)
  end

  # The nature of the end where direction 0 trips end and of the one where
  # direction 1 trips end.
  def route_ends(outbound, inbound) = RoutePage::Ends.from_config({ 0 => outbound, 1 => inbound }, route_id: 9001)

  def render_trade(day, range: "day", ends: route_ends("stop", "stop"))
    coverage = RoutePage::Coverage.new(route_id: 9001, day: "2026-10-19", range:)
    render_inline(described_class.new(buffer_trade: RoutePage::BufferTrade.new(RouteDay.where(id: day.id), minutes: 15, ends:), coverage:))
  end

  def values(rendered) = rendered.css("[data-value]").to_h { [ it["data-value"], it.text.squish ] }

  it "每個數字放在自己的欄位：緩衝、天數、折返停留、趟次、達成率、車時、最忙小時的車數、每天車數" do
    expect(values(render_trade(route_day))).to include(
      "minutes" => "15", "days" => "1", "layovers" => "2", "trips" => "2", "achieved" => "50.0%",
      "vehicle-hours-lower" => "0.2", "vehicle-hours-upper" => "0.5", "vehicles-per-day" => "2.0"
    )
  end

  it "有開過去就走的一端時，停車端的筆數是試算的基礎，那一端的筆數另外報" do
    day = route_day(layovers: [ [ "07:00", 2, 0 ], [ "07:30", 2, 0 ], [ "09:00", 2, 0 ], [ "08:00", 5, 1 ], [ "08:20", 20, 1 ] ])
    expect(values(render_trade(day, ends: route_ends("pass_through", "stop")))).to include("layovers" => "2", "pass-through-layovers" => "3")
  end

  it "兩端都停車時沒有開過去就走那一端的筆數" do
    expect(render_trade(route_day).css("[data-value=pass-through-layovers]").size).to eq(0)
  end

  it "只有開過去就走那一端有折返停留時，說明沒有停車端的折返停留，仍報那一端的筆數" do
    rendered = render_trade(route_day(layovers: [ [ "08:00", 2, 0 ], [ "08:10", 2, 0 ], [ "08:20", 2, 0 ] ]), ends: route_ends("pass_through", "stop"))
    expect([ rendered.css("[data-no-layover]").size, values(rendered)["pass-through-layovers"] ]).to eq([ 1, "3" ])
  end

  it "最忙小時的車數標出是幾點" do
    peaks = render_trade(route_day).css("[data-peak]").map { [ it["data-peak"], it["data-hour"], it.at_css("[data-vehicles]").text.squish ] }
    expect(peaks).to eq([ %w[lower 8 0.2], %w[upper 8 0.5] ])
  end

  it "拉桿表單在 buffer-trade frame 裡，帶著目前的日期與範圍" do
    frame = render_trade(route_day, range: "7d").at_css("turbo-frame#buffer-trade")
    fields = %w[day range].to_h { [ it, frame.at_css("form input[type=hidden][name=#{it}]")["value"] ] }
    expect([ frame["data-turbo-action"], fields ]).to eq([ "advance", { "day" => "2026-10-19", "range" => "7d" } ])
  end

  it "拉桿是 0 到 20 分鐘，停在目前的緩衝分鐘數" do
    slider = render_trade(route_day).at_css("input[type=range][name=buffer]")
    expect(slider.attributes.slice("min", "max", "value").transform_values(&:value)).to eq("min" => "0", "max" => "20", "value" => "15")
  end

  it "沒有折返停留時顯示說明，不顯示達成率與增加量" do
    rendered = render_trade(route_day(layovers: []))
    expect([ rendered.css("[data-no-layover]").size, rendered.css("[data-value=achieved], [data-peak]").size ]).to eq([ 1, 0 ])
  end
end
