require "rails_helper"
require_relative "../support/duckdb"

RSpec.describe MonthlyCardsCommand, type: :model do
  let(:dir) { Dir.mktmpdir("monthly-cards") }
  let(:tunnel) { class_double(ProductionTunnel) }
  let(:opened) { [] }
  let(:printer) { instance_double(CardPrinter) }
  let(:printed) { [] }

  before do
    FileUtils.mkdir_p(data_root)
    FileUtils.ln_s(File.join(DuckdbHelpers::FIXTURE_DATA, "external"), File.join(data_root, "external"))
    allow(tunnel).to receive(:open) do |**target, &block|
      opened << target
      block.call
    end
    allow_printing
  end

  after { FileUtils.remove_entry(dir) }

  # A data root with the office calendar of the fixtures and room to write.
  def data_root = File.join(dir, "data")

  def november = Date.new(2026, 11, 1)

  def pdf = "%PDF-1.7 測試用的月卡".b

  def print_result = CardPrinter::Printed.new(bytes: pdf, program_version: "abc1234", summary: { "weekdays" => 21 }, page_seconds: 3.24)

  # The printer answers for every card, except that it fails for route `failing`.
  def allow_printing(failing: nil, error: CardPrinter::Failure.new("月卡頁回 500"))
    allow(printer).to receive(:print) do |card|
      printed << card.identity
      raise error if card.route_id == failing

      print_result
    end
  end

  def taipei(time) = Time.find_zone("Taipei").parse(time)

  def deploy_config = { "accessories" => { "db" => { "host" => "203.0.113.5" } }, "proxy" => { "host" => "bus.example" } }

  # Every day but the last of November is before the first day collected, so the
  # month waits for 2026-11-30 alone.
  def derived_days = DerivedDays.new(first_day: Date.new(2026, 11, 30), skipped_days: {})

  def first_november = CardMonths.new(first_month: november)

  # Every day passes the raw file check.
  def raw_check = Class.new { def self.check!(**) = nil }

  def base_env = { "TURNAROUND_DATA" => data_root, "WEBSITE_DATABASE_PASSWORD" => "secret", "DB_PORT" => "15432" }

  def lock_path = File.join(dir, "lock")

  # Runs the command when 2026-11-30 is just loadable, and returns its exit status
  # and everything it printed.
  def run_command(*argv, env: {}, now: taipei("2026-12-01 03:00"), route_ids: [ 15373 ], months: first_november, days: derived_days, **options)
    out = StringIO.new
    status = described_class.new(argv, env: base_env.merge(env).compact, out:, now:, route_ids:, months:, days:, check: raw_check, printer:, tunnel:,
                                       lock_path:, deploy: deploy_config, **options).run
    [ status, out.string ]
  end

  # 2026-11 of the route is ready to print.
  def store_month(route_id = 15373, **attributes)
    create(:route_day, route_id:, day: Date.new(2026, 11, 30), rest_windows_loaded: true, published_schedule_day: Date.new(2026, 11, 30), **attributes)
  end

  def card(route_id = 15373, version = 1) = RouteCard.find_by(route_id:, month: november, version:)

  describe "開轉送之前就停：結束碼 1、不開轉送" do
    def stopped(*argv, **options)
      status, out = run_command(*argv, **options)
      [ status, opened, out ]
    end

    it "看不懂的參數：印用法" do
      expect(stopped("--foo")).to match([ 1, [], a_string_including("看不懂的參數：--foo", "用法") ])
    end

    it "兩個參數：印用法" do
      expect(stopped("--print", "--print")).to match([ 1, [], a_string_including("用法") ])
    end

    it "沒有 TURNAROUND_DATA" do
      expect(stopped(env: { "TURNAROUND_DATA" => nil })).to match([ 1, [], a_string_including("沒有 TURNAROUND_DATA") ])
    end

    it "沒有資料庫密碼" do
      expect(stopped(env: { "WEBSITE_DATABASE_PASSWORD" => nil })).to match([ 1, [], a_string_including("沒有 WEBSITE_DATABASE_PASSWORD") ])
    end

    it "埠不是數字" do
      expect(stopped(env: { "DB_PORT" => "abc" })).to match([ 1, [], a_string_including("不是埠號：abc") ])
    end

    it "config/route_cards.yml 壞了：印原因" do
      allow(CardMonths).to receive(:from_config).and_raise(CardMonths::InvalidConfiguration, "first_month 壞了")
      expect(stopped(months: nil)).to eq([ 1, [], "first_month 壞了\n" ])
    end

    it "config/derived_days.yml 壞了：印原因" do
      allow(DerivedDays).to receive(:from_config).and_raise(DerivedDays::InvalidConfiguration, "first_day 壞了")
      expect(stopped(days: nil)).to eq([ 1, [], "first_day 壞了\n" ])
    end

    it "--print 而 deploy 設定沒有 proxy.host，也沒有 CARD_BASE_URL：印原因" do
      status, out = run_command("--print", printer: nil, deploy: deploy_config.except("proxy"))
      expect([ status, opened, out ]).to match([ 1, [], a_string_including("proxy.host") ])
    end
  end

  it "另一個拿著鎖：說另一個還在跑、這次不做，結束碼 0，不開轉送" do
    status = File.open(lock_path, File::RDWR | File::CREAT) do |held|
      held.flock(File::LOCK_EX)
      run_command("--print").first
    end
    expect([ status, opened, printed ]).to eq([ 0, [], [] ])
  end

  it "migration 版本不一致：結束碼 1，不印" do
    store_month
    status, out = run_command("--print", checkout_versions: [ 1 ])
    expect([ status, out.include?("這次不印"), printed ]).to eq([ 1, true, [] ])
  end

  describe "不加參數：只印計畫" do
    it "規格的例子：2026-12 的台北月、第一個月 2026-11：每條路線一行，什麼都不寫" do
      store_month
      status, out = run_command(route_ids: [ 15373, 10712 ], now: taipei("2026-12-15 12:00"))
      expect([ status, out.lines.grep(/^路線/).map { it[/\A路線 \d+ \d{4}-\d{2}/] }, RouteCard.count, printed ]).to eq([ 0, [ "路線 15373 2026-11", "路線 10712 2026-11" ], 0, [] ])
    end

    it "還沒有到期的月份：說第一份是哪個月，沒有路線的行，結束碼 0" do
      status, out = run_command(now: taipei("2026-11-02 12:00"))
      expect([ status, out.lines.grep(/^路線/), out.include?("第一份是 2026-11") ]).to eq([ 0, [], true ])
    end

    it "規格的當月：2026-12-15 時 2026-12 沒有那一行" do
      _, out = run_command(now: taipei("2026-12-15 12:00"))
      expect(out).not_to include("2026-12：")
    end

    it "跨兩個月：每條路線每個月一行" do
      _, out = run_command(now: taipei("2027-01-15 12:00"))
      expect(out.lines.grep(/^路線/).map { it[/\A路線 \d+ \d{4}-\d{2}/] }).to eq([ "路線 15373 2026-11", "路線 15373 2026-12" ])
    end

    it "到齊：可以印" do
      store_month
      _, out = run_command
      expect(out).to include("路線 15373 2026-11：到齊可印\n")
    end

    it "印過：哪一版" do
      store_month
      create(:route_card, :printed, route_id: 15373, month: november)
      create(:route_card, :printed, route_id: 15373, month: november, version: 2)
      _, out = run_command
      expect(out).to include("路線 15373 2026-11：已印 v2\n")
    end

    it "還在等：哪幾天" do
      _, out = run_command
      expect(out).to include("路線 15373 2026-11：還在等 11-30\n")
    end

    it "存好的日子還沒重算：哪幾天" do
      store_month(rest_windows_loaded: false)
      _, out = run_command
      expect(out).to include("路線 15373 2026-11：數字還沒重算 11-30\n")
    end

    it "還沒讀公告的日子也算還沒重算" do
      store_month(published_schedule_day: nil)
      _, out = run_command
      expect(out).to include("數字還沒重算 11-30")
    end

    it "別的月份還沒重算不影響這個月" do
      store_month
      create(:route_day, route_id: 15373, day: Date.new(2026, 10, 31), rest_windows_loaded: false)
      _, out = run_command
      expect(out).to include("到齊可印")
    end
  end

  describe "--print" do
    it "規格的到齊：version 1 有 PDF、SHA-256、位元組數、摘要、程式版本與印製時間" do
      store_month
      status, = run_command("--print")
      row = card.reload
      expect([ status, row.route_card_pdf.pdf, row.pdf_bytes, row.summary, row.program_version, row.printed_at.present? ]).to eq([ 0, pdf, pdf.bytesize, { "weekdays" => 21 }, "abc1234", true ])
    end

    it "印好的那一行帶大小與開頁面的秒數" do
      store_month
      _, out = run_command("--print")
      expect(out).to include("路線 15373 2026-11：印好 v1，#{pdf.bytesize} bytes，開頁面 3.2 秒\n")
    end

    it "存的是這一次算的涵蓋" do
      store_month
      run_command("--print")
      expect(card.coverage.values_at("calendar_weekdays", "loaded_holidays", "loaded_weekdays")).to eq([ 21, 0, 1 ])
    end

    it "印之前涵蓋已經存好：頁面要讀的就是這一份" do
      store_month
      seen = []
      allow(printer).to receive(:print) { |route_card| seen << RouteCard.find(route_card.id).coverage["loaded_weekdays"]; print_result }
      run_command("--print")
      expect(seen).to eq([ 1 ])
    end

    it "已經有沒印的列：用那一列，換上新算的涵蓋" do
      store_month
      create(:route_card, route_id: 15373, month: november, coverage: { "loaded_weekdays" => 99, "calendar_weekdays" => 99 })
      run_command("--print")
      expect([ RouteCard.count, card.coverage["loaded_weekdays"], card ]).to match([ 1, 1, be_printed ])
    end

    it "規格的已印：不呼叫印表機，列不動，結束碼 0" do
      store_month
      row = create(:route_card, :printed, route_id: 15373, month: november)
      before = row.reload.updated_at
      status, = run_command("--print")
      expect([ status, printed, row.reload.updated_at ]).to eq([ 0, [], before ])
    end

    it "規格的還在等：不呼叫印表機，輸出點名那一天，結束碼 0" do
      status, out = run_command("--print")
      expect([ status, printed, out.include?("11-30"), RouteCard.count ]).to eq([ 0, [], true, 0 ])
    end

    it "規格的一天沒重算：不呼叫印表機，輸出點名那一天，結束碼 0" do
      store_month(rest_windows_loaded: false)
      status, out = run_command("--print")
      expect([ status, printed, out.include?("11-30"), RouteCard.count ]).to eq([ 0, [], true, 0 ])
    end

    it "規格的一條失敗：另一條照印，輸出點名失敗的路線，結束碼 1" do
      store_month(15373)
      store_month(10712)
      allow_printing(failing: 15373)
      status, out = run_command("--print", route_ids: [ 15373, 10712 ])
      expect([ status, card(10712), out.include?("路線 15373 2026-11：失敗：月卡頁回 500") ]).to match([ 1, be_printed, true ])
    end

    it "失敗的那一條留著沒有 PDF 的列" do
      store_month
      allow_printing(failing: 15373)
      run_command("--print")
      expect([ card.printed?, RouteCardPdf.count ]).to eq([ false, 0 ])
    end

    it "料想不到的錯誤也不擋下一條，訊息帶類別" do
      store_month(15373)
      store_month(10712)
      allow_printing(failing: 15373, error: ArgumentError.new("料想不到"))
      status, out = run_command("--print", route_ids: [ 15373, 10712 ])
      expect([ status, card(10712), out.include?("ArgumentError: 料想不到") ]).to match([ 1, be_printed, true ])
    end

    it "規格的當月：2026-12-15 不印 2026-12" do
      create(:route_day, route_id: 15373, day: Date.new(2026, 12, 14), rest_windows_loaded: true, published_schedule_day: Date.new(2026, 12, 14))
      run_command("--print", now: taipei("2026-12-15 12:00"), days: DerivedDays.new(first_day: Date.new(2026, 12, 14), skipped_days: {}))
      expect(printed).to eq([ "15373/2026-11/1" ])
    end

    it "最後印一行總數" do
      store_month(15373)
      create(:route_card, :printed, route_id: 10712, month: november)
      _, out = run_command("--print", route_ids: [ 15373, 10712, 10283 ])
      expect(out.lines.last.chomp).to eq("印好 1 份、失敗 0 份、還不能印 1 份、早就印過 1 份")
    end
  end

  describe "--revise" do
    def revise_env = { "ROUTE" => "15373", "MONTH" => "2026-11", "REASON" => "資料重算" }

    def printed_v1(**attributes) = create(:route_card, :printed, route_id: 15373, month: november, pdf: "第一版", **attributes)

    before { store_month }

    it "規格的例子：v2 有原因與 PDF，結束碼 0" do
      printed_v1
      status, = run_command("--revise", env: revise_env)
      expect([ status, card(15373, 2).revision_reason, card(15373, 2).route_card_pdf.pdf ]).to eq([ 0, "資料重算", pdf ])
    end

    it "規格的例子：v1 的位元組與列都不變" do
      first = printed_v1
      before = first.reload.attributes
      run_command("--revise", env: revise_env)
      expect([ first.reload.attributes, first.route_card_pdf.pdf ]).to eq([ before, "第一版".b ])
    end

    it "印好的那一行帶大小與開頁面的秒數" do
      printed_v1
      _, out = run_command("--revise", env: revise_env)
      expect(out).to include("印好 v2，#{pdf.bytesize} bytes，開頁面 3.2 秒")
    end

    it "v2 存的是這一次算的涵蓋" do
      printed_v1
      run_command("--revise", env: revise_env)
      expect(card(15373, 2).coverage["calendar_weekdays"]).to eq(21)
    end

    it "問印表機的是 v2：頁面讀的是版本最大的那一列" do
      printed_v1
      run_command("--revise", env: revise_env)
      expect(printed).to eq([ "15373/2026-11/2" ])
    end

    it "第一個月之前的月份也能更正：看的是有沒有印過，不是 first_month" do
      printed_v1
      expect(run_command("--revise", env: revise_env, months: CardMonths.new(first_month: Date.new(2027, 1, 1))).first).to eq(0)
    end

    { "REASON" => "沒有 REASON", "ROUTE" => "沒有 ROUTE", "MONTH" => "沒有 MONTH" }.each do |name, message|
      it "規格的缺原因（這裡缺 #{name}）：印用法，什麼都不寫，結束碼 1，不開轉送" do
        status, out = run_command("--revise", env: revise_env.merge(name => nil))
        expect([ status, out.include?(message), out.include?("用法"), RouteCard.count, opened ]).to eq([ 1, true, true, 0, [] ])
      end
    end

    it "原因是空字串也算缺" do
      expect(run_command("--revise", env: revise_env.merge("REASON" => " ")).last).to include("沒有 REASON")
    end

    it "月份格式不對：印用法" do
      expect(run_command("--revise", env: revise_env.merge("MONTH" => "2026-13")).last).to include("沒有 MONTH 或格式不對")
    end

    it "不是頁面路線：印用法，列出原因" do
      expect(run_command("--revise", env: revise_env.merge("ROUTE" => "9100")).last).to include("9100 不是頁面路線")
    end

    it "附屬路線：說要用哪一條" do
      allow(RoutePage).to receive(:member_of).with(19108).and_return(16111)
      expect(run_command("--revise", env: revise_env.merge("ROUTE" => "19108")).last).to include("請用 ROUTE=16111")
    end

    it "沒有印過的月份：用法錯誤，什麼都不寫，結束碼 1" do
      status, out = run_command("--revise", env: revise_env)
      expect([ status, out.include?("沒有印過"), RouteCard.count, printed ]).to eq([ 1, true, 0, [] ])
    end

    it "涵蓋還在等：失敗，不多一列" do
      printed_v1
      RouteDay.delete_all
      status, out = run_command("--revise", env: revise_env)
      expect([ status, out.include?("11-30"), RouteCard.count, printed ]).to eq([ 1, true, 1, [] ])
    end

    it "印失敗：結束碼 1，v2 留著沒有 PDF，v1 不動" do
      printed_v1
      allow_printing(failing: 15373)
      status, out = run_command("--revise", env: revise_env)
      expect([ status, out.include?("月卡頁回 500"), card(15373, 2).printed?, card(15373, 1).route_card_pdf.pdf ]).to eq([ 1, true, false, "第一版".b ])
    end

    it "規格的更正失敗之後：再跑一次用同一列，換上新的原因，沒有 v3" do
      printed_v1
      create(:route_card, route_id: 15373, month: november, version: 2, revision_reason: "舊原因")
      status, = run_command("--revise", env: revise_env)
      expect([ status, card(15373, 2).revision_reason, card(15373, 2).printed?, card(15373, 3) ]).to eq([ 0, "資料重算", true, nil ])
    end
  end

  describe "--sample" do
    def out_path = File.join(dir, "sample.pdf")

    def sample_env = { "ROUTE" => "15373", "MONTH" => "2026-11", "OUT" => out_path }

    it "規格的例子：第一個月之前的月份，沒有列：印到 OUT，之後沒有那一列" do
      store_month
      status, = run_command("--sample", env: sample_env, months: CardMonths.new(first_month: Date.new(2027, 1, 1)))
      expect([ status, File.binread(out_path), RouteCard.count ]).to eq([ 0, pdf, 0 ])
    end

    it "印的時候那一列在：頁面才打得開" do
      store_month
      existed = []
      allow(printer).to receive(:print) { |route_card| existed << RouteCard.exists?(route_card.id); print_result }
      run_command("--sample", env: sample_env)
      expect(existed).to eq([ true ])
    end

    it "試印好的那一行帶大小與開頁面的秒數：5.1 要記下來的數字" do
      store_month
      _, out = run_command("--sample", env: sample_env)
      expect(out).to include("#{pdf.bytesize} bytes，開頁面 3.2 秒")
    end

    it "不存 PDF：資料庫沒有位元組" do
      store_month
      run_command("--sample", env: sample_env)
      expect(RouteCardPdf.count).to eq(0)
    end

    it "不寫本機副本" do
      store_month
      run_command("--sample", env: sample_env)
      expect(Dir.exist?(File.join(data_root, "cards"))).to be(false)
    end

    it "規格的印失敗：輸出點名，結束碼 1，沒有留下那一列" do
      store_month
      allow_printing(failing: 15373)
      status, out = run_command("--sample", env: sample_env)
      expect([ status, out.include?("月卡頁回 500"), RouteCard.count, File.exist?(out_path) ]).to eq([ 1, true, 0, false ])
    end

    it "已經有的列：印那一列，之後一樣在，內容不變" do
      store_month
      row = create(:route_card, route_id: 15373, month: november, coverage: { "calendar_weekdays" => 1, "loaded_weekdays" => 1 })
      run_command("--sample", env: sample_env)
      expect([ printed, row.reload.coverage["calendar_weekdays"] ]).to eq([ [ "15373/2026-11/1" ], 1 ])
    end

    it "已印的月份：印得出來，列不動" do
      store_month
      row = create(:route_card, :printed, route_id: 15373, month: november, pdf: "定稿")
      status, = run_command("--sample", env: sample_env)
      expect([ status, File.binread(out_path), row.route_card_pdf.reload.pdf ]).to eq([ 0, pdf, "定稿".b ])
    end

    it "涵蓋還在等：照印，並印一行點名那幾天" do
      status, out = run_command("--sample", env: sample_env)
      expect([ status, out.include?("還在等 11-30"), File.exist?(out_path) ]).to eq([ 0, true, true ])
    end

    { "ROUTE" => "沒有 ROUTE", "MONTH" => "沒有 MONTH", "OUT" => "沒有 OUT" }.each do |name, message|
      it "缺 #{name}：印用法，結束碼 1，不開轉送" do
        status, out = run_command("--sample", env: sample_env.merge(name => nil))
        expect([ status, out.include?(message), opened ]).to eq([ 1, true, [] ])
      end
    end

    it "OUT 的目錄不存在：印用法，不開轉送" do
      status, out = run_command("--sample", env: sample_env.merge("OUT" => File.join(dir, "沒有這層", "x.pdf")))
      expect([ status, out.include?("OUT 的目錄不存在"), opened ]).to eq([ 1, true, [] ])
    end
  end

  describe "本機副本" do
    def copy_path(name = "15373-v1.pdf", month: "2026-11") = File.join(data_root, "cards", month, name)

    def keep_copy(content = "留著的原檔", name: "15373-v1.pdf")
      FileUtils.mkdir_p(File.dirname(copy_path(name)))
      File.write(copy_path(name), content)
    end

    it "規格的本機副本：PDF 的 SHA-256 跟存的一樣，JSON 帶同一個 SHA-256 與印製時間" do
      store_month
      run_command("--print")
      json = JSON.parse(File.read(copy_path("15373-v1.json")))
      expect([ Digest::SHA256.file(copy_path).hexdigest, json["pdf_sha256"], Time.iso8601(json["printed_at"]) ]).to eq([ card.pdf_sha256, card.pdf_sha256, card.printed_at ])
    end

    it "--revise 也留一份，檔名帶版本" do
      store_month
      create(:route_card, :printed, route_id: 15373, month: november)
      run_command("--revise", env: { "ROUTE" => "15373", "MONTH" => "2026-11", "REASON" => "資料重算" })
      expect(JSON.parse(File.read(copy_path("15373-v2.json")))["revision_reason"]).to eq("資料重算")
    end

    it "寫副本失敗：這條路線算失敗，結束碼 1，資料庫那一版留著" do
      store_month
      File.write(File.join(data_root, "cards"), "佔住目錄的位置")
      status, out = run_command("--print")
      expect([ status, out.include?("寫不進去"), card.printed? ]).to eq([ 1, true, true ])
    end

    describe "規格的資料庫重建：這台有檔、資料庫沒印過" do
      before do
        store_month
        keep_copy
      end

      it "--print 不呼叫印表機，原檔不變，點名版本與 --restore，結束碼 1" do
        status, out = run_command("--print")
        expect([ status, printed, File.read(copy_path), out.include?("v1"), out.include?("--restore") ]).to eq([ 1, [], "留著的原檔", true, true ])
      end

      it "--print 不寫列" do
        run_command("--print")
        expect(RouteCard.count).to eq(0)
      end

      it "只印計畫也點名，結束碼 1" do
        status, out = run_command
        expect([ status, out.include?("--restore") ]).to eq([ 1, true ])
      end

      it "另一條路線照印" do
        store_month(10712)
        status, = run_command("--print", route_ids: [ 15373, 10712 ])
        expect([ status, card(10712) ]).to match([ 1, be_printed ])
      end

      it "最後一行數得出幾份要先還原" do
        _, out = run_command("--print")
        expect(out.lines.last).to include("要先還原 1 份")
      end
    end

    it "資料庫少的是後面的版本：一樣先還原，v1 還在也不算沒事" do
      store_month
      create(:route_card, :printed, route_id: 15373, month: november)
      keep_copy(name: "15373-v2.pdf")
      status, out = run_command
      expect([ status, out.include?("v2"), out.include?("--restore") ]).to eq([ 1, true, true ])
    end

    it "--revise 碰到資料庫沒有的版本：不印，指向 --restore，結束碼 1" do
      store_month
      create(:route_card, :printed, route_id: 15373, month: november)
      keep_copy(name: "15373-v2.pdf")
      status, out = run_command("--revise", env: { "ROUTE" => "15373", "MONTH" => "2026-11", "REASON" => "資料重算" })
      expect([ status, out.include?("--restore"), printed, File.read(copy_path("15373-v2.pdf")) ]).to eq([ 1, true, [], "留著的原檔" ])
    end

    describe "規格的先前寫失敗：已印、這台沒有檔" do
      before { create(:route_card, :printed, route_id: 15373, month: november, pdf: "定稿") }

      it "--print 不呼叫印表機，從存的位元組補回來" do
        status, = run_command("--print")
        expect([ status, printed, File.binread(copy_path), JSON.parse(File.read(copy_path("15373-v1.json")))["version"] ]).to eq([ 0, [], "定稿".b, 1 ])
      end

      it "只印計畫不補" do
        run_command
        expect(File.exist?(copy_path)).to be(false)
      end

      it "補不進去：結束碼 1，點名原因" do
        File.write(File.join(data_root, "cards"), "佔住目錄的位置")
        status, out = run_command("--print")
        expect([ status, out.include?("寫不進去") ]).to eq([ 1, true ])
      end
    end

    it "這台已經有檔：不補，結束碼 0" do
      row = create(:route_card, :printed, route_id: 15373, month: november, pdf: "定稿")
      RouteCardLocalCopy.for(data_root, row).write(row, "定稿".b)
      status, out = run_command("--print")
      expect([ status, out.include?("補上") ]).to eq([ 0, false ])
    end
  end

  describe "--restore" do
    # A copy as a print left it, of a route card the database then lost.
    def keep_copy_of(route_id: 15373, version: 1, pdf: "定稿", **attributes)
      row = create(:route_card, :printed, route_id:, month: november, version:, pdf:, **attributes)
      RouteCardLocalCopy.for(data_root, row).write(row, pdf.b)
      row
    end

    def lose_database
      RouteCardPdf.delete_all
      RouteCard.delete_all
    end

    def copy_of(route_id = 15373, version = 1, extension = "pdf") = File.join(data_root, "cards/2026-11/#{route_id}-v#{version}.#{extension}")

    it "規格的資料庫重建：v2 回來，位元組與涵蓋、摘要、程式版本、印製時間、原因都照 JSON" do
      kept = keep_copy_of(version: 2, revision_reason: "資料重算", summary: { "weekdays" => 21 })
      before = kept.reload.attributes.slice("coverage", "summary", "program_version", "printed_at", "revision_reason", "pdf_sha256", "pdf_bytes")
      lose_database
      status, = run_command("--restore")
      expect([ status, card(15373, 2).attributes.slice(*before.keys), card(15373, 2).route_card_pdf.pdf ]).to eq([ 0, before, "定稿".b ])
    end

    it "規格的資料庫重建：之後的 --print 不呼叫印表機、結束碼 0" do
      store_month
      keep_copy_of
      lose_database
      run_command("--restore")
      expect([ run_command("--print").first, printed ]).to eq([ 0, [] ])
    end

    it "規格的已經有了：列不動，結束碼 0" do
      kept = keep_copy_of
      before = kept.reload.updated_at
      status, = run_command("--restore")
      expect([ status, kept.reload.updated_at ]).to eq([ 0, before ])
    end

    # Replaces the copy of a route card with one of other bytes that holds together.
    def replace_copy(route_card)
      other = RouteCard.new(route_card.attributes.merge("pdf_sha256" => Digest::SHA256.hexdigest("別的")))
      [ copy_of, copy_of(15373, 1, "json") ].each { FileUtils.rm(it) }
      RouteCardLocalCopy.for(data_root, other).write(other, "別的".b)
    end

    it "規格的位元組不同：列不動，點名那個檔，結束碼 1" do
      kept = keep_copy_of
      replace_copy(kept)
      status, out = run_command("--restore")
      expect([ status, out.include?(copy_of), kept.reload.route_card_pdf.pdf ]).to eq([ 1, true, "定稿".b ])
    end

    describe "規格的壞掉的副本" do
      before do
        [ 15373, 10712 ].each { keep_copy_of(route_id: it) }
        lose_database
        File.write(copy_of(15373), "被改過")
      end

      it "壞的不存，點名；另一條路線照存，結束碼 1" do
        status, out = run_command("--restore")
        expect([ status, card(15373), card(10712), out.include?(copy_of(15373)) ]).to match([ 1, nil, be_printed, true ])
      end
    end

    it "有 PDF 沒有 JSON：失敗，點名 JSON，結束碼 1" do
      keep_copy_of
      lose_database
      FileUtils.rm(copy_of(15373, 1, "json"))
      status, out = run_command("--restore")
      expect([ status, out.include?(copy_of(15373, 1, "json")), RouteCard.count ]).to eq([ 1, true, 0 ])
    end

    it "已經有沒印的列：用那一列存回去" do
      keep_copy_of
      lose_database
      create(:route_card, route_id: 15373, month: november, coverage: { "calendar_weekdays" => 99, "loaded_weekdays" => 99 })
      status, = run_command("--restore")
      expect([ status, RouteCard.count, card ]).to match([ 0, 1, be_printed ])
    end

    it "沒有 cards：說這台沒有留，結束碼 0" do
      status, out = run_command("--restore")
      expect([ status, out.include?("沒有留") ]).to eq([ 0, true ])
    end

    it "不呼叫印表機，也不需要 Chrome 的設定" do
      keep_copy_of
      lose_database
      status, = run_command("--restore", printer: nil, deploy: deploy_config.except("proxy"))
      expect([ status, RouteCard.count ]).to eq([ 0, 1 ])
    end

    it "最後一行是總數" do
      keep_copy_of(route_id: 15373)
      keep_copy_of(route_id: 10712)
      RouteCardPdf.where(route_card: card(10712)).delete_all
      RouteCard.where(route_id: 10712).delete_all
      expect(run_command("--restore").last.lines.last.chomp).to eq("存回 1 份、本來就有 1 份、失敗 0 份")
    end
  end

  describe "沒給印表機時自己建一個" do
    def built_with(env: {}, deploy: deploy_config)
      allow(CardPrinter).to receive(:new).and_return(printer)
      run_command("--print", env:, printer: nil, deploy:)
      CardPrinter
    end

    it "網址開頭來自 deploy 設定的 proxy.host，Chrome 用 macOS 的預設位置" do
      expect(built_with).to have_received(:new).with(base_url: "https://bus.example", chrome_path: CardPrinter::DEFAULT_CHROME)
    end

    it "CARD_BASE_URL、CHROME_PATH 蓋過預設" do
      expect(built_with(env: { "CARD_BASE_URL" => "http://127.0.0.1:3100", "CHROME_PATH" => "/opt/chrome" })).to have_received(:new).with(base_url: "http://127.0.0.1:3100", chrome_path: "/opt/chrome")
    end
  end

  describe "bin/monthly-cards" do
    def run_bin(env, *argv) = Open3.capture3(env, RbConfig.ruby, Rails.root.join("bin/monthly-cards").to_s, *argv)

    it "規格的環境不對：RAILS_ENV 是 development，說它寫的是正式站，不載入 Rails，結束碼 1" do
      stdout, stderr, status = run_bin({ "RAILS_ENV" => "development" })
      expect([ status.exitstatus, stderr.include?("production"), stdout ]).to eq([ 1, true, "" ])
    end

    # Runs the executable in production with nothing on PATH but a fake ssh that
    # records its arguments and fails, so nothing reaches the production host.
    # Returns what it printed and the -L argument ssh got.
    def run_with_fake_ssh(env = {})
      ssh = File.join(dir, "ssh")
      File.write(ssh, %(#!/bin/sh\necho "$@" > "$0.argv"\nexit 1\n))
      File.chmod(0o755, ssh)
      stdout, = run_bin({ "RAILS_ENV" => nil, "DB_HOST" => nil, "DB_PORT" => nil, "TUNNEL_PORT" => nil, "SECRET_KEY_BASE_DUMMY" => nil, "PATH" => dir, "TURNAROUND_DATA" => data_root, "WEBSITE_DATABASE_PASSWORD" => "x" }.merge(env))
      [ stdout, File.read("#{ssh}.argv").split.then { it[it.index("-L") + 1] } ]
    end

    it "沒設 RAILS_ENV 與 TUNNEL_PORT：以 production 跑，轉送的本機埠是 15432，開不了就說" do
      expect(run_with_fake_ssh).to match([ a_string_including("開不了到正式站的轉送"), "127.0.0.1:15432:127.0.0.1:5432" ])
    end

    it "TUNNEL_PORT=15433：轉送的本機埠跟著它" do
      expect(run_with_fake_ssh("TUNNEL_PORT" => "15433").last).to eq("127.0.0.1:15433:127.0.0.1:5432")
    end

    it "看不懂的參數：載入 Rails 之後印用法，結束碼 1，沒有碰 ssh" do
      stdout, _, status = run_bin({ "RAILS_ENV" => nil, "DB_HOST" => nil, "DB_PORT" => nil, "TUNNEL_PORT" => nil, "SECRET_KEY_BASE_DUMMY" => nil, "WEBSITE_DATABASE_PASSWORD" => "x" }, "--foo")
      expect([ status.exitstatus, stdout ]).to match([ 1, a_string_including("看不懂的參數：--foo") ])
    end
  end
end
