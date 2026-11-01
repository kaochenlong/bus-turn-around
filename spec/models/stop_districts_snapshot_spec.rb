require "rails_helper"
require "zip"

RSpec.describe StopDistrictsSnapshot, type: :model do
  let(:data_root) { Dir.mktmpdir("stop-districts") }
  let(:runs) { [] }
  let(:out) { StringIO.new }

  def fixtures = Rails.root.join("spec/fixtures/analysis")

  def day = Date.new(2026, 10, 22)

  def snapshot_dir = File.join(data_root, "external/stop-districts")

  def fake_csv = File.read(fixtures.join("external/stop-districts/2026-10-19.csv"))

  # The data root holds two static snapshots, both the fixture's GetStop.gz.
  before do
    %w[2026-10-19 2026-10-23].each do |static_day|
      FileUtils.mkdir_p(File.join(data_root, "static", static_day))
      FileUtils.cp(fixtures.join("static/2026-10-19/GetStop.gz"), File.join(data_root, "static", static_day))
    end
  end

  after { FileUtils.remove_entry(data_root) }

  def member(name) = [ name, File.binread(fixtures.join("external/town-boundaries", name)) ]

  def boundary_members = %w[TOWN_MOI_TEST.shp TOWN_MOI_TEST.shx TOWN_MOI_TEST.dbf TOWN_MOI_TEST.prj].map { member(it) }

  # A zip archive of the given [name, bytes] members, built in memory.
  def archive(members)
    Zip::OutputStream.write_buffer do |zip|
      members.each { |name, bytes| zip.put_next_entry(name) && zip.write(bytes) }
    end.string
  end

  # The boundary members plus a member whose name is Big5 and a spreadsheet.
  def real_archive = archive([ *boundary_members, [ "說明.txt".encode("Big5").b, "big5".b ], [ "readme.xlsx", "xlsx".b ] ])

  def fetcher(status, body) = ->(_url) { [ status, body ] }

  # A runner that records its variables and the files next to the shapefile,
  # writes `csv` as the output file and reports `counts` as DuckDB would.
  def runner(csv = fake_csv, counts: { "n_locations" => 16, "n_assigned" => 15 })
    lambda do |_duckdb, variables|
      runs << [ variables, Dir.children(File.dirname(variables[:shapefile_path])).sort ]
      File.write(variables[:output_path], csv)
      [ counts ]
    end
  end

  def failing_runner(message) = ->(*) { raise AnalysisRun::Error, message }

  def snapshot(fetcher: self.fetcher(200, real_archive), runner: self.runner)
    described_class.new(data_root:, day:, duckdb: "/usr/bin/true", fetcher:, runner:)
  end

  # The message of the failure `call` raises, or nil when it succeeds.
  def failure(**options)
    snapshot(**options).call
    nil
  rescue described_class::Error => e
    e.message
  end

  def snapshot_files = Dir.exist?(snapshot_dir) ? Dir.children(snapshot_dir).sort : []

  def written = File.read(File.join(snapshot_dir, "2026-10-22.csv"))

  it "寫出那一天的檔，內容是 runner 寫的 CSV，回傳站位數、判到數與區界檔的版本" do
    result = snapshot.call
    expect([ result.n_locations, result.n_assigned, result.version, written, snapshot_files ])
      .to eq([ 16, 15, "TEST", fake_csv, [ "2026-10-22.csv" ] ])
  end

  it "runner 拿到最新那一天的 GetStop.gz 與暫存目錄裡的 shapefile；目錄裡只有四個成員，Big5 檔名的成員與 readme.xlsx 不解" do
    snapshot.call
    variables, members = runs.first
    expect([ variables[:stops_path].end_with?("static/2026-10-23/GetStop.gz"), File.basename(variables[:shapefile_path]), members ])
      .to eq([ true, "TOWN_MOI_TEST.shp", %w[TOWN_MOI_TEST.dbf TOWN_MOI_TEST.prj TOWN_MOI_TEST.shp TOWN_MOI_TEST.shx] ])
  end

  it "下載不是 200：丟錯寫出狀態碼，不寫檔、不留 .partial" do
    expect([ failure(fetcher: fetcher(404, "")), snapshot_files ]).to match([ include("404"), [] ])
  end

  it "zip 裡沒有 TOWN_MOI 的四個成員：丟錯指名成員，不寫檔" do
    short = archive([ member("TOWN_MOI_TEST.shp"), member("TOWN_MOI_TEST.dbf"), [ "readme.xlsx", "x".b ] ])
    expect([ failure(fetcher: fetcher(200, short)), snapshot_files ]).to match([ include("TOWN_MOI"), [] ])
  end

  it "資料根目錄沒有任何 static/<日>/GetStop.gz：丟錯指名那個檔，不下載" do
    FileUtils.remove_entry(File.join(data_root, "static"))
    expect([ failure(fetcher: fetcher(500, "")), snapshot_files ]).to match([ include("GetStop.gz"), [] ])
  end

  it "LOAD spatial 失敗：訊息含安裝延伸的指令，不留 .partial" do
    message = failure(runner: failing_runner('IO Error: Extension "spatial" not found.'))
    expect([ message, snapshot_files ]).to match([ include('duckdb -c "INSTALL spatial"'), [] ])
  end

  it "DuckDB 的其他錯誤照原文丟出" do
    expect(failure(runner: failing_runner("Binder Error: no such column"))).to include("Binder Error")
  end

  it "寫出的檔不過檢查就不改名：表頭不對、欄數不對、Id 沒有遞增、town 空的、沒有列，都丟錯且不留檔" do
    bad = [ "id,county,town\n81000,臺北市,測試區\n", "stop_location_id,county,town\n81000,臺北市\n",
            "stop_location_id,county,town\n81001,臺北市,測試區\n81000,臺北市,測試區\n", "stop_location_id,county,town\n81000,臺北市,\n",
            "stop_location_id,county,town\n" ]
    expect(bad.map { [ failure(runner: runner(it, counts: { "n_locations" => 1, "n_assigned" => 1 })).nil?, snapshot_files ] }).to all(eq([ false, [] ]))
  end

  it "列數跟 DuckDB 回報的判到數不同也不改名" do
    expect([ failure(runner: runner(fake_csv, counts: { "n_locations" => 16, "n_assigned" => 10 })), snapshot_files ]).to match([ include("15"), [] ])
  end

  it "失敗時既有的快照留著" do
    FileUtils.mkdir_p(snapshot_dir)
    File.write(File.join(snapshot_dir, "2026-10-21.csv"), fake_csv)
    expect([ failure(fetcher: fetcher(404, "")), snapshot_files ]).to eq([ "下載回應 HTTP 404", [ "2026-10-21.csv" ] ])
  end

  describe ".run" do
    let(:bin) { Dir.mktmpdir("fake-duckdb") }

    before do
      File.write(File.join(bin, "duckdb"), "#!/bin/sh\n")
      File.chmod(0o755, File.join(bin, "duckdb"))
    end

    after { FileUtils.remove_entry(bin) }

    def run(env = { "TURNAROUND_DATA" => data_root, "PATH" => bin }, **options)
      described_class.run(env, out:, fetcher: fetcher(200, real_archive), runner: runner, day:, **options)
    end

    it "印路徑、三個數字與區界檔的版本，回 0" do
      status = run
      expect([ status, out.string ]).to eq([ 0, "#{File.join(snapshot_dir, '2026-10-22.csv')}：站位 16 個，判到行政區 15 個，判不到 1 個（區界檔 TOWN_MOI_TEST）\n" ])
    end

    it "沒有 TURNAROUND_DATA：印用法，回 1" do
      expect([ run({ "PATH" => bin }), out.string ]).to match([ 1, include("用法", "TURNAROUND_DATA", "external:stop_districts") ])
    end

    it "PATH 上沒有 duckdb：印要裝 DuckDB CLI，回 1" do
      expect([ run({ "TURNAROUND_DATA" => data_root, "PATH" => "/nonexistent" }), out.string ]).to match([ 1, include("DuckDB CLI") ])
    end

    it "失敗時印「沒有寫入站位行政區快照：」加原因，回 1" do
      expect([ run(fetcher: fetcher(404, "")), out.string ]).to eq([ 1, "沒有寫入站位行政區快照：下載回應 HTTP 404\n" ])
    end
  end
end
