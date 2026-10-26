# frozen_string_literal: true

require "rails_helper"

RSpec.describe TimetableHeaderComponent, type: :component do
  # The spec's four-departure day: direction 0 from 甲站 at 06:00 and 06:30
  # running 50 minutes, direction 1 from 乙站 at 07:00 and 07:30 running 45.
  let(:route_day) do
    create(:route_day).tap do |route_day|
      route_day.stops.create!([ { go_back: 0, seq: 0, stop_name: "甲站" }, { go_back: 1, seq: 5, stop_name: "乙站" } ])
      [ [ "06:00", 50, 0 ], [ "06:30", 50, 0 ], [ "07:00", 45, 1 ], [ "07:30", 45, 1 ] ].each { |start, minutes, go_back| trip(route_day, start, minutes, go_back) }
    end
  end

  def trip(route_day, start, minutes, go_back)
    start_time = Time.zone.parse("2026-10-19 #{start}")
    route_day.trips.create!(bus_id: "TEST-0001", path_attribute_id: 9001, go_back:, band: "other", start_time:, end_time: start_time + minutes.minutes,
                            first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5, completeness: "complete",
                            start_from_arrival: false, end_from_departure: false)
  end

  def render_header(buffer: 15, percentile: 85, range: "day")
    coverage = RoutePage::Coverage.new(route_id: 9001, day: route_day.day.iso8601, range:)
    ends = RoutePage::Ends.from_config({ 0 => "stop", 1 => "stop" }, route_id: 9001)
    timetable = RoutePage::Timetable.new(route_days: coverage.route_days, ends:, buffer:, percentile:)
    render_inline(described_class.new(timetable:, coverage:))
  end

  def figure(rendered, name) = rendered.at_css("[data-value=#{name}]")&.text&.squish

  def input_value(rendered, name) = rendered.at_css("[data-timetable-controls] input[name='#{name}']")&.[]("value")

  it "路線名、起訖、涵蓋的日子與日型別" do
    rendered = render_header
    expect([ rendered.at_css("h1").text.squish, rendered.at_css("[data-day-type]")["data-day-type"], rendered.css("[data-covered-days] [data-day]").map { it["data-day"] } ])
      .to eq([ "測試幹線", "weekday", [ "2026-10-19" ] ])
  end

  it "平日時日型別標籤與日期標籤都不是綠色，沒有備註的日期標籤沒有 title" do
    row = render_header.at_css("[data-covered-days]").parent
    tags = [ row.css("span").find { it.text == I18n.t("day_types.weekday") }, row.at_css("[data-day]") ]
    expect([ tags.map { |tag| tag.classes.grep(/green-/) }, tags.last["title"] ]).to eq([ [ [], [] ], nil ])
  end

  describe "那一天是備註「補假」的假日時" do
    let(:route_day) { super().tap { it.update!(day_type: "holiday", day_note: "補假") } }

    it "日期標籤只寫日期、備註是 title，日型別標籤與日期標籤都是綠色" do
      row = render_header.at_css("[data-covered-days]").parent
      day_tag = row.at_css("[data-day]")
      day_type_tag = row.css("span").find { it.text == I18n.t("day_types.holiday") }
      expect([ day_tag.text.squish, day_tag["title"], [ day_type_tag, day_tag ].map { |tag| tag.classes.include?("bg-green-50") } ]).to eq([ "2026-10-19（一）", "補假", [ true, true ] ])
    end
  end

  it "伺服器填 p、休息、量到的平均每天車數；車數、每個方向的班數、手動改過與跟著往後推的格數留給瀏覽器，先寫 —" do
    rendered = render_header
    expect(%w[percentile buffer vehicles-per-day vehicles departures-0 departures-1 edited pushed].map { figure(rendered, it) }).to eq(%w[85 15 1.0 — — — — —])
  end

  it "手動改過與跟著往後推是格數，數字後面帶單位；車數不帶" do
    rendered = render_header
    expect(%w[edited pushed vehicles].map { rendered.at_css("[data-value=#{it}]").parent.css("span").size }).to eq([ 2, 2, 1 ])
  end

  it "控制項不是表單：選單選著目前的 p、休息是目前的值" do
    rendered = render_header(buffer: 10, percentile: 50)
    expect([ rendered.css("form").size, rendered.at_css("[data-timetable-controls] select[name=p] option[selected]")["value"], input_value(rendered, "buffer") ]).to eq([ 0, "50", "10" ])
  end

  it "每小時發車數的 48 格都在，值是量到的：去程 06 時 2、返程 07 時 2、沒有趟次的小時 0" do
    rendered = render_header
    names = rendered.css("[data-timetable-controls] input[name^='departures[']").map { it["name"] }
    expect([ names.size, names.first, names.last, input_value(rendered, "departures[0][6]"), input_value(rendered, "departures[1][7]"), input_value(rendered, "departures[0][7]") ])
      .to eq([ 48, "departures[0][0]", "departures[1][23]", "2", "2", "0" ])
  end

  it "p 的選項是 50 到 95 每 5 一格；發車數的格子只收 0 到 30、休息只收 0 到 20" do
    rendered = render_header
    departures = rendered.at_css("[data-timetable-controls] input[name='departures[0][6]']")
    expect([ rendered.css("select[name=p] option").map { it["value"] }, departures["min"], departures["max"], rendered.at_css("input[name=buffer]")["min"], rendered.at_css("input[name=buffer]")["max"] ])
      .to eq([ %w[50 55 60 65 70 75 80 85 90 95], "0", "30", "0", "20" ])
  end

  it "控制項後面緊接著一句改了會重新鋪排、手動改過的會不見" do
    expect(render_header.at_css("[data-timetable-controls]").next_element&.key?("data-regeneration-notice")).to be(true)
  end
end
