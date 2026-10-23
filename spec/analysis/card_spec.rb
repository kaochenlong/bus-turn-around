require "spec_helper"
require "time"
require_relative "../support/duckdb"

RSpec.describe "bin/health-card 產出的卡" do
  # Runs on the fixture route and returns the card, the inspection directory
  # and the bytes of every CSV written there.
  def generate(*args, env: {})
    Dir.mktmpdir("health-card-card") do |dir|
      out, inspect_dir = %w[card.md inspect].map { File.join(dir, it) }
      _stdout, stderr, status = run_health_card("--data", DuckdbHelpers::FIXTURE_DATA, "--route", "9001", *args,
                                                "--out", out, "--inspect-dir", inspect_dir, env:)
      raise "bin/health-card exited #{status.exitstatus}: #{stderr}" unless status.success?

      { card: File.read(out), inspect_dir:, csvs: Dir.children(inspect_dir).sort.to_h { [ it, File.binread(File.join(inspect_dir, it)) ] } }
    end
  end

  # Examples that only read an output share one run per argument list.
  def shared_output(*args) = DuckdbHelpers.shared_runs[args] ||= generate(*args).freeze

  let(:output) { shared_output("--day", "2026-10-19") }

  def section(heading, card = output[:card]) = card[/^## #{heading}\n(.*?)(?=^## |\z)/m, 1]

  # The cells of every table row in `text`, separator rows left out.
  def table_rows(text)
    text.lines.grep(/\A\|/).grep_v(/\A(\|\s*:?-+:?\s*)+\|\s*\z/).map { it.strip.delete_prefix("|").delete_suffix("|").split("|").map(&:strip) }
  end

  def rows_starting_with(text, *keys) = table_rows(text).select { keys.include?(it.first) }

  # The text after "label：" on the bullet line that starts with the label.
  def bullet(text, label) = text[/^- #{Regexp.escape(label)}：(.*)$/, 1]

  describe "結構" do
    it "六節依序各出現一次：資料品質、趟次、折返停留、載客剖面、資料限制、資料來源與授權" do
      expect(output[:card].scan(/^## (.+)$/).flatten).to eq(%w[資料品質 趟次 折返停留 載客剖面 資料限制 資料來源與授權])
    end

    it "標題列的資料日與靜態快照日各自照參數" do
      header = shared_output("--day", "2026-10-20", "--static-day", "2026-10-19")[:card][/\A.*?(?=^## )/m]
      expect([ bullet(header, "資料日"), bullet(header, "靜態快照日") ]).to eq(%w[2026-10-20 2026-10-19])
    end

    it "標題列有路線名與起迄，附屬路線逐條列出名稱與 pathAttributeId" do
      header = output[:card][/\A.*?(?=^## )/m]
      expect([ header.lines.first.include?("測試幹線"), bullet(header, "起迄"), bullet(header, "附屬路線") ]).to eq(
        [ true, "甲站－戊站", "測試幹線（9001）、測試幹線去程半（9002）、測試幹線反程缺站（9003）" ]
      )
    end

    it "產出時刻是台北時間，機器的時區設成 UTC 也一樣" do
      started = Time.now.floor
      shown = bullet(generate("--day", "2026-10-19", env: { "TZ" => "UTC" })[:card], "產出時刻")[/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/]
      expect(Time.strptime("#{shown} +08:00", "%Y-%m-%d %H:%M:%S %z").between?(started, Time.now)).to be(true)
    end

    it "卡裡沒有任何車牌：trips.csv 的 TEST-0001 到 TEST-0004 都不在卡上" do
      bus_ids = output[:csvs].fetch("trips.csv").lines.drop(1).map { it[/\A[^,]+/] }.uniq
      expect([ bus_ids, bus_ids.select { output[:card].include?(it) } ]).to eq([ %w[TEST-0001 TEST-0002 TEST-0003 TEST-0004], [] ])
    end

    it "卡裡沒有檔案路徑：資料根目錄、檢查目錄、暫存目錄與 repo 的路徑都不在卡上" do
      paths = [ DuckdbHelpers::FIXTURE_DATA, output[:inspect_dir], Dir.tmpdir, DuckdbHelpers::ROOT ]
      expect(paths.select { output[:card].include?(it) }).to eq([])
    end

    it "資料來源與授權一節逐字收錄 docs/data-sources.md 授權那一節的三段顯名聲明，各成一段" do
      licence = File.read(File.join(DuckdbHelpers::ROOT, "docs/data-sources.md"))[/^### 授權\n(.*?)(?=^#)/m, 1]
      paragraphs = licence.lines.grep(/\A> /).map { it.delete_prefix("> ").chomp }
      expect(paragraphs.map { section("資料來源與授權").lines(chomp: true).include?(it) }).to eq([ true, true, true ])
    end

    it "連跑兩次：卡只有產出時刻那一行可能不同，五個 CSV 逐位元組相同" do
      first, second = Array.new(2) { generate("--day", "2026-10-19") }
      changed = first[:card].lines.zip(second[:card].lines).reject { |a, b| a == b }.flatten.reject { it.include?("產出時刻") }
      expect([ first[:card].lines.size - second[:card].lines.size, first[:card].lines.count { it.include?("產出時刻") },
               changed, first[:csvs] == second[:csvs], first[:csvs].size ]).to eq([ 0, 1, [], true, 5 ])
    end
  end

  describe "資料品質一節" do
    let(:quality) { section("資料品質") }

    it "每支 feed 讀到與去掉的筆數" do
      expect(rows_starting_with(quality, "bus_event", "bus_seat_event")).to eq([ %w[bus_event 276 1], %w[bus_seat_event 130 2] ])
    end

    it "各附屬路線的站序比對結果、比對的方向、趟數、佔趟次的比例，以及是那台車當天第一趟與最後一趟的趟數" do
      expect(rows_starting_with(quality, "測試幹線", "測試幹線去程半", "測試幹線反程缺站")).to eq(
        [ [ "測試幹線", "9001", "一樣", "去程、返程", "25", "92.6%", "4", "4" ], [ "測試幹線去程半", "9002", "一樣", "去程", "1", "3.7%", "0", "0" ],
          [ "測試幹線反程缺站", "9003", "不一樣", "返程", "1", "3.7%", "0", "0" ] ]
      )
    end

    it "每個方向的末站、完整趟次與終點後有離站事件的趟數" do
      expect(rows_starting_with(quality, "去程", "返程")).to eq([ %w[去程 戊站 13 11], %w[返程 甲站 9 9] ])
    end

    it "各完整性類別的趟數與合計" do
      expect(rows_starting_with(quality, *%w[complete missing_start missing_end missing_both 合計])).to eq(
        [ %w[complete 22], %w[missing_start 2], %w[missing_end 2], %w[missing_both 1], %w[合計 27] ]
      )
    end

    it "當天趟次裡到離站事件的 DutyStatus 分佈" do
      expect(rows_starting_with(quality, "1", "2")).to eq([ %w[1 243], %w[2 4] ])
    end

    it "讀檔視窗、對不到站序的事件、完整趟次的漏站率，以及 DutyStatus 2 跟趟末的對應" do
      labels = [ "讀檔視窗", "對不到站序的到離站事件", "完整趟次的漏站率", "最後一筆事件是 DutyStatus 2 的趟次", "DutyStatus 2 的事件落在趟末" ]
      expect(labels.map { bullet(quality, it) }).to eq(
        [ "2026-10-18 22:00 起，到 2026-10-20 02:00 前", "1 筆", "0 / 110 站（0.0%）", "3 / 27 趟（11.1%）", "3 / 4 筆（75.0%）" ]
      )
    end
  end

  describe "趟次一節" do
    let(:trips) { section("趟次") }

    it "每個方向與時段的趟數與完整趟數，時段標出起點小時的範圍" do
      expect(rows_starting_with(trips, "去程", "返程", "合計")).to eq(
        [ [ "去程", "早尖峰 07:00–08:59", "5", "4" ], [ "去程", "日間 09:00–16:59", "4", "4" ], [ "去程", "晚尖峰 17:00–18:59", "2", "2" ],
          [ "去程", "其餘", "3", "3" ], [ "返程", "早尖峰 07:00–08:59", "3", "2" ], [ "返程", "日間 09:00–16:59", "8", "5" ],
          [ "返程", "晚尖峰 17:00–18:59", "1", "1" ], [ "返程", "其餘", "1", "1" ], [ "合計", "", "27", "22" ] ]
      )
    end

    it "起點改用到站時刻與終點改用離站時刻的趟數" do
      labels = [ "起站沒有離站事件、起點改用到站時刻", "末站沒有到站事件、終點改用離站時刻" ]
      expect(labels.map { bullet(trips, it) }).to eq([ "1 趟", "1 趟" ])
    end
  end

  describe "折返停留一節" do
    let(:layovers) { section("折返停留") }

    it "整體與按結束那趟方向分列的筆數、p10、p50、p90 與不到 15 分鐘的比例，接著是六個分箱" do
      expect(rows_starting_with(layovers, "全部", "去程結束", "返程結束")).to eq(
        [ %w[全部 18 11.4 14.5 64.7 50.0%], %w[去程結束 10 11.8 13.5 28.1 60.0%], %w[返程結束 8 11.4 19.0 144.1 37.5%],
          %w[全部 0 0 9 6 1 2], %w[去程結束 0 0 6 3 1 0], %w[返程結束 0 0 3 3 0 2] ]
      )
    end

    it "不算折返停留的配對分四類計數，班次串列出起訖與趟數而不列車牌" do
      expect([ bullet(layovers, "不算折返停留的相鄰配對"), bullet(layovers, "班次串"), rows_starting_with(layovers, "1") ]).to eq(
        [ "本趟沒有到末站 3 組、下一趟不是從起站出發 1 組、兩趟之間跑了別的路線 1 組、差值為負 0 組", "1 串，涉及 1 台車", [ [ "1", "2026-10-19 06:00", "2026-10-19 11:30", "5" ] ] ]
      )
    end

    it "說明寫出兩趟之間跑了別的路線的門檻：經過至少 3 個站" do
      expect(layovers).to include("經過至少 3 個站")
    end

    it "沒有折返停留時百分位數與比例是 —，沒有班次串就不列串表" do
      sparse = section("折返停留", shared_output("--day", "2026-10-18", "--static-day", "2026-10-19")[:card])
      expect([ rows_starting_with(sparse, "全部").first, bullet(sparse, "班次串"), rows_starting_with(sparse, "1") ]).to eq(
        [ %w[全部 0 — — — —], "0 串，涉及 0 台車", [] ]
      )
    end
  end

  describe "載客剖面一節" do
    let(:profile) { section("載客剖面") }

    it "涵蓋率，以及負值與跳動的筆數" do
      labels = [ "有車上人數的趟次", "有車上人數的觀測站", "負值", "相鄰兩個有人數的站相差超過 30 人" ]
      expect(labels.map { bullet(profile, it) }).to eq([ "20 / 27 趟（74.1%）", "96 / 126 站（76.2%）", "1 筆", "1 次" ])
    end

    it "歸零檢查依方向各有起站上客前與末站下客後：站名、有記錄與沒有記錄的趟數、等於 0、不超過 2 人、最大值" do
      expect(rows_starting_with(profile, "起站上客前（到站記錄）", "末站下客後（離站記錄）")).to eq(
        [ %w[起站上客前（到站記錄） 去程 甲站 2 11 100.0% 100.0% 0], %w[末站下客後（離站記錄） 去程 戊站 2 11 50.0% 100.0% 2],
          %w[起站上客前（到站記錄） 返程 戊站對面 1 8 100.0% 100.0% 0], %w[末站下客後（離站記錄） 返程 甲站 0 9 — — —] ]
      )
    end

    it "歸零檢查的說明帶出往趟次起訖外找記錄的分鐘數" do
      expect(profile).to match(/前 60 分鐘內.*後 60 分鐘內/)
    end

    it "剖面表每列是一個方向的一站，依站序排，涵蓋 profile.csv 的每一站" do
      expect(rows_starting_with(profile, "去程", "返程").map { it.first(3) }).to eq(
        [ %w[去程 0 甲站], %w[去程 1 乙站], %w[去程 2 丙站], %w[去程 3 丁站], %w[去程 4 戊站],
          %w[返程 5 戊站對面], %w[返程 6 丁站對面], %w[返程 7 丙站對面], %w[返程 8 乙站對面], %w[返程 9 甲站] ]
      )
    end

    it "剖面表每格是那個時段的中位數 / p90（有人數的趟數），沒有人數的時段是 —" do
      expect(rows_starting_with(profile, "去程", "返程").values_at(2, 7)).to eq(
        [ [ "去程", "2", "丙站", "14.5 / 17.7（4）", "9.5 / 10.0（4）", "20.0 / 20.0（1）", "6.0 / 7.6（3）" ],
          [ "返程", "7", "丙站對面", "12.0 / 12.8（3）", "11.0 / 31.9（4）", "—", "15.0 / 15.0（1）" ] ]
      )
    end
  end
end
