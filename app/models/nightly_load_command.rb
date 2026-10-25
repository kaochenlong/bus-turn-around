# bin/nightly-load: writes the route days the production database lacks into
# it, from the machine that holds the raw files, through an ssh port forward
# to the database accessory (ProductionTunnel). Without --load it only prints
# the plan. --recompute selects the route days production already stores
# too, and ROUTE narrows it to one page route. A usage error, a missing
# environment variable, a broken config/derived_days.yml or a missing DuckDB
# CLI stops it before the forward is opened. The raw data root comes only
# from TURNAROUND_DATA, so no host path is written into the repo.
#
# The route days to load are the page routes, in the order of
# config/route_page.yml, times the candidate days of DerivedDays, oldest
# first, minus the route days production stores unless --recompute is given.
# Every candidate day is checked by RawDayCheck once; a day that fails is
# printed with the reason, none of its route days is loaded, and the exit
# status is non-zero, so it is reported every hour until someone completes
# the files or skips the day. With --load every route day is written by the
# loader of derived:load in its own transaction; one that fails is printed
# and the next one is loaded, because nobody watches the schedule and one
# route's bad data must not keep the other routes out of production.
#
# One run at a time: the lock on tmp/nightly-load.lock is taken before the
# forward and held to the end, because a manual --recompute can run for half
# an hour while the schedule starts the next run, and both would write the
# same route day. Before anything is read or written, the migration versions
# of production must be those of this checkout, which may be an hour behind
# or ahead of the deployed image.
class NightlyLoadCommand
  USAGE = <<~TEXT.freeze
    用法：bin/nightly-load                       印出要寫進正式站的路線日，不動正式站
          bin/nightly-load --load                寫進正式站還沒有的路線日
          bin/nightly-load --recompute [--load]  連正式站已有的路線日一起重算；加 ROUTE=<頁面路線 Id> 只算那一條
    原始檔的資料根目錄由環境變數 TURNAROUND_DATA 給，正式站的資料庫密碼由 WEBSITE_DATABASE_PASSWORD 給。
  TEXT
  ROUTE_ID = /\A[1-9]\d*\z/
  PORT = /\A[1-9]\d{0,4}\z/

  # A reason that stops the command; the message is what to print.
  class Failure < StandardError; end

  # What a run works through: the candidate days, the routes, the
  # [route Id, day] pairs production stores, the [day, route Id] pairs to
  # load in loading order, and the reason of every candidate day whose raw
  # files are incomplete.
  Plan = Data.define(:candidates, :route_ids, :stored, :to_load, :incomplete)

  # The default loader: writes one route day as derived:load does and returns
  # the counts RouteDayLoader returns.
  LOADER = ->(**options) { RouteDayLoader.new(**options).call }

  # `days` is a DerivedDays; without it config/derived_days.yml is read when
  # the command runs, so a broken file stops it like any other check.
  def initialize(argv, env:, out: $stdout, now: Time.current, route_ids: RoutePage.route_ids, days: nil, loader: LOADER,
                 tunnel: ProductionTunnel, lock_path: Rails.root.join("tmp/nightly-load.lock"),
                 checkout_versions: ActiveRecord::Base.connection_pool.migration_context.migrations.map(&:version),
                 deploy: DerivedPushCommand.deploy_config)
    @argv = argv
    @env = env
    @out = out
    @now = now
    @route_ids = route_ids
    @days = days
    @loader = loader
    @tunnel = tunnel
    @lock_path = lock_path.to_s
    @checkout_versions = checkout_versions
    @deploy = deploy
  end

  # Returns the exit status: 0 when every route day loaded was written and no
  # candidate day has incomplete raw files, or when another run holds the lock.
  def run
    load, recompute = parse
    route_id = route_filter(recompute)
    with_lock do
      candidates = derived_days.candidates(now: @now)
      local_port, duckdb = check_environment
      @tunnel.open(host: ssh_host, user: ssh_user, local_port:) { plan_and_load(candidates, route_id, recompute:, load:, duckdb:) }
    end
  rescue Failure => e
    @out.puts(e.message)
    1
  rescue ProductionTunnel::Error => e
    @out.puts("開不了到正式站的轉送：#{e.message}")
    1
  end

  private

  # [load, recompute] from the arguments, in either order.
  def parse
    case @argv.sort
    in [] then [ false, false ]
    in [ "--load" ] then [ true, false ]
    in [ "--recompute" ] then [ false, true ]
    in [ "--load", "--recompute" ] then [ true, true ]
    else usage!("看不懂的參數：#{@argv.join(' ')}")
    end
  end

  # The one page route ROUTE names, or nil without ROUTE. ROUTE only narrows
  # a recompute: the route days production lacks are loaded for every route.
  def route_filter(recompute)
    route = @env["ROUTE"]
    return if route.nil?

    usage!("ROUTE 只能跟 --recompute 一起用") unless recompute
    usage!("ROUTE 格式不對：#{route}") unless ROUTE_ID.match?(route)
    route_id = Integer(route)
    if (page_route_id = RoutePage.member_of(route_id))
      usage!("#{route_id} 是 #{page_route_id} 那一頁的附屬路線，請用 ROUTE=#{page_route_id}")
    end
    usage!("#{route_id} 不是頁面路線，頁面路線是 #{@route_ids.join('、')}") unless @route_ids.include?(route_id)

    route_id
  end

  def derived_days
    @days ||= DerivedDays.from_config
  rescue DerivedDays::InvalidConfiguration => e
    raise Failure, e.message
  end

  # [the local port of the forward, the duckdb executable]. bin/nightly-load
  # sets DB_PORT to TUNNEL_PORT, so the database connection goes through the
  # forward.
  def check_environment
    usage!("沒有 TURNAROUND_DATA") if @env["TURNAROUND_DATA"].to_s.empty?
    usage!("沒有 WEBSITE_DATABASE_PASSWORD") if @env["WEBSITE_DATABASE_PASSWORD"].to_s.empty?
    port = @env["DB_PORT"].to_s
    usage!("TUNNEL_PORT（DB_PORT）不是埠號：#{port}") unless PORT.match?(port) && Integer(port) <= 65_535
    duckdb = AnalysisRun.find_duckdb(@env["PATH"]) or raise Failure, "需要 DuckDB CLI，安裝：brew install duckdb"

    [ Integer(port), duckdb ]
  end

  def usage!(reason) = raise(Failure, "#{reason}\n\n#{USAGE}")

  # Runs the block holding the lock, released when the file is closed; does
  # nothing and returns 0 when another run holds it.
  def with_lock
    FileUtils.mkdir_p(File.dirname(@lock_path))
    File.open(@lock_path, File::RDWR | File::CREAT, 0o644) do |lock|
      unless lock.flock(File::LOCK_EX | File::LOCK_NB)
        @out.puts("另一個 bin/nightly-load 還在跑，這次不做")
        return 0
      end

      yield
    end
  end

  # Everything that reads or writes production, inside the forward. Returns
  # the exit status.
  def plan_and_load(candidates, route_id, recompute:, load:, duckdb:)
    check_migration_versions
    plan = plan(candidates, route_id ? [ route_id ] : @route_ids, recompute:)
    print_plan(plan, route_id:, recompute:, load:)
    failed = load ? load_route_days(plan.to_load, duckdb) : 0
    @out.puts("載入 #{plan.to_load.size - failed} 個路線日、失敗 #{failed} 個、原始檔不齊 #{plan.incomplete.size} 天") if load
    failed.zero? && plan.incomplete.empty? ? 0 : 1
  end

  # Prints the target with whether the migration versions agree; stops when
  # they do not, because the loader writes the columns of this checkout.
  def check_migration_versions
    target = "正式站：#{ssh_user}@#{ssh_host} 的 #{ActiveRecord::Base.connection_db_config.database}"
    database = ActiveRecord::Base.connection_pool.migration_context.get_all_versions
    only_database, only_checkout = (database - @checkout_versions).sort, (@checkout_versions - database).sort
    return @out.puts("#{target}，migration 版本一致") if only_database.empty? && only_checkout.empty?

    lines = [ ("  只在正式站：#{only_database.join('、')}" if only_database.any?), ("  只在這份 checkout：#{only_checkout.join('、')}" if only_checkout.any?) ]
    raise Failure, [ "#{target}，migration 版本不一致，這次不載入：", *lines.compact,
                     "正式站多的要等這份 checkout 跟上 origin/main，checkout 多的要等正式站 deploy；兩邊一樣才載入。" ].join("\n")
  end

  def plan(candidates, route_ids, recompute:)
    stored = RouteDay.pluck(:route_id, :day)
    incomplete = candidates.days.filter_map { |day| incomplete_reason(day)&.then { [ day, it ] } }.to_h
    to_load = (candidates.days - incomplete.keys).product(route_ids)
    to_load -= stored.map(&:reverse) unless recompute
    Plan.new(candidates:, route_ids:, stored:, to_load:, incomplete:)
  end

  # Loads every route day of `to_load` in order and returns the number that
  # failed. A route day written before a failure stays: the loader replaces
  # each one in a transaction of its own.
  def load_route_days(to_load, duckdb)
    failed = 0
    to_load.each do |day, route_id|
      counts = @loader.call(route_id:, day:, data_root: @env["TURNAROUND_DATA"], duckdb:, out: @out)
      @out.puts("#{day.iso8601} #{route_id} #{RouteDayLoader.summary(counts)}")
    rescue StandardError => e
      failed += 1
      @out.puts("#{day.iso8601} #{route_id} 失敗：#{failure_message(e)}")
    end
    failed
  end

  # The loader words its own failures; anything else is named by its class.
  def failure_message(error) = error.is_a?(RouteDayLoader::Error) ? error.message : "#{error.class}: #{error.message}"

  def incomplete_reason(day)
    RawDayCheck.check!(data_root: @env["TURNAROUND_DATA"], day:)
    nil
  rescue RawDayCheck::Failure => e
    e.message
  end

  def print_plan(plan, route_id:, recompute:, load:)
    candidates = plan.candidates
    @out.puts("頁面路線：#{plan.route_ids.join('、')}#{"（ROUTE=#{route_id}）" if route_id}")
    @out.puts("日子：#{candidates.first_day.iso8601} 到 #{candidates.last_day.iso8601}（讀檔視窗已結束的最後一天）")
    print_list("跳過的日子：", candidates.skipped_days.map { |day, reason| "#{day.iso8601}：#{reason}" })
    @out.puts("正式站已有 #{plan.stored.size} 個路線日")
    plan.stored.group_by(&:first).sort.each do |id, pairs|
      first, last = pairs.map(&:last).minmax
      @out.puts("  #{id}：#{first.iso8601} 到 #{last.iso8601}，#{pairs.size} 天")
    end
    print_to_load(plan.to_load, recompute:)
    print_list("原始檔不齊 #{plan.incomplete.size} 天：", plan.incomplete.map { |day, reason| "#{day.iso8601}：#{reason}" })
    @out.puts("沒有動正式站；要載入就加 --load。") unless load
  end

  def print_to_load(to_load, recompute:)
    return @out.puts("沒有要載入的路線日") if to_load.empty?

    @out.puts("要載入 #{to_load.size} 個路線日#{'（--recompute：含正式站已有的）' if recompute}：")
    to_load.group_by(&:first).each { |day, pairs| @out.puts("  #{day.iso8601}：#{pairs.map(&:last).join('、')}") }
  end

  # A heading and one indented line per item, or nothing without items.
  def print_list(heading, lines)
    return if lines.empty?

    @out.puts(heading)
    lines.each { @out.puts("  #{it}") }
  end

  def ssh_user = @deploy.dig("ssh", "user") || "root"

  def ssh_host
    @deploy.dig("accessories", "db", "host") or raise Failure, "config/deploy.yml 沒有 accessories 的 db.host"
  end
end
