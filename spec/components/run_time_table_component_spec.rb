# frozen_string_literal: true

require "rails_helper"

RSpec.describe RunTimeTableComponent, type: :component do
  let(:route_day) do
    create(:route_day)
  end

  def trip(start, minutes, go_back: 0, **attributes)
    start_time = Time.zone.parse("2026-10-19 #{start}")
    route_day.trips.create!({ bus_id: "TEST-0001", path_attribute_id: 9001, go_back:, band: "other", start_time:,
                              end_time: start_time + minutes.minutes, first_seq: 0, last_seq: 4, n_events: 10,
                              n_stops_observed: 5, completeness: "complete", start_from_arrival: false,
                              end_from_departure: false }.merge(attributes))
  end

  def rendered = render_inline(described_class.new(run_times: RoutePage::RunTimes.new(RouteDay.where(id: route_day.id))))

  # The text of each number cell; the bar cell has no text of its own.
  def cells(go_back) = rendered.css("[data-direction='#{go_back}'] tbody tr").map { |row| row.css("td:not([data-bar-from])").map { it.text.squish } }

  # The component's own translation for a small sample, read from its file:
  # sidecar translations are not in the global I18n backend.
  def small_sample_label = YAML.load_file(Rails.root.join("app/components/run_time_table_component.yml"), aliases: true).dig("tw", "small_sample")

  describe "寫入的趟次算出的表格" do
    before do
      [ 50, 52, 55, 60, 70 ].each_with_index { |minutes, index| trip(format("07:%02d", index * 10), minutes) }
      trip("22:00", 40, go_back: 1).then { trip("22:30", 50, go_back: 1) }
      trip("08:00", 45, start_from_arrival: true)
    end

    it "去程每個發車小時一列：時、趟數、p50、p85、p95" do
      expect(cells(0)).to eq([ [ "07", "5", "55.0", "64.0", "68.0" ] ])
    end

    it "趟數少於 5 的列標成樣本少" do
      expect([ 0, 1 ].map { |go_back| rendered.css("[data-direction='#{go_back}'] tr[data-small-sample]").size }).to eq([ 0, 1 ])
    end

    it "樣本少的列在趟數旁標出樣本少，其他列沒有" do
      rows = rendered.css("tbody tr").map { [ it.key?("data-small-sample"), it.text.include?(small_sample_label) ] }
      expect(rows).to eq([ [ false, false ], [ true, true ] ])
    end

    it "每個方向寫出排除的趟數" do
      expect([ 0, 1 ].map { rendered.at_css("[data-excluded-for='#{it}']")["data-excluded-count"] }).to eq(%w[1 0])
    end
  end

  describe "橫條與刻度" do
    # Run times whose rows are [direction, hour, p50, p85, p95, trips], five
    # trips unless given, so the percentiles are exactly the ones a test names.
    def run_times(*rows)
      instance_double(RoutePage::RunTimes, excluded: { 0 => 0, 1 => 0 }, rows: rows.map do |go_back, hour, p50, p85, p95, n_trips = 5|
        RoutePage::RunTimes::Row.new(go_back:, hour:, n_trips:, percentiles: [ p50, p85, p95 ], small_sample: n_trips < RoutePage::RunTimes::SMALL_SAMPLE)
      end)
    end

    def render_rows(*rows) = render_inline(described_class.new(run_times: run_times(*rows)))

    def scales(output) = output.css("table[data-scale-from]").map { [ it["data-scale-from"], it["data-scale-to"] ] }.uniq

    def bars(output)
      output.css("[data-direction]").flat_map { |direction| direction.css("[data-bar-from]").map { [ direction["data-direction"], it["data-bar-from"], it["data-bar-to"], it["data-bar-mark"] ] } }
    end

    let(:both_directions) { [ [ 0, 7, 55.0, 64.0, 68.0 ], [ 1, 22, 40.0, 45.0, 52.0 ] ] }

    it "兩個方向共用刻度 40 到 70：去程的橫條從 55.0 到 68.0、直線在 64.0，返程從 40.0 到 52.0、直線在 45.0" do
      output = render_rows(*both_directions)
      expect([ scales(output), bars(output) ]).to eq([ [ %w[40 70] ], [ %w[0 55.0 68.0 64.0], %w[1 40.0 52.0 45.0] ] ])
    end

    [ [ 54.7, 102.3, %w[50 110] ], [ 40.0, 70.0, %w[40 70] ], [ 60.0, 60.0, %w[60 70] ] ].each do |p50, p95, scale|
      it "最小的 p50 是 #{p50}、最大的 p95 是 #{p95} 時，刻度是 #{scale.join(' 到 ')}；沒有列的方向不影響刻度" do
        expect(scales(render_rows([ 0, 7, p50, p50, p95 ]))).to eq([ scale ])
      end
    end

    it "表頭寫出刻度的兩端與中點" do
      expect(render_rows(*both_directions).at_css("[data-direction='0'] thead [data-scale-ticks]").css("span").map(&:text)).to eq(%w[40 55 70])
    end

    it "橫條的位置是刻度上的百分比：刻度 40 到 70 時，55.0 到 68.0 從 50.0% 起、寬 43.3%，64.0 的直線在 80.0%" do
      bar = render_rows(*both_directions).at_css("[data-direction='0'] [data-bar-from]")
      expect(bar.css("[style]").map { it["style"] }).to eq([ "left: 50.0%; width: 43.3%", "left: 80.0%" ])
    end

    it "樣本少的列也有橫條，顏色比較淡" do
      rows = render_rows([ 0, 7, 55.0, 64.0, 68.0 ], [ 0, 8, 50.0, 52.0, 53.0, 2 ]).css("tbody tr")
      expect(rows.map { [ it.key?("data-small-sample"), it.css("[data-bar-from]").size, it.css("[data-bar-from] .bg-slate-300").size ] })
        .to eq([ [ false, 1, 0 ], [ true, 1, 1 ] ])
    end

    it "兩個方向都沒有趟次時，各寫一句沒有可算的趟次，沒有刻度、橫條與橫條的說明" do
      output = render_rows
      expect([ output.css("[data-no-trips]").size, output.css("[data-scale-from], [data-bar-from], [data-bar-legend]").size ]).to eq([ 2, 0 ])
    end

    it "有趟次時，表格上方有一行橫條的說明" do
      expect(render_rows(*both_directions).css("[data-bar-legend]").size).to eq(1)
    end
  end
end
