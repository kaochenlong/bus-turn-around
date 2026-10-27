# frozen_string_literal: true

require "rails_helper"

RSpec.describe DayDispatchComponent, type: :component do
  # Route 9001: 甲站 is where direction 0 departs, 乙站 where direction 1 departs.
  def render_day(route_name: "測試幹線", stop_names: { 0 => "甲站", 1 => "乙站" })
    render_inline(described_class.new(route_id: 9001, route_name:, stop_names:))
  end

  let(:rendered) { render_day }

  def root = rendered.at_css("[data-day-dispatch]")

  def labels = JSON.parse(root["data-labels"])

  # Each end control as its end, and the stop and direction names it carries.
  def end_controls(page = rendered) = page.css("button[data-end]").map { [ it["data-end"], it.text[/甲站|乙站/], it.text[/去程|返程/] ] }

  it "整塊在伺服器的輸出裡是藏起來的：沒有腳本就沒有當天調度" do
    expect(root&.key?("hidden")).to be(true)
  end

  it "帶路線 Id，計畫的班表連到那條路線的班表頁" do
    expect([ root["data-route-id"], root.at_css("a[data-plan-timetable]")&.[]("href") ]).to eq([ "9001", "/routes/9001/timetable" ])
  end

  it "兩端各一個選端按鈕，各帶從那一端發車的方向與起站名" do
    expect(end_controls).to eq([ [ "0", "甲站", "去程" ], [ "1", "乙站", "返程" ] ])
  end

  it "那一端沒有站名時按鈕只帶方向" do
    expect(end_controls(render_day(stop_names: { 0 => "甲站" }))).to eq([ [ "0", "甲站", "去程" ], [ "1", nil, "返程" ] ])
  end

  it "沒有路線名稱時標題只留日期的位子" do
    expect(render_day(route_name: nil).at_css("h1").text.squish).to eq("")
  end

  it "瀏覽器要填的文案留著要填的位子，包括跟班表單子共用的隔日與打不出來的時刻" do
    placeholders = { "vehicle" => %w[%{number}], "basisOne" => %w[%{day} %{dayType} %{percentile} %{buffer}], "basisRange" => %w[%{first} %{last} %{dayType} %{count} %{percentile} %{buffer}],
                     "standingNext" => %w[%{arrival} %{minutes} %{next}], "changeVehicle" => %w[%{departure} %{stop} %{vehicle} %{from}], "noTrip" => %w[%{vehicle} %{time} %{stop}],
                     "nextDay" => %w[%{time}], "rejectedTyped" => %w[%{typed}], "recordAction" => %w[%{vehicle} %{stop}] }
    expect(placeholders.map { |key, names| names.all? { labels[key]&.include?(it) } }).to eq([ true ] * placeholders.size)
  end

  it "打不出來的時刻那一句已經寫好時刻可以怎麼打" do
    expect([ labels["acceptedWritings"].present?, labels["rejectedTyped"].include?(labels["acceptedWritings"]) ]).to eq([ true, true ])
  end

  it "日期照網站的寫法帶星期：星期日到星期六的字與日期的寫法" do
    expect([ labels["weekdays"], labels["dayLabel"] ]).to eq([ RoutePage::Format::WEEKDAYS, "%{date}（%{weekday}）" ])
  end

  it "頁首有印出當天紀錄、匯出修改清單、匯出最後的單三個按鈕" do
    expect(%w[button[data-print-record] button[data-export=changes] button[data-export=sheets]].map { root.css("header #{it}").size }).to eq([ 1, 1, 1 ])
  end

  it "兩個 CSV 的表頭跟 day_record.js 寫的欄數一樣（修改清單 8 欄、最後的單 9 欄），三種修改、是與否、兩個方向都有字，那一趟留著方向與發車的位子" do
    csv = labels["csv"]
    expect([ csv["changesHeader"].size, csv["sheetsHeader"].size, csv["kinds"].keys.sort, [ csv["yes"], csv["no"] ].all?(&:present?), csv["directions"], %w[%{direction} %{departure}].all? { csv["trip"].include?(it) } ])
      .to eq([ 8, 9, %w[arrival departure vehicle], true, { "0" => "去程", "1" => "返程" }, true ])
  end

  it "單子標題下那一行與三種註記留著瀏覽器要填的位子，三種記號與列出好幾班時的分隔都有字" do
    filled = { "sheetHeader" => %w[%{date} %{days} %{percentile} %{buffer}], "sheetDaysOne" => %w[%{day} %{dayType}], "sheetDaysRange" => %w[%{first} %{last} %{dayType} %{count}] }
    notes = { "swapped" => %w[%{mark} %{departures} %{vehicle}], "recorded" => %w[%{mark} %{arrival} %{planned}], "typed" => %w[%{mark} %{departure} %{from}] }
    expect([ filled.all? { |key, names| names.all? { labels[key]&.include?(it) } }, notes.all? { |key, names| names.all? { labels.dig("notes", key)&.include?(it) } },
             labels["marks"]&.values_at("swapped", "recorded", "typed")&.all?(&:present?), labels.dig("notes", "separator").present? ]).to eq([ true ] * 4)
  end

  it "放單子的位置與單子的 template 都在：template 的表單抬頭有路線名，標題下那一行留給瀏覽器照存著的那一天寫" do
    template = root.at_css("template[data-sheet-template]")
    expect([ root.css("[data-record-sheets]").size, template&.at_css("[data-sheet-form-header]")&.text&.include?("測試幹線"), template&.[]("data-print-header") ]).to eq([ 1, true, "" ])
  end
end
