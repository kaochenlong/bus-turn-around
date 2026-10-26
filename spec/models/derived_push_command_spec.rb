require "rails_helper"

RSpec.describe DerivedPushCommand, type: :model do
  let(:dump_dir) { Dir.mktmpdir("derived-push") }
  let(:deploy) { { "service" => "website", "accessories" => { "db" => { "host" => "203.0.113.5" } } } }
  let(:calls) { [] }

  after { FileUtils.remove_entry(dump_dir) }

  def now = Time.zone.parse("2026-10-24 15:30:12")

  def schema_version = ActiveRecord::Base.connection.select_value("SELECT max(version) FROM schema_migrations")

  # The ten tables of today, each with the row count and sequence check of the
  # stored day below; `changes` replaces the line of a table.
  def production_rows(**changes)
    counts = { route_days: 1, route_day_depots: 1, route_day_shapes: 1 }
    described_class.derived_tables.map { |table| changes.fetch(table.to_sym) { "#{table} #{counts.fetch(table.to_sym, 0)} t" } }.join("\n")
  end

  # Answers each command with the first rule whose pattern matches it, as
  # [succeeded, output]; a command no rule matches succeeds without output.
  # Every command is recorded with the content of its input file and its argv.
  def shell(**overrides)
    rules = { "pg_dump --version" => [ true, "pg_dump (PostgreSQL) 16.10\n" ],
              "server_version_num" => [ true, "160010\n#{schema_version}\n" ], "last_value" => [ true, production_rows ] }.merge(overrides)
    lambda do |argv, input: nil, output: nil|
      line = argv.join(" ")
      calls << [ line, input && File.read(input), argv ]
      File.write(output, "-- the dump\n") if output
      rules.find { |pattern, _| line.include?(pattern) }&.last || [ true, "" ]
    end
  end

  def run(*argv, shell: self.shell)
    out = StringIO.new
    [ described_class.new(argv, out:, runner: shell, deploy:, dump_dir:, now:).run, out.string ]
  end

  # One stored day of route 9001 with a route shape and a depot.
  def store_day
    route_day = create(:route_day)
    create(:route_day_shape, route_day:)
    create(:route_day_depot, route_day:)
  end

  it "衍生表是 route_days 加上沿外鍵連到它的每一張表，目前十一張" do
    expect(described_class.derived_tables).to eq(%w[route_days layovers route_day_depots route_day_ends route_day_shapes route_day_stops trips
                                                     route_day_end_cells route_day_end_toilets trip_stop_counts trip_stop_speeds])
  end

  it "沒加 --push：印出目標、每張表的列數與每條路線的日子，不跑任何指令，結束碼 0" do
    store_day
    status, out = run
    expect([ status, calls, out ]).to match([ 0, [], a_string_including("root@203.0.113.5", "website-db", "route_days 1", "9001：2026-10-19 到 2026-10-19，1 天", "--push") ])
  end

  describe "--push" do
    before { store_day }

    it "依序：查 pg_dump 版本、查正式站版本、匯出、備份、換掉、比對，結束碼 0" do
      status, = run("--push")
      expect([ status, calls.map { it.first[/pg_dump --version|server_version_num|pg_dump -U postgres|pg_dump -U website|single-transaction|last_value/] } ])
        .to eq([ 0, [ "pg_dump --version", "server_version_num", "pg_dump -U postgres", "pg_dump -U website", "single-transaction", "last_value" ] ])
    end

    it "換掉正式站時送進去的 SQL 先 TRUNCATE 全部衍生表再接匯出的內容，遠端照錯了就停、整段一個交易跑" do
      run("--push")
      _, input, argv = calls.find { it.first.include?("single-transaction") }
      expect([ input, Shellwords.split(argv.last) ]).to match([ "TRUNCATE #{described_class.derived_tables.join(', ')};\n-- the dump\n", include("ON_ERROR_STOP=1", "--single-transaction") ])
    end

    it "備份檔名帶時間，最後印出退回用的指令" do
      _, out = run("--push")
      expect(out.lines.last).to include("ssh root@203.0.113.5", "cat /root/derived-before-20261024-153012.sql", "--single-transaction")
    end
  end

  describe "--push 換完之後對不上" do
    before { store_day }

    [
      [ "列數跟開發資料庫不同", { route_days: "route_days 3 t" }, "route_days" ],
      [ "序號落在最大的 id 之前", { trips: "trips 0 f" }, "trips" ]
    ].each do |situation, changes, table|
      it "#{situation}：結束碼 1，點名那張表，印出退回用的指令" do
        status, out = run("--push", shell: shell("last_value" => [ true, production_rows(**changes) ]))
        expect([ status, out.include?(table), out.include?("/root/derived-before-20261024-153012.sql") ]).to eq([ 1, true, true ])
      end
    end
  end

  describe "推之前就停下，正式站不動" do
    it "開發資料庫沒有任何路線日：結束碼 1，什麼指令都沒跑" do
      status, out = run("--push")
      expect([ status, calls, out.include?("沒有任何路線日") ]).to eq([ 1, [], true ])
    end

    [
      [ "pg_dump 是 17、正式站是 16", { "pg_dump --version" => [ true, "pg_dump (PostgreSQL) 17.5\n" ] }, "17" ],
      [ "正式站的 schema 版本跟開發資料庫不同", { "server_version_num" => [ true, "160010\n20240101000000\n" ] }, "20240101000000" ],
      [ "連不上正式站", { "server_version_num" => [ false, "ssh: connect to host 203.0.113.5 port 22: Connection refused\n" ] }, "Connection refused" ],
      [ "備份失敗", { "pg_dump -U website" => [ false, "No space left on device\n" ] }, "No space left on device" ]
    ].each do |situation, overrides, reason|
      it "#{situation}：結束碼 1，印出原因，沒有換掉正式站" do
        store_day
        status, out = run("--push", shell: shell(**overrides))
        expect([ status, out.include?(reason), calls.map(&:first).grep(/single-transaction/) ]).to eq([ 1, true, [] ])
      end
    end
  end

  describe "--push 前比對正式站的路線日" do
    before { store_day }

    # The answer of the version query when production also stores `route_days`, "<route Id>|<day>" each.
    def production_with(*route_days) = shell("server_version_num" => [ true, [ "160010", schema_version, *route_days ].join("\n") + "\n" ])

    def replacing_calls = calls.map(&:first).grep(/pg_dump -U postgres|pg_dump -U website|single-transaction/)

    it "正式站多一個這台沒有的 2026-10-20：結束碼 1，列出 9001 的那一天，說要重算用 bin/nightly-load --recompute，不匯出、不備份、不換" do
      status, out = run("--push", shell: production_with("9001|2026-10-19", "9001|2026-10-20"))
      expect([ status, out.include?("9001：2026-10-20 到 2026-10-20，1 天"), out.include?("bin/nightly-load --recompute"), replacing_calls ]).to eq([ 1, true, true, [] ])
    end

    it "正式站跟這台一樣：照樣匯出、備份、換掉、比對，結束碼 0" do
      status, = run("--push", shell: production_with("9001|2026-10-19"))
      expect([ status, replacing_calls.size ]).to eq([ 0, 3 ])
    end

    it "正式站回了讀不懂的一行：結束碼 1，印出那一行，不推" do
      status, out = run("--push", shell: production_with("WARNING: no such table"))
      expect([ status, out.include?("WARNING: no such table"), replacing_calls ]).to eq([ 1, true, [] ])
    end

    it "schema 版本也不同時先報 schema 版本" do
      _, out = run("--push", shell: shell("server_version_num" => [ true, "160010\n20240101000000\n9001|2026-10-20\n" ]))
      expect([ out.include?("20240101000000"), out.include?("--recompute") ]).to eq([ true, false ])
    end
  end

  it "看不懂的參數：印用法，結束碼 1，什麼指令都沒跑" do
    status, out = run("--force")
    expect([ status, calls, out.include?("用法") ]).to eq([ 1, [], true ])
  end

  it "bin/push-derived 只從開發資料庫推：RAILS_ENV 是別的環境時不載入 Rails，結束碼 1" do
    _, stderr, status = Open3.capture3({ "RAILS_ENV" => "production" }, RbConfig.ruby, Rails.root.join("bin/push-derived").to_s)
    expect([ status.exitstatus, stderr.include?("development") ]).to eq([ 1, true ])
  end
end
