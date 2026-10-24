require "rails_helper"

RSpec.describe NewestSnapshot, type: :model do
  let(:data_root) { Dir.mktmpdir("newest-snapshot") }
  let(:message) { "沒有捷運出入口快照：先跑 bin/rails external:mrt_exits" }

  after { FileUtils.remove_entry(data_root) }

  def directory = File.join(data_root, "external/taipei-mrt-exits")

  # Creates the snapshot folder with the given files in it, all empty.
  def snapshots(*names)
    FileUtils.mkdir_p(directory)
    names.each { FileUtils.touch(File.join(directory, it)) }
  end

  def find = described_class.find(data_root:, directory: "external/taipei-mrt-exits", label: "捷運出入口", task: "bin/rails external:mrt_exits")

  it "選檔名日期最新的那一份，帶它的路徑與檔名的日期" do
    snapshots("2026-10-22.csv", "2026-10-20.csv")
    expect(find).to eq(described_class::Snapshot.new(path: File.join(directory, "2026-10-22.csv"), day: Date.new(2026, 10, 22)))
  end

  it "不是 YYYY-MM-DD.csv 的檔不算，即使檔名排在後面" do
    snapshots("2026-10-20.csv", "2026-10-23-old.csv", "2026-10-22.csv.partial")
    expect(find.day).to eq(Date.new(2026, 10, 20))
  end

  it "目錄是空的：丟 Missing，訊息帶標籤與要先跑的指令" do
    snapshots
    expect { find }.to raise_error(described_class::Missing, message)
  end

  it "目錄不存在：丟 Missing，訊息帶標籤與要先跑的指令" do
    expect { find }.to raise_error(described_class::Missing, message)
  end
end
