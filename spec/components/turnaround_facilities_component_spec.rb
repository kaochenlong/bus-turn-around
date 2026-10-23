# frozen_string_literal: true

require "rails_helper"

RSpec.describe TurnaroundFacilitiesComponent, type: :component do
  # Direction 0 trips end at a pass-through end and direction 1 trips at a stopping end.
  def route_ends = RoutePage::Ends.from_config({ 0 => "pass_through", 1 => "stop" }, route_id: 9001)

  def render_facilities = render_inline(described_class.new(facilities: RoutePage::Facilities.new(RouteDay.order(:day), ends: route_ends)))

  # The text of each named data-value inside each end's part, in direction order.
  def values(rendered, *names) = rendered.css("[data-end]").map { |part| names.map { part.at_css("[data-value=#{it}]")&.text&.squish } }

  def inbound_location = { latitude: 25.0497, longitude: 121.5006, n_layovers: 8, n_located_layovers: 1, n_standstill_records: 8, end_stop_meters: 45.0 }

  # A stored day: direction 0 anchored on its last stop 戊站, direction 1
  # located 45.0 metres from 甲站, or without a location when `located` is
  # false. Returns both ends.
  def store_day(day = "2026-10-19", located: true)
    route_day = create(:route_day, day: Date.iso8601(day), public_toilets_day: Date.iso8601(day))
    outbound = create(:route_day_end, route_day:, go_back: 0, location_source: "end_stop", latitude: 25.06, longitude: 121.5, n_located_layovers: nil, end_stop_meters: 0.0)
    inbound = create(:route_day_end, *(located ? [] : [ :unlocated ]), route_day:, go_back: 1, end_seq: 9, end_stop_name: "甲站", n_layovers: 8, **(located ? inbound_location : {}))
    [ outbound, inbound ]
  end

  # Stores the given toilets, each [name, category, address, metres], for one end.
  def toilets(route_day_end, *rows)
    rows.each { |name, category, address, meters| create(:route_day_end_toilet, route_day_end:, name:, category:, address:, meters:) }
  end

  # A day whose direction 0 has three toilets at two addresses and direction 1 two toilets at two addresses.
  def store_day_with_toilets
    outbound, inbound = store_day
    toilets(outbound, [ "戊站公園-女廁", "公園", "臺北市測試區戊路2號", 130.0 ], [ "戊站公園-男廁", "公園", "臺北市測試區戊路2號", 120.0 ],
            [ "戊站加油站-混合廁所", "商業營業場所", "臺北市測試區戊路1號", 400.0 ])
    toilets(inbound, [ "甲站機關-無障礙廁所", "民眾洽公場所", "臺北市測試區甲路1號", 120.1 ], [ "甲站對面-男廁", "交通", "臺北市測試區甲路2號", 134.4 ])
  end

  describe "兩端都有位置的一天" do
    let(:rendered) { store_day_with_toilets.then { render_facilities } }

    it "每一端一段，依方向排，標出性質與位置怎麼來的" do
      parts = rendered.css("[data-end]").map { [ it["data-end"], it["data-end-nature"], it.at_css("[data-location-source]")&.[]("data-location-source") ] }
      expect(parts).to eq([ %w[0 pass_through end_stop], %w[1 stop standstill] ])
    end

    it "停車那一端帶三個查核數字：8 筆折返停留、1 筆在位置附近、離末站 45.0 公尺；開過去就走那一端沒有" do
      expect(values(rendered, "layovers", "located-layovers", "end-stop-meters")).to eq([ [ nil, nil, nil ], %w[8 1 45.0] ])
    end

    it "各自 300 與 500 公尺內的處數：同地址的兩間算一處" do
      expect(values(rendered, "toilets-300", "toilets-500")).to eq([ %w[1 2], %w[2 2] ])
    end

    it "最近一處報最近那一間的名稱、類別、公尺與這一處有幾間" do
      expect(values(rendered, "nearest-name", "nearest-category", "nearest-meters", "nearest-rooms")).to eq(
        [ %w[戊站公園-男廁 公園 120.0 2], %w[甲站機關-無障礙廁所 民眾洽公場所 120.1 1] ]
      )
    end

    it "500 公尺內每一處一列，收在預設關閉的清單裡：名稱、類別、地址、公尺、間數" do
      list = rendered.at_css("[data-end='0'] details[data-toilet-list]")
      expect([ list.key?("open"), list.css("tr[data-place]").map { |row| row.css("td").map { it.text.squish } } ]).to eq(
        [ false, [ %w[戊站公園-男廁 公園 臺北市測試區戊路2號 120.0 2], %w[戊站加油站-混合廁所 商業營業場所 臺北市測試區戊路1號 400.0 1] ] ]
      )
    end

    it "每一端標出用的是哪一天的位置與那一天的公廁快照" do
      days = rendered.css("[data-end]").map { [ it.at_css("[data-located-day]")["data-located-day"], it.at_css("[data-public-toilets-day]")["data-public-toilets-day"] ] }
      expect(days).to eq([ %w[2026-10-19 2026-10-19], %w[2026-10-19 2026-10-19] ])
    end

    it "不出現判定夠不夠的字樣" do
      expect(%w[達標 不足 夠不夠 合格].select { rendered.text.include?(it) }).to eq([])
    end
  end

  it "停車那一端量不到位置時，說量不到、報最近一天 8 筆折返停留，不列公廁" do
    store_day(located: false)
    part = render_facilities.at_css("[data-end='1']")
    expect([ part.css("[data-no-location]").size, part.at_css("[data-no-location] [data-value=layovers]")&.text, part.css("[data-toilet-list], [data-value=toilets-300]").size ]).to eq([ 1, "8", 0 ])
  end

  describe "涵蓋 10-19 與 10-20，方向 1 只有 10-19 有位置時" do
    let(:rendered) { store_day("2026-10-19").then { store_day("2026-10-20", located: false) }.then { render_facilities } }

    it "方向 1 用 10-19 的位置，並說有 1 天量不到" do
      part = rendered.at_css("[data-end='1']")
      expect([ part.at_css("[data-located-day]")["data-located-day"], part.at_css("[data-value=days-without-location]")&.text ]).to eq([ "2026-10-19", "1" ])
    end

    it "兩天都有位置的方向 0 不提量不到的天數" do
      expect(rendered.css("[data-end='0'] [data-value=days-without-location]").size).to eq(0)
    end
  end

  it "500 公尺內沒有任何公廁的一端說建檔資料裡沒有，不列清單" do
    store_day
    rendered = render_facilities
    expect([ rendered.css("[data-no-places]").size, rendered.css("details[data-toilet-list]").size ]).to eq([ 2, 0 ])
  end

  it "涵蓋的日子都沒有兩端的列時說要重新載入，不顯示任何一端" do
    create(:route_day)
    rendered = render_facilities
    expect([ rendered.css("[data-needs-reload]").size, rendered.css("[data-end]").size ]).to eq([ 1, 0 ])
  end
end
