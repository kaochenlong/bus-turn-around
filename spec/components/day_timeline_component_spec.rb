# frozen_string_literal: true

require "rails_helper"

RSpec.describe DayTimelineComponent, type: :component do
  # Route 9001: 甲站 is where direction 0 departs, 乙站 where direction 1 departs.
  def render_timeline(stop_names: { 0 => "甲站", 1 => "乙站" }, actions: { vehicle: "給別台", departure: "改時刻", deselect: "不選了" })
    render_inline(described_class.new(stop_names:, actions:))
  end

  # The legend's two directions, as their texts.
  def directions(page = render_timeline) = page.css("[data-legend-direction]").map { it.text.squish }

  # The selected trip's controls by their action, as their texts.
  def actions(page) = page.css("template[data-timeline-actions] button[data-action]").to_h { [ it["data-action"], it.text.squish ] }

  def labels = JSON.parse(render_timeline.at_css("[data-day-timeline]")["data-labels"])

  it "圖例寫出兩個方向的起訖站" do
    expect(directions).to eq([ "去程 甲站→乙站", "返程 乙站→甲站" ])
  end

  it "少了一端的站名時，圖例只寫方向" do
    expect(directions(render_timeline(stop_names: { 0 => "甲站" }))).to eq(%w[去程 返程])
  end

  it "趟次的 template 是按鈕" do
    trip = render_timeline.at_css("template[data-timeline-trip] [data-timeline-trip]")
    expect([ trip&.name, trip&.[]("type") ]).to eq(%w[button button])
  end

  it "選取的那一條照給的文案寫動作；記下回到哪一端由瀏覽器填" do
    expect(actions(render_timeline)).to eq("vehicle" => "給別台", "departure" => "改時刻", "record" => "", "deselect" => "不選了")
  end

  it "三個動作的文案跟側欄同一組：換給別台車就是側欄的派車" do
    page = render_inline(DayDispatchComponent.new(route_id: 9001, route_name: "測試幹線", stop_names: { 0 => "甲站", 1 => "乙站" }))
    header = page.at_css("th[data-column=vehicle]")&.text&.squish
    expect([ header.present?, actions(page)["vehicle"] ]).to eq([ true, header ])
  end

  it "瀏覽器要填的文案留著要填的位子" do
    placeholders = { "note" => %w[%{time} %{vehicle}], "late" => %w[%{minutes}], "shortStop" => %w[%{minutes}], "stopsAt" => %w[%{stop}],
                     "trip" => %w[%{vehicle} %{time} %{stop} %{direction} %{arrival}], "selectedTrip" => %w[%{vehicle} %{time}],
                     "selectedDetail" => %w[%{stop} %{direction} %{swapped} %{arrival} %{to}], "swapped" => %w[%{vehicle}], "dragHint" => %w[%{vehicle} %{time}] }
    expect(placeholders.map { |key, names| names.all? { labels[key]&.include?(it) } }).to eq([ true ] * placeholders.size)
  end

  it "瀏覽器寫趟次時用的兩個方向名稱" do
    expect(labels["directions"]).to eq("0" => "去程", "1" => "返程")
  end

  it "輸出裡沒有 BusID" do
    expect(render_timeline.to_html).not_to include("BusID")
  end
end
