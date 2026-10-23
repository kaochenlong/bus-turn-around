# bin/rails external:office_calendar: saves one year of the office calendar of
# 行政院人事行政總處 (data.gov.tw dataset 14718) under the data root, as
# external/office-calendar/<year>/<Taipei day>.csv. The published file is UTF-8
# with a byte order mark and CRLF line ends; the snapshot keeps every row as it
# is, without the mark and with LF, so nothing that reads it has to know. A file
# that does not cover its year day by day is never written, and existing
# snapshots stay.
class OfficeCalendarSnapshot
  # Every year's file has an address of its own; these are copied as the
  # dataset page on data.gov.tw publishes them. A revised calendar comes out
  # as another file with another address: replace the year's address here
  # before downloading again, or the download saves the old version under a
  # new date.
  DOWNLOAD_URLS = {
    2026 => "https://www.dgpa.gov.tw/FileConversion?filename=dgpa/files/202506/a52331bd-a189-466b-b0f0-cae3062bbf74.csv" \
            "&nfix=&name=115%e5%b9%b4%e4%b8%ad%e8%8f%af%e6%b0%91%e5%9c%8b%e6%94%bf%e5%ba%9c%e8%a1%8c%e6%94%bf%e6%a9%9f" \
            "%e9%97%9c%e8%be%a6%e5%85%ac%e6%97%a5%e6%9b%86%e8%a1%a8.csv",
    2027 => "https://www.dgpa.gov.tw/FileConversion?filename=dgpa/files/202607/f538b1ff-ba60-4c63-9477-10db8e6612d1.csv" \
            "&nfix=&name=116%e5%b9%b4%e4%b8%ad%e8%8f%af%e6%b0%91%e5%9c%8b%e6%94%bf%e5%ba%9c%e8%a1%8c%e6%94%bf%e6%a9%9f" \
            "%e9%97%9c%e8%be%a6%e5%85%ac%e6%97%a5%e6%9b%86%e8%a1%a8_utf8bom.csv"
  }.freeze
  HEADER = "西元日期,星期,是否放假,備註".freeze
  DIRECTORY = "external/office-calendar".freeze
  # 是否放假: 0 is a working day, 2 a day off.
  DAY_TYPES = { "0" => "weekday", "2" => "holiday" }.freeze
  WEEKDAYS = %w[日 一 二 三 四 五 六].freeze
  BYTE_ORDER_MARK = "\xEF\xBB\xBF".b.freeze
  YEAR = /\A\d{4}\z/
  SNAPSHOT_NAME = /\A\d{4}-\d{2}-\d{2}\.csv\z/

  # The download, the file or the year is not usable; the message says why.
  class Error < StandardError; end

  # The rake task: returns the exit status.
  def self.run(env, out: $stdout, fetcher: HttpFetcher, day: Date.current)
    data_root = env["TURNAROUND_DATA"].presence
    unless data_root
      out.puts("用法：TURNAROUND_DATA=<原始檔的資料根目錄> bin/rails external:office_calendar [YEAR=<西元年，預設今年>]")
      return 1
    end

    snapshot = new(data_root:, year: year(env["YEAR"], day), day:, fetcher:)
    counts = snapshot.call
    out.puts("#{snapshot.path}：#{counts[:days]} 天，假日 #{counts[:holidays]} 天")
    0
  rescue Error => e
    out.puts("沒有寫入辦公日曆快照：#{e.message}")
    1
  end

  # A Taipei day as the newest snapshot of its year has it: weekday or
  # holiday, the calendar's note (nil when it has none), and the file name
  # date of that snapshot.
  Entry = Data.define(:day_type, :note, :snapshot_day)

  # Reads one day from the snapshot with the latest file name date in the
  # folder of the day's year; a file whose name is not a date is not a snapshot.
  def self.entry(data_root:, day:)
    path = newest_snapshot(data_root, day.year)
    row = File.foreach(path, chomp: true, encoding: Encoding::UTF_8).find { it.start_with?("#{day.strftime('%Y%m%d')},") }
    raise Error, "#{path} 沒有 #{day.iso8601} 這一天" unless row

    _date, _weekday, code, note = row.split(",", -1)
    day_type = DAY_TYPES.fetch(code) { raise Error, "#{path} 裡 #{day.iso8601} 的是否放假不是 0 或 2" }
    Entry.new(day_type:, note: note.presence, snapshot_day: Date.iso8601(File.basename(path, ".csv")))
  end

  def self.newest_snapshot(data_root, year)
    directory = File.join(data_root, DIRECTORY, year.to_s)
    name = Dir.glob("*.csv", base: directory).grep(SNAPSHOT_NAME).max
    raise Error, "沒有 #{year} 年的辦公日曆快照：先跑 bin/rails external:office_calendar YEAR=#{year}" unless name

    File.join(directory, name)
  end
  private_class_method :newest_snapshot

  # YEAR as a number, or the year of today's Taipei day when it is not given.
  def self.year(text, day)
    return day.year if text.blank?
    raise Error, "YEAR 要是四位數字的西元年：#{text}" unless YEAR.match?(text)

    Integer(text, 10)
  end
  private_class_method :year

  def initialize(data_root:, year:, day:, fetcher: HttpFetcher)
    @data_root = data_root
    @year = Integer(year)
    @day = day
    @fetcher = fetcher
  end

  def path = File.join(@data_root, DIRECTORY, @year.to_s, "#{@day.iso8601}.csv")

  # Writes the snapshot and returns the number of days and of holidays in it.
  def call
    url = DOWNLOAD_URLS.fetch(@year) { raise Error, "沒有 #{@year} 年的下載網址，有的是 #{DOWNLOAD_URLS.keys.join('、')}" }
    status, body = @fetcher.call(url)
    raise Error, "下載回應 HTTP #{status}" unless status == 200

    lines = decode(body).lines.map(&:chomp).reject(&:empty?)
    check(lines)
    write(lines)
    { days: lines.size - 1, holidays: lines.drop(1).count { it.split(",", -1)[2] == "2" } }
  end

  private

  def decode(body)
    text = body.b.delete_prefix(BYTE_ORDER_MARK).force_encoding(Encoding::UTF_8)
    raise Error, "內容不是 UTF-8" unless text.valid_encoding?

    text
  end

  # Fields carry no quotes or commas in this file, so a row that does not
  # split into exactly four fields is rejected rather than guessed.
  def check(lines)
    raise Error, "表頭不是「#{HEADER}」" unless lines.first == HEADER

    days = Date.new(@year, 1, 1)..Date.new(@year, 12, 31)
    rows = lines.drop(1)
    raise Error, "#{@year} 年有 #{days.count} 天，檔案裡有 #{rows.size} 列" unless rows.size == days.count

    rows.zip(days).each.with_index(2) { |(row, date), line_number| check_row(row.split(",", -1), date, line_number) }
  end

  def check_row(fields, date, line_number)
    raise Error, "第 #{line_number} 行不是 4 欄" unless fields.size == 4
    raise Error, "第 #{line_number} 行的日期應該是 #{date.strftime('%Y%m%d')}" unless fields[0] == date.strftime("%Y%m%d")
    raise Error, "第 #{line_number} 行的星期應該是#{WEEKDAYS.fetch(date.wday)}" unless fields[1] == WEEKDAYS.fetch(date.wday)
    raise Error, "第 #{line_number} 行的是否放假不是 0 或 2" unless DAY_TYPES.key?(fields[2])
  end

  # Written to a temporary file first, so a failed write leaves no half file.
  def write(lines)
    FileUtils.mkdir_p(File.dirname(path))
    temporary = "#{path}.partial"
    File.write(temporary, "#{lines.join("\n")}\n", encoding: Encoding::UTF_8)
    File.rename(temporary, path)
  end
end
