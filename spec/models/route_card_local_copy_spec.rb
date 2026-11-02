require "rails_helper"

RSpec.describe RouteCardLocalCopy, type: :model do
  let(:root) { Dir.mktmpdir("card-copies") }
  let(:route_card) { create(:route_card, :printed, route_id: 15373, month: Date.new(2026, 11, 1), pdf: "abc", revision_reason: "資料重算", summary: { "weekdays" => 21 }) }

  after { FileUtils.remove_entry(root) }

  def copy = described_class.for(root, route_card)

  def pdf_path = File.join(root, "cards/2026-11/15373-v1.pdf")

  def json_path = File.join(root, "cards/2026-11/15373-v1.json")

  def written = JSON.parse(File.read(json_path))

  def corrupt_json(**changes) = File.write(json_path, written.merge(changes.stringify_keys).to_json)

  describe "#write" do
    before { copy.write(route_card, "abc") }

    it "PDF 寫到規格的路徑，存什麼就是什麼" do
      expect(File.binread(pdf_path)).to eq("abc")
    end

    it "JSON 帶這一版的列" do
      expect(written.values_at("route_id", "month", "version", "revision_reason", "pdf_bytes", "summary", "program_version")).to eq([ 15373, "2026-11", 1, "資料重算", 3, { "weekdays" => 21 }, "abc1234" ])
    end

    it "JSON 的 SHA-256 是 abc 那一個，FIPS 180-2 的第一個例子" do
      expect(written["pdf_sha256"]).to eq("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    end

    it "JSON 的印製時間讀回來跟列上的一樣，到微秒" do
      expect(Time.iso8601(written["printed_at"])).to eq(route_card.reload.printed_at)
    end

    it "JSON 帶涵蓋" do
      expect(written["coverage"]).to eq(route_card.coverage)
    end

    it "沒有留下暫存檔" do
      expect(Dir.children(File.dirname(pdf_path))).to contain_exactly("15373-v1.pdf", "15373-v1.json")
    end
  end

  describe "已經有同名檔" do
    before do
      FileUtils.mkdir_p(File.dirname(pdf_path))
      File.write(pdf_path, "舊的")
    end

    it "失敗，訊息點名那個檔" do
      expect { copy.write(route_card, "abc") }.to raise_error(described_class::Failure, /#{Regexp.escape(pdf_path)}/)
    end

    it "原檔不變" do
      suppress(described_class::Failure) { copy.write(route_card, "abc") }
      expect(File.read(pdf_path)).to eq("舊的")
    end

    it "沒有留下暫存檔" do
      suppress(described_class::Failure) { copy.write(route_card, "abc") }
      expect(Dir.children(File.dirname(pdf_path))).to eq([ "15373-v1.pdf" ])
    end
  end

  it "目錄寫不進去：失敗，訊息點名路徑" do
    File.write(File.join(root, "cards"), "佔住目錄的位置")
    expect { copy.write(route_card, "abc") }.to raise_error(described_class::Failure, /寫不進去/)
  end

  describe "#complete? 與 #fill_in" do
    it "兩個檔都有才算齊" do
      before = copy.complete?
      copy.write(route_card, "abc")
      expect([ before, copy.complete? ]).to eq([ false, true ])
    end

    it "少 JSON 也不算齊，補的時候只補 JSON，PDF 不動" do
      copy.write(route_card, "abc")
      FileUtils.rm(json_path)
      copy.fill_in(route_card, "不該寫進去")
      expect([ File.binread(pdf_path), written["version"], copy.complete? ]).to eq([ "abc", 1, true ])
    end

    it "兩個都沒有：兩個都補" do
      copy.fill_in(route_card, "abc")
      expect(copy.complete?).to be(true)
    end
  end

  describe ".versions" do
    def touch(name)
      FileUtils.mkdir_p(File.join(root, "cards/2026-11"))
      FileUtils.touch(File.join(root, "cards/2026-11", name))
    end

    it "這條路線這個月有檔的版本，由小到大" do
      [ "15373-v10.pdf", "15373-v2.pdf" ].each { touch(it) }
      expect(described_class.versions(root, 15373, Date.new(2026, 11, 1))).to eq([ 2, 10 ])
    end

    it "別條路線、JSON 與暫存檔都不算" do
      [ "153730-v1.pdf", "5373-v3.pdf", "15373-v4.json", "15373-v5.pdf.tmp" ].each { touch(it) }
      expect(described_class.versions(root, 15373, Date.new(2026, 11, 1))).to eq([])
    end

    it "沒有目錄：沒有版本" do
      expect(described_class.versions(root, 15373, Date.new(2026, 11, 1))).to eq([])
    end
  end

  describe "#read" do
    before { copy.write(route_card, "abc") }

    def read = described_class.all(root).sole.read

    it "讀回 PDF 與列，路線、月份、版本照 JSON" do
      kept = read
      expect([ kept.route_id, kept.month, kept.version, kept.pdf, kept.attributes[:revision_reason], kept.attributes[:coverage] ]).to eq([ 15373, Date.new(2026, 11, 1), 1, "abc".b, "資料重算", route_card.coverage ])
    end

    it "印製時間讀回來跟列上的一樣" do
      expect(read.attributes[:printed_at]).to eq(route_card.reload.printed_at)
    end

    it "PDF 跟 JSON 的 SHA-256 不同：失敗，點名那個檔" do
      File.write(pdf_path, "被改過")
      expect { read }.to raise_error(described_class::Failure, /#{Regexp.escape(pdf_path)}.*SHA-256/)
    end

    it "有 PDF 沒有 JSON：失敗，點名 JSON" do
      FileUtils.rm(json_path)
      expect { read }.to raise_error(described_class::Failure, /#{Regexp.escape(json_path)}/)
    end

    it "有 JSON 沒有 PDF：失敗，點名 PDF" do
      FileUtils.rm(pdf_path)
      expect { read }.to raise_error(described_class::Failure, /#{Regexp.escape(pdf_path)}/)
    end

    it "JSON 讀不出來：失敗，點名 JSON" do
      File.write(json_path, "{壞掉")
      expect { read }.to raise_error(described_class::Failure, /#{Regexp.escape(json_path)}.*讀不出來/)
    end

    it "JSON 不是對應表：失敗" do
      File.write(json_path, "[1]")
      expect { read }.to raise_error(described_class::Failure, /讀不出來/)
    end

    it "JSON 缺欄位：失敗" do
      File.write(json_path, { "route_id" => 15373 }.to_json)
      expect { read }.to raise_error(described_class::Failure, /讀不出來/)
    end

    it "JSON 寫的版本跟檔名不同：失敗，不會存到別的版本" do
      corrupt_json(version: 2)
      expect { read }.to raise_error(described_class::Failure, /不符/)
    end

    it "JSON 寫的月份跟目錄不同：失敗" do
      corrupt_json(month: "2026-12")
      expect { read }.to raise_error(described_class::Failure, /不符/)
    end
  end

  describe ".all" do
    it "沒有 cards：空的" do
      expect(described_class.all(root)).to eq([])
    end

    it "每一份一個，PDF 與 JSON 算同一份，照路徑排" do
      copy.write(route_card, "abc")
      FileUtils.touch(File.join(root, "cards/2026-11/10712-v1.pdf"))
      expect(described_class.all(root).map(&:pdf_path)).to eq([ File.join(root, "cards/2026-11/10712-v1.pdf"), pdf_path ])
    end

    it "看不懂的檔名也列出來，讀的時候才失敗：不會默默跳過" do
      FileUtils.mkdir_p(File.join(root, "cards/2026-11"))
      FileUtils.touch(File.join(root, "cards/2026-11/舊的.pdf"))
      expect { described_class.all(root).sole.read }.to raise_error(described_class::Failure)
    end
  end
end
