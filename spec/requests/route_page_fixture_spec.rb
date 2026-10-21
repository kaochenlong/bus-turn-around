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
end
