require "spec_helper"
require_relative "../support/duckdb"

RSpec.describe "analysis/gps_reports.sql" do
  def sql_file(name) = File.read(File.join(DuckdbHelpers::ANALYSIS_DIR, name))

  # Runs every stage on the fixture day, then `setup`, SQL that replaces
  # inputs, gps_reports.sql and `query`.
  def gps(query, setup: "")
    run_sql_stages(through: "50_quality", query: [ setup, sql_file("gps_reports.sql"), query ].join("\n"))
  end

  # The fixture README's section on vehicle GPS: TEST-0001 has 21 records in
  # its 06:50 window after the duplicate is dropped, 8 in its 08:30 window, 4
  # in its 11:30 window, and 5 during its 06:00 trip (06:30 at A and the four
  # moving ones from 06:10 to 06:11), all in the read window.
  it "留當天有趟次的車：TEST-0001 只剩 06:00 那一趟、沒有折返停留時，讀檔視窗裡它的 38 筆 GPS 都留著，沒有趟次的車一筆都不留" do
    rows = gps("SELECT bus_id, count(*) AS n FROM gps_reports GROUP BY bus_id",
               setup: replace_trips_sql([ { bus_id: "TEST-0001", start: "06:00", finish: "06:50" } ]))
    expect(rows).to eq([ { "bus_id" => "TEST-0001", "n" => 38 } ])
  end
end
