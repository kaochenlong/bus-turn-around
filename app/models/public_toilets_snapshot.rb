require "csv"

# bin/rails external:public_toilets: saves one snapshot of the national public
# toilet registry of 環境部 (data.gov.tw dataset 30794) under the data root, as
# external/public-toilets/<Taipei day>.csv. The registry has no file to
# download, only an API that answers at most 1,000 rows a request, so the rows
# are requested page by page in the order of `number`, and every page is
# checked before the next one is requested. The snapshot is written once,
# after the last page: pages that do not look like the expected table are
# never written, and existing snapshots stay.
class PublicToiletsSnapshot
  # The CSV address published on the dataset page, sorted by `number` instead
  # of the page's ImportDate: unsorted, the API repeats rows across pages. The
  # api_key is the one the dataset page hands out with this link to everyone,
  # not a secret; keep it as it is.
  PAGE_URL = "https://data.moenv.gov.tw/api/v2/fac_p_07?api_key=4c89a32a-a214-461b-bf29-30ff32a61a8a" \
             "&format=CSV&sort=number%20asc".freeze
  PAGE_SIZE = 1000
  MAX_PAGES = 200
  HEADER = "county,areacode,village,number,name,address,administration,latitude,longitude,grade,type2,type,exec,diaper".freeze
  COLUMNS = HEADER.split(",").freeze
  DIRECTORY = "external/public-toilets".freeze
  TAIPEI_COUNTY = "63000".freeze
  NEW_TAIPEI_COUNTY = "65000".freeze
  BYTE_ORDER_MARK = "\xEF\xBB\xBF".b.freeze

  # A page or the assembled rows are not usable; the message says which page and why.
  class Error < StandardError; end

  # The rake task: returns the exit status.
  def self.run(env, out: $stdout, fetcher: HttpFetcher, day: Date.current)
    data_root = env["TURNAROUND_DATA"].presence
    unless data_root
      out.puts("用法：TURNAROUND_DATA=<原始檔的資料根目錄> bin/rails external:public_toilets")
      return 1
    end

    snapshot = new(data_root:, day:, fetcher:)
    counts = snapshot.call
    out.puts("#{snapshot.path}：#{counts[:rows]} 列，臺北市 #{counts[:taipei]} 列、新北市 #{counts[:new_taipei]} 列")
    0
  rescue Error => e
    out.puts("沒有寫入公廁快照：#{e.message}")
    1
  end

  def initialize(data_root:, day:, fetcher: HttpFetcher, page_size: PAGE_SIZE, max_pages: MAX_PAGES)
    @data_root = data_root
    @day = day
    @fetcher = fetcher
    @page_size = page_size
    @max_pages = max_pages
  end

  def path = File.join(@data_root, DIRECTORY, "#{@day.iso8601}.csv")

  # Writes the snapshot and returns the number of rows, and of rows in 臺北市 and in 新北市.
  def call
    rows = fetch_pages
    write(rows)
    counties = rows.map(&:first)
    { rows: rows.size, taipei: counties.count(TAIPEI_COUNTY), new_taipei: counties.count(NEW_TAIPEI_COUNTY) }
  end

  private

  # Requests pages until one holds fewer rows than a page can.
  def fetch_pages
    rows = []
    page = 0
    loop do
      page += 1
      raise Error, "抓到第 #{page - 1} 頁還沒結束，超過上限 #{@max_pages} 頁" if page > @max_pages

      page_rows = fetch_page(page)
      check_order(page, page_rows, rows.last&.fetch(3))
      rows.concat(page_rows)
      break if page_rows.size < @page_size
    end
    raise Error, "第 #{page} 頁只有表頭，整份沒有任何公廁" if rows.empty?

    rows
  end

  # The rows of one page, checked before the next page is requested.
  def fetch_page(page)
    status, body = @fetcher.call("#{PAGE_URL}&limit=#{@page_size}&offset=#{(page - 1) * @page_size}")
    raise Error, "第 #{page} 頁回應 HTTP #{status}" unless status == 200

    header, *rows = parse(page, decode(page, body))
    raise Error, "第 #{page} 頁的表頭不是「#{HEADER}」" unless header == COLUMNS
    raise Error, "第 #{page} 頁有 #{rows.size} 列，超過每頁 #{@page_size} 列" if rows.size > @page_size

    rows.each.with_index(1) { |fields, index| check_row("第 #{page} 頁第 #{index} 列", fields) }
    rows
  end

  def decode(page, body)
    text = body.b.delete_prefix(BYTE_ORDER_MARK).force_encoding(Encoding::UTF_8)
    raise Error, "第 #{page} 頁的內容不是 UTF-8" unless text.valid_encoding?

    text
  end

  def parse(page, text)
    CSV.parse(text)
  rescue CSV::MalformedCSVError => e
    raise Error, "第 #{page} 頁不是合法的 CSV：#{e.message}"
  end

  def check_row(where, fields)
    raise Error, "#{where}不是 #{COLUMNS.size} 欄" unless fields.size == COLUMNS.size

    number, name, latitude, longitude = fields.values_at(3, 4, 7, 8)
    raise Error, "#{where}的 number 是空的" if number.blank?
    raise Error, "#{where}的 name 是空的" if name.blank?
    raise Error, "#{where}的經緯度不是數字" unless [ latitude, longitude ].all? { Float(it, exception: false) }
  end

  # `number` grows strictly in file order, which also rules out a row that
  # comes back on two pages.
  def check_order(page, rows, previous)
    rows.each.with_index(1) do |fields, index|
      number = fields[3]
      raise Error, "第 #{page} 頁第 #{index} 列的 number #{number} 沒有大於前一列的 #{previous}：分頁沒有照順序" if previous && number <= previous

      previous = number
    end
  end

  # Written to a temporary file first, so a failed write leaves no half file.
  def write(rows)
    FileUtils.mkdir_p(File.dirname(path))
    temporary = "#{path}.partial"
    File.write(temporary, CSV.generate { |csv| [ COLUMNS, *rows ].each { csv << it } }, encoding: Encoding::UTF_8)
    File.rename(temporary, path)
  end
end
