require "rails_helper"
require "rake"
require_relative "../support/duckdb"

RSpec.describe RouteCardPrepareCommand, type: :model do
  let(:base_env) { { "TURNAROUND_DATA" => DuckdbHelpers::FIXTURE_DATA, "ROUTE" => "9001", "MONTH" => "2026-10" } }
  # Every day of the month but 10-31 is before the first day, so one stored day
  # makes the month ready.
  let(:derived_days) { DerivedDays.new(first_day: Date.new(2026, 10, 31), skipped_days: {}) }
  # Every day passes the raw file check.
  let(:raw_check) { Class.new { def self.check!(**) = nil } }

  # Runs the command and returns its exit status and everything it printed.
  def run_command(env = {})
    out = StringIO.new
    status = described_class.new(base_env.merge(env).compact, out:, now: Time.zone.parse("2026-11-02 09:00"), days: derived_days, check: raw_check).run
    [ status, out.string ]
  end

  def store_last_day = create(:route_day, day: Date.new(2026, 10, 31))

  describe "到齊的月份" do
    before { store_last_day }

    it "寫 version 1 那一列，結束碼 0" do
      status, = run_command
      expect([ status, RouteCard.sole.attributes.values_at("route_id", "month", "version") ]).to eq([ 0, [ 9001, Date.new(2026, 10, 1), 1 ] ])
    end

    it "列存涵蓋：這個月 20 個平日、11 個假日，載入 1 個假日" do
      run_command
      expect(RouteCard.sole.coverage.values_at("calendar_weekdays", "calendar_holidays", "loaded_weekdays", "loaded_holidays")).to eq([ 20, 11, 0, 1 ])
    end

    it "印出涵蓋與少的日子" do
      _, out = run_command
      expect(out).to include("20", "11", "10-01", "10-30", "還沒開始收資料")
    end

    it "再跑一次只更新那一列的涵蓋，不多一列" do
      create(:route_card, coverage: { "calendar_weekdays" => 1, "loaded_weekdays" => 1 })
      expect { run_command }.not_to change(RouteCard, :count)
    end

    it "更新的是 version 1：涵蓋換成新算的" do
      create(:route_card, coverage: { "calendar_weekdays" => 1, "loaded_weekdays" => 1 })
      run_command
      expect(RouteCard.sole.coverage.fetch("calendar_weekdays")).to eq(20)
    end

    it "別的版本不動" do
      create(:route_card, version: 2, coverage: { "calendar_weekdays" => 1, "loaded_weekdays" => 1 })
      run_command
      expect(RouteCard.order(:version).map { it.coverage.fetch("calendar_weekdays") }).to eq([ 20, 1 ])
    end
  end

  describe "印過的月份" do
    before { store_last_day }

    it "規格的例子：說印過了、指向 --revise，列不動，結束碼非零" do
      card = create(:route_card, :printed)
      before = card.reload.attributes
      status, out = run_command
      expect([ status, out.include?("印"), out.include?("--revise"), card.reload.attributes ]).to eq([ 1, true, true, before ])
    end

    it "更正失敗留著的 v2 也一樣：這個月印過就不收" do
      create(:route_card, :printed)
      create(:route_card, version: 2)
      expect(run_command.first).to eq(1)
    end
  end

  describe "還有在等的日子" do
    it "點名那一天、不寫、結束碼非零" do
      status, out = run_command
      expect([ status.zero?, out.include?("2026-10-31"), RouteCard.count ]).to eq([ false, true, 0 ])
    end
  end

  describe "用法錯誤：印用法、結束碼非零、什麼都不寫" do
    { "沒有 ROUTE" => { "ROUTE" => nil },
      "ROUTE 不是數字" => { "ROUTE" => "abc" },
      "沒有 MONTH" => { "MONTH" => nil },
      "MONTH 沒有這個月" => { "MONTH" => "2026-13" },
      "MONTH 帶了日" => { "MONTH" => "2026-10-01" },
      "沒有 TURNAROUND_DATA" => { "TURNAROUND_DATA" => nil },
      "ROUTE 不是頁面路線" => { "ROUTE" => "19108" } }.each do |situation, env|
      it situation do
        status, out = run_command(env)
        expect([ status.zero?, out.include?("用法"), RouteCard.count ]).to eq([ false, true, 0 ])
      end
    end

    it "ROUTE 是別條路線的成員：點名頁面路線" do
      status, out = run_command("ROUTE" => "9050")
      expect([ status.zero?, out.lines.first.chomp, out.include?("用法") ]).to eq([ false, "9050 是 9001 那一頁的附屬路線，請用 ROUTE=9001", true ])
    end
  end

  it "資料根目錄沒有那一年的辦公日曆：說要先跑哪個指令，結束碼非零" do
    status, out = Dir.mktmpdir { run_command("TURNAROUND_DATA" => it) }
    expect([ status.zero?, out.include?("bin/rails external:office_calendar YEAR=2026"), RouteCard.count ]).to eq([ false, true, 0 ])
  end

  # Executes a rake task of the app and returns the status it exits with.
  def rake_exit_status(name)
    Rails.application.load_tasks if Rake::Task.tasks.none? { it.name == name }
    Rake::Task[name].execute
  rescue SystemExit => e
    e.status
  end

  it "rake task cards:prepare 交給這個指令執行，結束碼是指令回傳的值" do
    allow(described_class).to receive(:new).and_return(instance_double(described_class, run: 3))
    expect(rake_exit_status("cards:prepare")).to eq(3)
  end
end
