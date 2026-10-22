require "rails_helper"

RSpec.describe RoutePage::LoadProfile, type: :model do
  def route_day(day, names)
    RouteDay.create!(route_id: 9001, day:, route_name: "測試幹線", departure: "甲站", destination: "戊站",
                     static_day: day, loaded_at: Time.current).tap do |route_day|
      names.each { |(go_back, seq), stop_name| route_day.stops.create!(go_back:, seq:, stop_name:) }
    end
  end

  it "站序取最新那一天的站牌，依方向與站序排" do
    days = [ route_day(Date.new(2026, 10, 19), [ 0, 0 ] => "舊站"),
             route_day(Date.new(2026, 10, 20), [ 1, 2 ] => "丙站", [ 0, 1 ] => "乙站", [ 0, 0 ] => "甲站") ]
    stops = described_class.new(RouteDay.where(id: days.map(&:id))).stops
    expect(stops.map { [ it.go_back, it.seq, it.stop_name ] }).to eq([ [ 0, 0, "甲站" ], [ 0, 1, "乙站" ], [ 1, 2, "丙站" ] ])
  end
end
