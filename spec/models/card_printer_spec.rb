require "rails_helper"
require "socket"

RSpec.describe CardPrinter, type: :model do
  let(:dir) { Dir.mktmpdir("card-printer") }
  let(:card) { build(:route_card, route_id: 15373, month: Date.new(2026, 11, 1), version: 1) }
  let(:ran) { File.join(dir, "chrome-ran") }
  let(:big_pdf) { "%PDF-1.7\n".b + ("x".b * 100_000) }

  after { FileUtils.remove_entry(dir) }

  def page_html(identity: "15373/2026-11/1", program: "abc1234", summary: '{"weekdays":21}', incomplete: false)
    <<~HTML
      <!DOCTYPE html><html><head>
      <meta name="turnaround-card" content="#{identity}">
      <meta name="turnaround-program-version" content="#{program}">
      <meta name="turnaround-card-summary" content="#{CGI.escapeHTML(summary)}">
      </head><body><main data-month-card>#{'<p data-card-incomplete>不完整</p>' if incomplete}</main></body></html>
    HTML
  end

  def answer(code: "200", **page) = ->(_url) { Struct.new(:code, :body).new(code, page_html(**page)) }

  # An executable that notes it ran, writes `output` where it is told to and exits
  # with `status`.
  def chrome(output: big_pdf, status: 0, body: "")
    source = File.join(dir, "output")
    File.binwrite(source, output)
    path = File.join(dir, "chrome")
    File.write(path, <<~SH)
      #!/bin/sh
      printf '%s\\n' "$@" > "#{ran}"
      #{body}
      for arg in "$@"; do
        case "$arg" in --print-to-pdf=*) cp "#{source}" "${arg#--print-to-pdf=}" ;; esac
      done
      echo "chrome said this" >&2
      exit #{status}
    SH
    File.chmod(0o755, path)
    path
  end

  def printer(chrome_path: chrome, fetch: answer, **options)
    described_class.new(base_url: "https://bus.example", chrome_path:, fetch:, **options)
  end

  def failure_of(a_printer = printer)
    a_printer.print(card)
    nil
  rescue described_class::Failure => e
    e.message
  end

  def chrome_ran? = File.exist?(ran)

  describe "頁面與 Chrome 都正常" do
    it "回傳 Chrome 印出來的位元組" do
      expect(printer.print(card).bytes).to eq(big_pdf)
    end

    it "程式版本與摘要是頁面帶的" do
      printed = printer(fetch: answer(program: "abc1234", summary: '{"weekdays":21}')).print(card)
      expect([ printed.program_version, printed.summary ]).to eq([ "abc1234", { "weekdays" => 21 } ])
    end

    it "回傳開頁面花的秒數：正式站離逾時多遠，要看這個數字" do
      slow = ->(url) { sleep 0.05; answer.call(url) }
      expect(printer(fetch: slow).print(card).page_seconds).to be_between(0.05, 5)
    end

    it "問的是這一份月卡的網址" do
      asked = []
      fetch = ->(url) { asked << url; answer.call(url) }
      printer(fetch:).print(card)
      expect(asked).to eq([ "https://bus.example/routes/15373/cards/2026-11" ])
    end

    it "base_url 尾巴多一個斜線也一樣" do
      asked = []
      fetch = ->(url) { asked << url; answer.call(url) }
      described_class.new(base_url: "https://bus.example/", chrome_path: chrome, fetch:).print(card)
      expect(asked).to eq([ "https://bus.example/routes/15373/cards/2026-11" ])
    end

    it "Chrome 開這一份的網址，不印頁首頁尾" do
      printer.print(card)
      expect(File.readlines(ran, chomp: true)).to include("https://bus.example/routes/15373/cards/2026-11", "--headless=new", "--no-pdf-header-footer")
    end

    it "剛好 100 KB 算能用" do
      exact = "%PDF-".b + ("x".b * 99_995)
      expect(printer(chrome_path: chrome(output: exact)).print(card).bytes.bytesize).to eq(100_000)
    end
  end

  describe "頁面不對：Chrome 不開" do
    it "500：訊息說狀態碼" do
      message = failure_of(printer(fetch: answer(code: "500")))
      expect([ message, chrome_ran? ]).to match([ a_string_including("500"), false ])
    end

    it "別的月份的頁面：訊息說頁面是哪一份" do
      message = failure_of(printer(fetch: answer(identity: "15373/2026-10/1")))
      expect([ message, chrome_ran? ]).to match([ a_string_including("15373/2026-10/1", "15373/2026-11/1"), false ])
    end

    it "別的版本的頁面" do
      message = failure_of(printer(fetch: answer(identity: "15373/2026-11/2")))
      expect([ message, chrome_ran? ]).to match([ a_string_including("15373/2026-11/2"), false ])
    end

    it "頁面說數字不完整" do
      message = failure_of(printer(fetch: answer(incomplete: true)))
      expect([ message, chrome_ran? ]).to match([ a_string_including("不完整"), false ])
    end

    it "沒有 meta 的頁面：不是月卡" do
      fetch = ->(_url) { Struct.new(:code, :body).new("200", "<html><body>別的東西</body></html>") }
      expect([ failure_of(printer(fetch:)).present?, chrome_ran? ]).to eq([ true, false ])
    end

    it "沒有程式版本" do
      expect([ failure_of(printer(fetch: answer(program: ""))), chrome_ran? ]).to match([ a_string_including("程式版本"), false ])
    end

    [ "{壞掉", "[1,2]", "" ].each do |summary|
      it "摘要讀不出來（#{summary.inspect}）" do
        expect([ failure_of(printer(fetch: answer(summary:))), chrome_ran? ]).to match([ a_string_including("摘要"), false ])
      end
    end

    it "連不上：訊息說連不上哪裡" do
      fetch = ->(_url) { raise SocketError, "getaddrinfo failed" }
      expect([ failure_of(printer(fetch:)), chrome_ran? ]).to match([ a_string_including("bus.example", "getaddrinfo failed"), false ])
    end
  end

  describe "Chrome 不對" do
    it "找不到：訊息說 CHROME_PATH，頁面也不用問" do
      asked = []
      fetch = ->(url) { asked << url }
      message = failure_of(printer(chrome_path: File.join(dir, "沒有這個檔"), fetch:))
      expect([ message, asked ]).to match([ a_string_including("CHROME_PATH"), [] ])
    end

    it "結束碼不是 0：訊息帶結束碼與 Chrome 說的話" do
      expect(failure_of(printer(chrome_path: chrome(status: 3)))).to include("3", "chrome said this")
    end

    it "2 KB 的文字：不是能用的 PDF" do
      expect(failure_of(printer(chrome_path: chrome(output: "x" * 2048)))).to include("不是能用的 PDF")
    end

    it "開頭是 %PDF- 但太小：不是能用的 PDF" do
      expect(failure_of(printer(chrome_path: chrome(output: "%PDF-" + ("x" * 99_994))))).to include("不是能用的 PDF")
    end

    it "結束碼 0 但沒有檔：不是能用的 PDF" do
      path = File.join(dir, "silent-chrome")
      File.write(path, "#!/bin/sh\nexit 0\n")
      File.chmod(0o755, path)
      expect(failure_of(printer(chrome_path: path))).to include("不是能用的 PDF")
    end

    it "時間到還沒結束：連它開的程式一起停掉，訊息說跑太久" do
      helper = File.join(dir, "helper-pid")
      message = failure_of(printer(chrome_path: chrome(body: "sleep 30 &\necho $! > \"#{helper}\"\nwait"), timeout: 3))
      expect([ message, process_gone?(File.read(helper).to_i) ]).to match([ a_string_including("還沒結束"), true ])
    end

    describe "主程序收到 TERM 結束，輔助程序忽略 TERM" do
      def leader_pid_file = File.join(dir, "leader-pid")

      def helper_pid_file = File.join(dir, "helper-pid")

      def deny_first_group_probe
        denied = false
        allow(Process).to receive(:kill).and_wrap_original do |original, signal, *pids|
          if signal == 0 && pids.first.negative? && !denied
            denied = true
            raise Errno::EPERM
          end
          original.call(signal, *pids)
        end
      end

      let(:chrome_path) do
        chrome(body: <<~SH)
          echo $$ > "#{leader_pid_file}"
          trap 'exit 0' TERM
          sh -c 'trap "" TERM; echo $$ > "#{helper_pid_file}"; exec sleep 30' &
          wait
        SH
      end

      before { stub_const("CardPrinter::STOP_SECONDS", 0.2) }

      after do
        Process.kill("KILL", -File.read(leader_pid_file).to_i) if File.exist?(leader_pid_file)
      rescue Errno::ESRCH
        nil
      end

      it "逾時後強制結束仍存活的輔助程序" do
        message = failure_of(printer(chrome_path:, timeout: 3))
        expect([ message, process_gone?(File.read(helper_pid_file).to_i) ]).to match([ a_string_including("還沒結束"), true ])
      end

      it "查詢群組暫時回 EPERM，仍會停掉存活的輔助程序" do
        deny_first_group_probe
        message = failure_of(printer(chrome_path:, timeout: 3))
        expect([ message, process_gone?(File.read(helper_pid_file).to_i) ]).to match([ a_string_including("還沒結束"), true ])
      end
    end
  end

  # Whether a process ends soon: a killed helper takes a moment.
  def process_gone?(pid)
    20.times do
      Process.kill(0, pid)
      sleep 0.1
    end
    false
  rescue Errno::ESRCH
    true
  end

  describe "預設的 HTTP" do
    # A one-request server that answers `body` and records the request line.
    def serve(body)
      server = TCPServer.new("127.0.0.1", 0)
      thread = Thread.new do
        client = server.accept
        line = client.gets
        nil until client.gets.to_s.strip.empty?
        client.write("HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
        client.close
        line
      end
      [ server.addr[1], thread ]
    end

    it "真的發 HTTP 請求，頁面照樣讀得出來" do
      port, thread = serve(page_html(summary: '{"weekdays":21,"名稱":"中文"}'))
      printed = described_class.new(base_url: "http://127.0.0.1:#{port}", chrome_path: chrome).print(card)
      expect([ thread.value, printed.summary ]).to eq([ "GET /routes/15373/cards/2026-11 HTTP/1.1\r\n", { "weekdays" => 21, "名稱" => "中文" } ])
    end
  end
end
