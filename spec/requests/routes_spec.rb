require "rails_helper"

RSpec.describe "Routes", type: :request do
  def store_days(*days, route_id: 9001)
    days.each do |day|
      create(:route_day, route_id:, day: Date.iso8601(day))
    end
  end

  def store_holiday(day, note: nil) = create(:route_day, day: Date.iso8601(day), day_type: "holiday", day_note: note)

  # The last stop of each direction, so the layover table has a row per direction.
  def add_last_stops(route_day) = route_day.stops.create!([ { go_back: 0, seq: 4, stop_name: "戊站" }, { go_back: 1, seq: 9, stop_name: "甲站" } ])

  def page = response.parsed_body

  def buffer_minutes = page.at_css("[data-section=buffer-trade] [data-value=minutes]")&.text

  def covered_days = page.css("[data-covered-days] [data-day]").map { it["data-day"] }

  def covered_labels = page.css("[data-covered-days] [data-day]").map { it.text.squish }

  def covered_day_type = page.at_css("header [data-day-type]")&.[]("data-day-type")

  # The link to the other day type: which type it names, where it goes, and whether it names the day.
  def other_type_link(day_label) = page.at_css("a[data-other-day-type]")&.then { [ it["data-other-day-type"], it["href"], it.text.include?(day_label) ] }

  def layover_natures = page.css("[data-section=layovers] tr[data-direction]").map { it["data-end-nature"] }

  def pass_through_layovers = page.css("[data-section=buffer-trade] [data-value=pass-through-layovers]")

  it "路線不在路線清單裡回 404" do
    get route_path(9999)
    expect(response).to have_http_status(:not_found)
  end

  it "沒給 day、range 與 buffer 時，顯示最新一天、範圍是一天、緩衝 15 分鐘" do
    store_days("2026-10-19", "2026-10-20")
    get route_path(9001)
    expect([ response.status, covered_days, page.at_css("[data-range]")["data-range"], buffer_minutes ]).to eq([ 200, [ "2026-10-20" ], "day", "15" ])
  end

  it "緩衝分鐘數從網址來，拉桿表單帶著目前的日期與範圍" do
    store_days("2026-10-19")
    get route_path(9001), params: { day: "2026-10-19", range: "7d", buffer: "10" }
    hidden = %w[day range].map { page.at_css("#buffer-trade form input[name=#{it}]")["value"] }
    expect([ buffer_minutes, hidden ]).to eq([ "10", %w[2026-10-19 7d] ])
  end

  [ { range: "30d" }, { day: "2026-13-40" }, { day: "20261019" }, { buffer: "21" }, { buffer: [ "1" ] } ].each do |params|
    it "#{params.inspect} 回 400" do
      get route_path(9001), params: params
      expect(response).to have_http_status(:bad_request)
    end
  end

  it "最近 7 天只涵蓋已寫入的日子，列出日期與星期，標成平日" do
    store_days("2026-10-15", "2026-10-19", "2026-10-20", "2026-10-22")
    get route_path(9001), params: { day: "2026-10-22", range: "7d" }
    expect([ covered_day_type, covered_labels ]).to eq([ "weekday", [ "2026-10-19（一）", "2026-10-20（二）", "2026-10-22（四）" ] ])
  end

  describe "10-19 到 10-23 是平日、10-24 到 10-26 是假日、10-26 是補假時" do
    before do
      store_days("2026-10-19", "2026-10-20", "2026-10-21", "2026-10-22", "2026-10-23")
      %w[2026-10-24 2026-10-25].each { store_holiday(it) }
      store_holiday("2026-10-26", note: "補假")
    end

    it "選 10-26、最近 7 天：標成假日，只涵蓋 10-24 到 10-26，10-26 帶著補假，連到 10-23 為止的平日" do
      get route_path(9001), params: { day: "2026-10-26", range: "7d" }
      expect([ covered_day_type, covered_labels, other_type_link("2026-10-23（五）") ]).to eq(
        [ "holiday", [ "2026-10-24（六）", "2026-10-25（日）", "2026-10-26（一）補假" ], [ "weekday", "/routes/9001?day=2026-10-23&range=7d", true ] ]
      )
    end

    it "選 10-23、最近 7 天：標成平日，涵蓋 10-19 到 10-23，10-23 以前沒有假日所以沒有連結" do
      get route_path(9001), params: { day: "2026-10-23", range: "7d" }
      expect([ covered_day_type, covered_days, other_type_link("") ]).to eq([ "weekday", %w[2026-10-19 2026-10-20 2026-10-21 2026-10-22 2026-10-23], nil ])
    end
  end

  it "沒帶參數時是最新的 10-26：標成假日、帶著補假，連到 10-23 那一天" do
    store_days("2026-10-23").then { store_holiday("2026-10-26", note: "補假") }
    get route_path(9001)
    expect([ covered_day_type, covered_labels, other_type_link("2026-10-23（五）") ]).to eq(
      [ "holiday", [ "2026-10-26（一）補假" ], [ "weekday", "/routes/9001?day=2026-10-23&range=day", true ] ]
    )
  end

  it "有資料的那一天，頁面依序是摘要、折返停留分佈圖、沿線人數圖、行駛時間、折返停留、試算、捷運重疊、載客剖面、資料限制" do
    store_days("2026-10-19")
    get route_path(9001), params: { day: "2026-10-19" }
    expect(page.css("[data-section]").map { it["data-section"] })
      .to eq(%w[summary layover-chart load-chart run-times layovers buffer-trade mrt-overlap load-profile limitations])
  end

  it "兩端都停車的 9001，折返停留兩列都標停車" do
    store_days("2026-10-19")
    add_last_stops(RouteDay.sole)
    get route_path(9001), params: { day: "2026-10-19" }
    expect(layover_natures).to eq(%w[stop stop])
  end

  it "15373 的兩端照設定標示：去程結束那列開過去就走、返程結束那列停車" do
    store_days("2026-10-21", route_id: 15373)
    add_last_stops(RouteDay.sole)
    get route_path(15373), params: { day: "2026-10-21" }
    expect(layover_natures).to eq(%w[pass_through stop])
  end

  it "兩端都停車的 9001，試算沒有開過去就走那一端的筆數" do
    store_days("2026-10-19")
    get route_path(9001), params: { day: "2026-10-19" }
    expect(pass_through_layovers.size).to eq(0)
  end

  it "15373 有開過去就走的一端，試算另外報那一端的筆數" do
    store_days("2026-10-21", route_id: 15373)
    get route_path(15373), params: { day: "2026-10-21" }
    expect(pass_through_layovers.size).to eq(1)
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
