require "spec_helper"
require_relative "../support/duckdb"

RSpec.describe "analysis/stop_districts.sql" do
  def fixture_snapshot = File.join(DuckdbHelpers::FIXTURE_DATA, "external/stop-districts/2026-10-19.csv")

  def file = File.read(File.join(DuckdbHelpers::ANALYSIS_DIR, "stop_districts.sql"))

  # Rows of `query` after every stage and stop_districts.sql with the snapshot
  # at `path`; `prelude` runs between the stages and the file, so a test can
  # override a constant of params.sql.
  def districts_query(query, path: fixture_snapshot, prelude: "", **variables)
    run_sql_stages(through: "50_quality", stop_districts_path: path, query: "#{prelude}\n#{file}\n#{query}", **variables)
  end

  def shares_query = "SELECT county, town, n_locations, n_total, share, qualifies FROM route_day_districts ORDER BY n_locations DESC"

  it "fixture 日每站帶行政區：9001 去程五站與返程前四站是臺北市測試區，返程末站甲站是新北市甲區" do
    rows = districts_query("SELECT district FROM stop_district_names WHERE route_id = 9001 ORDER BY go_back, seq")
    expect(rows.map { it["district"] }).to eq([ "臺北市測試區" ] * 9 + [ "新北市甲區" ])
  end

  it "route_day_districts：測試區 9／10 達門檻，甲區 1／10 剛好在一成的門檻上也達" do
    expect(districts_query(shares_query)).to eq(
      [ { "county" => "臺北市", "town" => "測試區", "n_locations" => 9, "n_total" => 10, "share" => 0.9, "qualifies" => true },
        { "county" => "新北市", "town" => "甲區", "n_locations" => 1, "n_total" => 10, "share" => 0.1, "qualifies" => true } ]
    )
  end

  it "門檻改成 20：甲區不達門檻，測試區照舊" do
    rows = districts_query("SELECT town, qualifies FROM route_day_districts ORDER BY n_locations DESC", prelude: "SET VARIABLE district_min_share_percent = 20;")
    expect(rows).to eq([ { "town" => "測試區", "qualifies" => true }, { "town" => "甲區", "qualifies" => false } ])
  end

  it "成員日：9050 的己站帶臺北市測試區、己站對面沒有行政區，占比只算 9001 的站位，仍是 9 與 1 對 10" do
    query = "SELECT (SELECT district FROM stop_district_names WHERE route_id = 9050 AND seq = 2) AS seq2, " \
            "(SELECT district FROM stop_district_names WHERE route_id = 9050 AND seq = 7) AS seq7, " \
            "(SELECT list(n_locations ORDER BY n_locations DESC) FROM route_day_districts) AS counts, (SELECT any_value(n_total) FROM route_day_districts) AS total"
    rows = districts_query(query, member_route_ids: [ 9001, 9050 ], day: Date.new(2026, 10, 23), static_day: Date.new(2026, 10, 23))
    expect(rows.first).to eq({ "seq2" => "臺北市測試區", "seq7" => nil, "counts" => [ 9, 1 ], "total" => 10 })
  end

  it "快照少了 81009：甲區沒有列，測試區仍是 9 對 10，分母算全部站位" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "snapshot.csv")
      File.write(path, File.readlines(fixture_snapshot).reject { it.start_with?("81009,") }.join)
      expect(districts_query(shares_query, path:)).to eq([ { "county" => "臺北市", "town" => "測試區", "n_locations" => 9, "n_total" => 10, "share" => 0.9, "qualifies" => true } ])
    end
  end
end
