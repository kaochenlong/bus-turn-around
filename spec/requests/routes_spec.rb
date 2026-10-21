require "rails_helper"

RSpec.describe "Routes", type: :request do
  def store_days(*days)
    days.each do |day|
      RouteDay.create!(route_id: 9001, day: Date.iso8601(day), route_name: "測試幹線", departure: "甲站",
                       destination: "戊站", static_day: Date.iso8601(day), loaded_at: Time.current)
    end
  end

  def page = response.parsed_body

  def covered_days = page.css("[data-covered-days] [data-day]").map { it["data-day"] }

  it "路線不在路線清單裡回 404" do
    get route_path(9999)
    expect(response).to have_http_status(:not_found)
  end

  it "沒給 day 與 range 時，顯示最新一天、範圍是一天" do
    store_days("2026-10-19", "2026-10-20")
    get route_path(9001)
    expect([ response.status, covered_days, page.at_css("[data-range]")["data-range"] ]).to eq([ 200, [ "2026-10-20" ], "day" ])
  end

  [ { range: "30d" }, { day: "2026-13-40" }, { day: "20261019" } ].each do |params|
    it "#{params.inspect} 回 400" do
      get route_path(9001), params: params
      expect(response).to have_http_status(:bad_request)
    end
  end

  it "最近 7 天只涵蓋已寫入的日子，列出日期與星期" do
    store_days("2026-10-15", "2026-10-19", "2026-10-20", "2026-10-22")
    get route_path(9001), params: { day: "2026-10-22", range: "7d" }
    expect(page.css("[data-covered-days] [data-day]").map(&:text).map(&:squish)).to eq([ "2026-10-19（一）", "2026-10-20（二）", "2026-10-22（四）" ])
  end

  it "有資料的那一天，頁面依序是摘要、行駛時間、折返停留、捷運重疊、載客剖面、資料限制" do
    store_days("2026-10-19")
    get route_path(9001), params: { day: "2026-10-19" }
    expect(page.css("[data-section]").map { it["data-section"] }).to eq(%w[summary run-times layovers mrt-overlap load-profile limitations])
  end

  it "站牌還沒有到捷運的距離（之前寫入的資料）時，捷運重疊那一塊提示重算" do
    store_days("2026-10-19")
    get route_path(9001), params: { day: "2026-10-19" }
    expect(page.css("[data-section=mrt-overlap] [data-needs-reload]").size).to eq(1)
  end

  it "那一天沒有資料時回 200，標出沒有資料並列出已寫入的日子" do
    store_days("2026-10-19", "2026-10-20")
    get route_path(9001), params: { day: "2026-10-25" }
    expect([ response.status, page.at_css("[data-no-data]").present?, page.css("[data-stored-day]").map { it["data-stored-day"] } ])
      .to eq([ 200, true, [ "2026-10-19", "2026-10-20" ] ])
  end
end
