require "rails_helper"
require "rake"
require_relative "../support/duckdb"

RSpec.describe DerivedLoadCommand, :duckdb, type: :model do
  let(:base_env) { { "TURNAROUND_DATA" => DuckdbHelpers::FIXTURE_DATA, "ROUTE" => "9001", "PATH" => ENV.fetch("PATH") } }

  # Runs the command and returns its exit status and everything it printed.
  def run_command(env)
    out = StringIO.new
    status = described_class.new(base_env.merge(env).compact, out:).run
    [ status, out.string ]
  end

  def stored_days = RouteDay.order(:day).pluck(:day).map(&:iso8601)

  describe "用法錯誤" do
    [ { "ROUTE" => nil, "DAY" => "2026-10-19" }, { "TURNAROUND_DATA" => nil, "DAY" => "2026-10-19" },
      { "FROM" => "2026-10-19" }, { "FROM" => "2026-10-20", "TO" => "2026-10-19" }, { "DAY" => "2026-13-01" } ].each do |env|
      it "#{env.inspect}：印用法、結束碼非零、什麼都不寫" do
        status, out = run_command(env)
        expect([ status.zero?, out.include?("用法"), stored_days ]).to eq([ false, true, [] ])
      end
    end
  end

  it "ROUTE 是別條路線的成員（test 設定的 9050 掛在 9001 底下）：說它是 9001 那一頁的附屬路線、請用 ROUTE=9001，結束碼非零、什麼都不寫" do
    status, out = run_command("ROUTE" => "9050", "DAY" => "2026-10-23")
    expect([ status.zero?, out.lines.first.chomp, stored_days ]).to eq([ false, "9050 是 9001 那一頁的附屬路線，請用 ROUTE=9001", [] ])
  end

  it "ROUTE 是有成員的頁面路線時，成員的趟次一起寫進同一個路線日：2026-10-23 的 9001 寫入 3 趟" do
    status, out = run_command("DAY" => "2026-10-23")
    expect([ status, out.lines.first[/趟次 \d+/], RouteDay.sole.member_names, Trip.pluck(:route_id).tally ]).to eq([ 0, "趟次 3", { "9050" => "測試幹線經己站" }, { 9050 => 2, 9001 => 1 } ])
  end

  it "PATH 裡沒有 duckdb：說明需要 DuckDB CLI 與安裝方式，結束碼非零" do
    status, out = run_command("DAY" => "2026-10-19", "PATH" => path_without_duckdb)
    expect([ status.zero?, out.include?("brew install duckdb"), stored_days ]).to eq([ false, true, [] ])
  end

  it "寫入一天：印出那一天的趟次、折返停留、趟次站筆數與兩端的公廁間數、靜止格數，結束碼 0" do
    status, out = run_command("DAY" => "2026-10-19")
    expect([ status, out.lines.first.chomp ]).to eq([ 0, "2026-10-19 寫入：趟次 27、折返停留 18、趟次站 96、兩端公廁 5 間、靜止格 1 格" ])
  end

  it "讀檔視窗還沒結束的日子失敗，說明缺哪個小時檔，那一天不寫" do
    status, out = run_command("DAY" => "2026-10-20")
    expect([ status.zero?, out.lines.first.include?("bus_event/2026-10-21/01.jsonl"), stored_days ]).to eq([ false, true, [] ])
  end

  describe "資料根目錄缺東西時" do
    # A data root in `dir` that links the fixture's given feeds and external
    # snapshot folders, so an example can leave some out.
    def data_root(dir, feeds: %w[bus_event bus_seat_event bus_data static], externals: %w[taipei-mrt-exits public-toilets office-calendar])
      feeds.each { File.symlink(File.join(DuckdbHelpers::FIXTURE_DATA, it), File.join(dir, it)) }
      FileUtils.mkdir_p(File.join(dir, "external"))
      externals.each { File.symlink(File.join(DuckdbHelpers::FIXTURE_DATA, "external", it), File.join(dir, "external", it)) }
      dir
    end

    {
      "三種快照都沒有" => [ { externals: [] }, "bin/rails external:mrt_exits" ],
      "有辦公日曆、沒有捷運出入口與公廁快照" => [ { externals: %w[office-calendar] }, "bin/rails external:mrt_exits" ],
      "有捷運出入口快照與辦公日曆、沒有公廁快照" => [ { externals: %w[taipei-mrt-exits office-calendar] }, "bin/rails external:public_toilets" ],
      "只有捷運出入口快照" => [ { externals: %w[taipei-mrt-exits] }, "bin/rails external:public_toilets" ],
      "有捷運出入口與公廁快照、沒有辦公日曆" => [ { externals: %w[taipei-mrt-exits public-toilets] }, "bin/rails external:office_calendar YEAR=2026" ],
      "當天有 bus_event、沒有 bus_data 小時檔" => [ { feeds: %w[bus_event bus_seat_event static] }, "bus_data/2026-10-19" ]
    }.each do |situation, (options, message)|
      it "#{situation}：那一天失敗，訊息含 #{message}，什麼都不寫" do
        status, out = Dir.mktmpdir { run_command("DAY" => "2026-10-19", "TURNAROUND_DATA" => data_root(it, **options)) }
        expect([ status.zero?, out.lines.first.include?(message), stored_days ]).to eq([ false, true, [] ])
      end
    end

    # Like data_root, with a static snapshot of 2026-10-19 that has every fixture file but GetProvider.gz.
    def data_root_without_providers(dir)
      static = File.join(data_root(dir, feeds: %w[bus_event bus_seat_event bus_data]), "static/2026-10-19").tap { FileUtils.mkdir_p(it) }
      %w[GetRoute.gz GetStop.gz GetPathDetail.gz GetBusShape.gz].each { File.symlink(File.join(DuckdbHelpers::FIXTURE_DATA, "static/2026-10-19", it), File.join(static, it)) }
      dir
    end

    it "靜態快照沒有 GetProvider.gz：那一天照樣寫入，先印缺檔那一行" do
      status, out = Dir.mktmpdir { run_command("DAY" => "2026-10-19", "TURNAROUND_DATA" => data_root_without_providers(it)) }
      expect([ status, out.lines.first.include?("GetProvider.gz"), stored_days ]).to eq([ 0, true, [ "2026-10-19" ] ])
    end
  end

  it "範圍回補停在第一個失敗的日子：10-19 寫入、10-20 失敗、10-21 不跑，最後列出寫入的日子" do
    status, out = run_command("FROM" => "2026-10-19", "TO" => "2026-10-21")
    expect([ status.zero?, out.lines.map { it[/\A[^：]+：/] }, stored_days ]).to eq(
      [ false, [ "2026-10-19 寫入：", "2026-10-20 失敗：", "寫入的日子：" ], [ "2026-10-19" ] ]
    )
  end

  # Executes a rake task of the app and returns the status it exits with.
  def rake_exit_status(name)
    Rails.application.load_tasks if Rake::Task.tasks.none? { it.name == name }
    Rake::Task[name].execute
  rescue SystemExit => e
    e.status
  end

  it "rake task derived:load 交給這個指令執行，結束碼是指令回傳的值" do
    allow(described_class).to receive(:new).and_return(instance_double(described_class, run: 3))
    expect(rake_exit_status("derived:load")).to eq(3)
  end
end
