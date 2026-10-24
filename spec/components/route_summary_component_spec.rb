# frozen_string_literal: true

require "rails_helper"

RSpec.describe RouteSummaryComponent, type: :component do
  # The last stop of each direction: 戊站 for direction 0, 甲站 for direction 1.
  let(:stops) { [ { go_back: 0, seq: 4, stop_name: "戊站" }, { go_back: 1, seq: 9, stop_name: "甲站" } ] }

  let(:route_day) do
    create(:route_day).tap { it.stops.create!(stops) }
  end

  def trip(start, completeness)
    start_time = Time.zone.parse("2026-10-19 #{start}")
    route_day.trips.create!(bus_id: "TEST-0001", path_attribute_id: 9001, go_back: 0, band: "other", start_time:,
                            end_time: start_time + 50.minutes, first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5,
                            completeness:, start_from_arrival: false, end_from_departure: false)
  end

  # Layovers of the given minutes, ending in direction go_back.
  def add_layovers(go_back, minutes)
    end_time = Time.zone.parse("2026-10-19 08:00")
    minutes.each { route_day.layovers.create!(bus_id: "TEST-0001", go_back:, end_time:, next_start_time: end_time + it.minutes) }
  end

  # The nature of the end where direction 0 trips end and of the one where
  # direction 1 trips end.
  def route_ends(outbound, inbound) = RoutePage::Ends.from_config({ 0 => outbound, 1 => inbound }, route_id: 9001)

  def render_summary(ends = route_ends("stop", "stop"), day: route_day)
    route_days = RouteDay.where(id: day.id)
    render_inline(described_class.new(summary: RoutePage::Summary.new(route_days), layover_stats: RoutePage::LayoverStats.new(route_days),
                                      ends:, mrt_overlap: RoutePage::MrtOverlap.new(route_days)))
  end

  # The lines of a key number: the end or direction each is for, and its number.
  def numbers(rendered, key, by: "data-end") = rendered.css("[data-key-number=#{key}] [#{by}]").map { [ it[by], it.at_css("[data-number]").text ] }

  # The lines of a layover key number with their whole text.
  def lines(rendered, key) = rendered.css("[data-key-number=#{key}] [data-end]").map { [ it["data-end"], it.at_css("[data-number]").text, it.text.squish ] }

  it "顯示趟數與完整趟數" do
    trip("07:00", "complete").then { trip("08:00", "missing_end") }
    rendered = render_summary
    expect(%w[trips complete-trips].map { rendered.at_css("[data-#{it}]")["data-#{it}"] }).to eq(%w[2 1])
  end

  it "只有返程那一端停車時，兩個折返停留的重點數字只有那一端：p50 20.0、不到 15 分鐘 33.3%" do
    add_layovers(1, [ 10, 20, 30 ])
    rendered = render_summary(route_ends("pass_through", "stop"))
    expect([ lines(rendered, "layover-p50"), lines(rendered, "short-share") ]).to match([ [ [ "1", "20.0", include("甲站") ] ], [ [ "1", "33.3%", include("甲站") ] ] ])
  end

  it "兩端都停車時，兩個折返停留的重點數字各有兩行，每一行標出那一端的末站" do
    add_layovers(0, [ 5 ]).then { add_layovers(1, [ 10, 20, 30 ]) }
    rendered = render_summary
    expect([ lines(rendered, "layover-p50"), lines(rendered, "short-share") ]).to match(
      [ [ [ "0", "5.0", include("戊站") ], [ "1", "20.0", include("甲站") ] ], [ [ "0", "100.0%", include("戊站") ], [ "1", "33.3%", include("甲站") ] ] ]
    )
  end

  it "兩端都是直接折返時，寫明沒有停車的一端，不放折返停留的數字" do
    rendered = render_summary(route_ends("pass_through", "pass_through"))
    expect([ rendered.css("[data-no-stopping-end]").size, rendered.css("[data-key-number=layover-p50], [data-key-number=short-share]").size ]).to eq([ 1, 0 ])
  end

  it "停車的那一端沒有折返停留時，兩個數字都是 —，仍標出那一端的末站" do
    add_layovers(0, [ 5 ])
    rendered = render_summary
    expect([ lines(rendered, "layover-p50").last, lines(rendered, "short-share").last ]).to match([ [ "1", "—", include("甲站") ] ] * 2)
  end

  it "p50 有值時帶分鐘的單位，是 — 時不帶" do
    add_layovers(0, [ 5 ])
    expect(render_summary.css("[data-key-number=layover-p50] [data-end]").map { it.css("[data-unit]").size }).to eq([ 1, 0 ])
  end

  it "最新一天沒有站牌、折返停留表沒有任何一列時，摘要也沒有任何一端的行" do
    rendered = render_summary(day: create(:route_day, day: Date.new(2026, 10, 20)))
    expect(rendered.css("[data-key-number] [data-end]").size).to eq(0)
  end

  it "站牌還沒有到捷運的距離時，捷運重疊的去程、返程都是 —" do
    expect(numbers(render_summary, "mrt-share", by: "data-direction")).to eq([ %w[0 —], %w[1 —] ])
  end

  describe "站牌有到捷運的距離時" do
    let(:stops) do
      [ { go_back: 0, seq: 3, stop_name: "丁站", nearest_exit_meters: 400 }, { go_back: 0, seq: 4, stop_name: "戊站", nearest_exit_meters: 900 },
        { go_back: 1, seq: 9, stop_name: "甲站", nearest_exit_meters: 300 } ]
    end

    it "捷運重疊是兩個方向 500 公尺內的比例：去程 50.0%、返程 100.0%" do
      expect(numbers(render_summary, "mrt-share", by: "data-direction")).to eq([ %w[0 50.0%], %w[1 100.0%] ])
    end

    it "最新一天只有去程的站牌時，返程的捷運重疊是 —" do
      stops.pop
      expect(numbers(render_summary, "mrt-share", by: "data-direction")).to eq([ %w[0 50.0%], %w[1 —] ])
    end
  end
end
