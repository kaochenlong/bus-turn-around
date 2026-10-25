require "rails_helper"
require "rake"
require_relative "../support/duckdb"

RSpec.describe EndNatureSurveyCommand, :duckdb, type: :model do
  let(:root) { Dir.mktmpdir("end-nature-survey") }

  after { FileUtils.remove_entry(root) }

  def out_dir = File.join(root, "out")

  def base_env
    { "TURNAROUND_DATA" => DuckdbHelpers::FIXTURE_DATA, "FROM" => "2026-10-19", "TO" => "2026-10-19", "OUT" => out_dir, "PATH" => ENV.fetch("PATH") }
  end

  # Runs the command and returns its exit status and everything it printed.
  def run_command(env = {})
    out = StringIO.new
    status = described_class.new(base_env.merge(env).compact, out:).run
    [ status, out.string ]
  end

  def evidence_dir(day = "2026-10-19") = File.join(out_dir, "evidence", day)

  def day_line(out, day = "2026-10-19") = out.lines.find { it.start_with?("#{day}：") }&.chomp

  # The route days DuckDB runs from now on, as [route Id, day]: the calls of
  # AnalysisRun.run that append end_nature_export.sql.
  def record_route_day_runs
    [].tap do |runs|
      allow(AnalysisRun).to receive(:run).and_wrap_original do |original, *args, **options|
        runs << args[1].values_at(:route_id, :day) if options.fetch(:extra_files, []).include?("end_nature_export.sql")
        original.call(*args, **options)
      end
    end
  end

  def stored_counts
    [ RouteDay, Trip, Layover, TripStopCount, RouteDayStop, RouteDayEnd, RouteDayEndToilet, RouteDayEndCell, RouteDayShape, RouteDayDepot ].map(&:count)
  end

  describe "用法錯誤" do
    [ { "TO" => nil }, { "FROM" => nil }, { "FROM" => "2026-10-20" }, { "TO" => "2026-13-01" }, { "ROUTES" => "9001;9100" },
      { "ROUTES" => "" }, { "TURNAROUND_DATA" => nil } ].each do |env|
      it "#{env.inspect}：印原因與用法、結束碼非零，OUT 不存在" do
        status, out = run_command(env)
        expect([ status.zero?, out.include?("用法：bin/rails survey:end_natures"), File.exist?(out_dir) ]).to eq([ false, true, false ])
      end
    end

    it "只給 FROM：第一行說要同時給 FROM 與 TO" do
      expect(run_command("TO" => nil).last.lines.first.chomp).to eq("要同時給 FROM 與 TO")
    end
  end

  it "ROUTES 有成員路線（test 設定的 9050 掛在 9001 底下）：說它是 9001 那一頁的附屬路線，結束碼非零，OUT 不存在" do
    status, out = run_command("ROUTES" => "9100,9050")
    expect([ status.zero?, out.lines.first.chomp, File.exist?(out_dir) ]).to eq([ false, "9050 是 9001 那一頁的附屬路線，ROUTES 請改用 9001", false ])
  end

  it "PATH 裡沒有 duckdb：說明需要 DuckDB CLI 與安裝方式，結束碼非零，OUT 不存在" do
    status, out = run_command("PATH" => path_without_duckdb)
    expect([ status.zero?, out.include?("brew install duckdb"), File.exist?(out_dir) ]).to eq([ false, true, false ])
  end

  describe "範圍裡有一天的讀檔視窗還沒結束（fixture 沒有 2026-10-21 的 01 時檔）" do
    before { allow(AnalysisRun).to receive(:run).and_call_original }

    let!(:result) { run_command("TO" => "2026-10-20") }

    it "說 2026-10-20 的讀檔視窗還沒結束，結束碼非零，OUT 不存在" do
      expect([ result.first.zero?, result.last.lines.first.chomp, File.exist?(out_dir) ])
        .to eq([ false, "2026-10-20 不能調查：讀檔視窗還沒結束：沒有 #{DuckdbHelpers::FIXTURE_DATA}/bus_event/2026-10-21/01.jsonl 或 01.jsonl.gz", false ])
    end

    it "2026-10-19 的路線日也沒有跑" do
      expect(AnalysisRun).not_to have_received(:run)
    end
  end

  describe "資料根目錄缺外部快照時" do
    # A data root in `dir` that links the fixture's raw feeds and the given external snapshot folders.
    def data_root(dir, externals)
      %w[bus_event bus_seat_event bus_data static].each { File.symlink(File.join(DuckdbHelpers::FIXTURE_DATA, it), File.join(dir, it)) }
      FileUtils.mkdir_p(File.join(dir, "external"))
      externals.each { File.symlink(File.join(DuckdbHelpers::FIXTURE_DATA, "external", it), File.join(dir, "external", it)) }
      dir
    end

    {
      "兩種快照都沒有" => [ [], "沒有捷運出入口快照：先跑 bin/rails external:mrt_exits" ],
      "只有捷運出入口快照" => [ %w[taipei-mrt-exits], "沒有公廁快照：先跑 bin/rails external:public_toilets" ]
    }.each do |situation, (externals, message)|
      it "#{situation}：印「#{message}」，結束碼非零，OUT 不存在" do
        status, out = run_command("TURNAROUND_DATA" => data_root(File.join(root, "data").tap { FileUtils.mkdir_p(it) }, externals))
        expect([ status.zero?, out.lines.first.chomp, File.exist?(out_dir) ]).to eq([ false, message, false ])
      end
    end
  end

  describe "Fixture day：2026-10-19，test 設定的 9001 掛 9050" do
    let!(:first_run) { run_command }

    it "那一天一行：路線 2 條，跑完 2、沿用 0、失敗 0" do
      expect(day_line(first_run.last)).to eq("2026-10-19：路線 2 條，跑完 2、沿用 0、失敗 0")
    end

    it "9001 與 9100 各有一個目錄，成員路線 9050 沒有，也沒有留下暫存目錄" do
      expect(Dir.children(evidence_dir).sort).to eq(%w[9001 9100])
    end

    it "9001 跟 9050 一起跑：ends.csv 兩個方向的 route_ids 都是 9001・9050" do
      expect(CSV.read(File.join(evidence_dir, "9001/ends.csv"), headers: true).map { it["route_ids"] }).to eq(%w[9001・9050 9001・9050])
    end

    it "一個目錄裡是 layovers.csv、ends.csv，與一行 64 個十六進位字元的 fingerprint" do
      folder = File.join(evidence_dir, "9100")
      expect([ Dir.children(folder).sort, File.read(File.join(folder, "fingerprint")) ]).to match([ %w[ends.csv fingerprint layovers.csv], /\A\h{64}\n\z/ ])
    end

    describe "Second run reuses the route days：什麼都沒改，再跑一次" do
      let!(:runs) { record_route_day_runs }
      let!(:second_run) { run_command }

      it "那一天跑完 0、沿用 2、失敗 0" do
        expect(day_line(second_run.last)).to eq("2026-10-19：路線 2 條，跑完 0、沿用 2、失敗 0")
      end

      it "沒有任何一個路線日跑 DuckDB" do
        expect(runs).to eq([])
      end
    end

    describe "Changed analysis runs again：9100 目錄裡的 fingerprint 跟這次的不同" do
      let!(:current) { File.read(File.join(evidence_dir, "9100/fingerprint")) }
      let!(:runs) do
        File.write(File.join(evidence_dir, "9100/fingerprint"), "#{'0' * 64}\n")
        record_route_day_runs
      end
      let!(:second_run) { run_command }

      it "只有 9100 重跑，9001 沿用" do
        expect([ day_line(second_run.last), runs ]).to eq([ "2026-10-19：路線 2 條，跑完 1、沿用 1、失敗 0", [ [ 9100, Date.new(2026, 10, 19) ] ] ])
      end

      it "9100 的目錄換成新跑的，fingerprint 又是這次的" do
        expect(File.read(File.join(evidence_dir, "9100/fingerprint"))).to eq(current)
      end
    end

    it "分析的 SQL 改了（組出的 SQL 多一行註解）：兩個路線日都重跑" do
      allow(AnalysisRun).to receive(:sql).and_wrap_original { |original, *args, **options| "#{original.call(*args, **options)}\n-- changed" }
      runs = record_route_day_runs
      expect([ day_line(run_command.last), runs.map(&:first) ]).to eq([ "2026-10-19：路線 2 條，跑完 2、沿用 0、失敗 0", [ 9001, 9100 ] ])
    end

    it "成員路線改了（9001 不再掛 9050）：9001 重跑，9100 沿用" do
      allow(RoutePage).to receive(:member_route_ids).and_call_original
      allow(RoutePage).to receive(:member_route_ids).with(9001).and_return([ 9001 ])
      runs = record_route_day_runs
      expect([ day_line(run_command.last), runs.map(&:first) ]).to eq([ "2026-10-19：路線 2 條，跑完 1、沿用 1、失敗 0", [ 9001 ] ])
    end
  end

  describe "Failing route day：ROUTES=9001,9999，2026-10-19 的 GetRoute.gz 沒有 9999" do
    let!(:result) { run_command("ROUTES" => "9001,9999") }

    it "那一天跑完 1、失敗 1" do
      expect(day_line(result.last)).to eq("2026-10-19：路線 2 條，跑完 1、沿用 0、失敗 1")
    end

    it "失敗的路線日點名日期、9999 與 DuckDB 訊息的第一行" do
      lines = result.last.lines.map(&:chomp)
      expect(lines[lines.index("跑失敗的路線日：") + 1]).to match(/\A  2026-10-19 路線 9999：.*GetRoute\.gz 沒有路線 Id 9999 的列\z/)
    end

    it "9999 沒有留下目錄或暫存目錄" do
      expect(Dir.children(evidence_dir)).to eq(%w[9001])
    end
  end

  it "較早的分析留下的 9999 目錄，這次 9999 失敗之後也拿掉，報告不會讀到舊的證據" do
    FileUtils.mkdir_p(File.join(evidence_dir, "9999")).then { File.write(File.join(evidence_dir, "9999/fingerprint"), "#{'0' * 64}\n") }
    run_command("ROUTES" => "9001,9999")
    expect(Dir.children(evidence_dir)).to eq(%w[9001])
  end

  it "Database untouched：route_days 與掛在它底下的每一張表，筆數前後相同" do
    expect { run_command }.not_to(change { stored_counts })
  end

  it "config/route_page.yml 的內容前後相同" do
    expect { run_command }.not_to(change { Rails.root.join("config/route_page.yml").binread })
  end

  def report_path = File.join(out_dir, "report-2026-10-19_2026-10-19.csv")

  describe "Fixture report：2026-10-19，test 設定" do
    let!(:result) { run_command }

    # The columns of the spec's Example table of the fixture report.
    let(:columns) do
      %w[route_id route_ids go_back end_stop_name n_layovers n_other_route n_with_gps n_stood_still stood_still_share farthest_max
         nature reason configured_nature agrees]
    end

    # The spec's Example table of the fixture report, empty values as nil.
    let(:example_rows) do
      [ %w[9001 9001・9050 0 戊站 10 0 4 3 0.750 644.9 undetermined few_layovers stop false],
        %w[9001 9001・9050 1 甲站 8 1 1 1 1.000 45.0 undetermined few_layovers stop false],
        [ "9100", "9100", "0", "丑站", "5", "0", "0", "0", nil, nil, "undetermined", "few_layovers", nil, nil ],
        [ "9100", "9100", "1", "子站", "4", "0", "0", "0", nil, nil, "undetermined", "few_layovers", nil, nil ] ]
    end

    it "報告四列，數字照規格的 Example 表" do
      expect(CSV.read(report_path, headers: true).map { it.to_h.values_at(*columns) }).to eq(example_rows)
    end

    it "Summary printed：逐行是那一天、端點數、設定裡的端點與報告的路徑，結束碼 0" do
      expect([ result.first, result.last.lines.map(&:chomp) ]).to eq(
        [ 0, [ "2026-10-19：路線 2 條，跑完 2、沿用 0、失敗 0", "端點 4 個：停車 0、直接折返 0、待查證 4（樣本太少 4、介於兩個門檻之間 0）",
               "設定裡的端點：", "  9001 去程結束在戊站：設定 停車，判斷 待查證（樣本太少），停下來過 3／4 筆",
               "  9001 返程結束在甲站：設定 停車，判斷 待查證（樣本太少），停下來過 1／1 筆", "報告：#{report_path}" ] ]
      )
    end

    it "OUT 底下只有設定的性質、證據目錄與報告，沒有留下寫到一半的報告" do
      expect(Dir.children(out_dir).sort).to eq(%w[configured.csv evidence report-2026-10-19_2026-10-19.csv])
    end
  end

  it "Failing route day：9999 失敗，報告照樣從 9001 寫出，結束碼 0" do
    status, = run_command("ROUTES" => "9001,9999")
    expect([ status, CSV.read(report_path, headers: true).map { it["route_id"] } ]).to eq([ 0, %w[9001 9001] ])
  end

  it "只調查沒有設定的 9100：設定裡的端點寫「沒有」" do
    expect(run_command("ROUTES" => "9100").last.lines.map(&:chomp)).to include("設定裡的端點：沒有")
  end

  describe "Nothing surveyed：ROUTES=9999，2026-10-19 的 GetRoute.gz 沒有 9999" do
    let!(:result) { run_command("ROUTES" => "9999") }

    it "印出 9999 的失敗與沒有任何路線日跑成功，結束碼非零" do
      expect([ result.first.zero?, result.last.lines.map(&:chomp).last(3).map { it[/\A[^：]*/] } ])
        .to eq([ false, [ "跑失敗的路線日", "  2026-10-19 路線 9999", "沒有任何路線日跑成功，沒有寫報告" ] ])
    end

    it "沒有寫報告" do
      expect(File.exist?(report_path)).to be(false)
    end
  end

  describe "報告那一步 DuckDB 寫了一半就失敗時" do
    let!(:result) do
      allow(AnalysisRun).to receive(:run).and_wrap_original do |original, *args, **options|
        if options[:extra_files] == [ "end_nature_survey.sql" ]
          File.write(args[1].fetch(:report_path), "route_id,route_ids\n9001,")
          raise AnalysisRun::Error, "Binder Error: 壞掉的報告\n"
        end
        original.call(*args, **options)
      end
      run_command
    end

    it "印出錯誤，結束碼非零" do
      expect([ result.first.zero?, result.last.lines.last.chomp ]).to eq([ false, "寫報告失敗：Binder Error: 壞掉的報告" ])
    end

    it "證據目錄留著，沒有報告，也沒有寫到一半的檔" do
      expect([ Dir.children(evidence_dir).sort, Dir.children(out_dir).sort ]).to eq([ %w[9001 9100], %w[configured.csv evidence] ])
    end
  end

  # Executes a rake task of the app and returns the status it exits with.
  def rake_exit_status(name)
    Rails.application.load_tasks if Rake::Task.tasks.none? { it.name == name }
    Rake::Task[name].execute
  rescue SystemExit => e
    e.status
  end

  it "rake task survey:end_natures 交給這個指令執行，結束碼是指令回傳的值" do
    allow(described_class).to receive(:new).and_return(instance_double(described_class, run: 3))
    expect(rake_exit_status("survey:end_natures")).to eq(3)
  end
end
