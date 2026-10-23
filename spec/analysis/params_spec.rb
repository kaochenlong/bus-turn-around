require "spec_helper"
require_relative "../support/duckdb"

RSpec.describe "analysis/params.sql" do
  let(:values) do
    names = %w[split_gap_minutes lookback_hours overflow_hours short_layover_minutes rest_window_minutes
               rest_min_minutes rest_credit_minutes morning_peak_start_hour daytime_start_hour
               evening_peak_start_hour evening_peak_end_hour jump_threshold]
    run_sql_stages(through: "params", query: "SELECT #{names.map { "getvariable('#{it}') AS #{it}" }.join(', ')}").first
  end

  # Numeric literals left in a stage file once comments and quoted strings are removed.
  def literals_in(path)
    code = File.read(path).gsub(/--[^\n]*/, "").gsub(/'(?:[^']|'')*'/, "''")
    code.scan(/(?<![\w.])\d+(?:\.\d+)?(?![\w.])/)
  end

  it "往前回看的時數由 60 分鐘的中斷門檻算出，是 2 小時" do
    expect(values.values_at("split_gap_minutes", "lookback_hours")).to eq([ 60, 2 ])
  end

  it "往後讀兩小時，折返停留不到 15 分鐘算短" do
    expect(values.values_at("overflow_hours", "short_layover_minutes")).to eq([ 2, 15 ])
  end

  it "四小時視窗 240 分鐘、每段至少 15 分鐘、累計 30 分鐘" do
    expect(values.values_at("rest_window_minutes", "rest_min_minutes", "rest_credit_minutes")).to eq([ 240, 15, 30 ])
  end

  it "時段邊界是 7、9、17、19 時，跳動門檻 30 人" do
    expect(values.values_at(*%w[morning_peak_start_hour daytime_start_hour evening_peak_start_hour
                                evening_peak_end_hour jump_threshold])).to eq([ 7, 9, 17, 19, 30 ])
  end

  it "其他 SQL 檔不出現這些常數的字面數字" do
    constants = %w[2 3 7 9 15 17 19 30 60 240]
    found = Dir[File.join(DuckdbHelpers::ANALYSIS_DIR, "[0-9]*.sql")].to_h { [ File.basename(it), literals_in(it) & constants ] }
    expect(found.reject { |_file, literals| literals.empty? }).to eq({})
  end

  describe "折返點設施" do
    let(:names) { %w[standstill_radius_meters located_radius_meters toilet_radius_meters standstill_cell_degrees cell_min_buses] }

    # The cell size is a DECIMAL, which DuckDB's JSON output writes as a string.
    it "靜止點聚在 50 公尺內、查核用 150 公尺、公廁存 500 公尺內、靜止格 0.0002 度、一格至少 3 台車" do
      row = run_sql_stages(through: "params", query: "SELECT #{names.map { "getvariable('#{it}') AS #{it}" }.join(', ')}").first
      expect(row.values_at(*names).map(&:to_s)).to eq(%w[50 150 500 0.0002 3])
    end

    it "turnaround_facilities.sql 不出現這五個常數的字面數字" do
      expect(literals_in(File.join(DuckdbHelpers::ANALYSIS_DIR, "turnaround_facilities.sql")) & %w[50 150 500 0.0002 3]).to eq([])
    end
  end
end
