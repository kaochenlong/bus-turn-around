# frozen_string_literal: true

require "rails_helper"

RSpec.describe TimetableOverrunTableComponent, type: :component do
  def row(percentile, overrun_share, exhausted_share, median_overrun)
    RoutePage::TimetableOverruns::Row.new(percentile:, overrun_share:, exhausted_share:, median_overrun:)
  end

  # The spec's example rows for the run times 44, 47, 50, 52 and 60 with 15
  # rest minutes; the other percentiles are given no overrun.
  def rows
    named = { 50 => row(50, 0.4, 0.0, 6.0), 85 => row(85, 0.2, 0.0, 5.0), 95 => row(95, 0.2, 0.0, 2.0) }
    RoutePage::PlannedRunTimes::PERCENTILES.map { |percentile| named.fetch(percentile) { row(percentile, 0.0, 0.0, nil) } }
  end

  def render_table(overruns: rows, percentile: 85, buffer: 15) = render_inline(described_class.new(overruns:, percentile:, buffer:))

  def cells(rendered) = rendered.css("tbody tr").map { |tr| tr.css("td").map { it.text.squish } }

  it "每個百分位數一列、三個數字：q50 是 40.0%、0.0%、6.0；q85 是 20.0%、0.0%、5.0；沒有超時趟次的列中位數是 —" do
    table = cells(render_table)
    expect([ table.size, table[0], table[7], table[1] ]).to eq([ 10, %w[p50 40.0% 0.0% 6.0], %w[p85 20.0% 0.0% 5.0], %w[p55 0.0% 0.0% —] ])
  end

  it "目前選的 p 那一列標 data-selected 並加粗，其他列沒有" do
    marks = render_table(percentile: 50).css("tbody tr").map { [ it["data-percentile"], it.key?("data-selected"), it.classes.include?("font-semibold") ] }
    expect(marks.first(2)).to eq([ [ "50", true, true ], [ "55", false, false ] ])
  end

  it "沒有任何行駛時間時，兩個比例與中位數都是 —" do
    expect(cells(render_table(overruns: [ row(50, nil, nil, nil) ]))).to eq([ %w[p50 — — —] ])
  end

  it "吃光休息那一欄的標題寫著用的休息分鐘數" do
    expect(render_table(buffer: 10).css("thead th")[2].text).to include("10")
  end
end
