# frozen_string_literal: true

require "rails_helper"

RSpec.describe MonthCardDrivingComponent, type: :component do
  let(:route_card) { create(:route_card) }
  let(:month_card) { RoutePage::MonthCard.new(route_card) }

  def store(day, **attributes) = create(:route_day, day: Date.iso8601(day), **attributes)

  # Windows of a rule on a day: `flags` says which are flagged, `over` how many of
  # the first ones are on a vehicle over the daily driving limit.
  def add_windows(route_day, flags, rule: "four_hours", over: 0)
    flags.each_with_index do |flagged, index|
      create(:route_day_rest_window, route_day:, rule:, bus_id: "TEST-#{index}", flagged:, over_daily_driving: index < over)
    end
  end

  # A stretch of `minutes` minutes for each of the lengths given.
  def add_stretches(route_day, *lengths)
    lengths.each_with_index do |minutes, index|
      start_time = Time.zone.parse("#{route_day.day} 06:00")
      create(:route_day_driving_stretch, route_day:, bus_id: "TEST-#{index}", start_time:, end_time: start_time + minutes.minutes)
    end
  end

  def render_block = render_inline(described_class.new(month_card:))

  def rule_row(set, rule) = page.find("tr[data-set='#{set}'][data-rule='#{rule}']").all("td").map(&:text)

  it "規則列：能判斷的視窗、符合條件的視窗、比例與逐日範圍" do
    add_windows(store("2026-10-19"), [ true, false ])
    add_windows(store("2026-10-20"), [ true, true ])
    render_block
    expect(rule_row("weekday", "four_hours").drop(1).drop(1)).to eq([ "4", "3", "75.0%", "50%–100%" ])
  end

  it "6 小時的規則與假日各有一列" do
    add_windows(store("2026-10-25", day_type: "holiday"), [ true, false ], rule: "six_hours")
    render_block
    expect(rule_row("holiday", "six_hours").drop(2)).to eq([ "2", "1", "50.0%", "50%–50%" ])
  end

  it "沒有視窗：能判斷的視窗是 0，其他都是 —" do
    render_block
    expect(rule_row("weekday", "four_hours").drop(2)).to eq([ "0", "0", "—", "—" ])
  end

  describe "表下面那段" do
    it "落在當天行駛超過 10 小時的車上的視窗數與比例" do
      add_windows(store("2026-10-19"), [ true, false, false, false ], over: 1)
      render_block
      expect(page.find("[data-over-daily]").text).to include("有 1 個（25%）落在")
    end

    it "沒有視窗：不寫" do
      render_block
      expect(page).to have_no_css("[data-over-daily]")
    end

    it "連續行駛段的分佈" do
      add_stretches(store("2026-10-19"), 100, 200, 300, 400)
      render_block
      expect(page.find("[data-stretches]").text).to include("中位數 250 分鐘，最長一成 370 分鐘以上，共 4 段，其中超過 4 小時 2 段、超過 6 小時 1 段")
    end

    it "沒有連續行駛段：不寫" do
      render_block
      expect(page).to have_no_css("[data-stretches]")
    end
  end

  it "區塊標記是 driving" do
    render_block
    expect(page).to have_css("section[data-card-section='driving']")
  end
end
