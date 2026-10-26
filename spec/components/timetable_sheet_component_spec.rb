# frozen_string_literal: true

require "rails_helper"

RSpec.describe TimetableSheetComponent, type: :component do
  # The spec's four-departure day of route 9001, 2026-10-19, a weekday.
  let(:route_day) do
    create(:route_day).tap do |route_day|
      route_day.stops.create!([ { go_back: 0, seq: 0, stop_name: "甲站" }, { go_back: 1, seq: 5, stop_name: "乙站" } ])
      [ [ "06:00", 50, 0 ], [ "06:30", 50, 0 ], [ "07:00", 45, 1 ], [ "07:30", 45, 1 ] ].each { |start, minutes, go_back| trip(route_day, start, minutes, go_back) }
    end
  end
  let(:rendered) { render_sheet }

  def trip(route_day, start, minutes, go_back)
    start_time = Time.zone.parse("2026-10-19 #{start}")
    route_day.trips.create!(bus_id: "TEST-0001", path_attribute_id: 9001, go_back:, band: "other", start_time:, end_time: start_time + minutes.minutes,
                            first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5, completeness: "complete",
                            start_from_arrival: false, end_from_departure: false)
  end

  def render_sheet(range: "day", buffer: 15, percentile: 85)
    coverage = RoutePage::Coverage.new(route_id: 9001, day: route_day.day.iso8601, range:)
    ends = RoutePage::Ends.from_config({ 0 => "stop", 1 => "stop" }, route_id: 9001)
    timetable = RoutePage::Timetable.new(route_days: coverage.route_days, ends:, buffer:, percentile:)
    render_inline(described_class.new(timetable:, coverage:))
  end


  def sheet_template = rendered.at_css("template[data-sheet-template]")

  def row_template = rendered.at_css("template[data-row-template]")

  # What each cell of the row template is for, in order.
  def cell_kinds(row)
    row.css("td").map do |cell|
      if cell.key?("data-departure") then "departure"
      elsif cell["data-slot"] == "origin" then "origin"
      elsif cell.key?("data-arrival") then "arrival"
      elsif cell.key?("data-stop") then "stop"
      elsif cell.key?("data-blank") then "blank"
      elsif cell.at_css("button[data-delete-row]") then "actions"
      end
    end
  end

  it "輸出單子與列各一個 template，瀏覽器複製它們來畫" do
    expect([ rendered.css("template[data-sheet-template]").size, rendered.css("template[data-row-template]").size ]).to eq([ 1, 1 ])
  end

  it "單子的 template 帶瀏覽器要填的文案，留著要填的位子：標題的車次、隔日時刻、加一列的方向、四小時那一句的分鐘數、資料依據的百分位數與休息、被退回的字；時刻可以怎麼打已經寫好" do
    placeholders = { "data-title" => "%{number}", "data-next-day" => "%{time}", "data-add-label" => "%{direction}", "data-rest-credit-text" => "%{minutes}",
                     "data-print-header" => "%{percentile}", "data-rejected-typed" => "%{typed}" }
    expect([ placeholders.map { |name, placeholder| sheet_template[name]&.include?(placeholder) }, sheet_template["data-print-header"].include?("%{buffer}"), sheet_template["data-accepted-writings"].present? ])
      .to eq([ [ true ] * 6, true, true ])
  end

  it "單子的 template 帶跟著往後推的說明，留著推了幾分與原本時刻的位子，也帶它接在手動改過後面時的分隔" do
    expect([ %w[%{minutes} %{time}].map { sheet_template["data-pushed-title"]&.include?(it) }, sheet_template["data-title-separator"].present? ]).to eq([ [ true, true ], true ])
  end

  it "單子的 template 帶兩個方向的名字與退回全天的標記；四小時那兩句已經填好小時數；印刷時至少補到 14 列" do
    expect([ sheet_template["data-direction-0"], sheet_template["data-direction-1"], sheet_template["data-fallback-mark"].present?,
             sheet_template["data-rest-credit-text"].include?("4"), sheet_template["data-shorter-text"].include?("4"), sheet_template["data-min-rows"] ])
      .to eq([ I18n.t("directions.0"), I18n.t("directions.1"), true, true, true, "14" ])
  end

  it "資料依據那一行：伺服器填了那一天與日型別，留著百分位數與休息的位子" do
    expect(%w[2026-10-19（一） 平日 %{percentile} %{buffer}].map { sheet_template["data-print-header"].include?(it) }).to eq([ true ] * 4)
  end

  it "涵蓋最近 7 天時資料依據寫從哪一天到哪一天、幾個平日" do
    create(:route_day, day: Date.new(2026, 10, 16))
    header = render_sheet(range: "7d").at_css("template[data-sheet-template]")["data-print-header"]
    expect(%w[2026-10-16（五） 2026-10-19（一） 平日 2].map { header.include?(it) }).to eq([ true ] * 4)
  end

  it "印刷用的表單抬頭：公司與站的空格、路線名、車次的位子、車號的空格、年月日星期的空格、資料依據的位子" do
    header = sheet_template.at_css("[data-sheet-form-header]")
    expect([ header.text.squish.include?("測試幹線"), %w[公司 站 車號 年 月 日 星期].map { header.text.include?(it) }, header.css("[data-slot=run-number]").size, header.css("[data-slot=print-header]").size ])
      .to eq([ true, [ true ] * 7, 1, 1 ])
  end

  it "單子裡有車次的標題、空的 tbody、加一列的輸入與鈕、預設藏著的退回全天說明、四小時那一行" do
    sheet = sheet_template.at_css("section[data-vehicle]")
    expect([ sheet.css("[data-slot=title]").size, sheet.css("tbody[data-slot=rows] tr").size, sheet.css("[data-add-row] input[data-add-input]").size, sheet.css("button[data-add]").size,
             sheet.at_css("[data-fallback-legend]").key?("hidden"), sheet.css("[data-rest-credit]").size ]).to eq([ 1, 0, 1, 1, true, 1 ])
  end

  it "列的 template 最前面是操作，接著照紙本的欄位順序：職號、姓名、發車、起點、調度員、到達、停留、返回發車、累計里程、返站、回站後停留、行駛里程、調度員；沒有列號" do
    expect([ cell_kinds(row_template.at_css("tr[data-row]")), sheet_template.css("thead th").size ])
      .to eq([ %w[actions blank blank departure origin blank arrival stop departure blank arrival stop blank blank], 14 ])
  end

  it "兩個時刻格各有輸入框與印刷用的文字" do
    row = row_template.at_css("tr[data-row]")
    expect([ row.css("td[data-departure] input[data-departure-input]").size, row.css("td[data-departure] span").size ]).to eq([ 2, 2 ])
  end

  it "四小時視窗的長度跟瀏覽器端寫的一樣：元件的小時數乘 60 等於 rest_windows.js 的 WINDOW_MINUTES" do
    window_minutes = Rails.root.join("app/frontend/timetable/rest_windows.js").read[/WINDOW_MINUTES = (\d+)/, 1].to_i
    expect(described_class::WINDOW_HOURS * 60).to eq(window_minutes)
  end
end
