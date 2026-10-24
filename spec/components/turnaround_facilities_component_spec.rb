# frozen_string_literal: true

require "rails_helper"

RSpec.describe TurnaroundFacilitiesComponent, type: :component do
  # Direction 0 trips end at a pass-through end and direction 1 trips at a stopping end.
  def route_ends = RoutePage::Ends.from_config({ 0 => "pass_through", 1 => "stop" }, route_id: 9001)

  def render_facilities
    route_days = RouteDay.order(:day)
    render_inline(described_class.new(facilities: RoutePage::Facilities.new(route_days, ends: route_ends), depots: RoutePage::Depots.new(route_days)))
  end

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

  describe "車輛所屬調度站" do
    # The day's depots of 測試客運, the test configuration's three cases: 測試站
    # with scores, 測試二站 not in the appendix and 測試三站 not checked.
    def store_depots
      route_day = store_day.first.route_day
      [ [ 19001, "測試站", 4, 7 ], [ 19002, "測試二站", 2, 3 ], [ 19003, "測試三站", 1, 2 ] ].each do |station_id, station_name, n_buses, n_trips|
        create(:route_day_depot, route_day:, station_id:, station_name:, n_buses:, n_trips:)
      end
    end

    let(:rendered) { store_depots.then { render_facilities } }

    def depot(status) = rendered.at_css("[data-depots] [data-depot-status=#{status}]")

    it "在兩端之後，車數多的在前：有分數、不在名單、還沒對" do
      expect(rendered.css("[data-depots] [data-depot]").map { it["data-depot-status"] }).to eq(%w[scored not_in_appendix unchecked])
    end

    it "有分數的那一站寫名稱、車數與趟次" do
      expect(depot(:scored).at_css("[data-depot-name]").text.squish).to eq("測試客運 測試站・4 輛・7 趟")
    end

    it "九項各一個分數，兩欄相同寫一次、不同寫「a／b」" do
      scores = depot(:scored).css("[data-score]").to_h { [ it["data-score"], it.text.strip ] }
      expect([ scores.size, scores.values_at("調度室環境", "休憩室空間及環境", "盥洗室環境", "總分") ]).to eq([ 9, %w[8／9 7 5／4 98／97] ])
    end

    it "有分數的那一站寫檢查日期、附錄頁碼，連到報告書的公告頁" do
      part = depot(:scored)
      expect([ part.at_css("[data-value=inspected-on]").text, part.at_css("[data-value=printed-page]").text, part.at_css("a")["href"] ])
        .to eq([ "12月2日", "A-99", RoutePage::DepotInspections.current.page_url ])
    end

    it "不在名單的那一站寫明不在 115 年第 1 期的名單，沒有分數" do
      part = depot(:not_in_appendix)
      expect([ part.at_css("[data-not-in-appendix]").text.include?("115 年第 1 期"), part.css("[data-score]").size ]).to eq([ true, 0 ])
    end

    it "還沒對的那一站沒有分數" do
      expect(depot(:unchecked).css("[data-score]").size).to eq(0)
    end

    it "寫明車數與趟次是哪一天的" do
      expect(rendered.at_css("[data-depots] [data-depots-day]")["data-depots-day"]).to eq("2026-10-19")
    end

    it "不出現判定好壞的字樣" do
      expect(%w[達標 不足 合格 優良 不佳 良好].select { rendered.at_css("[data-depots]").text.include?(it) }).to eq([])
    end
  end

  it "調度站的名稱是空的：寫營業站 Id 與 StationID" do
    create(:route_day_depot, route_day: store_day.first.route_day, station_id: 19005, provider_name: "", station_name: "")
    expect(render_facilities.at_css("[data-depot] [data-depot-name]").text.squish).to start_with("營業站 Id 19005・")
  end

  it "涵蓋的日子有兩端與公廁、沒有調度站的列：兩端照常，調度站那一段只有一句要重新載入" do
    store_day_with_toilets
    rendered = render_facilities
    expect([ rendered.css("[data-end]").size, rendered.css("[data-depots] [data-depots-needs-reload]").size, rendered.css("[data-depot]").size ]).to eq([ 2, 1, 0 ])
  end
end
