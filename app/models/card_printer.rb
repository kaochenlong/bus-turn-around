require "net/http"
require "tmpdir"

# Prints the month card page of a route card into a PDF with headless Chrome, as in
# the monthly-card-pdf spec. Chrome is happy to print an error page and exit 0, so
# the page is fetched and checked first, and the file is checked afterwards. What
# the page says about its own program version and figures is returned with the file,
# because the page is what gets printed: the checkout running this may be another
# commit than the image serving the page. Nobody watches the schedule, so both the
# request and Chrome have a time limit.
class CardPrinter
  DEFAULT_CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome".freeze
  CHROME_FLAGS = %w[--headless=new --disable-gpu --no-first-run --no-default-browser-check --no-pdf-header-footer --virtual-time-budget=10000].freeze
  PDF_HEAD = "%PDF-".freeze
  # The fonts alone are over this, so it only keeps out a blank page or an error page.
  MIN_BYTES = 100_000
  OPEN_SECONDS = 10
  READ_SECONDS = 120
  CHROME_SECONDS = 120
  # How long Chrome gets to stop on TERM before KILL.
  STOP_SECONDS = 5
  POLL_SECONDS = 0.1

  # This route and month could not be printed; the message says why.
  class Failure < StandardError; end

  # page_seconds is how long the page took to answer: the proxy in front of the site
  # gives up at 30 seconds, and a longer month takes longer.
  Printed = Data.define(:bytes, :program_version, :summary, :page_seconds)

  # The default fetcher: GETs the address and returns the response.
  FETCH = lambda do |url|
    uri = URI(url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: OPEN_SECONDS, read_timeout: READ_SECONDS) { it.get(uri.request_uri) }
  end

  # `fetch` takes a URL and answers something with code and body.
  def initialize(base_url:, chrome_path:, fetch: FETCH, timeout: CHROME_SECONDS)
    @base_url = base_url.chomp("/")
    @chrome_path = chrome_path
    @fetch = fetch
    @timeout = timeout
  end

  # Returns a Printed; raises Failure when the card cannot be printed.
  def print(route_card)
    raise Failure, "找不到 Chrome：#{@chrome_path}。要換位置就設 CHROME_PATH" unless File.file?(@chrome_path) && File.executable?(@chrome_path)

    url = "#{@base_url}#{Rails.application.routes.url_helpers.route_card_path(route_card.route_id, route_card.year_month)}"
    started = monotonic
    document = checked_page(url, route_card)
    page_seconds = monotonic - started
    program_version = program_version_of(document, url)
    summary = summary_of(document, url)
    Printed.new(bytes: run_chrome(url), program_version:, summary:, page_seconds:)
  end

  private

  def checked_page(url, route_card)
    response = fetch_page(url)
    raise Failure, "月卡頁回 #{response.code}：#{url}" unless response.code.to_s == "200"

    document = Nokogiri::HTML5(response.body.dup.force_encoding(Encoding::UTF_8))
    identity = meta(document, "turnaround-card")
    raise Failure, "#{url} 不是這一份：頁面寫 #{identity.inspect}，要的是 #{route_card.identity}" unless identity == route_card.identity
    raise Failure, "月卡頁說數字不完整，要等重算才印：#{url}" if document.at_css("[data-card-incomplete]")

    document
  end

  def fetch_page(url)
    @fetch.call(url)
  rescue SocketError, SystemCallError, Timeout::Error, IOError, OpenSSL::SSL::SSLError => e
    raise Failure, "連不上 #{url}：#{e.message}"
  end

  def meta(document, name) = document.at_css("meta[name='#{name}']")&.[]("content")

  def program_version_of(document, url)
    meta(document, "turnaround-program-version").presence || raise(Failure, "#{url} 沒有程式版本")
  end

  def summary_of(document, url)
    summary = JSON.parse(meta(document, "turnaround-card-summary").to_s)
    summary.is_a?(Hash) ? summary : raise(Failure, "#{url} 的摘要不是對應表")
  rescue JSON::ParserError
    raise Failure, "#{url} 的摘要讀不出來"
  end

  # The bytes of the printed file. The directory is removed whatever happens, without
  # failing on what a helper process of Chrome may still be writing there.
  def run_chrome(url)
    dir = Dir.mktmpdir("card-printer")
    output, errors = File.join(dir, "card.pdf"), File.join(dir, "chrome.err")
    status = wait_for(spawn_chrome(url, dir, output, errors))
    raise Failure, "Chrome 結束碼 #{status.exitstatus || "訊號 #{status.termsig}"}：#{last_lines(errors)}" unless status.success?

    usable_pdf(output)
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  # In a process group of its own, so that stopping it stops its helpers too.
  def spawn_chrome(url, dir, output, errors)
    Process.spawn(@chrome_path, *CHROME_FLAGS, "--user-data-dir=#{File.join(dir, 'profile')}", "--print-to-pdf=#{output}", url,
                  in: File::NULL, out: File::NULL, err: errors, pgroup: true)
  rescue SystemCallError => e
    raise Failure, "開不了 Chrome（#{@chrome_path}）：#{e.message}。要換位置就設 CHROME_PATH"
  end

  def wait_for(pid)
    deadline = monotonic + @timeout
    loop do
      _, status = Process.wait2(pid, Process::WNOHANG)
      return status if status

      if monotonic > deadline
        stop(pid)
        raise Failure, "Chrome 跑了 #{@timeout} 秒還沒結束，已經停掉"
      end
      sleep POLL_SECONDS
    end
  end

  def stop(pid)
    Process.kill("TERM", -pid)
    deadline = monotonic + STOP_SECONDS
    reaped = false
    while process_group_running?(pid) && monotonic < deadline
      reaped ||= Process.wait2(pid, Process::WNOHANG)
      sleep POLL_SECONDS
    end

    Process.kill("KILL", -pid) if process_group_running?(pid)
    Process.wait(pid) unless reaped
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  end

  # Helpers can outlive their leader, even after wait2 has reaped it. EPERM still
  # means the group exists, and can be transient while its processes are exiting.
  def process_group_running?(pid)
    Process.kill(0, -pid)
    true
  rescue Errno::EPERM
    true
  rescue Errno::ESRCH
    false
  end

  def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  def usable_pdf(path)
    bytes = File.exist?(path) ? File.binread(path) : "".b
    return bytes if bytes.start_with?(PDF_HEAD) && bytes.bytesize >= MIN_BYTES

    raise Failure, "印出來的檔不是能用的 PDF（#{bytes.bytesize} bytes）"
  end

  def last_lines(path) = File.exist?(path) ? File.readlines(path, chomp: true).last(3).join(" / ") : ""
end
