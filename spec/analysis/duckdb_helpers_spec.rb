require "spec_helper"
require_relative "../support/duckdb"

RSpec.describe DuckdbHelpers do
  it "把 SQL 交給 DuckDB CLI，讀回查詢結果的每一列" do
    expect(duckdb_rows("SELECT 1 AS one, 'a' AS letter")).to eq([ { "one" => 1, "letter" => "a" } ])
  end

  it "查詢沒有結果時讀回空陣列" do
    expect(duckdb_rows("SELECT 1 AS one WHERE false")).to eq([])
  end

  it "SQL 出錯時丟出帶有 DuckDB 錯誤訊息的例外" do
    expect { duckdb_rows("SELECT * FROM no_such_table") }.to raise_error(RuntimeError, /no_such_table/)
  end

  it "換掉 other_route_events 時，空陣列給出空表，欄位跟第 10 階段建的一樣" do
    columns = "SELECT list(column_name || ' ' || data_type ORDER BY column_index) AS columns, (SELECT count(*) FROM other_route_events) AS n " \
              "FROM duckdb_columns() WHERE table_name = 'other_route_events'"
    stage, replaced = [ "", replace_other_route_events_sql([]) ].map { run_sql_stages(through: "10_load", query: "#{it}\n#{columns}").first }
    expect(replaced).to eq(stage.merge("n" => 0))
  end

  it "換掉 other_route_events 的每筆是車牌、時刻與站牌，路線預設 9100" do
    sql = replace_other_route_events_sql([ [ "TEST-0001", "08:40", 92000 ], [ "TEST-0002", "2026-10-20 00:10:30", 92001, 9200 ] ])
    rows = duckdb_rows("#{sql}\nSELECT bus_id, path_attribute_id, stop_id, strftime(data_time, '%Y-%m-%d %H:%M:%S') AS at FROM other_route_events ORDER BY bus_id")
    expect(rows.map(&:values)).to eq([ [ "TEST-0001", 9100, 92000, "2026-10-19 08:40:00" ], [ "TEST-0002", 9200, 92001, "2026-10-20 00:10:30" ] ])
  end

  it "用 DuckDB 讀回 CSV 檔，每一格都是字串" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "t.csv"), "bus_id,n\nTEST-0001,3\n")
      expect(read_csv_rows(File.join(dir, "t.csv"))).to eq([ { "bus_id" => "TEST-0001", "n" => "3" } ])
    end
  end
end
