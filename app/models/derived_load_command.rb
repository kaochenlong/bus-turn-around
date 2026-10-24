# bin/rails derived:load: writes one route's Taipei days into the derived
# tables, oldest first, one RouteDayLoader call per day, with the member
# routes its page counts with it. A route listed under another route's
# member_routes has no page and is a usage error that names the page route.
# A range stops at the first day that fails; the days written before it stay.
# The raw data root comes only from TURNAROUND_DATA, so no host path is
# written into the repo.
class DerivedLoadCommand
  USAGE = <<~TEXT.freeze
    用法：bin/rails derived:load ROUTE=<路線 Id> DAY=<YYYY-MM-DD>
          bin/rails derived:load ROUTE=<路線 Id> FROM=<YYYY-MM-DD> TO=<YYYY-MM-DD>
    原始檔的資料根目錄由環境變數 TURNAROUND_DATA 給。
  TEXT
  ISO_DATE = /\A\d{4}-\d{2}-\d{2}\z/
  ROUTE_ID = /\A[1-9]\d*\z/

  # A reason that stops the command or one day; the message is what to print.
  class Failure < StandardError; end

  def initialize(env, out: $stdout)
    @env = env
    @out = out
  end

  # Returns the exit status: 0 when every requested day was written.
  def run
    route_id, days = parse
    duckdb = AnalysisRun.find_duckdb(@env["PATH"]) or raise Failure, "需要 DuckDB CLI，安裝：brew install duckdb"
    load_days(route_id, days, duckdb)
  rescue Failure => e
    @out.puts(e.message)
    1
  end

  private

  def parse
    route, day, from, to = @env.values_at("ROUTE", "DAY", "FROM", "TO")
    usage!("沒有 ROUTE 或格式不對") unless ROUTE_ID.match?(route.to_s)
    usage!("沒有 TURNAROUND_DATA") if data_root.to_s.empty?
    days = day ? [ parse_day(day) ] : day_range(from, to)
    route_id = Integer(route)
    if (page_route_id = RoutePage.member_of(route_id))
      raise Failure, "#{route_id} 是 #{page_route_id} 那一頁的附屬路線，請用 ROUTE=#{page_route_id}"
    end

    [ route_id, days ]
  end

  def day_range(from, to)
    usage!("要給 DAY，或同時給 FROM 與 TO") if from.nil? || to.nil?
    first, last = parse_day(from), parse_day(to)
    usage!("FROM 晚於 TO") if first > last
    (first..last).to_a
  end

  def parse_day(text)
    usage!("日期格式不對：#{text}") unless ISO_DATE.match?(text)
    Date.iso8601(text)
  rescue Date::Error
    usage!("沒有這一天：#{text}")
  end

  def usage!(reason) = raise(Failure, "#{reason}\n\n#{USAGE}")

  def data_root = @env["TURNAROUND_DATA"]

  def load_days(route_id, days, duckdb)
    written = []
    days.each do |day|
      load_day(route_id, day, duckdb)
      written << day
    rescue Failure, RawDayCheck::Failure, RouteDayLoader::Error => e
      @out.puts("#{day.iso8601} 失敗：#{e.message}")
      break
    end
    @out.puts("寫入的日子：#{written.empty? ? '沒有' : written.map(&:iso8601).join('、')}")
    written.size == days.size ? 0 : 1
  end

  def load_day(route_id, day, duckdb)
    RawDayCheck.check!(data_root:, day:)
    counts = RouteDayLoader.new(route_id:, day:, data_root:, duckdb:, out: @out, member_route_ids: RoutePage.member_route_ids(route_id)).call
    @out.puts("#{day.iso8601} 寫入：趟次 #{counts[:trips]}、折返停留 #{counts[:layovers]}、趟次站 #{counts[:trip_stop_counts]}、" \
              "兩端公廁 #{counts[:end_toilets]} 間、靜止格 #{counts[:end_cells]} 格")
  end
end
