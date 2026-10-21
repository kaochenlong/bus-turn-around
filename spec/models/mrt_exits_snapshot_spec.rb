require "rails_helper"

RSpec.describe MrtExitsSnapshot, type: :model do
  def header = "項次,出入口名稱,出入口編號,經度,緯度,是否為無障礙用"
  def rows = [ "1,頂埔站出口1,1,121.4183364,24.9593267,是", "2,頂埔站出口2,2,121.4183575,24.95894725,否" ]
  def day = Date.new(2026, 10, 22)
  let(:data_root) { Dir.mktmpdir("mrt-exits") }
  let(:snapshot_dir) { File.join(data_root, "external/taipei-mrt-exits") }

  after { FileUtils.remove_entry(data_root) }

  def big5(*lines) = "#{lines.join("\n")}\n".encode("Big5").b

  def fetcher(status, body) = ->(_url) { [ status, body ] }

  def snapshot(fetcher) = described_class.new(data_root:, day:, fetcher:)

  def call_ignoring_failure(fetcher)
    snapshot(fetcher).call
  rescue described_class::Error
    nil
  end

  def snapshot_files = Dir.exist?(snapshot_dir) ? Dir.children(snapshot_dir).sort : []

  it "把 Big5 的內容轉成 UTF-8，寫到那一天的檔，回傳出入口數" do
    count = snapshot(fetcher(200, big5(header, *rows))).call
    written = File.read(File.join(snapshot_dir, "2026-10-22.csv"), encoding: "UTF-8")
    expect([ count, written.valid_encoding?, written.lines.map(&:chomp) ]).to eq([ 2, true, [ header, *rows ] ])
  end

  {
    "HTTP 500" => [ 500, nil ],
    "表頭不同" => [ 200, :wrong_header ],
    "沒有資料列" => [ 200, :header_only ],
    "緯度不是數字" => [ 200, :bad_latitude ]
  }.each do |reason, (status, kind)|
    describe "#{reason}時" do
      let(:body) do
        { nil => "", wrong_header: big5("項次,名稱,經度,緯度", *rows), header_only: big5(header),
          bad_latitude: big5(header, "1,頂埔站出口1,1,121.4183364,北緯,是") }.fetch(kind)
      end

      before do
        FileUtils.mkdir_p(snapshot_dir)
        File.write(File.join(snapshot_dir, "2026-10-20.csv"), "舊的快照")
      end

      it "丟出錯誤" do
        expect { snapshot(fetcher(status, body)).call }.to raise_error(described_class::Error)
      end

      it "不寫新檔，既有的快照不變" do
        call_ignoring_failure(fetcher(status, body))
        expect([ snapshot_files, File.read(File.join(snapshot_dir, "2026-10-20.csv")) ]).to eq([ [ "2026-10-20.csv" ], "舊的快照" ])
      end
    end
  end

  describe ".run（rake task 用）" do
    it "沒有 TURNAROUND_DATA 時印用法，結束碼 1" do
      out = StringIO.new
      expect([ described_class.run({}, out:), out.string.include?("TURNAROUND_DATA") ]).to eq([ 1, true ])
    end

    it "成功時印出寫了幾個出入口，結束碼 0" do
      out = StringIO.new
      status = described_class.run({ "TURNAROUND_DATA" => data_root }, out:, fetcher: fetcher(200, big5(header, *rows)), day:)
      expect([ status, out.string ]).to eq([ 0, "#{snapshot_dir}/2026-10-22.csv：2 個出入口\n" ])
    end
  end
end
