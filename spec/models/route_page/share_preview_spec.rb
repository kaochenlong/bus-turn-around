require "rails_helper"

RSpec.describe RoutePage::SharePreview, type: :model do
  # The last stop of each direction: 戊站 for direction 0, 甲站 for direction 1.
  def last_stops = [ { go_back: 0, seq: 4, stop_name: "戊站" }, { go_back: 1, seq: 9, stop_name: "甲站" } ]

  # A stored day of 9001 with the given stops, by default the last stop of
  # each direction, and layovers of the given minutes ending in each direction.
  def store_day(day, layovers: {}, stops: last_stops, **attributes)
    create(:route_day, day: Date.iso8601(day), **attributes).tap do |route_day|
      route_day.stops.create!(stops)
      end_time = Time.zone.parse("#{day} 08:00")
      layovers.each { |go_back, minutes| minutes.each { route_day.layovers.create!(bus_id: "TEST-0001", go_back:, end_time:, next_start_time: end_time + it.minutes) } }
    end
  end

  # The nature of the end where direction 0 trips end and of the one where
  # direction 1 trips end.
  def route_ends(outbound, inbound) = RoutePage::Ends.from_config({ 0 => outbound, 1 => inbound }, route_id: 9001)

  # The preview of /routes/9001 for the day and range, built the way the page
  # builds it: from Coverage#route_days, which lists the oldest day first.
  def share_preview(day:, range: "day", ends: route_ends("stop", "stop"))
    coverage = RoutePage::Coverage.new(route_id: 9001, day:, range:)
    route_days = coverage.route_days
    described_class.new(coverage:, route_days:, layover_stats: RoutePage::LayoverStats.new(route_days), ends:)
  end

  it "只有返程那一端停車：title 是路線名接站名；分享文字是起迄、那一天與日型別、那一端的筆數、中位數與比例，句尾寫休息的上限" do
    store_day("2026-10-19", layovers: { 0 => [ 2 ], 1 => [ 10, 20, 30 ] })
    preview = share_preview(day: "2026-10-19", ends: route_ends("pass_through", "stop"))
    expect([ preview.title, preview.description ]).to eq(
      [ "測試幹線｜折返點 TurnAround", "甲站－戊站，2026-10-19（一）平日：停車端甲站：量到 3 次折返停留，中位數 20.0 分鐘，33.3% 不到 15 分鐘。折返停留是駕駛休息的上限，不是工時。" ]
    )
  end

  it "兩端都停車：依方向各一句，用「；」接" do
    store_day("2026-10-19", layovers: { 0 => [ 5 ], 1 => [ 10, 20, 30 ] })
    expect(share_preview(day: "2026-10-19").description).to eq(
      "甲站－戊站，2026-10-19（一）平日：停車端戊站：量到 1 次折返停留，中位數 5.0 分鐘，100.0% 不到 15 分鐘；停車端甲站：量到 3 次折返停留，中位數 20.0 分鐘，33.3% 不到 15 分鐘。折返停留是駕駛休息的上限，不是工時。"
    )
  end

  it "兩端都直接折返：停車端那一段換成沒有停車的一端那一句" do
    store_day("2026-10-19", layovers: { 0 => [ 5 ], 1 => [ 10 ] })
    expect(share_preview(day: "2026-10-19", ends: route_ends("pass_through", "pass_through")).description)
      .to eq("甲站－戊站，2026-10-19（一）平日：兩端都是直接折返，沒有停車的一端。折返停留是駕駛休息的上限，不是工時。")
  end

  it "停車端在涵蓋的日子沒有折返停留：那一端寫折返停留 0 次" do
    store_day("2026-10-19", layovers: { 0 => [ 5 ] })
    expect(share_preview(day: "2026-10-19", ends: route_ends("pass_through", "stop")).description)
      .to eq("甲站－戊站，2026-10-19（一）平日：停車端甲站：折返停留 0 次。折返停留是駕駛休息的上限，不是工時。")
  end

  it "最新一天只有返程的站序：去程那一端沒有列，分享文字略過它，跟摘要一樣" do
    store_day("2026-10-19", layovers: { 0 => [ 5 ], 1 => [ 10, 20, 30 ] }, stops: last_stops.last(1))
    expect(share_preview(day: "2026-10-19").description)
      .to eq("甲站－戊站，2026-10-19（一）平日：停車端甲站：量到 3 次折返停留，中位數 20.0 分鐘，33.3% 不到 15 分鐘。折返停留是駕駛休息的上限，不是工時。")
  end

  # The spec's coverage wording per range. The older day has another route
  # name and departure, so the title and the span show which day they read.
  { "day" => "2026-10-20（二）平日", "7d" => "到 2026-10-20（二）為止的最近 7 天，平日 2 天" }.each do |range, coverage|
    it "range=#{range}：涵蓋寫成「#{coverage}」，title 與起迄取涵蓋到的最新一天" do
      store_day("2026-10-19", route_name: "舊幹線", departure: "乙站").then { store_day("2026-10-20") }
      preview = share_preview(day: "2026-10-20", range:, ends: route_ends("pass_through", "pass_through"))
      expect([ preview.title, preview.description ]).to eq([ "測試幹線｜折返點 TurnAround", "甲站－戊站，#{coverage}：兩端都是直接折返，沒有停車的一端。折返停留是駕駛休息的上限，不是工時。" ])
    end
  end

  it "選的那一天沒有資料時不建立，丟出 ArgumentError" do
    store_day("2026-10-19")
    expect { share_preview(day: "2026-10-21") }.to raise_error(ArgumentError, /route 9001/)
  end

  it "en：最近 7 天、兩端都停車、其中一端沒有折返停留" do
    store_day("2026-10-19", layovers: { 0 => [ 5 ] }).then { store_day("2026-10-20") }
    preview = share_preview(day: "2026-10-20", range: "7d")
    expect(I18n.with_locale(:en) { [ preview.title, preview.description ] }).to eq(
      [ "測試幹線 | TurnAround", "甲站–戊站, the last 7 days up to 2026-10-20（二）, 2 weekday days: stopping end 戊站: 1 layovers measured, median 5.0 min, 100.0% under 15 min; stopping end 甲站: 0 layovers. A layover is an upper bound on the driver's rest, not working time." ]
    )
  end

  it "en：當天、兩端都直接折返" do
    store_day("2026-10-19")
    expect(I18n.with_locale(:en) { share_preview(day: "2026-10-19", ends: route_ends("pass_through", "pass_through")).description })
      .to eq("甲站–戊站, 2026-10-19（一）, weekday: Buses drive straight on at both ends; neither end is a stopping end. A layover is an upper bound on the driver's rest, not working time.")
  end
end
