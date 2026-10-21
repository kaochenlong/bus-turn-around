require "net/http"

# bin/rails external:mrt_exits: saves one snapshot of the Taipei MRT entrance
# coordinates (data.gov.tw dataset 128428) under the data root, as
# external/taipei-mrt-exits/<Taipei day>.csv. The published file is Big5; the
# snapshot is UTF-8, so nothing that reads it has to know. A file that does not
# look like the expected table is never written, and existing snapshots stay.
class MrtExitsSnapshot
  DOWNLOAD_URL = "https://data.taipei/api/dataset/cfa4778c-62c1-497b-b704-756231de348b/resource/" \
                 "307a7f61-e302-4108-a817-877ccbfca7c1/download".freeze
  HEADER = "項次,出入口名稱,出入口編號,經度,緯度,是否為無障礙用".freeze
  DIRECTORY = "external/taipei-mrt-exits".freeze
  MAX_REDIRECTS = 3

  # The download or the file is not usable; the message says why.
  class Error < StandardError; end

  # Fetches a URL and returns [HTTP status, body bytes], following redirects.
  HTTP_FETCHER = lambda do |url, redirects_left = MAX_REDIRECTS|
    response = Net::HTTP.get_response(URI(url))
    if response.is_a?(Net::HTTPRedirection) && redirects_left.positive?
      HTTP_FETCHER.call(response["location"], redirects_left - 1)
    else
      [ response.code.to_i, response.body.to_s ]
    end
  end

  # The rake task: returns the exit status.
  def self.run(env, out: $stdout, fetcher: HTTP_FETCHER, day: Date.current)
    data_root = env["TURNAROUND_DATA"].presence
    unless data_root
      out.puts("用法：TURNAROUND_DATA=<原始檔的資料根目錄> bin/rails external:mrt_exits")
      return 1
    end

    snapshot = new(data_root:, day:, fetcher:)
    out.puts("#{snapshot.path}：#{snapshot.call} 個出入口")
    0
  rescue Error => e
    out.puts("沒有寫入出入口快照：#{e.message}")
    1
  end

  def initialize(data_root:, day:, fetcher: HTTP_FETCHER)
    @data_root = data_root
    @day = day
    @fetcher = fetcher
  end

  def path = File.join(@data_root, DIRECTORY, "#{@day.iso8601}.csv")

  # Writes the snapshot and returns the number of entrances in it.
  def call
    status, body = @fetcher.call(DOWNLOAD_URL)
    raise Error, "下載回應 HTTP #{status}" unless status == 200

    lines = decode(body).lines.map(&:chomp).reject(&:empty?)
    check(lines)
    write(lines)
    lines.size - 1
  end

  private

  def decode(body)
    body.dup.force_encoding(Encoding::Big5).encode(Encoding::UTF_8)
  rescue EncodingError
    raise Error, "內容不是 Big5"
  end

  # Fields carry no quotes or commas in this file, so a row that does not
  # split into exactly the header's columns is rejected rather than guessed.
  def check(lines)
    raise Error, "表頭不是「#{HEADER}」" unless lines.first == HEADER
    raise Error, "沒有任何出入口" if lines.size < 2

    columns = HEADER.split(",").size
    lines.drop(1).each_with_index do |line, index|
      fields = line.split(",", -1)
      raise Error, "第 #{index + 2} 行不是 #{columns} 欄" unless fields.size == columns
      raise Error, "第 #{index + 2} 行的經緯度不是數字" unless fields.values_at(3, 4).all? { Float(it, exception: false) }
    end
  end

  # Written to a temporary file first, so a failed write leaves no half file.
  def write(lines)
    FileUtils.mkdir_p(File.dirname(path))
    temporary = "#{path}.partial"
    File.write(temporary, "#{lines.join("\n")}\n", encoding: Encoding::UTF_8)
    File.rename(temporary, path)
  end
end
