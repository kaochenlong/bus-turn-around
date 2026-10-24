require "spec_helper"
require_relative "../support/duckdb"
require_relative "../../lib/analysis_run"

RSpec.describe AnalysisRun do
  # An analysis directory with params.sql, two numbered stages written out of
  # order, a file that is not a numbered stage, and a file a caller appends.
  def with_analysis_dir(files)
    Dir.mktmpdir("analysis-run") do |dir|
      files.each { |name, text| File.write(File.join(dir, name), text) }
      yield dir
    end
  end

  let(:files) do
    { "params.sql" => "-- params\n", "20_b.sql" => "-- 20\n", "10_a.sql" => "-- 10\n",
      "notes.sql" => "-- notes\n", "extra.sql" => "-- extra\n" }
  end

  describe ".sql" do
    it "依序是變數、params.sql、依檔名排序的編號階段檔、呼叫端指定的檔；不是編號的檔不放" do
      sql = with_analysis_dir(files) { |dir| described_class.sql({ route_id: 9001 }, analysis_dir: dir, extra_files: [ "extra.sql" ]) }
      expect(sql).to eq("SET VARIABLE route_id = 9001;\n-- params\n\n-- 10\n\n-- 20\n\n-- extra\n")
    end

    it "日期寫成 DATE，字串跳脫單引號" do
      sql = with_analysis_dir("params.sql" => "") { |dir| described_class.sql({ day: Date.new(2026, 10, 19), data_root: "a'b" }, analysis_dir: dir) }
      expect(sql.lines.first(2)).to eq([ "SET VARIABLE day = DATE '2026-10-19';\n", "SET VARIABLE data_root = 'a''b';\n" ])
    end

    it "整數陣列寫成 DuckDB 的清單：一頁的路線 Id" do
      sql = with_analysis_dir("params.sql" => "") { |dir| described_class.sql({ member_route_ids: [ 16111, 19108 ] }, analysis_dir: dir) }
      expect(sql.lines.first).to eq("SET VARIABLE member_route_ids = [16111, 19108];\n")
    end
  end

  describe ".run" do
    it "回傳 DuckDB 印出的那一列結果" do
      rows = with_analysis_dir("params.sql" => "SELECT getvariable('n') + 1 AS x;") { |dir| described_class.run("duckdb", { n: 1 }, analysis_dir: dir) }
      expect(rows).to eq([ { "x" => 2 } ])
    end

    it "DuckDB 失敗時丟出 AnalysisRun::Error，訊息是它原樣的標準錯誤" do
      run = -> { with_analysis_dir("params.sql" => "SELECT * FROM no_such_table;") { |dir| described_class.run("duckdb", {}, analysis_dir: dir) } }
      expect(&run).to raise_error(described_class::Error, /no_such_table/)
    end
  end

  describe ".find_duckdb" do
    it "PATH 裡沒有 duckdb 時回傳 nil" do
      expect(described_class.find_duckdb(path_without_duckdb)).to be_nil
    end
  end
end
