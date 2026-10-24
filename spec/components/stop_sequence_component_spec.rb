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

  it "每個方向依站序列出站名，第一站標起站、最後一站標末站" do
    rendered = render_both_directions
    expect([ stops(rendered, 0), stops(rendered, 1) ]).to eq([ [ [ "甲站", true, false ], [ "乙站", false, false ], [ "戊站", false, true ] ],
                                                               [ [ "己站", true, false ], [ "丁站", false, false ], [ "甲站", false, true ] ] ])
  end

  it "清單之後是那一端的折返：去程開過去就走、下一趟從己站出發，返程停車、下一趟從甲站出發" do
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
