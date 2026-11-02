# frozen_string_literal: true

require "rails_helper"

RSpec.describe MonthCardRunTimesComponent, type: :component do
  let(:route_card) { create(:route_card) }
  let(:month_card) { RoutePage::MonthCard.new(route_card) }

  def run_row(go_back, hour, n_trips, p50 = 50.0, p85 = 60.0)
    RoutePage::RunTimes::Row.new(go_back:, hour:, n_trips:, percentiles: [ p50, p85, 70.0 ], small_sample: n_trips < 5)
  end

  def cycle_row(hour, n_round_trips: 5, n_cycles: 5)
    RoutePage::Cycles::Row.new(hour:, n_round_trips:, round_trip_percentiles: [ 150.0, 170.0 ], n_cycles:, cycle_percentiles: [ 140.0, 180.0 ])
  end

  def legs(*rows) = instance_double(RoutePage::SlowLegs, rows:)

  def leg(kmh, band: "morning_peak", go_back: 0, from_name: "甲站", to_name: "乙站", meters: 300.4, n_trips: 20)
    RoutePage::SlowLegs::Row.new(go_back:, from_name:, to_name:, band:, meters:, n_trips:, kmh:)
  end

  # Renders with these figures standing in for the query objects' results.
  def render_block(run_rows: [], excluded: { 0 => 0, 1 => 0 }, cycle_rows: [], total: cycle_row(nil, n_round_trips: 40, n_cycles: 30), slow_legs: legs)
    allow(month_card).to receive_messages(run_times: instance_double(RoutePage::RunTimes, rows: run_rows, excluded:), cycles: instance_double(RoutePage::Cycles, rows: cycle_rows, total:), slow_legs:)
    render_inline(described_class.new(month_card:))
  end

  def hour_row(hour) = page.find("tr[data-hour='#{hour}']")

  describe "不算的趟次" do
    it "寫出每個方向幾趟" do
      render_block(excluded: { 0 => 199, 1 => 7 })
      expect(page.find("[data-run-times-lead]").text).to include("去程 199 趟、返程 7 趟")
    end

    it "去程比較多：說去程的筆數比較少" do
      render_block(excluded: { 0 => 199, 1 => 7 })
      expect(page.find("[data-run-times-lead]").text).to include("所以去程的筆數比較少")
    end

    it "返程比較多：說返程的筆數比較少" do
      render_block(excluded: { 0 => 7, 1 => 199 })
      expect(page.find("[data-run-times-lead]").text).to include("所以返程的筆數比較少")
    end

    it "兩邊一樣多：不說哪邊比較少" do
      render_block(excluded: { 0 => 3, 1 => 3 })
      expect(page.find("[data-run-times-lead]").text).not_to include("筆數比較少")
    end
  end

  describe "每小時一列" do
    it "去程、返程的趟數與 p50、p85，來回一趟與週期" do
      render_block(run_rows: [ run_row(0, 7, 10), run_row(1, 7, 9, 55.0, 65.0) ], cycle_rows: [ cycle_row(7) ])
      expect(hour_row(7).all("td").map(&:text)).to eq(%w[07 10 50 60 9 55 65 5 150 170 5 140 180])
    end

    it "只有一個方向有趟次：另一邊是 0 與 —" do
      render_block(run_rows: [ run_row(0, 7, 10) ])
      expect(hour_row(7).all("td").map(&:text).values_at(4, 5, 6)).to eq(%w[0 — —])
    end

    it "只有週期有筆數的小時也有一列" do
      render_block(cycle_rows: [ cycle_row(22) ])
      expect(hour_row(22).all("td").map(&:text).first(2)).to eq(%w[22 0])
    end

    it "筆數不到 5 的值灰字" do
      render_block(run_rows: [ run_row(0, 7, 4), run_row(1, 7, 5) ])
      expect(hour_row(7).all(".smallsample").map(&:text)).to eq(%w[4 50 60])
    end

    it "週期筆數不到 5 也灰字" do
      render_block(cycle_rows: [ cycle_row(7, n_cycles: 4) ])
      expect(hour_row(7).all(".smallsample").map(&:text)).to eq(%w[4 140 180])
    end
  end

  it "最後一列是全天：來回一趟與週期的筆數與百分位數" do
    render_block
    expect(page.find("tr[data-total]").all("td").map(&:text)).to eq([ "全天", "", "40", "150", "170", "30", "140", "180" ])
  end

  describe "最慢的幾段" do
    it "一列寫方向、兩站、時段、距離、趟數與時速" do
      render_block(slow_legs: legs(leg(4.2, band: "evening_peak", go_back: 1)))
      expect(page.find("tr[data-slow-leg]").all("td").map(&:text)).to eq([ "返程", "甲站 → 乙站", "晚尖峰", "300", "20", "4.2" ])
    end

    it "照查詢物件給的順序" do
      render_block(slow_legs: legs(leg(4.2), leg(4.9)))
      expect(page.all("tr[data-slow-leg]").map { it.all("td").last.text }).to eq(%w[4.2 4.9])
    end

    it "沒有符合的段：表不出現" do
      render_block
      expect(page).to have_no_css("[data-slow-legs]")
    end
  end

  it "區塊標記是 run-times" do
    render_block
    expect(page).to have_css("section[data-card-section='run-times']")
  end
end
