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

  it "用 DuckDB 讀回 CSV 檔，每一格都是字串" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "t.csv"), "bus_id,n\nTEST-0001,3\n")
      expect(read_csv_rows(File.join(dir, "t.csv"))).to eq([ { "bus_id" => "TEST-0001", "n" => "3" } ])
    end
  end
end
