require "rails_helper"

RSpec.describe RoutePage::StopSequence, type: :model do
  def route_day(day, names)
    create(:route_day, day:).tap do |route_day|
      names.each { |(go_back, seq), stop_name| route_day.stops.create!(go_back:, seq:, stop_name:) }
    end
  end

  # Ordered by day like RoutePage::Coverage#route_days, which the page passes in.
  def stop_sequence(*days) = described_class.new(RouteDay.where(id: days.map(&:id)).order(:day))

  def summary(directions) = directions.map { [ it.go_back, it.stop_names, it.next_first_stop ] }

  it "涵蓋 10-19 與 10-20、由舊到新傳進來：去程是 10-20 的甲站、丙站、戊站，快照日是 10-20" do
    older = route_day(Date.new(2026, 10, 19), [ 0, 0 ] => "甲站", [ 0, 1 ] => "乙站")
    newer = route_day(Date.new(2026, 10, 20), [ 0, 0 ] => "甲站", [ 0, 1 ] => "丙站", [ 0, 2 ] => "戊站")
    stop_sequence = stop_sequence(older, newer)
    expect([ stop_sequence.directions.map(&:stop_names), stop_sequence.static_day ]).to eq([ [ %w[甲站 丙站 戊站] ], Date.new(2026, 10, 20) ])
  end

  it "兩個方向依去返程排、各自依站序排，下一趟的起站是另一個方向的第一站" do
    day = route_day(Date.new(2026, 10, 20), [ 1, 5 ] => "甲站", [ 1, 4 ] => "丁站", [ 1, 3 ] => "己站", [ 0, 2 ] => "戊站", [ 0, 1 ] => "乙站", [ 0, 0 ] => "甲站")
    stop_sequence = stop_sequence(day)
    expect([ stop_sequence.any?, summary(stop_sequence.directions) ]).to eq([ true, [ [ 0, %w[甲站 乙站 戊站], "己站" ], [ 1, %w[己站 丁站 甲站], "甲站" ] ] ])
  end

  it "只有去程有站牌時只有去程，下一趟的起站是 nil" do
    day = route_day(Date.new(2026, 10, 20), [ 0, 0 ] => "甲站", [ 0, 1 ] => "乙站")
    expect(summary(stop_sequence(day).directions)).to eq([ [ 0, %w[甲站 乙站], nil ] ])
  end

  it "最新那一天沒有站牌時沒有任何方向、any? 為假，不退回前一天的站牌" do
    stop_sequence = stop_sequence(route_day(Date.new(2026, 10, 19), [ 0, 0 ] => "甲站"), route_day(Date.new(2026, 10, 20), {}))
    expect([ stop_sequence.any?, stop_sequence.directions ]).to eq([ false, [] ])
  end

  it "快照日是最新那一天的 static_day，不是 day；沒有任何路線日時是 nil" do
    day = create(:route_day, day: Date.new(2026, 10, 20), static_day: Date.new(2026, 10, 19))
    expect([ stop_sequence(day).static_day, described_class.new(RouteDay.none).static_day ]).to eq([ Date.new(2026, 10, 19), nil ])
  end

  it "同一個物件呼叫兩次 directions，只查一次 route_day_stops" do
    stop_sequence = stop_sequence(route_day(Date.new(2026, 10, 20), [ 0, 0 ] => "甲站"))
    queries = []
    count_stop_queries = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?('FROM "route_day_stops"') }
    ActiveSupport::Notifications.subscribed(count_stop_queries, "sql.active_record") { 2.times { stop_sequence.directions } }
    expect(queries.size).to eq(1)
  end
end
