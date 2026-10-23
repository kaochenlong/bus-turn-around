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

  def cells(go_back) = rendered.css("[data-direction='#{go_back}'] tbody tr").map { |row| row.css("td").map { it.text.squish } }

  # The component's own translation for a small sample, read from its file:
  # sidecar translations are not in the global I18n backend.
  def small_sample_label = YAML.load_file(Rails.root.join("app/components/run_time_table_component.yml"), aliases: true).dig("tw", "small_sample")

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
