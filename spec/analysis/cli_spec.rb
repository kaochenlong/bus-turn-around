require "spec_helper"
require "fileutils"
require_relative "../support/duckdb"

RSpec.describe "bin/health-card" do
  let(:fixture_args) { [ "--data", DuckdbHelpers::FIXTURE_DATA, "--route", "9001" ] }

  # Runs bin/health-card with --out and --inspect-dir inside a fresh directory
  # and returns the exit code, standard error and what the run left there.
  def run_isolated(*args, env: {})
    Dir.mktmpdir("health-card-cli") do |dir|
      _stdout, stderr, status = run_health_card(*args, "--out", File.join(dir, "card.md"),
                                                "--inspect-dir", File.join(dir, "inspect"), env:)
      [ status.exitstatus, stderr, Dir.children(dir).sort ]
    end
  end

  # Copies the given fixture paths, such as "bus_event/2026-10-19", into `dir`,
  # so a run can read a data root that lacks something.
  def partial_data(dir, *paths)
    paths.each do |path|
      FileUtils.mkdir_p(File.dirname(File.join(dir, path)))
      FileUtils.cp_r(File.join(DuckdbHelpers::FIXTURE_DATA, path), File.join(dir, path))
    end
  end

  # Runs on the fixture's 2026-10-19 and returns the rows of each named CSV.
  def inspection_rows(*names)
    Dir.mktmpdir("health-card-cli") do |dir|
      run_health_card(*fixture_args, "--day", "2026-10-19", "--out", File.join(dir, "card.md"), "--inspect-dir", dir)
      names.map { read_csv_rows(File.join(dir, "#{it}.csv")) }
    end
  end

  def usage_printed?(stderr) = %w[--data --route --day --static-day --out --inspect-dir].all? { stderr.include?(it) }

  describe "參數與預設值" do
    let(:default_inspect_dir) { File.join(DuckdbHelpers::ROOT, "tmp/health-card/9001-2026-10-19") }

    before { FileUtils.rm_rf(default_inspect_dir) }
    after { FileUtils.rm_rf(default_inspect_dir) }

    it "只給 --data、--route、--day 時，卡寫到標準輸出，CSV 寫到 tmp/health-card/9001-2026-10-19" do
      stdout, _stderr, status = run_health_card(*fixture_args, "--day", "2026-10-19")
      expect([ status.exitstatus, stdout.start_with?("# "), File.exist?(File.join(default_inspect_dir, "trips.csv")) ]).to eq([ 0, true, true ])
    end

    it "沒給 --static-day 時用 --day 那天的快照：fixture 沒有 2026-10-18 的快照，結束碼 3 並指出 static/2026-10-18" do
      code, stderr, = run_isolated(*fixture_args, "--day", "2026-10-18")
      expect([ code, stderr.include?(File.join(DuckdbHelpers::FIXTURE_DATA, "static/2026-10-18")) ]).to eq([ 3, true ])
    end

    it "沒給 --data 時讀環境變數 TURNAROUND_DATA" do
      code, _stderr, files = run_isolated("--route", "9001", "--day", "2026-10-19", env: { "TURNAROUND_DATA" => DuckdbHelpers::FIXTURE_DATA })
      expect([ code, files ]).to eq([ 0, %w[card.md inspect] ])
    end

    it "--data 與 TURNAROUND_DATA 都有時用 --data" do
      code, _stderr, files = run_isolated(*fixture_args, "--day", "2026-10-19", env: { "TURNAROUND_DATA" => "/nonexistent" })
      expect([ code, files ]).to eq([ 0, %w[card.md inspect] ])
    end

    it "給了 --out 時卡寫到那個檔，上層目錄不存在就建起來，標準輸出沒有東西" do
      Dir.mktmpdir("health-card-cli") do |dir|
        stdout, = run_health_card(*fixture_args, "--day", "2026-10-19", "--out", File.join(dir, "cards/card.md"), "--inspect-dir", dir)
        expect([ stdout, File.read(File.join(dir, "cards/card.md")).start_with?("# ") ]).to eq([ "", true ])
      end
    end

    it "在這個 bundle 底下也跑得完：只用預設 gem，Gemfile 沒有的 csv 用不到" do
      Dir.mktmpdir("health-card-cli") do |dir|
        _stdout, _stderr, status = run_health_card(*fixture_args, "--day", "2026-10-19", "--out", File.join(dir, "card.md"), "--inspect-dir", dir, bundled: true)
        expect([ status.exitstatus, File.exist?(File.join(dir, "trips.csv")) ]).to eq([ 0, true ])
      end
    end

    [ %w[2026-10-18 前一天], %w[2026-10-20 隔天] ].each do |day, side|
      it "#{day} 的#{side}沒有任何小時檔也照常產出" do
        code, _stderr, files = run_isolated(*fixture_args, "--day", day, "--static-day", "2026-10-19")
        expect([ code, files ]).to eq([ 0, %w[card.md inspect] ])
      end
    end
  end

  describe "對 fixture 跑完的檢查檔" do
    it "trips.csv 有 27 趟，完整性跟 fixture README 手算的一致" do
      trips, = inspection_rows("trips")
      expect(trips.map { it["completeness"] }.tally).to eq("complete" => 22, "missing_start" => 2, "missing_end" => 2, "missing_both" => 1)
    end

    it "layovers.csv 的分鐘數跟 fixture README 手算的 18 筆一致" do
      layovers, = inspection_rows("layovers")
      expect(layovers.group_by { it["bus_id"] }.transform_values { |rows| rows.map { it["minutes"] } }).to eq(
        "TEST-0001" => %w[10.0 12.0 13.0 10.0 56.0 21.0 25.0 85.0], "TEST-0002" => %w[14.0 12.0 12.0 282.0],
        "TEST-0003" => %w[15.0 14.0 23.0 17.0], "TEST-0004" => %w[17.0 12.0]
      )
    end

    it "chains.csv 只有一串：TEST-0001 從 06:00 到 11:30，5 趟" do
      chains, = inspection_rows("chains")
      expect(chains.map { it.values_at("bus_id", "start_time", "end_time", "n_trips") }).to eq(
        [ [ "TEST-0001", "2026-10-19 06:00:00", "2026-10-19 11:30:00", "5" ] ]
      )
    end
  end

  describe "用法錯誤" do
    fixture = DuckdbHelpers::FIXTURE_DATA
    [
      [ "缺 --day", [ "--data", fixture, "--route", "9001" ], {} ],
      [ "缺 --route", [ "--data", fixture, "--day", "2026-10-19" ], {} ],
      [ "--data 與 TURNAROUND_DATA 都沒有", [ "--route", "9001", "--day", "2026-10-19" ], { "TURNAROUND_DATA" => nil } ],
      [ "TURNAROUND_DATA 是空字串", [ "--route", "9001", "--day", "2026-10-19" ], { "TURNAROUND_DATA" => "" } ],
      [ "日期不是 YYYY-MM-DD", [ "--data", fixture, "--route", "9001", "--day", "2026-1-9" ], {} ],
      [ "日期不存在", [ "--data", fixture, "--route", "9001", "--day", "2026-02-30" ], {} ],
      [ "靜態快照日不是 YYYY-MM-DD", [ "--data", fixture, "--route", "9001", "--day", "2026-10-19", "--static-day", "20261019" ], {} ],
      [ "路線 Id 不是整數", [ "--data", fixture, "--route", "9001x", "--day", "2026-10-19" ], {} ],
      [ "不認得的參數", [ "--data", fixture, "--route", "9001", "--day", "2026-10-19", "--color" ], {} ],
      [ "多出不屬於任何參數的引數", [ "--data", fixture, "--route", "9001", "--day", "2026-10-19", "extra" ], {} ]
    ].each do |label, args, env|
      it "#{label}：用法印到標準錯誤，結束碼 1，不寫任何檔" do
        code, stderr, files = run_isolated(*args, env:)
        expect([ code, usage_printed?(stderr), files ]).to eq([ 1, true, [] ])
      end
    end
  end

  describe "前置檢查" do
    it "PATH 裡沒有 duckdb：結束碼 2，不寫任何檔" do
      code, _stderr, files = run_isolated(*fixture_args, "--day", "2026-10-19", env: { "PATH" => path_without_duckdb })
      expect([ code, files ]).to eq([ 2, [] ])
    end

    it "那一天沒有任何 bus_event 檔：結束碼 3，指出缺的目錄，不寫任何檔" do
      code, stderr, files = run_isolated(*fixture_args, "--day", "2026-10-21", "--static-day", "2026-10-19")
      expect([ code, stderr.include?(File.join(DuckdbHelpers::FIXTURE_DATA, "bus_event/2026-10-21")), files ]).to eq([ 3, true, [] ])
    end

    it "沒有那一天的靜態快照：結束碼 3，指出缺的快照日並列出現有的快照日，不寫任何檔" do
      Dir.mktmpdir("health-card-data") do |data|
        partial_data(data, "bus_event/2026-10-19").then { %w[2026-10-15 2026-10-16].each { FileUtils.mkdir_p(File.join(data, "static", it)) } }
        code, stderr, files = run_isolated("--data", data, "--route", "9001", "--day", "2026-10-19")
        expect([ code, [ File.join(data, "static/2026-10-19"), "2026-10-15", "2026-10-16" ].all? { stderr.include?(it) }, files ]).to eq([ 3, true, [] ])
      end
    end

    it "快照日的目錄在但缺 GetPathDetail.gz：結束碼 3，只指出缺的那支檔，不寫任何檔" do
      Dir.mktmpdir("health-card-data") do |data|
        partial_data(data, "bus_event/2026-10-19", "static/2026-10-19/GetRoute.gz", "static/2026-10-19/GetStop.gz")
        code, stderr, files = run_isolated("--data", data, "--route", "9001", "--day", "2026-10-19")
        expect([ code, stderr.include?("GetPathDetail.gz"), stderr.include?("GetRoute.gz"), files ]).to eq([ 3, true, false, [] ])
      end
    end
  end

  describe "DuckDB 失敗" do
    # Puts a stand-in duckdb first on PATH: it writes trips.csv into the
    # inspection directory the SQL names, prints `error_line` to standard error
    # when given, and exits 1. Returns the PATH to run with.
    def fake_duckdb_path(dir, error_line)
      File.write(File.join(dir, "duckdb"), <<~SH)
        #!/bin/sh
        inspect_dir=$(sed -n "s/^SET VARIABLE inspect_dir = '\\(.*\\)';$/\\1/p")
        echo partial > "$inspect_dir/trips.csv"
        #{"echo '#{error_line}' >&2" if error_line}
        exit 1
      SH
      File.chmod(0o755, File.join(dir, "duckdb"))
      [ dir, ENV.fetch("PATH") ].join(File::PATH_SEPARATOR)
    end

    it "DuckDB 寫了一部分 CSV 才失敗：結束碼 4，標準錯誤一字不改，檢查目錄與卡都沒有寫" do
      Dir.mktmpdir("health-card-fake") do |bin|
        code, stderr, files = run_isolated(*fixture_args, "--day", "2026-10-19", env: { "PATH" => fake_duckdb_path(bin, "Fake Error: stopped after COPY") })
        expect([ code, stderr, files ]).to eq([ 4, "Fake Error: stopped after COPY\n", [] ])
      end
    end

    it "DuckDB 失敗卻沒有印任何錯誤訊息：結束碼 4，標準錯誤仍說明 duckdb 失敗" do
      Dir.mktmpdir("health-card-fake") do |bin|
        code, stderr, files = run_isolated(*fixture_args, "--day", "2026-10-19", env: { "PATH" => fake_duckdb_path(bin, nil) })
        expect([ code, stderr.empty?, files ]).to eq([ 4, false, [] ])
      end
    end

    it "整個讀檔視窗都沒有 bus_seat_event 檔時 DuckDB 報錯：結束碼 4，原樣印出它的標準錯誤，不寫任何檔" do
      Dir.mktmpdir("health-card-data") do |data|
        partial_data(data, "bus_event/2026-10-19", "static/2026-10-19")
        code, stderr, files = run_isolated("--data", data, "--route", "9001", "--day", "2026-10-19")
        expect([ code, stderr.include?("read_json cannot take NULL list as parameter"), files ]).to eq([ 4, true, [] ])
      end
    end
  end
end
