# frozen_string_literal: true

require "rails_helper"

RSpec.describe DayStartComponent, type: :component do
  # A stored weekday of route 9001; 甲站 is where direction 0 departs, 乙站
  # where direction 1 departs, unless the day has no stops.
  def store_day(iso, stops: true)
    create(:route_day, day: Date.iso8601(iso)).tap do |route_day|
      route_day.stops.create!([ { go_back: 0, seq: 0, stop_name: "甲站" }, { go_back: 1, seq: 5, stop_name: "乙站" } ]) if stops
    end
  end

  # Today's plan of the stored days, as the controller builds it.
  def plan_of(days, percentile:, buffer:)
    coverage = RoutePage::Coverage.new(route_id: 9001, day: days.last.day.iso8601, range: "7d")
    RoutePage::Timetable.new(route_days: coverage.route_days, ends: RoutePage.ends(9001), buffer:, percentile:)
  end

  def render_start(days: [ store_day("2026-10-19") ], day_type: "weekday", percentile: 85, buffer: 15, plan: true)
    timetable = plan_of(days, percentile:, buffer:) if plan
    render_inline(described_class.new(route_id: 9001, route_name: "測試幹線", day_type:, timetable:, percentile:, buffer:))
  end

  def root(rendered) = rendered.at_css("[data-day-start]")

  # The component's words in tw, with the values filled in.
  def start_text(key, **values) = format(YAML.load_file(Rails.root.join("app/components/day_start_component.yml"), aliases: true).dig("tw", key.to_s), **values)

  def options(rendered, name) = rendered.css("form select[name=#{name}] option").map { [ it["value"], it.key?("selected") ] }

  it "整塊在伺服器的輸出裡藏著：沒有腳本就沒有今天的計畫" do
    expect(root(render_start)&.key?("hidden")).to be(true)
  end

  it "開始當天要帶的：涵蓋的日子與日型別" do
    start = root(render_start(days: [ store_day("2026-10-19"), store_day("2026-10-20") ]))
    expect([ JSON.parse(start["data-days"]), start["data-day-type"] ]).to eq([ %w[2026-10-19 2026-10-20], "weekday" ])
  end

  it "依據寫出涵蓋的第一天到最後一天、日型別與天數" do
    rendered = render_start(days: [ store_day("2026-10-19"), store_day("2026-10-20") ])
    expect(rendered.at_css("[data-basis]").text.squish).to eq(start_text(:basis_range, first: "2026-10-19（一）", last: "2026-10-20（二）", day_type: "平日", count: 2))
  end

  it "只涵蓋一天時依據只寫那一天" do
    expect(render_start.at_css("[data-basis]").text.squish).to eq(start_text(:basis_one, day: "2026-10-19（一）", day_type: "平日"))
  end

  it "日型別、百分位數與休息在送回當天調度頁的 GET 表單裡：選中的是給的值，百分位數的選項與休息的範圍照班表頁" do
    rendered = render_start(percentile: 50, buffer: 10)
    form, buffer = rendered.at_css("form"), rendered.at_css("form input[name=buffer]")
    expect([ form["action"], form["method"], options(rendered, "type"), options(rendered, "p"), [ buffer["value"], buffer["min"], buffer["max"] ] ])
      .to eq([ "/routes/9001/dispatch", "get", [ [ "weekday", true ], [ "holiday", false ] ], RoutePage::PlannedRunTimes::PERCENTILES.map { [ it.to_s, it == 50 ] }, %w[10 0 20] ])
  end

  it "鋪成幾台車寫出兩端的站名，數字的位子留給瀏覽器" do
    summary = render_start.at_css("[data-plan-summary]")
    expect([ summary.text.include?("甲站"), summary.text.include?("乙站"), %w[vehicles departures-0 departures-1].map { summary.css("[data-slot=#{it}]").size } ]).to eq([ true, true, [ 1, 1, 1 ] ])
  end

  it "那一端沒有站名時寫方向" do
    summary = render_start(days: [ store_day("2026-10-19", stops: false) ]).at_css("[data-plan-summary]")
    expect([ summary.text.include?(I18n.t("directions.0")), summary.text.include?(I18n.t("directions.1")) ]).to eq([ true, true ])
  end

  it "有計畫時有開始當天，沒有說鋪不出來的那一句" do
    rendered = render_start
    expect([ rendered.css("button[data-start-button]").size, rendered.css("[data-no-plan]").size ]).to eq([ 1, 0 ])
  end

  it "沒有那個日型別的資料：說鋪不出今天的計畫，沒有百分位數、休息、鋪成幾台車與開始當天；百分位數與休息照帶在表單裡" do
    rendered = render_start(day_type: "holiday", percentile: 50, buffer: 10, plan: false)
    hidden = %w[p buffer].map { rendered.at_css("form input[type=hidden][name=#{it}]")&.[]("value") }
    expect([ rendered.at_css("[data-no-plan]")&.text&.squish, hidden, %w[select[name=p] [data-plan-summary] button[data-start-button]].map { rendered.css(it).size } ])
      .to eq([ start_text(:no_plan, day_type: "假日"), %w[50 10], [ 0, 0, 0 ] ])
  end

  it "瀏覽器要填的字留著日期的位子，日期照網站的寫法帶星期" do
    labels = JSON.parse(root(render_start)["data-labels"])
    expect([ labels["yesterday"].include?("%{date}"), labels["unreadable"].include?("%{date}"), labels["dayLabel"], labels["weekdays"] ])
      .to eq([ true, true, RoutePage::Format::DAY_LABEL, RoutePage::Format::WEEKDAYS ])
  end
end
