require "rails_helper"

# The day dispatch page of a route: the day itself lives in the browser that
# keeps it, so the server only answers the page, its words and the names of
# the route and its ends.
RSpec.describe "DayDispatches", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  def page = response.parsed_body

  def day_block = page.at_css("[data-day-dispatch]")

  def start_block = page.at_css("[data-day-start]")

  # The data of today's plan the page embeds, nil without a plan.
  def plan_data = page.at_css("script[data-plan-data]")&.text&.then { JSON.parse(it) }

  # Opens 9001's day dispatch page at 10:00 Taipei time on the given date.
  def open_on(iso, query = "") = travel_to(Time.zone.parse("#{iso} 10:00")) { get "/routes/9001/dispatch#{query}" }

  # A complete trip of the day starting at `start` that runs `minutes`.
  def add_trip(route_day, start, minutes, go_back)
    start_time = Time.zone.parse("#{route_day.day} #{start}")
    route_day.trips.create!(bus_id: "TEST-0001", path_attribute_id: 9001, go_back:, band: "other", start_time:, end_time: start_time + minutes.minutes,
                            first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5, completeness: "complete",
                            start_from_arrival: false, end_from_departure: false)
  end

  # A stored day of 9001: 甲站 is where direction 0 departs, 乙站 where
  # direction 1 departs.
  def store_day
    create(:route_day, day: Date.new(2026, 10, 19)).tap do |route_day|
      route_day.stops.create!([ { go_back: 0, seq: 0, stop_name: "甲站" }, { go_back: 1, seq: 5, stop_name: "乙站" } ])
      [ [ "06:00", 50, 0 ], [ "07:00", 45, 1 ] ].each { |start, minutes, go_back| add_trip(route_day, start, minutes, go_back) }
    end
  end

  it "不在路線清單裡的路線回 404，內容是 public/404.html" do
    get "/routes/9999/dispatch"
    expect([ response.status, response.body ]).to eq([ 404, Rails.public_path.join("404.html").read ])
  end

  it "沒有 POST：送回來回 404" do
    store_day
    post "/routes/9001/dispatch"
    expect(response).to have_http_status(:not_found)
  end

  it "9001 回 200：當天調度那一塊在伺服器的輸出裡藏著，交給瀏覽器的 dayDispatch，沒有腳本就只有需要 JavaScript 那一句" do
    store_day
    get "/routes/9001/dispatch"
    expect([ response.status, day_block&.key?("hidden"), page.at_css("main[x-data]")&.[]("x-data"), page.css("main [data-needs-script]").size ]).to eq([ 200, true, "dayDispatch", 1 ])
  end

  it "換過來時不拿 Turbo 快取裡上一次的畫面當預覽：那一天全在瀏覽器照存著的畫" do
    get "/routes/9001/dispatch"
    expect(page.at_css("head meta[name='turbo-cache-control']")&.[]("content")).to eq("no-preview")
  end

  it "兩端的按鈕帶最新一天的站名，標題帶路線名" do
    store_day
    get "/routes/9001/dispatch"
    expect([ day_block.css("button[data-end]").map { it["data-name"] }, page.at_css("title").text ])
      .to eq([ %w[甲站 乙站], I18n.t("day_dispatches.show.document_title", route: "測試幹線", site: I18n.t("site.name")) ])
  end

  it "這條路線還沒有任何資料也回 200：沒有站名，按鈕只寫方向" do
    get "/routes/9001/dispatch"
    expect([ response.status, day_block.css("button[data-end]").map { it["data-name"] } ]).to eq([ 200, [ I18n.t("directions.0"), I18n.t("directions.1") ] ])
  end

  it "規格的不認得的日型別：type=sunday 回 400" do
    store_day
    get "/routes/9001/dispatch?type=sunday"
    expect(response).to have_http_status(:bad_request)
  end

  it "百分位數或休息不是班表頁收的值時回 400" do
    store_day
    expect(%w[p=42 buffer=99].map { get("/routes/9001/dispatch?type=weekday&#{it}").then { response.status } }).to eq([ 400, 400 ])
  end

  it "今天的計畫：嵌了 2026-10-19 平日的資料，預設 p85、休息 15，開始當天要帶的涵蓋日子與日型別" do
    store_day.then { get "/routes/9001/dispatch?type=weekday" }
    expect([ plan_data&.values_at("percentile", "buffer"), JSON.parse(start_block["data-days"]), start_block["data-day-type"] ]).to eq([ [ 85, 15 ], [ "2026-10-19" ], "weekday" ])
  end

  it "網址的 p 與 buffer 帶進今天的計畫與控制項" do
    store_day.then { get "/routes/9001/dispatch?type=weekday&p=50&buffer=10" }
    expect([ plan_data.values_at("percentile", "buffer"), start_block.at_css("select[name=p] option[selected]")["value"], start_block.at_css("input[name=buffer]")["value"] ])
      .to eq([ [ 50, 10 ], "50", "10" ])
  end

  it "沒有指定日型別時照今天：2026-10-26 星期一是平日，有今天的計畫" do
    store_day.then { open_on("2026-10-26") }
    expect([ start_block["data-day-type"], plan_data.nil? ]).to eq([ "weekday", false ])
  end

  it "規格的選的日型別沒有資料：2026-10-31 星期六是假日，9001 沒有假日，說鋪不出來，沒有嵌資料也沒有開始當天" do
    store_day.then { open_on("2026-10-31") }
    expect([ start_block.css("[data-no-plan]").size, plan_data, start_block.css("button[data-start-button]").size ]).to eq([ 1, nil, 0 ])
  end

  it "選的日型別沒有資料時，路線名與兩端的站名照最新一天" do
    store_day.then { get "/routes/9001/dispatch?type=holiday" }
    expect([ start_block.at_css("h1").text.include?("測試幹線"), day_block.css("button[data-end]").map { it["data-name"] } ]).to eq([ true, %w[甲站 乙站] ])
  end

  it "頁面上沒有任何車輛識別碼" do
    store_day
    get "/routes/9001/dispatch?type=weekday"
    expect(response.body.include?("TEST-0001")).to be(false)
  end
end
