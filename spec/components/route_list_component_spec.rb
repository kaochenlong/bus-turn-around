# frozen_string_literal: true

require "rails_helper"

RSpec.describe RouteListComponent, type: :component do
  def store_days(*days)
    days.each do |day|
      create(:route_day, day: Date.iso8601(day))
    end
  end

  def render_list = render_inline(described_class.new(route_list: HomePage::RouteList.new))

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
end
