require "spec_helper"
require "fileutils"
require_relative "../support/duckdb"
require_relative "../../lib/analysis_run"

RSpec.describe "analysis/end_nature_export.sql" do
  # The files the survey runs after the stages for a route day.
  def survey_files = %w[mrt_overlap.sql gps_reports.sql turnaround_facilities.sql end_nature_evidence.sql end_nature_export.sql]

  def fixture_path(path) = File.join(DuckdbHelpers::FIXTURE_DATA, path)

  def files_in(dir) = Dir.children(dir).sort.to_h { [ it, File.binread(File.join(dir, it)) ] }

  # Runs every stage and then `extra_files` on the fixture day with 9050
  # counted with 9001 and both ends unknown, the variables the survey gives a
  # route day, and returns the files written to survey_dir and to inspect_dir,
  # each as { name => bytes }.
  def run_files(extra_files: survey_files)
    Dir.mktmpdir("end-nature-export") do |dir|
      inspect_dir, survey_dir = %w[inspect survey].map { File.join(dir, it).tap { FileUtils.mkdir_p(it) } }
      variables = DuckdbHelpers::FIXTURE_VARIABLES.merge(
        member_route_ids: [ 9001, 9050 ], inspect_dir:, derived_dir: inspect_dir, survey_dir:,
        mrt_exits_path: fixture_path("external/taipei-mrt-exits/2026-10-19.csv"), mrt_exits_day: Date.new(2026, 10, 19),
        public_toilets_path: fixture_path("external/public-toilets/2026-10-19.csv"), public_toilets_day: Date.new(2026, 10, 19),
        end_nature_0: "unknown", end_nature_1: "unknown"
      )
      AnalysisRun.run("duckdb", variables, extra_files:)
      { survey: files_in(survey_dir), inspect: files_in(inspect_dir) }
    end
  end

  let(:survey) { run_files.fetch(:survey) }

  def lines(name) = survey.fetch(name).dup.force_encoding(Encoding::UTF_8).lines.map(&:chomp)

  it "survey_dir 只寫 layovers.csv 與 ends.csv，表頭照 design 的欄位順序" do
    expect(survey.keys.to_h { [ it, lines(it).first ] }).to eq(
      "ends.csv" => "route_id,route_ids,day,go_back,route_name,end_stop_name,n_pairs,n_layovers,n_no_last_stop,n_no_first_stop,n_other_route,n_negative",
      "layovers.csv" => "route_id,day,go_back,bus_id,end_time,next_start_time,minutes,next_route_id,next_go_back,stop_gap_meters," \
                        "n_reports,longest_still_minutes,farthest_meters"
    )
  end

  it "layovers.csv 有 18 列，方向 0 有 10 列、方向 1 有 8 列" do
    expect(lines("layovers.csv").drop(1).map { it.split(",")[2] }.tally).to eq("0" => 10, "1" => 8)
  end

  it "layovers.csv 依方向、本趟終點、車牌排序，時刻寫台北時間不帶時差，沒有回報的最長靜止與最遠離站是空的" do
    expect(lines("layovers.csv").values_at(1, 4)).to eq(
      [ "9001,2026-10-19,0,TEST-0001,2026-10-19 06:50:00,2026-10-19 07:00:00,10.0,9001,1,30.2,21,2.0,64.5",
        "9001,2026-10-19,0,TEST-0003,2026-10-19 08:56:00,2026-10-19 09:10:00,14.0,9001,1,30.2,0,," ]
    )
  end

  it "ends.csv 每個方向一列：這次的路線 Id 用「・」接，路線名稱是測試幹線，末站是戊站與甲站" do
    expect(lines("ends.csv").drop(1)).to eq(
      [ "9001,9001・9050,2026-10-19,0,測試幹線,戊站,12,10,1,1,0,0", "9001,9001・9050,2026-10-19,1,測試幹線,甲站,11,8,2,0,1,0" ]
    )
  end

  it "同一份輸入跑兩次，兩個檔的位元組相同" do
    expect(run_files.fetch(:survey)).to eq(survey)
  end

  it "健檢卡的檢查用 CSV 跟只跑編號階段時相同：證據不寫進 inspect_dir" do
    expect(run_files.fetch(:inspect)).to eq(run_files(extra_files: []).fetch(:inspect))
  end
end
