require "rails_helper"

RSpec.describe OfficeCalendarSnapshot, type: :model do
  def day = Date.new(2026, 10, 23)
  let(:data_root) { Dir.mktmpdir("office-calendar") }
  let(:year_dir) { File.join(data_root, "external/office-calendar/2026") }

  after { FileUtils.remove_entry(data_root) }

  # The 2026 snapshot: the published calendar without its byte order mark and with LF line ends.
  def fixture = File.binread(Rails.root.join("spec/fixtures/analysis/external/office-calendar/2026/2026-10-19.csv"))

  def fixture_lines = fixture.force_encoding(Encoding::UTF_8).lines.map(&:chomp)

  # The lines as data.gov.tw publishes them: UTF-8 with a byte order mark and CRLF line ends.
  def published(lines = fixture_lines) = "\xEF\xBB\xBF".b + lines.map { "#{it}\r\n" }.join.b

  # The fixture lines with line `index` replaced; index 1 is the row of 2026-01-01.
  def replaced(index, line) = fixture_lines.tap { it[index] = line }

  def fetcher(status, body) = ->(_url) { [ status, body ] }

  def snapshot(fetcher) = described_class.new(data_root:, year: 2026, day:, fetcher:)

  def call_ignoring_failure(fetcher)
    snapshot(fetcher).call
  rescue described_class::Error
    nil
  end

  def snapshot_files = Dir.exist?(year_dir) ? Dir.children(year_dir).sort : []

  it "去掉 BOM、把 CRLF 換成 LF，寫出的 2026/2026-10-23.csv 跟 fixture 位元組相同" do
    snapshot(fetcher(200, published)).call
    expect(File.binread(File.join(year_dir, "2026-10-23.csv"))).to eq(fixture)
  end

  it "回傳 365 天、假日 120 天" do
    expect(snapshot(fetcher(200, published)).call).to eq(days: 365, holidays: 120)
  end

  {
    "HTTP 500" => [ :server_error, /HTTP 500/ ],
    "內容不是 UTF-8" => [ :not_utf8, /不是 UTF-8/ ],
    "表頭不同" => [ :wrong_header, /表頭不是/ ],
    "2026 年只有 364 列" => [ :missing_day, /365 天，檔案裡有 364 列/ ],
    "有一列只有三欄" => [ :three_fields, /第 2 行不是 4 欄/ ],
    "日期跳過一天" => [ :skipped_day, /第 3 行的日期應該是 20260102/ ],
    "星期跟日期對不上" => [ :wrong_weekday, /第 2 行的星期應該是四/ ],
    "是否放假不是 0 或 2" => [ :wrong_code, /第 2 行的是否放假不是 0 或 2/ ]
  }.each do |reason, (kind, message)|
    describe "#{reason}時" do
      let(:response) do
        {
          server_error: [ 500, "" ], not_utf8: [ 200, "\xFF\xFE".b + fixture ],
          wrong_header: [ 200, published(replaced(0, "日期,星期,是否放假,備註")) ],
          missing_day: [ 200, published(fixture_lines.first(365)) ],
          three_fields: [ 200, published(replaced(1, "20260101,四,2")) ],
          skipped_day: [ 200, published(replaced(2, "20260103,六,2,")) ],
          wrong_weekday: [ 200, published(replaced(1, "20260101,五,2,開國紀念日")) ],
          wrong_code: [ 200, published(replaced(1, "20260101,四,1,開國紀念日")) ]
        }.fetch(kind)
      end

      before do
        FileUtils.mkdir_p(year_dir)
        File.write(File.join(year_dir, "2026-10-20.csv"), "舊的快照")
      end

      it "丟出錯誤，訊息指出是哪一項檢查" do
        expect { snapshot(fetcher(*response)).call }.to raise_error(described_class::Error, message)
      end

      it "不寫新檔，同一年既有的快照不變" do
        call_ignoring_failure(fetcher(*response))
        expect([ snapshot_files, File.read(File.join(year_dir, "2026-10-20.csv")) ]).to eq([ [ "2026-10-20.csv" ], "舊的快照" ])
      end
    end
  end

  describe ".entry" do
    def fixture_root = Rails.root.join("spec/fixtures/analysis").to_s

    def entry(day, data_root: fixture_root) = described_class.entry(data_root:, day: Date.iso8601(day))

    # Writes a 2026 snapshot under the temporary data root whose row for
    # 2026-10-19 is `row` (nil leaves the day out).
    def write_snapshot(name, row)
      FileUtils.mkdir_p(year_dir)
      lines = fixture_lines.map { it.start_with?("20261019,") ? row : it }.compact
      File.write(File.join(year_dir, name), "#{lines.join("\n")}\n")
    end

    [
      [ "2026-10-23", "weekday", nil ],
      [ "2026-10-24", "holiday", nil ],
      [ "2026-10-25", "holiday", "臺灣光復暨金門古寧頭大捷紀念日" ],
      [ "2026-10-26", "holiday", "補假" ]
    ].each do |day, day_type, note|
      it "fixture 的 2026 快照裡，#{day} 是 #{day_type}，備註 #{note.inspect}，快照日 2026-10-19" do
        expect(entry(day)).to have_attributes(day_type:, note:, snapshot_day: Date.new(2026, 10, 19))
      end
    end

    it "用那一年檔名日期最新的一份：2026-10-23.csv 把 10-19 標成假日，就是假日、快照日 2026-10-23" do
      write_snapshot("2026-10-20.csv", "20261019,一,0,").then { write_snapshot("2026-10-23.csv", "20261019,一,2,補假") }
      expect(entry("2026-10-19", data_root:)).to have_attributes(day_type: "holiday", note: "補假", snapshot_day: Date.new(2026, 10, 23))
    end

    it "檔名不是日期的檔不算快照，寫到一半留下的 .partial 也不算" do
      write_snapshot("2026-10-20.csv", "20261019,一,0,").then { write_snapshot("2026-10-24.csv.partial", "20261019,一,2,") }
      expect(entry("2026-10-19", data_root:).snapshot_day).to eq(Date.new(2026, 10, 20))
    end

    it "那一年沒有任何快照時，訊息說要先跑 bin/rails external:office_calendar YEAR=2027" do
      expect { entry("2027-01-04", data_root:) }.to raise_error(described_class::Error, /bin\/rails external:office_calendar YEAR=2027/)
    end

    it "最新的快照裡沒有那一天時，訊息指出檔案與日期" do
      write_snapshot("2026-10-23.csv", nil)
      expect { entry("2026-10-19", data_root:) }.to raise_error(described_class::Error, /2026-10-23\.csv.*2026-10-19/)
    end

    it "快照裡那一天的是否放假不是 0 或 2 時丟出錯誤" do
      write_snapshot("2026-10-23.csv", "20261019,一,1,")
      expect { entry("2026-10-19", data_root:) }.to raise_error(described_class::Error, /2026-10-19/)
    end
  end

  describe ".run（rake task 用）" do
    let(:requested) { [] }

    def recording_fetcher = ->(url) { requested.push(url).then { [ 200, published ] } }

    # Runs the task and returns its exit status and everything it printed.
    def run_task(env)
      out = StringIO.new
      [ described_class.run(env, out:, fetcher: recording_fetcher, day:), out.string ]
    end

    it "沒有 TURNAROUND_DATA 時印用法，結束碼 1，不發請求" do
      status, out = run_task({})
      expect([ status, out.include?("TURNAROUND_DATA"), requested ]).to eq([ 1, true, [] ])
    end

    it "YEAR=2025 沒有下載網址：結束碼 1，訊息列出 2026 與 2027，不發請求也不寫檔" do
      status, out = run_task("TURNAROUND_DATA" => data_root, "YEAR" => "2025")
      expect([ status, out.include?("2026、2027"), requested, Dir.exist?(File.join(data_root, "external")) ]).to eq([ 1, true, [], false ])
    end

    it "YEAR 不是四位數字：結束碼 1，不發請求" do
      status, = run_task("TURNAROUND_DATA" => data_root, "YEAR" => "26")
      expect([ status, requested ]).to eq([ 1, [] ])
    end

    it "沒給 YEAR 時抓今天的台北日所在的 2026 年那一份" do
      run_task("TURNAROUND_DATA" => data_root)
      expect(requested).to match([ include("a52331bd-a189-466b-b0f0-cae3062bbf74") ])
    end

    it "成功時印出路徑、天數與假日數，結束碼 0" do
      status, out = run_task("TURNAROUND_DATA" => data_root, "YEAR" => "2026")
      expect([ status, out ]).to eq([ 0, "#{year_dir}/2026-10-23.csv：365 天，假日 120 天\n" ])
    end
  end
end
