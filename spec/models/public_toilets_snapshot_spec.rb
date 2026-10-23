require "rails_helper"

RSpec.describe PublicToiletsSnapshot, type: :model do
  def header = "county,areacode,village,number,name,address,administration,latitude,longitude,grade,type2,type,exec,diaper"
  def day = Date.new(2026, 10, 24)
  let(:data_root) { Dir.mktmpdir("public-toilets") }
  let(:snapshot_dir) { File.join(data_root, "external/public-toilets") }
  let(:requested) { [] }

  after { FileUtils.remove_entry(data_root) }

  def path = File.join(snapshot_dir, "2026-10-24.csv")

  # One row as the API returns it; the keywords replace single fields.
  def row(number, county: "63000", name: "測試公園-男廁", latitude: "25.0497")
    [ county, "#{county}010", "測試里", number, name, "測試區甲路1號", "測試管理處", latitude, "121.5006", "優等級", "公園", "男廁所", "測試管理處", "0" ].join(",")
  end

  # The rows of "Pages assembled into one file": three in 臺北市 on the first
  # page, two in 新北市 on the second, one of them with a comma in its address.
  def taipei_rows = %w[A010000001 A010000002 A010000003].map { row(it) }

  def new_taipei_rows
    [ row("F010000001", county: "65000"),
      "65000,65000010,測試里,F010000002,乙站-女廁,\"新北市測試區乙路1號, 2樓\",測試管理處,25.0001,121.6001,普通級,商業營業場所,女廁所,測試管理處,0" ]
  end

  def page(*rows) = "#{[ header, *rows ].join("\n")}\n"

  # Answers the n-th request with the n-th response and records every URL.
  def fetcher(*responses) = ->(url) { requested.push(url).then { responses.fetch(requested.size - 1) } }

  # Answers every request with a full page of `size` rows numbered after those of the request before.
  def endless(size) = ->(url) { requested.push(url).then { [ 200, page(*(1..size).map { row(format("A%03d%06d", requested.size, it)) }) ] } }

  def query(url) = URI.decode_www_form(URI(url).query).to_h

  def snapshot(fetcher, **options) = described_class.new(data_root:, day:, fetcher:, page_size: 3, **options)

  def call_ignoring_failure(fetcher, **options)
    snapshot(fetcher, **options).call
  rescue described_class::Error
    nil
  end

  def snapshot_files = Dir.exist?(snapshot_dir) ? Dir.children(snapshot_dir).sort : []

  describe "兩頁接成一份" do
    let(:pages) { fetcher([ 200, page(*taipei_rows) ], [ 200, page(*new_taipei_rows) ]) }

    it "請求 offset 0 與 3 兩頁，每一頁都要 CSV、照 number 由小到大、每頁 3 列" do
      snapshot(pages).call
      expect(requested.map { query(it).values_at("format", "sort", "limit", "offset") }).to eq([ %w[CSV number\ asc 3 0], %w[CSV number\ asc 3 3] ])
    end

    it "寫出那一天的檔：表頭一次、五列照順序、行尾 LF、沒有 BOM、含逗號的地址帶引號" do
      snapshot(pages).call
      expect(File.binread(path)).to eq("#{header}\n#{[ *taipei_rows, *new_taipei_rows ].join("\n")}\n".b)
    end

    it "回傳 5 列，其中臺北市 3 列、新北市 2 列" do
      expect(snapshot(pages).call).to eq(rows: 5, taipei: 3, new_taipei: 2)
    end

    it "同一天已經有快照時覆蓋它" do
      FileUtils.mkdir_p(snapshot_dir).then { File.write(path, "舊的快照") }
      snapshot(pages).call
      expect(File.read(path).lines.size).to eq(6)
    end
  end

  it "剛好滿一頁、下一頁只有表頭：請求兩頁，寫出三列，回報 3 列" do
    counts = snapshot(fetcher([ 200, page(*taipei_rows) ], [ 200, page ])).call
    expect([ requested.size, File.readlines(path).size, counts[:rows] ]).to eq([ 2, 4, 3 ])
  end

  it "每一頁開頭的 BOM 先去掉再檢查，寫出的檔沒有 BOM" do
    bom = "\xEF\xBB\xBF".b
    snapshot(fetcher([ 200, bom + page(*taipei_rows).b ], [ 200, bom + page.b ])).call
    expect(File.binread(path)).to eq("#{header}\n#{taipei_rows.join("\n")}\n".b)
  end

  {
    "第二頁回應 HTTP 500" => [ :server_error, /第 2 頁.*HTTP 500/ ],
    "第二頁不是 UTF-8" => [ :not_utf8, /第 2 頁.*UTF-8/ ],
    "第二頁的表頭少了 diaper" => [ :short_header, /第 2 頁.*表頭/ ],
    "第二頁有一列只有 13 欄" => [ :thirteen_fields, /第 2 頁第 1 列.*14 欄/ ],
    "每頁 3 列的第二頁回了 4 列" => [ :four_rows, /第 2 頁.*4 列/ ],
    "第二頁有一列的 number 是空的" => [ :empty_number, /第 2 頁第 1 列.*number/ ],
    "第二頁有一列的 name 是空的" => [ :empty_name, /第 2 頁第 1 列.*name/ ],
    "第二頁有一列的緯度是 north" => [ :north, /第 2 頁第 1 列.*經緯度/ ],
    "第二頁有沒關上的引號" => [ :unclosed_quote, /第 2 頁.*CSV/ ],
    "第二頁第一列的 number 跟第一頁最後一列相同" => [ :repeated, /第 2 頁第 1 列.*順序/ ],
    "第一頁只有表頭" => [ :header_only, /第 1 頁.*沒有任何公廁/ ]
  }.each do |reason, (kind, message)|
    describe "#{reason}時" do
      let(:responses) do
        second = {
          server_error: [ 500, "" ], not_utf8: [ 200, "\xFF".b + page(row("F010000001")).b ],
          short_header: [ 200, page(row("F010000001")).sub(",diaper", "") ],
          thirteen_fields: [ 200, page(row("F010000001").delete_suffix(",0")) ],
          four_rows: [ 200, page(*%w[F010000001 F010000002 F010000003 F010000004].map { row(it) }) ],
          empty_number: [ 200, page(row("")) ], empty_name: [ 200, page(row("F010000001", name: "")) ],
          north: [ 200, page(row("F010000001", latitude: "north")) ],
          unclosed_quote: [ 200, page(row("F010000001").sub("測試區甲路1號", "\"測試區甲路1號")) ],
          repeated: [ 200, page(row("A010000003")) ]
        }
        kind == :header_only ? [ [ 200, page ] ] : [ [ 200, page(*taipei_rows) ], second.fetch(kind) ]
      end

      before do
        FileUtils.mkdir_p(snapshot_dir)
        File.write(File.join(snapshot_dir, "2026-10-20.csv"), "舊的快照")
      end

      it "丟出錯誤，訊息指出第幾頁與原因" do
        expect { snapshot(fetcher(*responses)).call }.to raise_error(described_class::Error, message)
      end

      it "不寫新檔、不留 .partial，既有的快照不變" do
        call_ignoring_failure(fetcher(*responses))
        expect([ snapshot_files, File.read(File.join(snapshot_dir, "2026-10-20.csv")) ]).to eq([ [ "2026-10-20.csv" ], "舊的快照" ])
      end
    end
  end

  describe "每一頁都回滿、頁數上限 2 時" do
    it "抓完第 2 頁就停，丟出超過頁數上限的錯誤" do
      expect { snapshot(endless(3), max_pages: 2).call }.to raise_error(described_class::Error, /第 2 頁.*上限 2 頁/)
    end

    it "只請求兩頁、不寫檔" do
      call_ignoring_failure(endless(3), max_pages: 2)
      expect([ requested.size, Dir.exist?(snapshot_dir) ]).to eq([ 2, false ])
    end
  end

  it "沒給頁數上限時是 200 頁：每頁 1 列永遠回滿，請求 200 頁之後停下" do
    snapshot = described_class.new(data_root:, day:, fetcher: endless(1), page_size: 1)
    expect { snapshot.call }.to raise_error(described_class::Error, /上限 200 頁/)
  end

  describe ".run（rake task 用）" do
    # Runs the task and returns its exit status and everything it printed.
    def run_task(env, fetcher)
      out = StringIO.new
      [ described_class.run(env, out:, fetcher:, day:), out.string ]
    end

    it "沒有 TURNAROUND_DATA 時印用法，結束碼 1，不發請求" do
      status, out = run_task({}, fetcher)
      expect([ status, out.include?("TURNAROUND_DATA"), requested ]).to eq([ 1, true, [] ])
    end

    it "成功時印出路徑、列數與臺北市、新北市各幾列，結束碼 0" do
      status, out = run_task({ "TURNAROUND_DATA" => data_root }, fetcher([ 200, page(*taipei_rows, *new_taipei_rows) ]))
      expect([ status, out ]).to eq([ 0, "#{snapshot_dir}/2026-10-24.csv：5 列，臺北市 3 列、新北市 2 列\n" ])
    end

    it "每頁要 1,000 列" do
      run_task({ "TURNAROUND_DATA" => data_root }, fetcher([ 200, page(*taipei_rows) ]))
      expect(query(requested.first)["limit"]).to eq("1000")
    end

    it "失敗時印出第幾頁的原因，結束碼 1" do
      status, out = run_task({ "TURNAROUND_DATA" => data_root }, fetcher([ 500, "" ]))
      expect([ status, out.include?("第 1 頁") ]).to eq([ 1, true ])
    end
  end
end
