require "spec_helper"
require "csv"
require "fileutils"
require_relative "../support/duckdb"
require_relative "../../lib/analysis_run"

RSpec.describe "analysis/end_nature_survey.sql" do
  def layovers_header = %w[route_id day go_back bus_id end_time next_start_time minutes next_route_id next_go_back stop_gap_meters
                           n_reports longest_still_minutes farthest_meters]

  def ends_header = %w[route_id route_ids day go_back route_name end_stop_name n_pairs n_layovers n_no_last_stop n_no_first_stop
                       n_other_route n_negative]

  # What a layover holds when an example does not say: route 9001, direction
  # 0 on 2026-10-19, with GPS reports and a longest standstill of 1.5 minutes.
  def layover_defaults = { route_id: 9001, day: "2026-10-19", go_back: 0, minutes: 10.0, stop_gap_meters: 30.2, n_reports: 5,
                           longest_still_minutes: 1.5, farthest_meters: 40.0 }

  # `count` layovers of one end; a column given as an array gives each
  # layover its own value.
  def layovers(count, **columns) = Array.new(count) { |i| columns.transform_values { it.is_a?(Array) ? it.fetch(i) : it } }

  def with_gps(stills, **columns) = layovers(stills.size, longest_still_minutes: stills, **columns)

  def without_gps(count, **columns) = layovers(count, n_reports: 0, longest_still_minutes: nil, farthest_meters: nil, **columns)

  # One ends.csv row per route, day and direction of `rows`, counting their layovers as pairs.
  def ends_of(rows)
    rows.map { layover_defaults.merge(it) }.group_by { it.values_at(:route_id, :day, :go_back) }.map do |(route_id, day, go_back), group|
      { route_id:, route_ids: route_id.to_s, day:, go_back:, route_name: "測試幹線", end_stop_name: "戊站", n_pairs: group.size, n_layovers: group.size }
    end
  end

  # A row of `header` from a hash. The report does not read the vehicle, the
  # times or the next trip, and a pair count left out is 0.
  def csv_row(header, values)
    filler = { bus_id: "TEST-0001", end_time: "#{values[:day]} 06:00:00", next_start_time: "#{values[:day]} 06:10:00",
               next_route_id: values[:route_id], next_go_back: 1 - values[:go_back].to_i }
    header.map { values.fetch(it.to_sym) { filler.fetch(it.to_sym, 0) } }
  end

  # Writes the evidence of `rows` and `ends` as the route days of a survey
  # hold it and configured.csv from `configured`, each [route_id, go_back,
  # nature]; runs end_nature_survey.sql the way the survey task does and
  # returns the report as a CSV::Table, every value a string and an empty one nil.
  def report_table(rows, ends: ends_of(rows), configured: [])
    Dir.mktmpdir("end-nature-survey") do |dir|
      layovers_files, ends_files = write_route_days(dir, rows.map { layover_defaults.merge(it) }, ends)
      variables = { layovers_files:, ends_files:, report_path: File.join(dir, "report.csv"),
                    configured_path: write_csv(File.join(dir, "configured.csv"), %w[route_id go_back nature], configured) }
      AnalysisRun.run("duckdb", variables, extra_files: [ "end_nature_survey.sql" ], stages: false)
      CSV.read(variables[:report_path], headers: true)
    end
  end

  def report(...) = report_table(...).map(&:to_h)

  # One folder per route day of `rows` and `ends`, <dir>/<day>/<route_id>/,
  # holding its layovers.csv and ends.csv as end_nature_export.sql writes
  # them, only the header when there are no rows. Returns the paths of each.
  def write_route_days(dir, rows, ends)
    (rows + ends).map { it.values_at(:day, :route_id) }.uniq.map do |key|
      folder = File.join(dir, key.first, key.last.to_s).tap { FileUtils.mkdir_p(it) }
      [ [ "layovers.csv", layovers_header, rows ], [ "ends.csv", ends_header, ends ] ].map do |name, header, list|
        write_csv(File.join(folder, name), header, list.select { it.values_at(:day, :route_id) == key }.map { csv_row(header, it) })
      end
    end.transpose
  end

  def write_csv(path, header, rows) = path.tap { File.write(it, CSV.generate { |csv| [ header, *rows ].each { csv << it } }) }

  it "報告的欄位照規格 Survey report 的順序" do
    expect(report_table(with_gps([ 1.5 ])).headers).to eq(
      %w[route_id route_ids route_name go_back end_stop_name n_days n_pairs n_layovers n_other_route n_with_gps n_stood_still
         layover_p10 layover_p50 layover_p90 stop_gap_p50 still_p50 still_max stood_still_share farthest_p50 farthest_p90
         farthest_max nature reason configured_nature agrees]
    )
  end

  describe "Shares against the thresholds：有 GPS 的折返停留合起來判斷" do
    {
      "20 筆都是 1.5" => [ [ 1.5 ] * 20, "0.000", "pass_through", nil ],
      "20 筆都剛好 2.0" => [ [ 2.0 ] * 20, "0.000", "pass_through", nil ],
      "一筆 3.0、其餘 1.5" => [ [ 3.0 ] + ([ 1.5 ] * 19), "0.050", "pass_through", nil ],
      "兩筆 3.0、其餘 1.5" => [ ([ 3.0 ] * 2) + ([ 1.5 ] * 18), "0.100", "undetermined", "between" ],
      "十筆 3.0、其餘 1.5" => [ ([ 3.0 ] * 10) + ([ 1.5 ] * 10), "0.500", "stop", nil ],
      "19 筆都是 30.0" => [ [ 30.0 ] * 19, "1.000", "undetermined", "few_layovers" ]
    }.each do |situation, (stills, share, nature, reason)|
      it "#{stills.size} 筆有 GPS、#{situation}：比例 #{share}，判斷 #{nature}，理由 #{reason.inspect}" do
        row = report(with_gps(stills)).first
        expect(row.values_at("n_with_gps", "stood_still_share", "nature", "reason")).to eq([ stills.size.to_s, share, nature, reason ])
      end
    end
  end

  it "Days pooled：兩天各 10 筆有 GPS、最長靜止都是 30.0，合起來 20 筆、比例 1.000，判斷 stop" do
    row = report(with_gps([ 30.0 ] * 10) + with_gps([ 30.0 ] * 10, day: "2026-10-20")).first
    expect(row.values_at("n_days", "n_with_gps", "stood_still_share", "nature", "reason")).to eq([ "2", "20", "1.000", "stop", nil ])
  end

  it "Layovers without reports left out：25 筆裡 19 筆有 GPS（都是 30.0），沒有回報的 6 筆不算，判斷 undetermined（few_layovers）" do
    row = report(with_gps([ 30.0 ] * 19) + without_gps(6)).first
    expect(row.values_at("n_layovers", "n_with_gps", "n_stood_still", "nature", "reason")).to eq(%w[25 19 19 undetermined few_layovers])
  end

  it "百分位數在順序統計量之間線性內插：1、2、3、4 分鐘的 p10、p50、p90 是 1.3、2.5、3.7" do
    row = report(layovers(4, minutes: [ 1.0, 2.0, 3.0, 4.0 ])).first
    expect(row.values_at("layover_p10", "layover_p50", "layover_p90")).to eq(%w[1.3 2.5 3.7])
  end

  it "兩站距離的中位數、最長靜止的中位數與最大值、最遠離站的 p50、p90 與最大值，都取一位小數" do
    meters = [ 10.0, 20.0, 30.0, 40.0 ]
    row = report(layovers(4, stop_gap_meters: meters, longest_still_minutes: [ 1.0, 2.0, 3.0, 6.0 ], farthest_meters: meters)).first
    expect(row.values_at("stop_gap_p50", "still_p50", "still_max", "farthest_p50", "farthest_p90", "farthest_max")).to eq(%w[25.0 2.5 6.0 25.0 37.0 40.0])
  end

  it "一端沒有任何 GPS 回報：比例、最長靜止與最遠離站都是空的，判斷 undetermined（few_layovers）" do
    row = report(without_gps(3)).first
    expect(row.values_at("n_with_gps", "stood_still_share", "still_p50", "still_max", "farthest_p50", "farthest_p90", "farthest_max", "nature", "reason"))
      .to eq([ "0", nil, nil, nil, nil, nil, nil, "undetermined", "few_layovers" ])
  end

  describe "跟設定比對，一端一列、依路線 Id 與方向排序" do
    let(:rows) do
      evidence = with_gps([ 30.0 ] * 20, route_id: 9200) + with_gps([ 30.0 ] * 20) + with_gps([ 30.0 ] * 5, go_back: 1) + with_gps([ 30.0 ] * 20, route_id: 9100)
      report(evidence, configured: [ [ 9001, 0, "stop" ], [ 9001, 1, "stop" ], [ 9100, 0, "pass_through" ] ])
    end

    def columns(route_id, go_back) = rows.find { it.values_at("route_id", "go_back") == [ route_id.to_s, go_back.to_s ] }.values_at("nature", "configured_nature", "agrees")

    it "列的順序是 9001 去程、9001 返程、9100、9200" do
      expect(rows.map { it.values_at("route_id", "go_back") }).to eq([ %w[9001 0], %w[9001 1], %w[9100 0], %w[9200 0] ])
    end

    it "判斷與設定相同：agrees 是 true" do
      expect(columns(9001, 0)).to eq(%w[stop stop true])
    end

    it "判斷是待查證、設定是停車：agrees 是 false" do
      expect(columns(9001, 1)).to eq(%w[undetermined stop false])
    end

    it "判斷是停車、設定是直接折返：agrees 是 false" do
      expect(columns(9100, 0)).to eq(%w[stop pass_through false])
    end

    it "沒有設定的路線：設定的性質與 agrees 都是空的" do
      expect(columns(9200, 0)).to eq([ "stop", nil, nil ])
    end
  end

  describe "兩天的端點" do
    # Direction 0 has 3 layovers on 2026-10-19 and none on 10-20; direction 1
    # has none at all. The route was renamed on 10-20.
    let(:ends) do
      [ { route_id: 9001, route_ids: "9001", day: "2026-10-19", go_back: 0, route_name: "舊名", end_stop_name: "舊站", n_pairs: 4, n_layovers: 3, n_other_route: 1 },
        { route_id: 9001, route_ids: "9001・9050", day: "2026-10-20", go_back: 0, route_name: "新名", end_stop_name: "新站", n_pairs: 1, n_layovers: 0, n_no_last_stop: 1 },
        { route_id: 9001, route_ids: "9001・9050", day: "2026-10-20", go_back: 1, route_name: "新名", end_stop_name: "甲站", n_pairs: 0, n_layovers: 0 } ]
    end
    let(:rows) { report(with_gps([ 30.0 ] * 3), ends:) }

    it "路線 Id、名稱與末站取調查的最後一天" do
      expect(rows.first.values_at("route_ids", "route_name", "end_stop_name")).to eq(%w[9001・9050 新名 新站])
    end

    it "有折返停留的日子只數 10-19，配對、折返停留與跑了別的路線的配對數兩天合計" do
      expect(rows.first.values_at("n_days", "n_pairs", "n_layovers", "n_other_route")).to eq(%w[1 5 3 1])
    end

    it "完全沒有折返停留的那一端也有一列，數字是 0、分佈是空的" do
      expect(rows.last.values_at("go_back", "n_days", "n_layovers", "n_with_gps", "layover_p50", "stop_gap_p50", "nature", "reason"))
        .to eq([ "1", "0", "0", "0", nil, nil, "undetermined", "few_layovers" ])
    end
  end
end
