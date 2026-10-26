require "spec_helper"
require_relative "../support/duckdb"

RSpec.describe "analysis/params.sql" do
  let(:values) do
    names = %w[split_gap_minutes lookback_hours overflow_hours short_layover_minutes rest_window_minutes
               rest_min_minutes rest_credit_minutes morning_peak_start_hour daytime_start_hour
               evening_peak_start_hour evening_peak_end_hour jump_threshold min_trip_stops]
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

  it "一段至少要觀測到 2 個不同的站才是一趟" do
    expect(values["min_trip_stops"]).to eq(2)
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

  it "time_band 照 7、9、17、19 時分四個時段，每段含起點的小時、不含終點的小時" do
    times = %w[06:59 07:00 08:59 09:00 16:59 17:00 18:59 19:00].each_with_index.map { |at, i| "time_band(TIMESTAMP '2026-10-19 #{at}:00') AS b#{i}" }
    bands = run_sql_stages(through: "params", query: "SELECT #{times.join(', ')}").first.values
    expect(bands).to eq(%w[other morning_peak morning_peak daytime daytime evening_peak evening_peak other])
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

  describe "兩端性質的判斷規則" do
    let(:names) { %w[nature_still_minutes nature_min_layovers nature_pass_through_max_share nature_stop_min_share] }

    # The two shares are DECIMALs, which DuckDB's JSON output writes as strings.
    it "最長靜止超過 2 分鐘算停下來過、有 GPS 的折返停留至少 20 筆、比例不超過 0.05 是直接折返、至少 0.5 是停車" do
      row = run_sql_stages(through: "params", query: "SELECT #{names.map { "getvariable('#{it}') AS #{it}" }.join(', ')}").first
      expect(row.values_at(*names).map(&:to_s)).to eq(%w[2 20 0.05 0.5])
    end

    it "end_nature_survey.sql 不出現這四個門檻的字面數字" do
      expect(literals_in(File.join(DuckdbHelpers::ANALYSIS_DIR, "end_nature_survey.sql")) & %w[2 20 0.05 0.5]).to eq([])
    end
  end

  describe "路線軌跡" do
    let(:names) { %w[route_shape_min_points route_shape_min_latitude route_shape_max_latitude route_shape_min_longitude route_shape_max_longitude] }

    it "一列至少 2 點，緯度在 20 到 27、經度在 118 到 123 之間" do
      row = run_sql_stages(through: "params", query: "SELECT #{names.map { "getvariable('#{it}') AS #{it}" }.join(', ')}").first
      expect(row.values_at(*names)).to eq([ 2, 20, 27, 118, 123 ])
    end

    it "route_shape.sql 不出現這三個門檻的字面數字" do
      expect(literals_in(File.join(DuckdbHelpers::ANALYSIS_DIR, "route_shape.sql")) & %w[2 20 27 118 123]).to eq([])
    end
  end

  describe "站間車速" do
    let(:names) { %w[shape_snap_meters stop_tie_meters stop_zone_meters pair_max_seconds pair_max_meters_per_second] }

    it "離路線軌跡 50 公尺內才對得上、對位差 15 公尺內算平手、站的前後 40 公尺不算、一組相隔 40 秒以內、每秒 25 公尺以下" do
      row = run_sql_stages(through: "params", query: "SELECT #{names.map { "getvariable('#{it}') AS #{it}" }.join(', ')}").first
      expect(row.values_at(*names)).to eq([ 50, 15, 40, 40, 25 ])
    end

    it "stop_speeds.sql 不出現這五個門檻的字面數字" do
      expect(literals_in(File.join(DuckdbHelpers::ANALYSIS_DIR, "stop_speeds.sql")) & %w[50 15 40 25]).to eq([])
    end
  end
end
