require "rails_helper"
require_relative "../support/duckdb"

# The route page over the fixture day written by the real loader: the numbers
# come from the whole pipeline, and Bullet watches every query of the page.
RSpec.describe "路線頁（fixture 寫入後）", :duckdb, type: :request do
  before do
    RouteDayLoader.new(route_id: 9001, day: Date.new(2026, 10, 19), data_root: DuckdbHelpers::FIXTURE_DATA, duckdb: "duckdb").call
    get route_path(9001), params: { day: "2026-10-19" }
  end

  it "頁面上沒有任何車牌" do
    expect(%w[TEST-0001 TEST-0002 TEST-0003 TEST-0004].select { response.body.include?(it) }).to eq([])
  end

  it "捷運重疊標出用的出入口快照日 2026-10-19" do
    expect(response.parsed_body.at_css("[data-mrt-exits-day]")["data-mrt-exits-day"]).to eq("2026-10-19")
  end

  it "摘要是 27 趟、完整 22 趟" do
    expect(%w[trips complete-trips].map { response.parsed_body.at_css("[data-#{it}]")["data-#{it}"] }).to eq(%w[27 22])
  end

  def facilities_part(go_back) = response.parsed_body.at_css("[data-section=facilities] [data-end='#{go_back}']")

  it "折返點設施兩端的位置日子與公廁快照日都是 2026-10-19" do
    days = [ 0, 1 ].map { |go_back| %w[located-day public-toilets-day].map { facilities_part(go_back)&.at_css("[data-#{it}]")&.[]("data-#{it}") } }
    expect(days).to eq([ %w[2026-10-19 2026-10-19], %w[2026-10-19 2026-10-19] ])
  end

  it "戊站端 300 公尺內 1 處、500 公尺內 2 處，最近一處是戊站公園併成的 2 間" do
    expect(%w[toilets-300 toilets-500 nearest-rooms].map { facilities_part(0)&.at_css("[data-value=#{it}]")&.text }).to eq(%w[1 2 2])
  end

  def map_data(go_back) = JSON.parse(response.parsed_body.at_css("[data-end-map][data-end='#{go_back}'] script[data-end-map-data]").text)

  it "戊站端的地圖資料：一格 25.0604, 121.5002、25 筆、第 4 級，涵蓋約 0.862，兩處公廁" do
    data = map_data(0)
    expect([ data["cells"].map { it.values_at("lat", "lon", "records", "level") }, data["coverage"]["share"].round(3), data["places"].map { it.values_at("name", "toilets") } ])
      .to eq([ [ [ 25.0604, 121.5002, 25, 4 ] ], 0.862, [ [ "戊站公園-男廁", 2 ], [ "戊站加油站-混合廁所", 1 ] ] ])
  end

  it "甲站端的地圖資料沒有格子，涵蓋比例是 0" do
    data = map_data(1)
    expect([ data["cells"], data["coverage"]["share"] ]).to eq([ [], 0.0 ])
  end

  it "來回與週期全天那一列：來回一趟 7 筆、週期 5 筆" do
    counts = %w[round_trip cycle].map { response.parsed_body.at_css("[data-section=cycles] [data-measure=#{it}] tr[data-total]")&.css("td")&.[](1)&.text&.squish }
    expect(counts).to eq(%w[7 5])
  end
end
