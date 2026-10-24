# frozen_string_literal: true

require "rails_helper"

RSpec.describe LoadChartComponent, type: :component do
  # A stored day whose direction 0 stops, at sequence 0 to 4, have the given
  # nearest-entrance distances.
  def route_day(distances)
    create(:route_day, mrt_exits_day: Date.new(2026, 10, 19)).tap do |route_day|
      distances.each_with_index do |meters, seq|
        route_day.stops.create!(go_back: 0, seq:, stop_name: %w[甲站 乙站 丙站 丁站 戊站][seq], nearest_exit_name: "出口", nearest_exit_meters: meters)
      end
    end
  end

  # A trip in direction 0 of the given band with on-board counts by sequence.
  def trip(route_day, band, counts)
    start_time = Time.zone.parse("2026-10-19 07:00") + route_day.trips.count.minutes
    trip = route_day.trips.create!(bus_id: "TEST-0001", path_attribute_id: 9001, go_back: 0, band:, start_time:,
                                   end_time: start_time + 50.minutes, first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5,
                                   completeness: "complete", start_from_arrival: false, end_from_departure: false)
    counts.each { |seq, on_board| trip.trip_stop_counts.create!(seq:, on_board:) }
  end

  def render_chart(route_day)
    route_days = RouteDay.where(id: route_day.id)
    render_inline(described_class.new(load_profile: RoutePage::LoadProfile.new(route_days), mrt_overlap: RoutePage::MrtOverlap.new(route_days)))
  end

  def points(rendered, band) = rendered.css("[data-direction='0'] [data-band='#{band}'] [data-seq]").map { [ it["data-seq"], it["data-median"] ] }

  # Direction 0's rows for narrow screens in a band: sequence, median, how
  # many bars and the row's text.
  def rows(rendered, band)
    rendered.css("[data-direction='0'] [data-row-band='#{band}'] [data-row-seq]").map { [ it["data-row-seq"], it["data-row-median"], it.css("[data-row-bar]").size, it.text.squish ] }
  end

  # Direction 0's list of stretches below the chart: number, first and last
  # stop, and the entry's text.
  def legend(rendered)
    rendered.css("[data-direction='0'] [data-span-legend] li").map { [ it["data-span-number"], it["data-first-stop"], it["data-last-stop"], it.text.squish ] }
  end

  # Direction 0's numbered spans on the chart: number, first and last
  # sequence, the circle's centre and the middle of its shaded span, and the
  # circle's height and radius.
  def markers(rendered)
    rendered.css("[data-direction='0'] svg [data-span-number]").map do |span|
      rect, circle = span.at_css("rect"), span.at_css("circle[data-span-marker]")
      [ span["data-span-number"], span["data-span-from"], span["data-span-to"], circle["cx"].to_f, (rect["x"].to_f + (rect["width"].to_f / 2)).round(1), circle["cy"], circle["r"] ]
    end
  end

  let(:day) { route_day([ 900, 900, 400, 250, 450 ]).tap { trip(it, "morning_peak", 0 => 3, 1 => 8) }.tap { trip(it, "daytime", 0 => 5) } }

  it "每個時段一條線：早尖峰第 0、1 站是 3.0、8.0，日間只有第 0 站的 5.0" do
    rendered = render_chart(day)
    expect([ points(rendered, "morning_peak"), points(rendered, "daytime") ]).to eq([ [ %w[0 3.0], %w[1 8.0] ], [ %w[0 5.0] ] ])
  end

  it "沒有人數的站把線斷開：第 0、2 站有人數、第 1 站沒有時是兩段" do
    trip(day, "evening_peak", 0 => 4, 2 => 6)
    expect(render_chart(day).css("[data-direction='0'] [data-band='evening_peak'] [data-segment]").size).to eq(2)
  end

  it "同一個方向的時段共用縱軸，頂端是最大中位數 8.0 往上取到 10" do
    expect(render_chart(day).at_css("[data-direction='0']")["data-scale-top"]).to eq("10")
  end

  it "沒有任何人數的方向，縱軸頂端是 10" do
    expect(render_chart(route_day([ 900, 900, 900, 900, 900 ])).at_css("[data-direction='0']")["data-scale-top"]).to eq("10")
  end

  it "500 公尺內的第 2 到 4 站畫成一段底色帶，標出兩端站名" do
    span = render_chart(day).at_css("[data-direction='0'] [data-span-from]")
    expect([ span["data-span-from"], span["data-span-to"], span["data-first-stop"], span["data-last-stop"] ]).to eq(%w[2 4 丙站 戊站])
  end

  it "站牌沒有距離時，照樣畫線但沒有底色帶" do
    rendered = render_chart(route_day([ nil, nil, nil, nil, nil ]).tap { trip(it, "morning_peak", 0 => 3) })
    expect([ rendered.css("[data-span-from]").size, points(rendered, "morning_peak") ]).to eq([ 0, [ %w[0 3.0] ] ])
  end

  describe "重疊路段的編號" do
    let(:two_stretches) { render_chart(route_day([ 400, 450, 900, 250, 300 ])) }

    it "圖下方的清單照站序列出兩段：1 甲站–乙站、2 丁站–戊站" do
      expect(legend(two_stretches)).to match([ [ "1", "甲站", "乙站", end_with("甲站–乙站") ], [ "2", "丁站", "戊站", end_with("丁站–戊站") ] ])
    end

    it "站牌沒有距離時，圖下方沒有清單" do
      expect(render_chart(route_day([ nil, nil, nil, nil, nil ])).css("[data-span-legend]").size).to eq(0)
    end

    # 五站在 840 寬的圖上相隔 196，第 0 到 4 站的 x 是 40、236、432、628、824
    it "底色帶上方照站序畫編號 1、2，圓心在底色帶中點 138.0 與 726.0，y 是 18、半徑 8" do
      expect(markers(two_stretches)).to eq([ [ "1", "0", "1", 138.0, 138.0, "18", "8" ], [ "2", "3", "4", 726.0, 726.0, "18", "8" ] ])
    end

    it "底色帶上只寫編號，圖上沒有寫出路段名字的字" do
      svg = two_stretches.at_css("[data-direction='0'] svg")
      expect([ svg.css("[data-span-number]").map { it.text.squish }, svg.css("text").map(&:text).grep(/靠近捷運|乙站|丁站/) ]).to eq([ %w[1 2], [] ])
    end

    it "站牌沒有距離時，圖上沒有編號" do
      expect(render_chart(route_day([ nil, nil, nil, nil, nil ])).css("[data-span-number]").size).to eq(0)
    end
  end

  describe "窄螢幕的每站一列" do
    it "早尖峰第 0 站是 3.0、帶長條，第 1 站沒有人數，寫 —、沒有長條" do
      rendered = render_chart(route_day([ 900, 900 ]).tap { trip(it, "morning_peak", 0 => 3) })
      expect(rows(rendered, "morning_peak")).to match([ [ "0", "3.0", 1, end_with("3.0") ], [ "1", nil, 0, end_with("—") ] ])
    end

    it "長條的長度是中位數佔同一個方向刻度頂端的比例：頂端 10 時 3.0 是 30.0%、8.0 是 80.0%" do
      expect(render_chart(day).css("[data-direction='0'] [data-row-band='morning_peak'] [data-row-bar]").map { it["style"] }).to eq([ "width: 30.0%", "width: 80.0%" ])
    end

    it "500 公尺內第 2 到 4 站的列帶底色，第 2 站那一列前面一行寫出兩端站名" do
      group = render_chart(day).at_css("[data-direction='0'] [data-row-band='morning_peak']")
      span = group.at_css("[data-row-span]")
      expect([ group.css("[data-row-near]").map { it["data-row-seq"] }, span && [ span["data-first-stop"], span["data-last-stop"], span.next_element["data-row-seq"] ] ])
        .to eq([ %w[2 3 4], [ "丙站", "戊站", "2" ] ])
    end

    it "站牌沒有距離時，沒有帶底色的列，也沒有路段標題" do
      rendered = render_chart(route_day([ nil, nil, nil, nil, nil ]).tap { trip(it, "morning_peak", 0 => 3) })
      expect(rendered.css("[data-row-near], [data-row-span]").size).to eq(0)
    end

    it "預設顯示早尖峰的列，其他時段在 Alpine 接手前藏起來" do
      groups = render_chart(day).css("[data-direction='0'] [data-row-band]")
      expect(groups.to_h { [ it["data-row-band"], it.key?("x-cloak") ] }).to eq("morning_peak" => false, "daytime" => true, "evening_peak" => true, "other" => true)
    end
  end

  it "預設顯示早尖峰，其他時段在 Alpine 接手前藏起來" do
    groups = render_chart(day).css("[data-direction='0'] [data-band]")
    expect(groups.to_h { [ it["data-band"], it.key?("x-cloak") ] }).to eq("morning_peak" => false, "daytime" => true, "evening_peak" => true, "other" => true)
  end
end
