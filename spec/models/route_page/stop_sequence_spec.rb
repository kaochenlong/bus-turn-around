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

  # The stop names of each direction, at the locations 81000 to 81009 by sequence number.
  def outbound = %w[甲站 乙站 丙站 丁站 戊站]

  def inbound = %w[戊站對面 丁站對面 丙站對面 乙站對面 甲站]

  # Writes one route's ten stops on the day; `swap` replaces a stop name and
  # location by sequence number, as 9050's 己站 does.
  def add_stops(route_day, route_id, swap = {})
    (outbound + inbound).each_with_index do |name, seq|
      name, location = swap.fetch(seq, [ name, 81000 + seq ])
      route_day.stops.create!(route_id:, go_back: seq < 5 ? 0 : 1, seq:, stop_name: name, stop_location_id: location)
    end
  end

  # A stored day of 9001 with the member 9050, which serves 己站 instead of
  # 丙站 outbound and, unless `same_inbound`, 己站對面 instead of 丙站對面 inbound.
  def member_day(same_inbound: false)
    create(:route_day, day: Date.new(2026, 10, 20), member_names: { "9050" => "測試幹線經己站" }).tap do |route_day|
      add_stops(route_day, 9001)
      add_stops(route_day, 9050, { 2 => [ "己站", 85002 ] }.merge(same_inbound ? {} : { 7 => [ "己站對面", 85007 ] }))
    end
  end

  def notes(direction) = direction.member_notes.map { [ it.name, it.route_id, it.skipped_stops, it.added_stops ] }

  it "去程的註記：成員 9050 不停丙站、改停己站，帶名稱與路線 Id" do
    expect(notes(stop_sequence(member_day).directions.first)).to eq([ [ "測試幹線經己站", 9050, [ "丙站" ], [ "己站" ] ] ])
  end

  it "返程的註記：不停丙站對面、改停己站對面" do
    expect(notes(stop_sequence(member_day).directions.last)).to eq([ [ "測試幹線經己站", 9050, [ "丙站對面" ], [ "己站對面" ] ] ])
  end

  it "返程兩邊站位完全相同時，返程沒有註記、去程仍有" do
    expect(stop_sequence(member_day(same_inbound: true)).directions.map { it.member_notes.size }).to eq([ 1, 0 ])
  end

  it "沒有成員的日子沒有任何註記" do
    day = route_day(Date.new(2026, 10, 20), [ 0, 0 ] => "甲站", [ 1, 1 ] => "乙站")
    expect(stop_sequence(day).directions.map(&:member_notes)).to eq([ [], [] ])
  end

  it "站序只列頁面路線 9001 的站：己站與己站對面不在清單裡" do
    expect(stop_sequence(member_day).directions.map(&:stop_names)).to eq([ outbound, inbound ])
  end

  it "同一個物件呼叫兩次 directions，只查一次 route_day_stops" do
    stop_sequence = stop_sequence(route_day(Date.new(2026, 10, 20), [ 0, 0 ] => "甲站"))
    queries = []
    count_stop_queries = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?('FROM "route_day_stops"') }
    ActiveSupport::Notifications.subscribed(count_stop_queries, "sql.active_record") { 2.times { stop_sequence.directions } }
    expect(queries.size).to eq(1)
  end
end
