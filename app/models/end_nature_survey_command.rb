require "csv"
require "digest"
require "json"
require "tmpdir"
require "zlib"

# bin/rails survey:end_natures: surveys every route of the network over a
# range of Taipei days, writing for each end the GPS evidence of whether buses
# wait there and the nature a fixed rule infers from it. It writes files under
# OUT only, never the database, the route list configuration or a route page.
# Every check runs before the first route day, so a survey that cannot run
# leaves OUT untouched. The raw data root comes only from TURNAROUND_DATA, so
# no host path is written into the repo.
#
# A route day runs the analysis derived:load runs, with both ends unknown,
# then analysis/end_nature_evidence.sql and analysis/end_nature_export.sql,
# and keeps its files in <OUT>/evidence/<day>/<route Id>/ with the
# fingerprint of that analysis. A folder holding the current fingerprint is
# reused without running DuckDB, so a survey can be stopped and run again.
# The report, <OUT>/report-<FROM>_<TO>.csv, is computed again every time from
# the evidence of every route day of the range by
# analysis/end_nature_survey.sql.
class EndNatureSurveyCommand
  USAGE = <<~TEXT.freeze
    用法：bin/rails survey:end_natures FROM=<YYYY-MM-DD> TO=<YYYY-MM-DD> [ROUTES=<路線 Id,…>] [OUT=<目錄>]
    原始檔的資料根目錄由環境變數 TURNAROUND_DATA 給；OUT 省略時是 tmp/end-natures。
  TEXT
  ISO_DATE = /\A\d{4}-\d{2}-\d{2}\z/
  # An empty ROUTES is a usage error, not the whole network.
  ROUTE_IDS = /\A[1-9]\d*(?:,[1-9]\d*)*\z/
  DEFAULT_OUT = "tmp/end-natures".freeze
  # The files a route day runs after the stages; the fingerprint is taken
  # over them, the stages and params.sql.
  EXTRA_FILES = %w[mrt_overlap.sql turnaround_facilities.sql end_nature_evidence.sql end_nature_export.sql].freeze
  EVIDENCE_FILES = %w[layovers.csv ends.csv].freeze
  # A route day's staging folder: hidden, and never a route Id.
  STAGING_PREFIX = ".partial-".freeze
  # How the summary words the values of the report.
  NATURES = { "stop" => "停車", "pass_through" => "直接折返", "undetermined" => "待查證" }.freeze
  REASONS = { "few_layovers" => "樣本太少", "between" => "介於兩個門檻之間" }.freeze
  DIRECTIONS = { "0" => "去程", "1" => "返程" }.freeze

  # A reason that stops the survey; the message is what to print.
  class Failure < StandardError; end

  def initialize(env, out: $stdout)
    @env = env
    @out = out
  end

  # Returns the exit status: 0 when the report was written from at least one
  # route day with evidence.
  def run
    days, route_ids = parse
    duckdb = AnalysisRun.find_duckdb(@env["PATH"]) or raise Failure, "需要 DuckDB CLI，安裝：brew install duckdb"
    route_ids&.each { check_page_route(it) }
    days.each { check_day(it) }
    survey(days, route_ids, duckdb, external_snapshots)
  rescue Failure => e
    @out.puts(e.message)
    1
  end

  private

  def parse
    from, to, routes = @env.values_at("FROM", "TO", "ROUTES")
    usage!("要同時給 FROM 與 TO") if from.nil? || to.nil?
    first, last = parse_day(from), parse_day(to)
    usage!("FROM 晚於 TO") if first > last
    usage!("ROUTES 格式不對：#{routes}") unless routes.nil? || ROUTE_IDS.match?(routes)
    usage!("沒有 TURNAROUND_DATA") if data_root.to_s.empty?
    [ (first..last).to_a, routes&.split(",")&.map { Integer(it) }&.uniq&.sort ]
  end

  def parse_day(text)
    usage!("日期格式不對：#{text}") unless ISO_DATE.match?(text)
    Date.iso8601(text)
  rescue Date::Error
    usage!("沒有這一天：#{text}")
  end

  def usage!(reason) = raise(Failure, "#{reason}\n\n#{USAGE}")

  def data_root = @env["TURNAROUND_DATA"]

  def out_dir = File.expand_path(@env["OUT"].presence || Rails.root.join(DEFAULT_OUT).to_s)

  # A member route is surveyed with its page route, as derived:load runs it,
  # so naming it alone is a usage error that names the page route.
  def check_page_route(route_id)
    page_route_id = RoutePage.member_of(route_id) or return
    raise Failure, "#{route_id} 是 #{page_route_id} 那一頁的附屬路線，ROUTES 請改用 #{page_route_id}"
  end

  # The day eligibility rules of derived:load for the raw files.
  def check_day(day)
    RawDayCheck.check!(data_root:, day:)
  rescue RawDayCheck::Failure => e
    raise Failure, "#{day.iso8601} 不能調查：#{e.message}"
  end

  # The newest MRT entrance and public toilet snapshots, looked up as
  # derived:load looks them up, the entrance snapshot first.
  def external_snapshots
    { mrt_exits: NewestSnapshot.find(data_root:, directory: MrtExitsSnapshot::DIRECTORY, label: "捷運出入口", task: "bin/rails external:mrt_exits"),
      public_toilets: NewestSnapshot.find(data_root:, directory: PublicToiletsSnapshot::DIRECTORY, label: "公廁", task: "bin/rails external:public_toilets") }
  rescue NewestSnapshot::Missing => e
    raise Failure, e.message
  end

  def survey(days, route_ids, duckdb, snapshots)
    analysis_sql = AnalysisRun.sql({}, extra_files: EXTRA_FILES)
    folders = []
    failures = []
    days.each do |day|
      routes = route_ids || day_route_ids(day)
      outcomes = routes.map { survey_route_day(day, it, duckdb, snapshots, analysis_sql) }
      outcomes.each { |outcome, detail| (outcome == :failed ? failures : folders) << detail }
      tally = outcomes.map(&:first).tally
      @out.puts("#{day.iso8601}：路線 #{routes.size} 條，跑完 #{tally.fetch(:run, 0)}、沿用 #{tally.fetch(:reused, 0)}、失敗 #{tally.fetch(:failed, 0)}")
    end
    finish(folders, failures, duckdb, days)
  end

  # The route Ids of the day's GetRoute.gz, smallest first, without the
  # member routes, which run with their page route.
  def day_route_ids(day)
    snapshot = File.join(data_root, "static", day.iso8601, "GetRoute.gz")
    JSON.parse(Zlib::GzipReader.open(snapshot, &:read)).fetch("BusInfo").map { it.fetch("Id") }.uniq.sort
        .reject { RoutePage.member_of(it) }
  end

  # Returns :run or :reused with the route day's folder, or :failed with the
  # line that tells about it. A failed route day leaves no folder, not even
  # one an earlier analysis wrote.
  def survey_route_day(day, route_id, duckdb, snapshots, analysis_sql)
    member_route_ids = RoutePage.member_route_ids(route_id)
    folder = File.join(out_dir, "evidence", day.iso8601, route_id.to_s)
    fingerprint = Digest::SHA256.hexdigest("#{analysis_sql}\n#{member_route_ids.join(',')}")
    return [ :reused, folder ] if reusable?(folder, fingerprint)

    run_route_day(folder, fingerprint, duckdb, variables(day, route_id, member_route_ids, snapshots))
    [ :run, folder ]
  rescue AnalysisRun::Error => e
    FileUtils.rm_rf(folder)
    [ :failed, "#{day.iso8601} 路線 #{route_id}：#{e.message.lines.first.to_s.chomp}" ]
  end

  def reusable?(folder, fingerprint)
    stored = File.join(folder, "fingerprint")
    File.file?(stored) && File.read(stored).strip == fingerprint && EVIDENCE_FILES.all? { File.file?(File.join(folder, it)) }
  end

  # DuckDB writes into a staging folder beside the route day's folder, which
  # takes its place only once the whole route day has succeeded. The
  # inspection and derived files go to a folder that is thrown away.
  def run_route_day(folder, fingerprint, duckdb, variables)
    staging = Dir.mktmpdir(STAGING_PREFIX, File.dirname(folder).tap { FileUtils.mkdir_p(it) })
    Dir.mktmpdir("end-nature-scratch") do |scratch|
      AnalysisRun.run(duckdb, variables.merge(inspect_dir: scratch, derived_dir: scratch, survey_dir: staging), extra_files: EXTRA_FILES)
    end
    File.write(File.join(staging, "fingerprint"), "#{fingerprint}\n")
    FileUtils.rm_rf(folder)
    File.rename(staging, folder)
  ensure
    FileUtils.rm_rf(staging) if staging
  end

  # Both ends are unknown, so the configured natures play no part in the evidence.
  def variables(day, route_id, member_route_ids, snapshots)
    mrt_exits, public_toilets = snapshots.values_at(:mrt_exits, :public_toilets)
    { data_root:, route_id:, member_route_ids:, day:, static_day: day,
      mrt_exits_path: mrt_exits.path, mrt_exits_day: mrt_exits.day,
      public_toilets_path: public_toilets.path, public_toilets_day: public_toilets.day,
      end_nature_0: "unknown", end_nature_1: "unknown" }
  end

  def finish(folders, failures, duckdb, days)
    if failures.any?
      @out.puts("跑失敗的路線日：")
      failures.each { @out.puts("  #{it}") }
    end
    if folders.empty?
      @out.puts("沒有任何路線日跑成功，沒有寫報告")
      return 1
    end

    print_summary(write_report(folders, duckdb, days))
    0
  end

  # The report is written under a temporary name and takes its own only once
  # DuckDB has finished, so a failed report leaves no half-written file; the
  # evidence stays for the next run to reuse.
  def write_report(folders, duckdb, days)
    report_path = File.join(out_dir, "report-#{days.first.iso8601}_#{days.last.iso8601}.csv")
    partial = "#{report_path}.partial"
    variables = { layovers_files: folders.map { File.join(it, "layovers.csv") }, ends_files: folders.map { File.join(it, "ends.csv") },
                  configured_path: write_configured, report_path: partial }
    AnalysisRun.run(duckdb, variables, extra_files: %w[end_nature_survey.sql], stages: false)
    File.rename(partial, report_path)
    report_path
  rescue AnalysisRun::Error => e
    raise Failure, "寫報告失敗：#{e.message}"
  ensure
    FileUtils.rm_f(partial) if partial
  end

  # The configured nature of each end of every route in
  # config/route_page.yml, which the report only compares with.
  def write_configured
    File.join(out_dir, "configured.csv").tap do |path|
      CSV.open(path, "w") do |csv|
        csv << %w[route_id go_back nature]
        RoutePage.route_ids.each do |route_id|
          ends = RoutePage.ends(route_id)
          RoutePage::Ends::DIRECTIONS.each { csv << [ route_id, it, ends.nature(it) ] }
        end
      end
    end
  end

  def print_summary(report_path)
    rows = CSV.read(report_path, headers: true)
    natures = rows.map { it["nature"] }.tally
    reasons = rows.filter_map { it["reason"] }.tally
    @out.puts("端點 #{rows.size} 個：停車 #{natures.fetch('stop', 0)}、直接折返 #{natures.fetch('pass_through', 0)}、" \
              "待查證 #{natures.fetch('undetermined', 0)}（樣本太少 #{reasons.fetch('few_layovers', 0)}、" \
              "介於兩個門檻之間 #{reasons.fetch('between', 0)}）")
    configured = rows.select { it["configured_nature"] }
    @out.puts("設定裡的端點：#{'沒有' if configured.empty?}")
    configured.each { @out.puts("  #{configured_end(it)}") }
    @out.puts("報告：#{report_path}")
  end

  def configured_end(row)
    reason = ("（#{REASONS.fetch(row['reason'])}）" if row["reason"])
    "#{row['route_id']} #{DIRECTIONS.fetch(row['go_back'])}結束在#{row['end_stop_name']}：設定 #{NATURES.fetch(row['configured_nature'])}，" \
      "判斷 #{NATURES.fetch(row['nature'])}#{reason}，停下來過 #{row['n_stood_still']}／#{row['n_with_gps']} 筆"
  end
end
