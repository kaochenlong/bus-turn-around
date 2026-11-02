# bin/monthly-cards: prints the month cards of the months that are over, from the
# machine that holds the raw files, and stores the files in the production database
# through the ssh port forward, as in the monthly-card-pdf spec. Without arguments it
# only prints the plan: one line per page route and month. --print prints the months
# that are ready and have no printed version. It runs every hour after
# bin/nightly-load: a month is printed the first hour it is ready, and a printed
# version never changes, so that is once. --revise adds a corrected version of a
# printed month, and --sample prints to a file of the caller's and stores nothing.
#
# Every print also leaves a copy on this machine (RouteCardLocalCopy), because the
# production database is not backed up and a printed card cannot be recomputed. A
# copy of a version the database has not printed therefore means the database was
# rebuilt: the month is not printed again, which would replace the only original
# with new figures, and --restore stores the copies back.
#
# A usage error, a missing environment variable or a broken configuration stops it
# before the forward is opened. One route's failure does not stop the others, because
# nobody watches the schedule, and makes the exit status non-zero; a month that is
# not ready yet does not.
class MonthlyCardsCommand
  USAGE = <<~TEXT.freeze
    用法：bin/monthly-cards          印出每條路線每個月的狀態，不動正式站
          bin/monthly-cards --print  把到齊而且還沒印的月份印成 PDF，存進正式站
          ROUTE=<頁面路線 Id> MONTH=<YYYY-MM> REASON=<原因> bin/monthly-cards --revise  出一份更正版
          ROUTE=<頁面路線 Id> MONTH=<YYYY-MM> OUT=<路徑> bin/monthly-cards --sample     印一份不存的試印檔
          bin/monthly-cards --restore  資料庫重建之後，把這台留的檔存回正式站
    原始檔的資料根目錄由環境變數 TURNAROUND_DATA 給，正式站的資料庫密碼由 WEBSITE_DATABASE_PASSWORD 給。
    CHROME_PATH 換 Chrome 的位置，CARD_BASE_URL 換月卡頁網址的開頭。
  TEXT
  ACTIONS = { [] => :print_plan, [ "--print" ] => :print_ready, [ "--revise" ] => :revise, [ "--sample" ] => :sample, [ "--restore" ] => :restore }.freeze
  PRINTING = %i[print_ready revise sample].freeze
  ROUTE_ID = /\A[1-9]\d*\z/

  # A reason that stops the command; the message is what to print.
  class Failure < StandardError; end

  # Where a route's month stands. kind is what to do about it, text what to say and
  # coverage, for a month not printed, what was worked out.
  State = Data.define(:kind, :text, :coverage)

  # `months` is a CardMonths and `days` a DerivedDays; without them the configuration
  # files are read when the command runs, so a broken file stops it like any other
  # check. `check` answers like RawDayCheck and `printer` like CardPrinter.
  def initialize(argv, env:, out: $stdout, now: Time.current, route_ids: RoutePage.route_ids, months: nil, days: nil, check: RawDayCheck, printer: nil,
                 tunnel: ProductionTunnel, lock_path: Rails.root.join("tmp/nightly-load.lock"),
                 checkout_versions: ActiveRecord::Base.connection_pool.migration_context.migrations.map(&:version),
                 deploy: DerivedPushCommand.deploy_config)
    @argv = argv
    @env = env
    @out = out
    @now = now
    @route_ids = route_ids
    @months = months
    @days = days
    @check = check
    @printer = printer
    @deploy = deploy
    @session = ProductionSession.new(action: "印", out:, tunnel:, lock_path:, checkout_versions:, deploy:)
  end

  # Returns the exit status: 0 when nothing failed, or when another run holds the lock.
  def run
    action = ACTIONS.fetch(@argv) { usage!("看不懂的參數：#{@argv.join(' ')}") }
    card_months
    derived_days
    local_port = check_environment
    check_arguments(action)
    printer if PRINTING.include?(action)
    @session.with_lock { @session.open(local_port:) { send(action) } }
  rescue Failure, ProductionSession::Failure, CardMonths::InvalidConfiguration, DerivedDays::InvalidConfiguration, OfficeCalendarSnapshot::Error => e
    @out.puts(e.message)
    1
  end

  private

  def usage!(reason) = raise(Failure, "#{reason}\n\n#{USAGE}")

  def card_months = @months ||= CardMonths.from_config

  def derived_days = @days ||= DerivedDays.from_config

  # The local port of the forward. bin/monthly-cards sets DB_PORT to TUNNEL_PORT, so
  # the database connection goes through the forward.
  def check_environment
    usage!("沒有 TURNAROUND_DATA") if data_root.to_s.empty?
    usage!("沒有 WEBSITE_DATABASE_PASSWORD") if @env["WEBSITE_DATABASE_PASSWORD"].to_s.empty?
    ProductionSession.local_port(@env["DB_PORT"]) || usage!("TUNNEL_PORT（DB_PORT）不是埠號：#{@env['DB_PORT']}")
  end

  def data_root = @env["TURNAROUND_DATA"]

  # What --revise and --sample take from the environment, read before the forward.
  def check_arguments(action)
    return unless %i[revise sample].include?(action)

    @route_id, @month = route_and_month
    return usage!("沒有 REASON") if action == :revise && @env["REASON"].blank?

    check_out_path if action == :sample
  end

  def route_and_month
    usage!("沒有 ROUTE 或格式不對") unless ROUTE_ID.match?(@env["ROUTE"].to_s)
    month = CardMonths.parse(@env["MONTH"]) || usage!("沒有 MONTH 或格式不對")
    route_id = Integer(@env["ROUTE"])
    page_route_id = RoutePage.member_of(route_id)
    usage!("#{route_id} 是 #{page_route_id} 那一頁的附屬路線，請用 ROUTE=#{page_route_id}") if page_route_id
    usage!("#{route_id} 不是頁面路線") unless @route_ids.include?(route_id)

    [ route_id, month ]
  end

  def check_out_path
    usage!("沒有 OUT") if @env["OUT"].blank?
    usage!("OUT 的目錄不存在：#{File.dirname(@env['OUT'])}") unless File.directory?(File.dirname(@env["OUT"]))
  end

  def printer
    @printer ||= CardPrinter.new(base_url: base_url, chrome_path: @env["CHROME_PATH"].presence || CardPrinter::DEFAULT_CHROME)
  end

  def base_url
    return @env["CARD_BASE_URL"] if @env["CARD_BASE_URL"].present?

    host = @deploy.dig("proxy", "host") or raise Failure, "config/deploy.yml 沒有 proxy.host，也沒有 CARD_BASE_URL"
    "https://#{host}"
  end

  # Every page route and month that is over, by route.
  def route_months = @route_ids.product(card_months.due(now: @now))

  def print_plan
    print_nothing_due if card_months.due(now: @now).empty?
    states = route_months.map { |route_id, month| state_of(route_id, month).tap { @out.puts(line(route_id, month, it.text)) } }
    states.any? { it.kind == :unrestored } ? 1 : 0
  end

  def print_nothing_due
    @out.puts("還沒有到期的月份：第一份是 #{card_months.first_month.strftime('%Y-%m')}，那個月過完才印。")
  end

  def line(route_id, month, text) = "路線 #{route_id} #{month.strftime('%Y-%m')}：#{text}"

  def state_of(route_id, month)
    printed = printed_versions(route_id, month)
    unrestored = RouteCardLocalCopy.versions(data_root, route_id, month) - printed
    return State.new(kind: :unrestored, text: unrestored_text(unrestored), coverage: nil) if unrestored.any?
    return State.new(kind: :printed, text: "已印 v#{printed.max}", coverage: nil) if printed.any?

    coverage = coverage_of(route_id, month)
    return State.new(kind: :waiting, text: "還在等 #{days_text(coverage.waiting_days)}", coverage:) unless coverage.ready?

    stale = RouteDay.needing_reload.where(route_id:, day: month..month.end_of_month).order(:day).pluck(:day)
    return State.new(kind: :waiting, text: "數字還沒重算 #{days_text(stale)}", coverage:) if stale.any?

    State.new(kind: :ready, text: "到齊可印", coverage:)
  end

  def printed_versions(route_id, month) = RouteCard.printed.where(route_id:, month:).pluck(:version)

  def unrestored_text(versions) = "這台有 #{versions.map { "v#{it}" }.join('、')} 的檔，正式站沒有；先跑 bin/monthly-cards --restore"

  def coverage_of(route_id, month) = RouteCardCoverage.new(route_id:, month:, data_root:, days: derived_days, now: @now, check: @check)

  def days_text(days) = days.map { it.strftime("%m-%d") }.join("、")

  # Prints every month that is ready and says how many of each there were. One that
  # fails is printed and the next one goes on: what was stored before it stays.
  def print_ready
    counts = Hash.new(0)
    print_nothing_due if card_months.due(now: @now).empty?
    route_months.each { |route_id, month| counts[print_month(route_id, month)] += 1 }
    @out.puts("印好 #{counts[:stored]} 份、失敗 #{counts[:failed]} 份、還不能印 #{counts[:waiting]} 份、早就印過 #{counts[:printed]} 份" \
              "#{"、要先還原 #{counts[:unrestored]} 份" if counts[:unrestored].positive?}")
    counts[:failed].zero? && counts[:unrestored].zero? ? 0 : 1
  end

  # What became of the month: its state's kind, :stored or :failed.
  def print_month(route_id, month)
    state = state_of(route_id, month)
    @out.puts(line(route_id, month, state.text)) unless state.kind == :printed
    fill_in_copies(route_id, month) if state.kind == :printed
    return state.kind unless state.kind == :ready

    route_card = RouteCard.newest(route_id, month) || RouteCard.new(route_id:, month:)
    route_card.update!(coverage: state.coverage.to_h)
    @out.puts(line(route_id, month, stored_text(route_card, store_print(route_card))))
    :stored
  rescue StandardError => e
    @out.puts(line(route_id, month, "失敗：#{failure_message(e)}"))
    :failed
  end

  # Returns what was printed. The copy comes after the database: a failure there
  # leaves a version that is printed and whose copy the next --print fills in.
  def store_print(route_card)
    printer.print(route_card).tap do |printed|
      route_card.store_printed!(pdf: printed.bytes, summary: printed.summary, program_version: printed.program_version)
      RouteCardLocalCopy.for(data_root, route_card).write(route_card, printed.bytes)
    end
  end

  def stored_text(route_card, printed) = "印好 v#{route_card.version}，#{size_and_seconds(printed)}"

  def size_and_seconds(printed) = "#{printed.bytes.bytesize} bytes，開頁面 #{printed.page_seconds.round(1)} 秒"

  # A printed version whose copy is not all here gets it from the stored bytes.
  def fill_in_copies(route_id, month)
    RouteCard.printed.where(route_id:, month:).order(:version).each do |route_card|
      copy = RouteCardLocalCopy.for(data_root, route_card)
      next if copy.complete?

      copy.fill_in(route_card, route_card.route_card_pdf.pdf)
      @out.puts(line(route_id, month, "補上 v#{route_card.version} 的本機副本"))
    end
  end

  # A new version of a printed month. A revision whose print failed left a version
  # without a PDF, which the next one uses, so that a failure takes no version number.
  def revise
    printed = printed_versions(@route_id, @month)
    unrestored = RouteCardLocalCopy.versions(data_root, @route_id, @month) - printed
    raise Failure, line(@route_id, @month, unrestored_text(unrestored)) if unrestored.any?

    usage!("#{line(@route_id, @month, '沒有印過的版本，不用更正')}；還沒印的月份由 --print 印") if printed.empty?
    coverage = coverage_of(@route_id, @month)
    raise Failure, line(@route_id, @month, "還在等 #{days_text(coverage.waiting_days)}，不能更正") unless coverage.ready?

    newest = RouteCard.newest(@route_id, @month)
    route_card = newest.printed? ? RouteCard.new(route_id: @route_id, month: @month, version: newest.version + 1) : newest
    route_card.update!(coverage: coverage.to_h, revision_reason: @env["REASON"].strip)
    @out.puts(line(@route_id, @month, stored_text(route_card, store_print(route_card))))
    0
  rescue CardPrinter::Failure, RouteCardLocalCopy::Failure => e
    @out.puts(line(@route_id, @month, "失敗：#{e.message}"))
    1
  end

  # Prints to the file asked for and stores nothing. The page needs a route card, so
  # one is added for as long as the print takes when the month has none.
  def sample
    coverage = coverage_of(@route_id, @month)
    @out.puts(line(@route_id, @month, "還在等 #{days_text(coverage.waiting_days)}，照樣試印")) unless coverage.ready?
    route_card = RouteCard.newest(@route_id, @month)
    added = route_card.nil?
    route_card ||= RouteCard.create!(route_id: @route_id, month: @month, coverage: coverage.to_h)
    printed = printer.print(route_card)
    File.binwrite(@env["OUT"], printed.bytes)
    @out.puts(line(@route_id, @month, "試印好了：#{@env['OUT']}，#{size_and_seconds(printed)}"))
    0
  rescue CardPrinter::Failure, SystemCallError => e
    @out.puts(line(@route_id, @month, "失敗：#{e.message}"))
    1
  ensure
    route_card.destroy! if added
  end

  # Stores back every copy the database does not have. One that does not hold together
  # is named and the next one goes on.
  def restore
    copies = RouteCardLocalCopy.all(data_root)
    @out.puts("這台沒有留任何一份") if copies.empty?
    counts = Hash.new(0)
    copies.each { counts[restore_copy(it)] += 1 }
    @out.puts("存回 #{counts[:restored]} 份、本來就有 #{counts[:present]} 份、失敗 #{counts[:failed]} 份") if copies.any?
    counts[:failed].zero? ? 0 : 1
  end

  # What became of the copy: :restored, :present or :failed. A printed row is never
  # changed, whichever of the two holds the right bytes: a person has to look.
  def restore_copy(copy)
    kept = copy.read
    route_card = RouteCard.find_or_initialize_by(route_id: kept.route_id, month: kept.month, version: kept.version)
    return present_or_different(route_card, kept, copy) if route_card.printed?

    route_card.store_printed!(pdf: kept.pdf, **kept.attributes)
    @out.puts("存回 #{copy.pdf_path}")
    :restored
  rescue StandardError => e
    @out.puts("失敗：#{failure_message(e)}")
    :failed
  end

  def present_or_different(route_card, kept, copy)
    return :present if route_card.pdf_sha256 == kept.pdf_sha256

    raise RouteCardLocalCopy::Failure, "#{copy.pdf_path} 跟正式站的 v#{kept.version} 不同（SHA-256），兩邊都沒有動，要人看過"
  end

  # The printer and the copy word their own failures; anything else is named by its class.
  def failure_message(error)
    [ CardPrinter::Failure, RouteCardLocalCopy::Failure ].any? { error.is_a?(it) } ? error.message : "#{error.class}: #{error.message}"
  end
end
