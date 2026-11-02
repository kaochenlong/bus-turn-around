# frozen_string_literal: true

require "rails_helper"

RSpec.describe MonthCardCyclesComponent, type: :component do
  let(:route_card) { create(:route_card, route_id: 15373) }
  let(:month_card) { RoutePage::MonthCard.new(route_card) }

  def row(hour, round_trip_p50, cycle_p10, n_round_trips: 5, n_cycles: 5)
    RoutePage::Cycles::Row.new(hour:, n_round_trips:, round_trip_percentiles: [ round_trip_p50, nil ], n_cycles:, cycle_percentiles: [ cycle_p10, nil ])
  end

  def render_block(rows)
    cycles = instance_double(RoutePage::Cycles, rows:, first_stop_name: "青年公園", last_stop_name: "天母")
    allow(month_card).to receive(:cycles).and_return(cycles)
    render_inline(described_class.new(month_card:))
  end

  def points(series) = page.all("[data-series='#{series}'] circle", visible: :all).map { it["data-hour"].to_f }

  it "來回一趟 p50 與週期 p10 兩條線，只畫筆數 5 以上的小時" do
    render_block([ row(7, 150.0, 140.0), row(8, 150.0, 140.0, n_round_trips: 4), row(9, 150.0, 140.0, n_cycles: 4) ])
    expect([ points("round-trip"), points("cycle") ]).to eq([ [ 7.5, 9.5 ], [ 7.5, 8.5 ] ])
  end

  it "差不到 4 分鐘的小時標出來" do
    render_block([ row(7, 150.0, 148.0), row(8, 150.0, 140.0), row(9, 150.0, 153.9) ])
    expect(page.all("[data-shaded-hour]", visible: :all).map { it["data-shaded-hour"] }).to eq(%w[7 9])
  end

  it "筆數不夠的小時就算差不到 4 分鐘也不標" do
    render_block([ row(7, 150.0, 148.0, n_cycles: 4) ])
    expect(page).to have_no_css("[data-shaded-hour]", visible: :all)
  end

  it "說明寫來回一趟的起站與末站" do
    render_block([ row(7, 150.0, 140.0) ])
    expect(page.find("[data-cycles-lead]").text).to include("從青年公園發車，到回到天母為止")
  end

  it "沒有小時可以畫：不畫圖" do
    render_block([ row(7, 150.0, 140.0, n_round_trips: 1, n_cycles: 1) ])
    expect(page).to have_no_css("svg", visible: :all)
  end

  it "區塊標記是 cycles" do
    render_block([])
    expect(page).to have_css("section[data-card-section='cycles']")
  end
end
