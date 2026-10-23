# frozen_string_literal: true

require "rails_helper"

RSpec.describe LayoverTableComponent, type: :component do
  let(:route_day) do
    create(:route_day).tap do |route_day|
      route_day.stops.create!([ { go_back: 0, seq: 4, stop_name: "戊站" }, { go_back: 1, seq: 9, stop_name: "甲站" } ])
    end
  end

  # The nature of the end where direction 0 trips end and of the one where
  # direction 1 trips end.
  def route_ends(outbound, inbound) = RoutePage::Ends.from_config({ 0 => outbound, 1 => inbound }, route_id: 9001)

  def render_table(ends)
    render_inline(described_class.new(layover_stats: RoutePage::LayoverStats.new(RouteDay.where(id: route_day.id)), ends:))
  end

  def cells(rendered) = rendered.css("tbody tr").map { |row| row.css("td").map { it.text.squish } }

  it "每個方向一列：方向、末站、那一端停車或開過去就走、筆數、p10、p50、p90、不到 15 分鐘的比例；沒有折返停留的方向顯示 —" do
    end_time = Time.zone.parse("2026-10-19 08:00")
    [ 10, 20, 30 ].each { route_day.layovers.create!(bus_id: "TEST-0001", go_back: 0, end_time:, next_start_time: end_time + it.minutes) }
    expect(cells(render_table(route_ends("pass_through", "stop")))).to eq([ %w[去程 戊站 開過去就走 3 12.0 20.0 28.0 33.3%], %w[返程 甲站 停車 0 — — — —] ])
  end

  it "每一列標出那一端的性質" do
    natures = render_table(route_ends("pass_through", "stop")).css("tr[data-direction]").map { [ it["data-direction"], it["data-end-nature"] ] }
    expect(natures).to eq([ %w[0 pass_through], %w[1 stop] ])
  end

  it "有開過去就走的一端時，表下說明那一端的折返停留不是休息機會" do
    expect(render_table(route_ends("pass_through", "stop")).css("[data-pass-through-note]").size).to eq(1)
  end

  it "兩端都停車時沒有那句說明" do
    expect(render_table(route_ends("stop", "stop")).css("[data-pass-through-note]").size).to eq(0)
  end
end
