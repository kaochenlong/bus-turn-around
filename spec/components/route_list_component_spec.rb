# frozen_string_literal: true

require "rails_helper"

RSpec.describe RouteListComponent, type: :component do
  def store_days(*days)
    days.each do |day|
      RouteDay.create!(route_id: 9001, day: Date.iso8601(day), route_name: "測試幹線", departure: "甲站",
                       destination: "戊站", static_day: Date.iso8601(day), loaded_at: Time.current)
    end
  end

  def render_list = render_inline(described_class.new(route_list: HomePage::RouteList.new))

  it "有資料的 9001：卡上有路線名、Id、起迄與最新一天和星期，整張連到路線頁" do
    store_days("2026-10-19", "2026-10-20")
    cards = render_list.css("[data-route='9001'][data-latest-day='2026-10-20']")
    expect([ cards.text, cards.map { it["href"] } ]).to match([ include("測試幹線", "9001", "甲站－戊站", "2026-10-20（二）"), [ "/routes/9001" ] ])
  end

  it "沒有資料的 15373 標成沒有資料，清單裡唯一的連結是 9001 的" do
    store_days("2026-10-20")
    rendered = render_list
    expect([ rendered.css("[data-route='15373'][data-no-data]").size, rendered.css("a").map { it["href"] } ]).to eq([ 1, [ "/routes/9001" ] ])
  end
end
