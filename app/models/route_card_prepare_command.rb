# bin/rails cards:prepare: works out which days of a month a page route's card
# covers and stores it in version 1 of the route card, so that the month card page
# can be opened. A month with a day still waiting is named and not written, and a
# month with a printed version is refused. The raw
# data root comes only from TURNAROUND_DATA, so no host path is written into the
# repo. It writes to whichever database the environment points at.
class RouteCardPrepareCommand
  USAGE = <<~TEXT.freeze
    用法：bin/rails cards:prepare ROUTE=<頁面路線 Id> MONTH=<YYYY-MM>
    原始檔的資料根目錄由環境變數 TURNAROUND_DATA 給。
  TEXT
  ROUTE_ID = /\A[1-9]\d*\z/
  MONTH = /\A(\d{4})-(0[1-9]|1[0-2])\z/

  # A reason that stops the command; the message is what to print.
  class Failure < StandardError; end

  # `days` is a DerivedDays; without it config/derived_days.yml is read when the
  # command runs, so a broken file stops it like any other check.
  def initialize(env, out: $stdout, now: Time.current, days: nil, check: RawDayCheck)
    @env = env
    @out = out
    @now = now
    @days = days
    @check = check
  end

  # Returns the exit status: 0 when the month is ready and written.
  def run
    route_id, month = parse
    refuse_printed(route_id, month)
    coverage = RouteCardCoverage.new(route_id:, month:, data_root:, days: derived_days, now: @now, check: @check)
    print_coverage(route_id, month, coverage)
    return print_waiting(coverage) unless coverage.ready?

    RouteCard.find_or_initialize_by(route_id:, month:, version: 1).update!(coverage: coverage.to_h)
    @out.puts("寫入 version 1")
    0
  rescue Failure, OfficeCalendarSnapshot::Error, DerivedDays::InvalidConfiguration => e
    @out.puts(e.message)
    1
  end

  private

  def parse
    route, month = @env.values_at("ROUTE", "MONTH")
    usage!("沒有 ROUTE 或格式不對") unless ROUTE_ID.match?(route.to_s)
    usage!("沒有 MONTH 或格式不對") unless MONTH.match?(month.to_s)
    usage!("沒有 TURNAROUND_DATA") if data_root.to_s.empty?
    route_id = Integer(route)
    page_route_id = RoutePage.member_of(route_id)
    usage!("#{route_id} 是 #{page_route_id} 那一頁的附屬路線，請用 ROUTE=#{page_route_id}") if page_route_id
    usage!("#{route_id} 不是頁面路線") unless RoutePage.route_ids.include?(route_id)

    [ route_id, Date.iso8601("#{month}-01") ]
  end

  def usage!(reason) = raise(Failure, "#{reason}\n\n#{USAGE}")

  # A printed version gets cited and never changes; a correction is a new version.
  def refuse_printed(route_id, month)
    printed = RouteCard.printed.where(route_id:, month:).maximum(:version)
    raise Failure, "路線 #{route_id} #{month.strftime('%Y-%m')} 已經印好 v#{printed}，定稿不再改；要更正用 bin/monthly-cards --revise" if printed
  end

  def data_root = @env["TURNAROUND_DATA"]

  def derived_days = @days || DerivedDays.from_config

  def print_coverage(route_id, month, coverage)
    figures = coverage.to_h
    @out.puts("路線 #{route_id} #{month.strftime('%Y-%m')}：涵蓋 #{figures['loaded_weekdays']} 個平日（這個月有 #{figures['calendar_weekdays']} 個）、" \
              "#{figures['loaded_holidays']} 個假日（這個月有 #{figures['calendar_holidays']} 個）#{'，部分月份' if coverage.partial?}")
    figures["missing"].each { @out.puts("少的日子：#{it['from']} 到 #{it['to']}，#{it['reason']}") }
  end

  def print_waiting(coverage)
    @out.puts("還在等的日子：#{coverage.waiting_days.map(&:iso8601).join('、')}。沒有寫入")
    1
  end
end
