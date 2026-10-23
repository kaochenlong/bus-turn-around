# frozen_string_literal: true

require "rails_helper"

RSpec.describe RouteSummaryComponent, type: :component do
  let(:route_day) do
    create(:route_day)
  end

  def trip(start, completeness)
    start_time = Time.zone.parse("2026-10-19 #{start}")
    route_day.trips.create!(bus_id: "TEST-0001", path_attribute_id: 9001, go_back: 0, band: "other", start_time:,
                            end_time: start_time + 50.minutes, first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5,
                            completeness:, start_from_arrival: false, end_from_departure: false)
  end

  it "顯示趟數與完整趟數" do
    trip("07:00", "complete").then { trip("08:00", "missing_end") }
    rendered = render_inline(described_class.new(summary: RoutePage::Summary.new(RouteDay.where(id: route_day.id))))
    expect(%w[trips complete-trips].map { rendered.at_css("[data-#{it}]")["data-#{it}"] }).to eq(%w[2 1])
  end
end
