# frozen_string_literal: true

require "rails_helper"

RSpec.describe StopSequenceComponent, type: :component do
  # The nature of the end where direction 0 trips end and of the one where
  # direction 1 trips end.
  def route_ends(outbound, inbound) = RoutePage::Ends.from_config({ 0 => outbound, 1 => inbound }, route_id: 9001)

  # A stored day of route 9001 with the given stops, keyed by direction and
  # sequence number, whose direction 0 ends at a pass-through end and
  # direction 1 at a stopping end.
  def render_stops(names)
    route_day = create(:route_day, day: Date.new(2026, 10, 20))
    names.each { |(go_back, seq), stop_name| route_day.stops.create!(go_back:, seq:, stop_name:) }
    stop_sequence = RoutePage::StopSequence.new(RouteDay.where(id: route_day.id).order(:day))
    render_inline(described_class.new(stop_sequence:, ends: route_ends("pass_through", "stop")))
  end

  # Direction 0 runs 甲站, 乙站, 戊站 and direction 1 己站, 丁站, 甲站, with the
  # sequence numbers 0 to 5.
  def render_both_directions = render_stops([ 0, 0 ] => "甲站", [ 0, 1 ] => "乙站", [ 0, 2 ] => "戊站", [ 1, 3 ] => "己站", [ 1, 4 ] => "丁站", [ 1, 5 ] => "甲站")

  # Each stop of a direction as [its own text, marked first stop, marked last stop].
  def stops(rendered, go_back) = rendered.css("[data-direction='#{go_back}'] li").map { [ it.xpath("text()").text.strip, it.key?("data-first-stop"), it.key?("data-last-stop") ] }

  def turnaround(rendered, go_back) = rendered.at_css("[data-direction='#{go_back}'] p[data-turnaround]")

  # A stored day of 9001 with the member 9050 (named in member_names): both
  # serve 甲乙丙丁戊 and back, at the locations 81000 to 81009, except that
  # 9050 serves 己站 (85002) instead of 丙站 and, unless `same_inbound`,
  # 己站對面 (85007) instead of 丙站對面.
  def render_member_day(same_inbound: false)
    route_day = create(:route_day, day: Date.new(2026, 10, 20), member_names: { "9050" => "測試幹線經己站" })
    swaps = { 9001 => {}, 9050 => { 2 => [ "己站", 85002 ] }.merge(same_inbound ? {} : { 7 => [ "己站對面", 85007 ] }) }
    swaps.each do |route_id, swap|
      %w[甲站 乙站 丙站 丁站 戊站 戊站對面 丁站對面 丙站對面 乙站對面 甲站].each_with_index do |name, seq|
        name, location = swap.fetch(seq, [ name, 81000 + seq ])
        route_day.stops.create!(route_id:, go_back: seq < 5 ? 0 : 1, seq:, stop_name: name, stop_location_id: location)
      end
    end
    stop_sequence = RoutePage::StopSequence.new(RouteDay.where(id: route_day.id).order(:day))
    render_inline(described_class.new(stop_sequence:, ends: route_ends("stop", "stop")))
  end

  def member_note(rendered, go_back) = rendered.at_css("[data-direction='#{go_back}'] p[data-member-note='9050']")&.text&.strip

  it "成員路線的那一句：去程寫 9050 不停丙站、改停己站" do
    expect(member_note(render_member_day, 0)).to eq("測試幹線經己站（路線 Id 9050）在這個方向不停 丙站，改停 己站。")
  end

  it "成員路線的那一句：返程寫 9050 不停丙站對面、改停己站對面" do
    expect(member_note(render_member_day, 1)).to eq("測試幹線經己站（路線 Id 9050）在這個方向不停 丙站對面，改停 己站對面。")
  end

  it "那一句在站的清單之後、折返那一列之前" do
    children = render_member_day.css("[data-direction='0'] > *").map { it.name == "p" ? it.attributes.keys.find { |key| key.start_with?("data-") } : it.name }
    expect(children).to eq([ "h3", "ol", "data-member-note", "data-turnaround" ])
  end

  it "返程站位完全相同時返程沒有那一句，去程仍有" do
    rendered = render_member_day(same_inbound: true)
    expect([ member_note(rendered, 0).nil?, member_note(rendered, 1) ]).to eq([ false, nil ])
  end

  it "沒有成員的路線沒有那一句" do
    expect(render_both_directions.css("[data-member-note]").size).to eq(0)
  end

  it "有成員時清單只列 9001 的站，沒有己站" do
    expect(stops(render_member_day, 0).map(&:first)).to eq(%w[甲站 乙站 丙站 丁站 戊站])
  end

  it "每個方向依站序列出站名，第一站標起站、最後一站標末站" do
    rendered = render_both_directions
    expect([ stops(rendered, 0), stops(rendered, 1) ]).to eq([ [ [ "甲站", true, false ], [ "乙站", false, false ], [ "戊站", false, true ] ],
                                                               [ [ "己站", true, false ], [ "丁站", false, false ], [ "甲站", false, true ] ] ])
  end

  it "清單之後是那一端的折返：去程直接折返、下一趟從己站出發，返程停車、下一趟從甲站出發" do
    rendered = render_both_directions
    rows = [ 0, 1 ].map { turnaround(rendered, it) }
    expect(rows.map { [ it&.[]("data-end-nature"), it&.[]("data-next-first-stop"), it&.text ] })
      .to match([ [ "pass_through", "己站", include("己站") ], [ "stop", "甲站", include("甲站") ] ])
  end

  it "不印站序號碼：返程三站的站序是 3 到 5，三列的文字都沒有這些數字" do
    texts = render_both_directions.css("[data-direction='1'] li").map(&:text)
    expect([ texts.size, texts.grep(/[345]/) ]).to eq([ 3, [] ])
  end

  it "清單收在預設關閉的 details 裡：每一站都在，摘要寫出兩個方向各 3 站" do
    details = render_both_directions.at_css("[data-section=stop-sequence] details[data-stop-sequence]")
    expect([ details&.key?("open"), details&.css("li")&.size, details&.css("summary [data-stop-count]")&.map { it["data-stop-count"] } ]).to eq([ false, 6, %w[3 3] ])
  end

  it "只有去程有站牌時只列去程，折返那一列只寫折返方式、沒有下一趟的起站" do
    rendered = render_stops([ 0, 0 ] => "甲站", [ 0, 1 ] => "乙站")
    expect([ rendered.css("[data-direction]").map { it["data-direction"] }, turnaround(rendered, 0)&.key?("data-next-first-stop") ]).to eq([ [ "0" ], false ])
  end

  it "最新那一天沒有站牌時寫沒有站序，不輸出 details，也沒有快照日那一句" do
    rendered = render_stops({})
    expect([ rendered.css("[data-no-stops]").size, rendered.css("details").size, rendered.css("[data-static-day]").size ]).to eq([ 1, 0, 0 ])
  end

  it "最後一句寫出站序取自 2026-10-20 的快照" do
    snapshot = render_both_directions.at_css("[data-section=stop-sequence] p[data-static-day]")
    expect([ snapshot&.[]("data-static-day"), snapshot&.text&.include?("2026-10-20") ]).to eq([ "2026-10-20", true ])
  end
end
