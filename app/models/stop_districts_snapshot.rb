require "tmpdir"
require "zip"

# bin/rails external:stop_districts: saves one snapshot of the district of
# every stop location under the data root, as
# external/stop-districts/<Taipei day>.csv. The township boundaries come from
# data.gov.tw dataset 7441 (內政部國土測繪中心, 鄉鎮市區界線(TWD97經緯度)), a
# zip archive on TGOS whose boundary members are TOWN_MOI_<version>.shp, .shx,
# .dbf and .prj; its other members, some with Big5 names, are left alone. The
# stop locations come from the GetStop.gz of the static snapshot with the
# latest day name under the data root. The point-in-polygon work is
# analysis/stop_district_snapshot.sql, which needs the DuckDB spatial
# extension on this machine only: the nightly load reads the CSV. A file that
# does not look like the expected table is never given its name, and existing
# snapshots stay.
class StopDistrictsSnapshot
  # The archive on TGOS, percent-encoded because its path carries CJK
  # characters, which URI() does not accept as they are.
  DOWNLOAD_URL = "https://www.tgos.tw/tgos/VirtualDir/Product/3fe61d4a-ca23-4f45-8aca-4a536f40f290/" \
                 "%E9%84%89(%E9%8E%AE%E3%80%81%E5%B8%82%E3%80%81%E5%8D%80)%E7%95%8C%E7%B7%9A1140318.zip".freeze
  DIRECTORY = "external/stop-districts".freeze
  HEADER = "stop_location_id,county,town".freeze
  SQL_FILE = "stop_district_snapshot.sql".freeze
  INSTALL_HINT = 'duckdb -c "INSTALL spatial"'.freeze
  # A boundary member of the archive; the version is the date in its name,
  # such as 1140318. Matched against the name's bytes, since other members
  # have names that are not UTF-8.
  MEMBER = /\ATOWN_MOI_(?<version>[A-Za-z0-9]+)\.(?<extension>shp|shx|dbf|prj|cpg)\z/
  REQUIRED_EXTENSIONS = %w[shp shx dbf prj].freeze
  STATIC_DAY = /\A\d{4}-\d{2}-\d{2}\z/
  WHOLE_NUMBER = /\A\d+\z/

  # The download, the archive, DuckDB or the written file is not usable; the
  # message says why.
  class Error < StandardError; end

  # What a written snapshot reports: stop locations read, assigned to a
  # district, and the version of the boundaries.
  Result = Data.define(:n_locations, :n_assigned, :version)

  # The default runner: the SQL file after params.sql alone, in the DuckDB
  # CLI; it returns the rows of the counts the file prints.
  RUNNER = ->(duckdb, variables) { AnalysisRun.run(duckdb, variables, extra_files: [ SQL_FILE ], stages: false) }

  # The rake task: returns the exit status.
  def self.run(env, out: $stdout, fetcher: HttpFetcher, runner: RUNNER, day: Date.current)
    data_root = env["TURNAROUND_DATA"].presence
    unless data_root
      out.puts("用法：TURNAROUND_DATA=<原始檔的資料根目錄> bin/rails external:stop_districts")
      return 1
    end
    duckdb = AnalysisRun.find_duckdb(env["PATH"])
    unless duckdb
      out.puts("需要 DuckDB CLI，安裝：brew install duckdb")
      return 1
    end

    snapshot = new(data_root:, day:, duckdb:, fetcher:, runner:)
    result = snapshot.call
    out.puts("#{snapshot.path}：站位 #{result.n_locations} 個，判到行政區 #{result.n_assigned} 個，" \
             "判不到 #{result.n_locations - result.n_assigned} 個（區界檔 TOWN_MOI_#{result.version}）")
    0
  rescue Error => e
    out.puts("沒有寫入站位行政區快照：#{e.message}")
    1
  end

  def initialize(data_root:, day:, duckdb:, fetcher: HttpFetcher, runner: RUNNER)
    @data_root = data_root
    @day = day
    @duckdb = duckdb
    @fetcher = fetcher
    @runner = runner
  end

  def path = File.join(@data_root, DIRECTORY, "#{@day.iso8601}.csv")

  # Writes the snapshot and returns its counts and the boundaries' version.
  # The stop list is looked up before anything is downloaded.
  def call
    stops_path = newest_stop_list
    status, body = @fetcher.call(DOWNLOAD_URL)
    raise Error, "下載回應 HTTP #{status}" unless status == 200

    Dir.mktmpdir("stop-districts") do |dir|
      version = extract(body, dir)
      counts = write_checked(shapefile: File.join(dir, "TOWN_MOI_#{version}.shp"), stops_path:)
      Result.new(n_locations: counts.fetch("n_locations"), n_assigned: counts.fetch("n_assigned"), version:)
    end
  end

  private

  # The GetStop.gz of the static snapshot with the latest day name.
  def newest_stop_list
    paths = Dir.glob(File.join(@data_root, "static", "*", "GetStop.gz")).select { STATIC_DAY.match?(File.basename(File.dirname(it))) }
    paths.max_by { File.basename(File.dirname(it)) } or raise Error, "資料根目錄沒有任何 static/<台北日>/GetStop.gz"
  end

  # Writes the boundary members of one version into dir and returns the
  # version. Of several complete versions, the latest by name is taken.
  def extract(body, dir)
    members = boundary_members(body)
    version = members.keys.select { |v| (REQUIRED_EXTENSIONS - members[v].keys).empty? }.max
    raise Error, "區界檔裡沒有 TOWN_MOI_<版本>.shp、.shx、.dbf、.prj 四個成員" unless version

    members[version].each { |extension, bytes| File.binwrite(File.join(dir, "TOWN_MOI_#{version}.#{extension}"), bytes) }
    version
  end

  # version => { extension => bytes } of the members whose names match MEMBER.
  def boundary_members(body)
    found = Hash.new { |hash, version| hash[version] = {} }
    Zip::File.open_buffer(body) do |zip|
      zip.each do |entry|
        match = MEMBER.match(entry.name.b) or next
        found[match[:version]][match[:extension]] = entry.get_input_stream.read
      end
    end
    found
  rescue Zip::Error => e
    raise Error, "下載到的內容不是 zip：#{e.message}"
  end

  # Runs the SQL into a temporary file next to the snapshot, checks it and
  # gives it its name; a failure anywhere leaves no temporary file.
  def write_checked(shapefile:, stops_path:)
    FileUtils.mkdir_p(File.dirname(path))
    temporary = "#{path}.partial"
    counts = run_sql(shapefile:, stops_path:, output: temporary)
    check(temporary, counts.fetch("n_assigned"))
    File.rename(temporary, path)
    counts
  rescue StandardError
    FileUtils.rm_f(temporary)
    raise
  end

  # The counts row the SQL prints. A DuckDB failure that mentions the spatial
  # extension is the one every new machine hits, so it names the install.
  def run_sql(shapefile:, stops_path:, output:)
    rows = @runner.call(@duckdb, { shapefile_path: shapefile, stops_path:, output_path: output })
    rows.last or raise Error, "analysis/#{SQL_FILE} 沒有印出站位數"
  rescue AnalysisRun::Error => e
    message = e.message.lines.first.to_s.strip
    raise Error, message unless message.include?("spatial")

    raise Error, "需要 DuckDB 的 spatial 延伸：先在這台機器跑 #{INSTALL_HINT}（#{message}）"
  end

  # Fields carry no quotes or commas in this file, so a row that does not
  # split into exactly three columns is rejected rather than guessed.
  def check(file, n_assigned)
    lines = File.read(file, encoding: Encoding::UTF_8).lines.map(&:chomp)
    raise Error, "表頭不是「#{HEADER}」" unless lines.first == HEADER

    rows = lines.drop(1)
    raise Error, "沒有任何站位判到行政區" if rows.empty?

    rows.each_with_index.inject(0) { |previous, (line, index)| check_row(line, index + 2, previous) }
    raise Error, "檔裡 #{rows.size} 列，DuckDB 回報判到 #{n_assigned} 個站位" unless rows.size == n_assigned
  end

  # Returns the row's stop location Id, which has to be above the previous one.
  def check_row(line, number, previous)
    fields = line.split(",", -1)
    raise Error, "第 #{number} 行不是 3 欄" unless fields.size == 3

    id, county, town = fields
    raise Error, "第 #{number} 行的站位 Id 不是遞增的整數" unless WHOLE_NUMBER.match?(id) && Integer(id, 10) > previous
    raise Error, "第 #{number} 行的縣市或鄉鎮市區是空的" if county.empty? || town.empty?

    Integer(id, 10)
  end
end
