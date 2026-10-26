require "rails_helper"

RSpec.describe "Timetables", type: :request do
  def page = response.parsed_body

  def timetable = page.at_css("main[data-timetable]")

  # The parameters the timetable starts from, as the page's root marks them.
  def parameters(*names) = names.map { timetable["data-#{it}"] }

  # The figures the header shows.
  def figures(*names) = names.map { page.at_css("[data-timetable-header] [data-value=#{it}]")&.text&.squish }

  # The data the page embeds for the browser.
  def data = JSON.parse(page.at_css("script[data-timetable-data]").text)

  # A complete trip of the day starting at `start` (Taipei time) that runs for
  # `minutes`.
  def add_trip(route_day, start, minutes, go_back: 0)
    start_time = Time.zone.parse("#{route_day.day} #{start}")
    route_day.trips.create!(bus_id: "TEST-0001", path_attribute_id: 9001, go_back:, band: "other", start_time:, end_time: start_time + minutes.minutes,
                            first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5, completeness: "complete",
                            start_from_arrival: false, end_from_departure: false)
  end

  # A stored day with the spec's four departures: direction 0 from 甲站 at
  # 06:00 and 06:30 running 50 minutes, direction 1 from 乙站 at 07:00 and
  # 07:30 running 45 minutes.
  def store_four_departures(day = "2026-10-19")
    create(:route_day, day: Date.iso8601(day)).tap do |route_day|
      route_day.stops.create!([ { go_back: 0, seq: 0, stop_name: "甲站" }, { go_back: 0, seq: 4, stop_name: "乙站" },
                                { go_back: 1, seq: 5, stop_name: "乙站" }, { go_back: 1, seq: 9, stop_name: "甲站" } ])
      [ [ "06:00", 50, 0 ], [ "06:30", 50, 0 ], [ "07:00", 45, 1 ], [ "07:30", 45, 1 ] ].each { |start, minutes, go_back| add_trip(route_day, start, minutes, go_back:) }
    end
  end

  it "沒給參數時：最新一天、範圍一天、休息 15 分鐘、p85 當初始值" do
    store_four_departures("2026-10-19").then { store_four_departures("2026-10-20") }
    get route_timetable_path(9001)
    expect([ response.status, *parameters(:day, :range, :buffer, :percentile) ]).to eq([ 200, "2026-10-20", "day", "15", "85" ])
  end

  it "參數從網址來：day、range、buffer、p 照給的用，資料裡的初始值跟著" do
    store_four_departures("2026-10-19").then { store_four_departures("2026-10-20") }
    get route_timetable_path(9001), params: { day: "2026-10-19", range: "7d", buffer: "10", p: "50" }
    expect([ *parameters(:day, :range, :buffer, :percentile), data["buffer"], data["percentile"] ]).to eq([ "2026-10-19", "7d", "10", "50", 10, 50 ])
  end

  it "每小時發車數不再是網址參數：departures[0][7]=31 照常回 200" do
    store_four_departures
    get route_timetable_path(9001), params: { departures: { 0 => { 7 => "31" } } }
    expect(response).to have_http_status(:ok)
  end

  [ { p: "83" }, { p: "100" }, { p: "abc" }, { range: "30d" }, { day: "20261019" }, { buffer: "21" } ].each do |params|
    it "#{params.inspect} 回 400" do
      store_four_departures
      get route_timetable_path(9001), params: params
      expect(response).to have_http_status(:bad_request)
    end
  end

  it "路線不在路線清單裡回 404，內容是 public/404.html" do
    get route_timetable_path(9999)
    expect([ response.status, response.body ]).to eq([ 404, Rails.public_path.join("404.html").read ])
  end

  it "沒有 POST：送回來回 404" do
    store_four_departures
    post route_timetable_path(9001), params: { trips: {} }
    expect(response).to have_http_status(:not_found)
  end

  it "選的日子沒有資料：回 200、說這一天沒有資料，沒有資料、沒有單子、沒有資料限制那一段" do
    store_four_departures
    get route_timetable_path(9001), params: { day: "2026-01-01" }
    expect([ response.status, page.at_css("[data-no-data]")&.text&.include?("2026-01-01"), page.css("[data-timetable-data], [data-vehicle], [data-section=limitations]").size ])
      .to eq([ 200, true, 0 ])
  end

  it "返程沒有任何行駛時間：回 200、寫出是方向 1，沒有資料、沒有單子" do
    create(:route_day).then { add_trip(it, "06:00", 50) }
    get route_timetable_path(9001)
    expect([ response.status, page.at_css("[data-no-run-times]")&.[]("data-no-run-times"), page.css("[data-timetable-data], [data-vehicle]").size ]).to eq([ 200, "1", 0 ])
  end

  describe "規格的四班例子那一天" do
    before do
      store_four_departures
      get route_timetable_path(9001)
    end

    it "頁首：路線名、涵蓋 2026-10-19 平日、p 85、休息 15、量到每天 1.0 台車；車數、班數、手動改過與跟著往後推的格數留給瀏覽器填" do
      header = page.at_css("[data-timetable-header]")
      expect([ header.at_css("h1").text.squish, header["data-day-type"], header.css("[data-covered-days] [data-day]").map { it["data-day"] },
               *figures("percentile", "buffer", "vehicles-per-day", "vehicles", "departures-0", "departures-1", "edited", "pushed") ])
        .to eq([ "測試幹線", "weekday", [ "2026-10-19" ], "85", "15", "1.0", "—", "—", "—", "—", "—" ])
    end

    it "控制項不是表單：p 的選單、buffer、departures[0][0] 到 departures[1][23] 帶量到的值，後面緊接著改了會重新鋪排的提醒" do
      controls = page.at_css("[data-timetable-controls]")
      names = controls.css("input, select").map { it["name"] }
      expect([ page.css("[data-timetable-header] form").size, names.count { it.start_with?("departures[") }, (%w[p buffer departures[0][0] departures[1][23]] - names),
               controls.at_css("input[name='departures[0][6]']")["value"], controls.next_element&.key?("data-regeneration-notice") ]).to eq([ 0, 48, [], "2", true ])
    end

    it "伺服器不畫單子：裝單子的容器是空的，有單子與列的 template，和需要 JavaScript 的那一句" do
      expect([ page.css("[data-sheets] [data-vehicle]").size, page.at_css("[data-sheets]")&.element_children&.size, page.css("template[data-sheet-template], template[data-row-template]").size,
               page.css("[data-needs-script]").size ]).to eq([ 0, 0, 2, 1 ])
    end

    it "嵌給瀏覽器的資料：量到的發車數、每格退回全天的計畫行駛時間、兩端的停留與哪些端停車、站名" do
      expect([ data["departures"]["0"][6], data["departures"]["1"][7], data["runTimes"]["0"][6]["85"], data["runTimes"]["1"][7]["85"], data["holds"], data["stoppingEnds"], data["stopNames"] ])
        .to eq([ 2, 2, [ 50, true ], [ 45, true ], { "0" => 15, "1" => 15 }, [ 0, 1 ], { "0" => "甲站", "1" => "乙站" } ])
    end

    it "頁面上沒有任何車輛識別碼" do
      expect(response.body.include?("TEST-0001")).to be(false)
    end

    it "恰好一個顯名聲明 footer；超時比例表十列、選著 p85 那一列；資料限制在它後面" do
      sections = page.css("[data-section]").map { it["data-section"] }
      expect([ page.css('footer[data-attribution][data-license="OGDL-Taiwan-1.0"]').size, sections, page.css("[data-section=overruns] tbody tr").size,
               page.css("[data-section=overruns] tr[data-selected]").map { it["data-percentile"] } ]).to eq([ 1, %w[overruns limitations], 10, [ "85" ] ])
    end

    it "列印鈕在伺服器的輸出裡是藏起來的：沒有腳本就沒有鈕，瀏覽器選單的列印照常" do
      expect(page.at_css("[data-timetable-header] button[data-print]")&.key?("hidden")).to be(true)
    end

    it "再加一台車的控制項在伺服器的輸出裡也是藏起來的：沒有腳本就沒有它" do
      expect(page.at_css("[data-add-vehicle]")&.key?("hidden")).to be(true)
    end

    it "班表頁只排班：沒有開始當天、繼續那一天，也沒有當天調度區塊" do
      expect(%w[[data-day-start] [data-day-continue] [data-day-dispatch]].map { page.css(it).size }).to eq([ 0, 0, 0 ])
    end

    it "文件標題帶路線名、班表與站名" do
      expect(page.at_css("title").text).to eq(I18n.t("timetables.show.document_title", route: "測試幹線", site: I18n.t("site.name")))
    end
  end
end
