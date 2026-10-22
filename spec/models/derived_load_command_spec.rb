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

  it "PATH 裡沒有 duckdb：說明需要 DuckDB CLI 與安裝方式，結束碼非零" do
    status, out = run_command("DAY" => "2026-10-19", "PATH" => path_without_duckdb)
    expect([ status.zero?, out.include?("brew install duckdb"), stored_days ]).to eq([ false, true, [] ])
  end

  it "寫入一天：印出那一天的趟次、折返停留與趟次站筆數，結束碼 0" do
    status, out = run_command("DAY" => "2026-10-19")
    expect([ status, out.lines.first.chomp ]).to eq([ 0, "2026-10-19 寫入：趟次 27、折返停留 19、趟次站 96" ])
  end

  it "讀檔視窗還沒結束的日子失敗，說明缺哪個小時檔，那一天不寫" do
    status, out = run_command("DAY" => "2026-10-20")
    expect([ status.zero?, out.lines.first.include?("bus_event/2026-10-21/01.jsonl"), stored_days ]).to eq([ false, true, [] ])
  end

  describe "資料根目錄沒有捷運出入口快照時" do
    # The fixture's raw files without its external/ folder.
    def data_root_without_snapshot(dir)
      %w[bus_event bus_seat_event static].each { File.symlink(File.join(DuckdbHelpers::FIXTURE_DATA, it), File.join(dir, it)) }
      dir
    end

    it "那一天失敗，說要先跑 bin/rails external:mrt_exits，什麼都不寫" do
      status, out = Dir.mktmpdir { run_command("DAY" => "2026-10-19", "TURNAROUND_DATA" => data_root_without_snapshot(it)) }
      expect([ status.zero?, out.lines.first.include?("bin/rails external:mrt_exits"), stored_days ]).to eq([ false, true, [] ])
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
