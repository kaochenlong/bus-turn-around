require "rails_helper"

RSpec.describe NightlyLoadCommand, type: :model do
  let(:dir) { Dir.mktmpdir("nightly-load") }
  let(:tunnel) { class_double(ProductionTunnel) }
  let(:opened) { [] }
  let(:loads) { [] }

  # The forward opens at once; what it was asked to open is recorded.
  before do
    allow(tunnel).to receive(:open) do |**target, &block|
      opened << target
      block.call
    end
  end

  after { FileUtils.remove_entry(dir) }

  def deploy_config = { "service" => "website", "accessories" => { "db" => { "host" => "203.0.113.5" } } }

  # A PATH with nothing on it but an executable named duckdb, so the examples
  # that never run the loader do not need the DuckDB CLI.
  def path_with_duckdb
    bin = File.join(dir, "bin")
    FileUtils.mkdir_p(bin)
    FileUtils.touch(File.join(bin, "duckdb"))
    File.chmod(0o755, File.join(bin, "duckdb"))
    bin
  end

  def base_env = { "TURNAROUND_DATA" => DuckdbHelpers::FIXTURE_DATA, "WEBSITE_DATABASE_PASSWORD" => "secret", "DB_PORT" => "15432", "PATH" => path_with_duckdb }

  def fixture_days = DerivedDays.new(first_day: Date.new(2026, 10, 19), skipped_days: {})

  def lock_path = File.join(dir, "nightly-load.lock")

  # Runs the block while another process holds the lock on lock_path.
  def while_another_process_holds_the_lock
    script = 'lock = File.open(ARGV[0], File::RDWR | File::CREAT); lock.flock(File::LOCK_EX); puts "locked"; $stdout.flush; $stdin.read'
    IO.popen([ RbConfig.ruby, "-e", script, lock_path ], "r+") do |child|
      child.gets
      yield
    ensure
      child.close_write
    end
  end

  # Whether a process could take the lock on lock_path now.
  def lock_free? = File.open(lock_path, File::RDWR | File::CREAT) { it.flock(File::LOCK_EX | File::LOCK_NB) } == 0

  # Whether the lock was free while the forward was open.
  def lock_free_during_forward
    free = nil
    allow(tunnel).to receive(:open) do |**, &block|
      free = lock_free?
      block.call
    end
    run_command
    free
  end

  def refuse_forward = allow(tunnel).to receive(:open).and_raise(ProductionTunnel::Error, "ssh: connect to host 203.0.113.5 port 22: Connection refused")

  # Records each route day it is asked to write instead of writing it, and
  # raises `error` for the route day `failing`, [day, route Id].
  def recording_loader(failing: nil, error: RouteDayLoader::Error.new("測試用的失敗"))
    lambda do |route_id:, day:, **|
      loads << [ day.iso8601, route_id ]
      raise error if [ day.iso8601, route_id ] == failing

      { trips: 1, layovers: 2, trip_stop_counts: 3, end_toilets: 4, end_cells: 5 }
    end
  end

  def derived_counts = DerivedPushCommand.derived_tables.to_h { [ it, ActiveRecord::Base.connection.select_value("SELECT count(*) FROM #{it}") ] }

  # A data root in which every day from `first` to `last` passes RawDayCheck.
  # The files are empty, which only the loader would notice.
  def complete_data_root(first, last)
    root = File.join(dir, "data")
    (Date.iso8601(first)..Date.iso8601(last)).each do |day|
      [ "bus_event/#{day}/00.jsonl", "bus_event/#{day + 1}/01.jsonl", "bus_data/#{day}/00.jsonl", *RawDayCheck::STATIC_FILES.map { "static/#{day}/#{it}" } ].each do |file|
        FileUtils.mkdir_p(File.dirname(File.join(root, file)))
        FileUtils.touch(File.join(root, file))
      end
    end
    root
  end

  # The route days the plan lists to load, as [day, [route Id, ...]] per day.
  def to_load(out) = out.scan(/^  (\d{4}-\d{2}-\d{2})：([\d、]+)$/).map { |day, routes| [ day, routes.split("、").map(&:to_i) ] }

  # Runs the command at 2026-10-20 02:00 Taipei time, when 2026-10-19 is the
  # last candidate day, and returns its exit status, everything it printed
  # and whether the derived tables are as they were.
  def run_command(*argv, env: {}, now: Time.zone.parse("2026-10-20 02:00"), route_ids: [ 9001 ], days: fixture_days, deploy: deploy_config,
                  loader: recording_loader, **options)
    out, before = StringIO.new, derived_counts
    status = described_class.new(argv, env: base_env.merge(env).compact, out:, now:, route_ids:, days:, loader:, tunnel:,
                                       lock_path:, deploy:, **options).run
    [ status, out.string, derived_counts == before ]
  end

  # What derived:load prints for one day of route 9001 with `env`.
  def derived_load_output(env)
    StringIO.new.tap { DerivedLoadCommand.new({ "ROUTE" => "9001", "DAY" => "2026-10-19", "TURNAROUND_DATA" => DuckdbHelpers::FIXTURE_DATA }.merge(env), out: it).run }.string
  end

  describe "開轉送之前就停：結束碼非零、不開轉送、衍生表不變" do
    before { create(:route_day) }

    {
      "看不懂的參數 --push" => [ [ "--push" ], {}, "--push" ],
      "--load 沒有 TURNAROUND_DATA" => [ [ "--load" ], { "TURNAROUND_DATA" => nil }, "TURNAROUND_DATA" ],
      "--load 沒有 WEBSITE_DATABASE_PASSWORD" => [ [ "--load" ], { "WEBSITE_DATABASE_PASSWORD" => nil }, "WEBSITE_DATABASE_PASSWORD" ],
      "ROUTE=9001 沒有 --recompute" => [ [], { "ROUTE" => "9001" }, "--recompute" ],
      "ROUTE=9050 --recompute（9050 掛在 9001 底下）" => [ [ "--recompute" ], { "ROUTE" => "9050" }, "9050 是 9001 那一頁的附屬路線，請用 ROUTE=9001" ],
      "ROUTE=4242 --recompute（不是頁面路線）" => [ [ "--recompute" ], { "ROUTE" => "4242" }, "4242 不是頁面路線" ],
      "ROUTE=abc --recompute" => [ [ "--recompute" ], { "ROUTE" => "abc" }, "abc" ],
      "DB_PORT 不是埠號" => [ [ "--load" ], { "DB_PORT" => "15432x" }, "TUNNEL_PORT" ],
      "DB_PORT 超過 65535" => [ [ "--load" ], { "DB_PORT" => "70000" }, "70000" ]
    }.each do |input, (argv, env, reason)|
      it "#{input}：印用法與原因（#{reason}）" do
        status, out, unchanged = run_command(*argv, env:)
        expect([ status.zero?, out.include?("用法"), out.include?(reason), opened, unchanged ]).to eq([ false, true, true, [], true ])
      end
    end

    it "PATH 裡沒有 duckdb：訊息跟 derived:load 相同" do
      status, out, unchanged = run_command("--load", env: { "PATH" => dir })
      expect([ status.zero?, out, opened, unchanged ]).to eq([ false, derived_load_output("PATH" => dir), [], true ])
    end

    it "config/derived_days.yml 壞掉：印出哪裡不對" do
      allow(DerivedDays).to receive(:from_config).and_raise(DerivedDays::InvalidConfiguration, "config/derived_days.yml 缺 first_day")
      status, out, unchanged = run_command("--load", days: nil)
      expect([ status.zero?, out.chomp, opened, unchanged ]).to eq([ false, "config/derived_days.yml 缺 first_day", [], true ])
    end
  end

  it "檢查都過：開轉送到 config/deploy.yml 的 db 主機，沒設 ssh 使用者就是 root，本機埠是 DB_PORT" do
    run_command
    expect(opened).to eq([ { host: "203.0.113.5", user: "root", local_port: 15432 } ])
  end

  it "config/deploy.yml 設了 ssh 使用者：轉送用那個使用者，計畫的目標也是它" do
    _, out = run_command(deploy: deploy_config.merge("ssh" => { "user" => "app" }))
    expect([ opened.sole[:user], out.lines.first ]).to match([ "app", a_string_including("app@203.0.113.5 的 website_test") ])
  end

  it "config/deploy.yml 沒有 accessories 的 db.host：結束碼非零，不開轉送" do
    status, out = run_command(deploy: { "service" => "website" })
    expect([ status.zero?, out.include?("db.host"), opened ]).to eq([ false, true, [] ])
  end

  describe "計畫（不加 --load）" do
    it "fixture 的 2026-10-19 正式站沒有 9001：列在要載入，最後一行說要加 --load，沒有呼叫 loader，衍生表不變" do
      status, out, unchanged = run_command
      expect([ status, to_load(out), out.lines.last.include?("--load"), loads, unchanged ]).to eq([ 0, [ [ "2026-10-19", [ 9001 ] ] ], true, [], true ])
    end

    it "第一行是目標：<ssh 使用者>@<主機> 的資料庫" do
      _, out = run_command
      expect(out.lines.first).to include("root@203.0.113.5 的 website_test")
    end

    it "正式站全都有：說沒有要載入，結束碼 0" do
      create(:route_day)
      status, out = run_command
      expect([ status, to_load(out), out.include?("沒有要載入") ]).to eq([ 0, [], true ])
    end

    it "讀檔視窗還沒結束的 2026-10-20：印出 RawDayCheck 的訊息，那一天不列在要載入，結束碼非零" do
      status, out = run_command(now: Time.zone.parse("2026-10-21 02:00"))
      expect([ status.zero?, to_load(out), out ]).to match([ false, [ [ "2026-10-19", [ 9001 ] ] ], a_string_including("2026-10-20：讀檔視窗還沒結束：沒有 #{DuckdbHelpers::FIXTURE_DATA}/bus_event/2026-10-21/01.jsonl") ])
    end
  end

  # Page routes 9001 and 9100, candidate days 2026-10-19 to 2026-10-23 with
  # 2026-10-20 skipped, and production storing 9001 on 2026-10-19 and 9100 on
  # 2026-10-19 and 2026-10-21.
  describe "選要載入的路線日" do
    let(:selection) { { now: Time.zone.parse("2026-10-24 02:00"), route_ids: [ 9001, 9100 ], days: DerivedDays.new(first_day: Date.new(2026, 10, 19), skipped_days: { Date.new(2026, 10, 20) => "測試跳過的理由" }) } }

    before do
      [ [ 9001, "2026-10-19" ], [ 9100, "2026-10-19" ], [ 9100, "2026-10-21" ] ].each { |route_id, day| create(:route_day, route_id:, day: Date.iso8601(day)) }
    end

    def plan(*argv, env: {}) = run_command(*argv, env: { "TURNAROUND_DATA" => complete_data_root("2026-10-19", "2026-10-23") }.merge(env), **selection)[1]

    it "已有的與跳過的不列：2026-10-21 只有 9001，2026-10-22 與 2026-10-23 兩條都有，同一天照設定的順序" do
      expect(to_load(plan)).to eq([ [ "2026-10-21", [ 9001 ] ], [ "2026-10-22", [ 9001, 9100 ] ], [ "2026-10-23", [ 9001, 9100 ] ] ])
    end

    it "日子範圍到讀檔視窗已結束的最後一天，跳過的日子附理由，已有的路線日每條路線一行" do
      expect(plan).to include("2026-10-19 到 2026-10-23", "2026-10-20：測試跳過的理由", "9001：2026-10-19 到 2026-10-19，1 天", "9100：2026-10-19 到 2026-10-21，2 天")
    end

    it "--recompute：已有的也列，2026-10-20 照樣不列" do
      expect(to_load(plan("--recompute"))).to eq([ "2026-10-19", "2026-10-21", "2026-10-22", "2026-10-23" ].map { [ it, [ 9001, 9100 ] ] })
    end

    it "--recompute 加 ROUTE=9100：只列 9100 的 2026-10-19、2026-10-21、2026-10-22、2026-10-23" do
      expect(to_load(plan("--recompute", env: { "ROUTE" => "9100" }))).to eq([ "2026-10-19", "2026-10-21", "2026-10-22", "2026-10-23" ].map { [ it, [ 9100 ] ] })
    end

    it "--load 的載入順序：日子升冪，同一天 9001 在 9100 前面" do
      plan("--load")
      expect(loads).to eq([ [ "2026-10-21", 9001 ], [ "2026-10-22", 9001 ], [ "2026-10-22", 9100 ], [ "2026-10-23", 9001 ], [ "2026-10-23", 9100 ] ])
    end
  end

  describe "同時只跑一個" do
    it "另一個 process 拿著 tmp/nightly-load.lock：說另一個還在跑、這次不做，結束碼 0，不開轉送也不呼叫 loader" do
      status, out = while_another_process_holds_the_lock { run_command("--load") }
      expect([ status, out.chomp, opened, loads ]).to eq([ 0, "另一個 bin/nightly-load 還在跑，這次不做", [], [] ])
    end

    it "開著轉送的整段時間都拿著鎖" do
      expect(lock_free_during_forward).to be(false)
    end

    it "跑完之後鎖已放開，下一次拿得到" do
      run_command("--load")
      expect(lock_free?).to be(true)
    end

    it "有路線日失敗之後鎖也放開" do
      run_command("--load", loader: recording_loader(failing: [ "2026-10-19", 9001 ]))
      expect(lock_free?).to be(true)
    end

    it "轉送開不起來之後鎖也放開" do
      refuse_forward
      run_command("--load")
      expect(lock_free?).to be(true)
    end
  end

  it "轉送開不起來：印出轉送失敗與 ssh 印的原因，結束碼非零，不呼叫 loader" do
    refuse_forward
    status, out, unchanged = run_command("--load")
    expect([ status.zero?, out, loads, unchanged ]).to match([ false, a_string_including("轉送", "Connection refused"), [], true ])
  end

  describe "載入前比對 migration 版本" do
    let(:checkout_versions) { ActiveRecord::Base.connection_pool.migration_context.migrations.map(&:version) }

    it "正式站多一個 20991231000000：印出只在正式站的版本，結束碼非零，不呼叫 loader" do
      ActiveRecord::Base.connection.execute("INSERT INTO schema_migrations (version) VALUES ('20991231000000')")
      status, out = run_command("--load", checkout_versions:)
      expect([ status.zero?, out.include?("只在正式站：20991231000000"), loads ]).to eq([ false, true, [] ])
    end

    it "這份 checkout 多一個 20991231000001：印出只在 checkout 的版本，結束碼非零，不呼叫 loader" do
      status, out = run_command("--load", checkout_versions: checkout_versions + [ 20991231000001 ])
      expect([ status.zero?, out.include?("只在這份 checkout：20991231000001"), loads ]).to eq([ false, true, [] ])
    end

    it "兩邊一樣：計畫的第一行說版本一致，照樣載入" do
      status, out = run_command("--load", checkout_versions:)
      expect([ status, out.lines.first.include?("migration 版本一致"), loads ]).to eq([ 0, true, [ [ "2026-10-19", 9001 ] ] ])
    end
  end

  describe "--load" do
    # Page routes 9001 and 9100 on the fixture days 2026-10-19 and 2026-10-23,
    # with production already storing 9100 on 2026-10-23: three route days to load.
    def load_three(loader)
      create(:route_day, route_id: 9100, day: Date.new(2026, 10, 23))
      days = DerivedDays.new(first_day: Date.new(2026, 10, 19), skipped_days: (20..22).to_h { [ Date.new(2026, 10, it), "測試跳過" ] })
      run_command("--load", now: Time.zone.parse("2026-10-24 02:00"), route_ids: [ 9001, 9100 ], days:, loader:)
    end

    it "2026-10-19 的 9100 失敗：印出那一天、路線與訊息，另外兩個照樣寫入，摘要 2 寫入 1 失敗 0 不齊，結束碼非零" do
      status, out = load_three(recording_loader(failing: [ "2026-10-19", 9100 ]))
      expect([ status.zero?, loads.size, out.lines.grep(/寫入：|失敗：/).map(&:chomp), out.lines.last.chomp ]).to eq(
        [ false, 3, [ "2026-10-19 9001 寫入：趟次 1、折返停留 2、趟次站 3、兩端公廁 4 間、靜止格 5 格", "2026-10-19 9100 失敗：測試用的失敗",
                      "2026-10-23 9001 寫入：趟次 1、折返停留 2、趟次站 3、兩端公廁 4 間、靜止格 5 格" ], "載入 2 個路線日、失敗 1 個、原始檔不齊 0 天" ]
      )
    end

    it "loader 丟出 RouteDayLoader::Error 以外的錯誤：失敗那一行帶錯誤的類別，其他照樣寫入" do
      status, out = load_three(recording_loader(failing: [ "2026-10-19", 9100 ], error: RuntimeError.new("意料之外")))
      expect([ status.zero?, out.lines.grep(/失敗：/).map(&:chomp), out.lines.last.chomp ]).to eq([ false, [ "2026-10-19 9100 失敗：RuntimeError: 意料之外" ], "載入 2 個路線日、失敗 1 個、原始檔不齊 0 天" ])
    end

    it "讀檔視窗還沒結束的 2026-10-20 不試，2026-10-19 照樣寫入，摘要 1 寫入 0 失敗 1 不齊，結束碼非零" do
      status, out = run_command("--load", now: Time.zone.parse("2026-10-21 02:00"))
      expect([ status.zero?, loads, out.lines.last.chomp ]).to eq([ false, [ [ "2026-10-19", 9001 ] ], "載入 1 個路線日、失敗 0 個、原始檔不齊 1 天" ])
    end

    it "正式站全都有：說沒有要載入，不呼叫 loader，結束碼 0" do
      create(:route_day)
      status, out = run_command("--load")
      expect([ status, loads, out.include?("沒有要載入"), out.lines.last.chomp ]).to eq([ 0, [], true, "載入 0 個路線日、失敗 0 個、原始檔不齊 0 天" ])
    end

    it "fixture 的 2026-10-19 用真的 loader 寫進 9001：印出跟 derived:load 一樣的筆數，結束碼 0", :duckdb do
      status, out = run_command("--load", env: { "PATH" => ENV.fetch("PATH") }, loader: described_class::LOADER)
      expect([ status, out.lines.grep(/寫入：/).map(&:chomp), out.lines.last.chomp, RouteDay.pluck(:route_id, :day) ]).to eq(
        [ 0, [ "2026-10-19 9001 寫入：趟次 27、折返停留 18、趟次站 96、兩端公廁 5 間、靜止格 1 格" ], "載入 1 個路線日、失敗 0 個、原始檔不齊 0 天", [ [ 9001, Date.new(2026, 10, 19) ] ] ]
      )
    end
  end

  describe "bin/nightly-load" do
    # Runs the executable with `env` on top of this process's environment; a
    # nil value unsets the variable.
    def run_bin(env, *argv) = Open3.capture3(env, RbConfig.ruby, Rails.root.join("bin/nightly-load").to_s, *argv)

    # Runs the executable in production with `env`, with nothing on PATH but
    # a fake duckdb and a fake ssh that records its arguments and fails, so
    # nothing reaches the production host. Returns the -L argument ssh got.
    def local_forward_of_bin(env)
      ssh = File.join(path_with_duckdb, "ssh")
      File.write(ssh, %(#!/bin/sh\necho "$@" > "$0.argv"\nexit 1\n))
      File.chmod(0o755, ssh)
      run_bin({ "RAILS_ENV" => nil, "DB_HOST" => nil, "DB_PORT" => nil, "TUNNEL_PORT" => nil, "SECRET_KEY_BASE_DUMMY" => nil, "PATH" => File.dirname(ssh),
                "TURNAROUND_DATA" => DuckdbHelpers::FIXTURE_DATA, "WEBSITE_DATABASE_PASSWORD" => "x" }.merge(env))
      File.read("#{ssh}.argv").split.then { it[it.index("-L") + 1] }
    end

    it "RAILS_ENV 是 test：說它寫的是正式站、RAILS_ENV 要是 production，不載入 Rails、不印計畫，結束碼非零" do
      stdout, stderr, status = run_bin({ "RAILS_ENV" => "test" })
      expect([ status.exitstatus.zero?, stderr.include?("production"), stdout ]).to eq([ false, true, "" ])
    end

    it "沒設 RAILS_ENV 與 TUNNEL_PORT：以 production 跑，轉送的本機埠是 15432" do
      expect(local_forward_of_bin({})).to eq("127.0.0.1:15432:127.0.0.1:5432")
    end

    it "TUNNEL_PORT=15433：DB_PORT 跟著它，轉送的本機埠是 15433" do
      expect(local_forward_of_bin("TUNNEL_PORT" => "15433")).to eq("127.0.0.1:15433:127.0.0.1:5432")
    end
  end
end
