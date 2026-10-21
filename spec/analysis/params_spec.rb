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
    constants = %w[2 7 9 15 17 19 30 60 240]
    found = Dir[File.join(DuckdbHelpers::ANALYSIS_DIR, "[0-9]*.sql")].to_h { [ File.basename(it), literals_in(it) & constants ] }
    expect(found.reject { |_file, literals| literals.empty? }).to eq({})
  end
end
