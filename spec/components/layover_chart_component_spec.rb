# frozen_string_literal: true

require "rails_helper"

RSpec.describe LayoverChartComponent, type: :component do
  # The nature of the end where direction 0 trips end and of the one where
  # direction 1 trips end.
  def route_ends(outbound, inbound) = RoutePage::Ends.from_config({ 0 => outbound, 1 => inbound }, route_id: 9001)

  # A stored day whose direction 0 runs 甲站 to 戊站 and direction 1 己站 to
  # 甲站, with layovers of the given minutes ending in direction 0.
  def render_chart(layover_minutes, ends: route_ends("stop", "stop"))
    route_day = create(:route_day)
    route_day.stops.create!([ { go_back: 0, seq: 0, stop_name: "甲站" }, { go_back: 0, seq: 4, stop_name: "戊站" },
                              { go_back: 1, seq: 5, stop_name: "己站" }, { go_back: 1, seq: 9, stop_name: "甲站" } ])
    end_time = Time.zone.parse("2026-10-19 08:00")
    layover_minutes.each { route_day.layovers.create!(bus_id: "TEST-0001", go_back: 0, end_time:, next_start_time: end_time + it.minutes) }
    render_inline(described_class.new(layover_distribution: RoutePage::LayoverDistribution.new(RouteDay.where(id: route_day.id)), ends:))
  end

  def bars(rendered, go_back) = rendered.css("[data-direction='#{go_back}'] [data-bin]")

  it "每個方向每組一根長條，帶下界與筆數" do
    bars = bars(render_chart([ 2, 3, 12, 40 ]), 0)
    expect(bars.map { [ it["data-bin"], it["data-count"] ] }).to eq([ %w[0 2], %w[5 0], %w[10 1], %w[15 0], %w[30 1], %w[60 0] ])
  end

  it "長條長度按同一個方向的最大筆數比例畫：2 筆的長度是 1 筆的兩倍" do
    widths = bars(render_chart([ 2, 3, 12 ]), 0).to_h { [ it["data-bin"], it["width"].to_f ] }
    expect([ widths["0"], widths["5"] ]).to eq([ widths["10"] * 2, 0.0 ])
  end

  it "標題寫出末站與下一趟出發的起站" do
    title = render_chart([ 10 ]).at_css("[data-direction='0'] [data-stops]")
    expect([ title["data-last-stop"], title["data-next-first-stop"], title.text.include?("戊站") && title.text.include?("己站") ])
      .to eq([ "戊站", "己站", true ])
  end

  it "每個方向的標題標出那一端是停車還是開過去就走" do
    figures = render_chart([ 10 ], ends: route_ends("pass_through", "stop")).css("figure[data-direction]")
    expect(figures.map { [ it["data-direction"], it.at_css("figcaption")["data-end-nature"] ] }).to eq([ %w[0 pass_through], %w[1 stop] ])
  end

  it "沒有折返停留的方向標出沒有，也不畫長條" do
    rendered = render_chart([ 10 ])
    expect([ rendered.css("[data-direction='1'] [data-no-layover]").size, bars(rendered, 1).size ]).to eq([ 1, 0 ])
  end

  it "15 分鐘處有一條分隔線" do
    expect(render_chart([ 10 ]).css("[data-direction='0'] [data-divider='15']").size).to eq(1)
  end
end
