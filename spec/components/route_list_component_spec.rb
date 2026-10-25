# frozen_string_literal: true

require "rails_helper"

RSpec.describe RouteListComponent, type: :component do
  def store_days(*days)
    days.each do |day|
      create(:route_day, day: Date.iso8601(day))
    end
  end

  def render_list = render_inline(described_class.new(route_list: HomePage::RouteList.new))

  # A stored day of 9001 with the last stop of each direction, 戊站 for
  # direction 0 and 甲站 for direction 1, and layovers of the given minutes
  # ending in each direction.
  def store_measured_day(day, layovers: {})
    create(:route_day, day: Date.iso8601(day)).tap do |route_day|
      route_day.stops.create!([ { go_back: 0, seq: 4, stop_name: "戊站" }, { go_back: 1, seq: 9, stop_name: "甲站" } ])
      end_time = Time.zone.parse("#{day} 08:00")
      layovers.each { |go_back, minutes| minutes.each { route_day.layovers.create!(bus_id: "TEST-0001", go_back:, end_time:, next_start_time: end_time + it.minutes) } }
    end
  end

  # The nature of the end where direction 0 trips end and of the one where
  # direction 1 trips end.
  def route_ends(outbound, inbound) = RoutePage::Ends.from_config({ 0 => outbound, 1 => inbound }, route_id: 9001)

  # The figure block on 9001's card, or nil without one.
  def figure_block = render_list.at_css("[data-route='9001'] [data-figure='short-share']")

  # Each line of a figure block: its end, its number and its whole text.
  def figure_lines(block) = Array(block&.css("[data-end]")).map { [ it["data-end"], it.at_css("[data-number]")&.text, it.text.squish ] }

  it "有資料的 9001：名稱那一行只有路線名，起迄那一行接著這一頁全部的路線 Id（test 設定掛 9050），再來是最新一天和星期與那天的日型別，整張只連到 9001 的路線頁" do
    store_days("2026-10-19", "2026-10-20")
    card = render_list.at_css("[data-route='9001'][data-latest-day='2026-10-20']")
    route_id = card.at_css("[data-route-id]")
    expect([ card.at_css("p").text, route_id&.text, route_id&.parent&.text&.include?("甲站－戊站"), card.text, card["data-day-type"], card["href"] ])
      .to match([ "測試幹線", "路線 Id 9001・9050", true, include("2026-10-20（二）#{I18n.t('day_types.weekday')}"), "weekday", "/routes/9001" ])
  end

  it "成員路線 9050 沒有自己的卡；只有一個 Id 的路線那一行一字不變" do
    allow(RoutePage).to receive(:member_route_ids).and_call_original
    allow(RoutePage).to receive(:member_route_ids).with(9001).and_return([ 9001 ])
    store_days("2026-10-20")
    rendered = render_list
    expect([ rendered.css("[data-route='9050']").size, rendered.at_css("[data-route='9001'] [data-route-id]").text ]).to eq([ 0, "路線 Id 9001" ])
  end

  it "有成員但還沒有資料的路線：卡上寫全部的路線 Id、標成沒有資料、沒有連結" do
    allow(RoutePage).to receive(:route_ids).and_return([ 9001 ])
    card = render_list.at_css("[data-route='9001'][data-no-data]")
    expect([ card&.at_css("p")&.text, card&.css("a")&.size ]).to eq([ "路線 Id 9001・9050", 0 ])
  end

  it "最新一天是假日 10-26 時，卡上的日期後面接假日" do
    store_days("2026-10-23").then { create(:route_day, day: Date.new(2026, 10, 26), day_type: "holiday") }
    cards = render_list.css("[data-route='9001'][data-latest-day='2026-10-26']")
    expect([ cards.text, cards.map { it["data-day-type"] } ]).to match([ include("2026-10-26（一）#{I18n.t('day_types.holiday')}"), [ "holiday" ] ])
  end

  it "沒有資料的 15373 只寫路線 Id 並標成沒有資料，清單裡唯一的連結是 9001 的" do
    store_days("2026-10-20")
    rendered = render_list
    no_data_card = rendered.at_css("[data-route='15373'][data-no-data]")
    expect([ no_data_card&.at_css("p")&.text, rendered.css("a").map { it["href"] } ]).to eq([ "路線 Id 15373", [ "/routes/9001" ] ])
  end

  it "兩端都停車：每一端一行，比例接末站與筆數；那一天沒有折返停留的去程是 — 與 0 次" do
    store_measured_day("2026-10-20", layovers: { 1 => [ 10, 20, 30 ] })
    expect(figure_lines(figure_block)).to eq([ [ "0", "—", "— 戊站・共 0 次折返" ], [ "1", "33.3%", "33.3% 甲站・共 3 次折返" ] ])
  end

  it "只有返程那一端停車：兩端都有折返停留，也只有返程那一行" do
    allow(RoutePage).to receive(:ends).and_return(route_ends("pass_through", "stop"))
    store_measured_day("2026-10-20", layovers: { 0 => [ 5 ], 1 => [ 10 ] })
    expect(figure_lines(figure_block).map(&:first)).to eq([ "1" ])
  end

  it "兩端都直接折返：那一塊只有沒有停車端的那一句，沒有任何一行" do
    allow(RoutePage).to receive(:ends).and_return(route_ends("pass_through", "pass_through"))
    store_measured_day("2026-10-20", layovers: { 0 => [ 5 ], 1 => [ 10 ] })
    block = figure_block
    expect([ block&.css("[data-no-stopping-end]")&.size, figure_lines(block) ]).to eq([ 1, [] ])
  end

  it "只算最新那一天：10-19 返程的 10 分鐘不算，返程那一行是 0.0%、共 2 次折返" do
    store_measured_day("2026-10-19", layovers: { 1 => [ 10 ] }).then { store_measured_day("2026-10-20", layovers: { 1 => [ 20, 30 ] }) }
    expect(figure_lines(figure_block).last).to eq([ "1", "0.0%", "0.0% 甲站・共 2 次折返" ])
  end

  # The card says what the summary says, but each component keeps its own
  # sidecar file: sidecar translations are not in the global I18n backend.
  it "卡上的 short_share、short_count、no_stopping_end，tw 與 en 都跟摘要同名的字串相同" do
    keys = %w[short_share short_count no_stopping_end]
    list, summary = %w[route_list_component route_summary_component].map { YAML.load_file(Rails.root.join("app/components/#{it}.yml"), aliases: true) }
                                                                     .map { |file| %w[tw en].map { file.fetch(it).values_at(*keys) } }
    expect([ list, summary.flatten.compact.size ]).to eq([ summary, 6 ])
  end

  it "沒有資料的卡沒有數字那一塊" do
    store_measured_day("2026-10-20", layovers: { 1 => [ 10 ] })
    expect(render_list.css("[data-route='15373'][data-figure], [data-route='15373'] [data-figure]").size).to eq(0)
  end
end
