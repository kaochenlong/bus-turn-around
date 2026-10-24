require "spec_helper"

# The first line of the statement in docs/data-sources.md, which the site footer
# and the health card carry word for word, must name by its code every feed of
# 臺北市公共運輸處 the code reads: the hourly feed folders analysis/ passes to
# day_files and the Get*.gz snapshot files named in the SQL and Ruby code. It
# only reads files, so it needs no DuckDB.
RSpec.describe "顯名聲明點名程式讀到的每一支公運處 feed" do
  # The code the statement names each hourly feed folder by.
  def folder_codes = { "bus_event" => "GetBusEvent", "bus_seat_event" => "BusSeatEvent", "bus_data" => "GetBusData" }

  def root = File.expand_path("../..", __dir__)

  # The text of every file the glob patterns match under the repo root.
  def read_all(*patterns) = patterns.flat_map { Dir.glob(File.join(root, it)) }.select { File.file?(it) }.sort.map { File.read(it) }.join("\n")

  def day_files_folders = read_all("analysis/*.sql").scan(/day_files\(\s*'([^']+)'/).flatten.uniq

  # Ruby's \b counts CJK characters as word characters, so a file name right
  # after Chinese text would be missed; these lookarounds look at ASCII only.
  def snapshot_codes
    read_all("analysis/*.sql", "app/**/*.rb", "lib/**/*.rb", "bin/*")
      .scan(/(?<![A-Za-z0-9_])(Get[A-Za-z0-9_]+)\.gz(?![A-Za-z0-9_])/).flatten.uniq
  end

  def codes_read = day_files_folders.filter_map { folder_codes[it] } | snapshot_codes

  # The first quoted paragraph of the 授權 section, taken the way
  # spec/analysis/card_spec.rb takes all three.
  def first_line
    licence = File.read(File.join(root, "docs/data-sources.md"))[/^### 授權\n(.*?)(?=^#)/m, 1]
    licence.lines.grep(/\A> /).first.delete_prefix("> ").chomp
  end

  def named?(code) = first_line.match?(/(?<![A-Za-z0-9_])#{code}(?![A-Za-z0-9_])/)

  it "analysis/ 傳給 day_files 的每個資料夾名都在對照裡" do
    expect(day_files_folders - folder_codes.keys).to eq([])
  end

  it "今天讀的八支都掃得到：bus_event、bus_seat_event、bus_data 的小時檔，與 GetRoute.gz、GetStop.gz、GetPathDetail.gz、GetBusShape.gz、GetProvider.gz" do
    expect(%w[GetBusEvent BusSeatEvent GetBusData GetRoute GetStop GetPathDetail GetBusShape GetProvider] - codes_read).to eq([])
  end

  it "程式讀到的每一支 feed，授權那一節的第一段引文都點名了它的代碼" do
    expect(codes_read.reject { named?(it) }).to eq([])
  end
end
