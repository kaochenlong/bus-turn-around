require "rails_helper"
require "rake"

RSpec.describe PtoAssessmentSnapshot, type: :model do
  let(:data_root) { Dir.mktmpdir("pto-assessment") }
  let(:requested) { [] }

  after { FileUtils.remove_entry(data_root) }

  # A stand-in report and the sha256 of its bytes, worked out with shasum.
  def report = "%PDF-1.7\n測試報告書\n".b
  def report_sha256 = "18895c2a19c04a7190fed4a6a0167b9a3c0d4687153cd6a8e4eb1e79a0d6130a"
  def replaced_report = "%PDF-1.7\n公運處換過的檔\n".b
  def replaced_sha256 = "5c2f595bc53b4c4cd44cdbd6378a084ce3b5ca52159ea2db464464b8aeb2f3e1"

  def terms = { "115-1": { download_url: "https://example.test/report.pdf", sha256: report_sha256 } }

  def path = File.join(data_root, "external/pto-assessment/115-1/report.pdf")

  # Answers every request with [status, body] and records its URL.
  def fetcher(status, body) = ->(url) { requested.push(url).then { [ status, body ] } }

  # Runs the rake task's entry point and returns its exit status and what it printed.
  def run(env, fetcher:, terms: self.terms)
    out = StringIO.new
    [ described_class.run({ "TURNAROUND_DATA" => data_root, "TERM" => "115-1" }.merge(env).compact, out:, fetcher:, terms:), out.string ]
  end

  it "下載那一期設定的網址，寫到 external/pto-assessment/<期別>/report.pdf，內容是回應原文" do
    run({}, fetcher: fetcher(200, report))
    expect([ requested, File.binread(path) ]).to eq([ [ "https://example.test/report.pdf" ], report ])
  end

  it "sha256 跟設定相同：結束碼 0，印出檔案路徑與 sha256，沒有警告" do
    status, out = run({}, fetcher: fetcher(200, report))
    expect([ status, out.lines.map(&:chomp) ]).to eq([ 0, [ "#{path}：sha256 #{report_sha256}" ] ])
  end

  it "sha256 跟設定不同：照樣存檔、結束碼 0，多印一行警告，帶兩個 sha256 並說分數要重抄" do
    status, out = run({}, fetcher: fetcher(200, replaced_report))
    expect([ status, File.binread(path), out.lines.last ]).to match([ 0, replaced_report, a_string_including(replaced_sha256, report_sha256, "重抄") ])
  end

  [
    [ "沒有 TURNAROUND_DATA", { "TURNAROUND_DATA" => nil } ],
    [ "沒有 TERM", { "TERM" => nil } ],
    [ "TERM 是設定裡沒有的期別", { "TERM" => "114-2" } ]
  ].each do |situation, env|
    it "#{situation}：印用法並列出設定裡的期別，結束碼 1，沒有下載" do
      status, out = run(env, fetcher: fetcher(200, report))
      expect([ status, out.include?("bin/rails external:pto_assessment TERM="), out.include?("115-1"), requested ]).to eq([ 1, true, true, [] ])
    end
  end

  describe "下載不能用時，既有的快照不動" do
    before { FileUtils.mkdir_p(File.dirname(path)).then { File.binwrite(path, report) } }

    [
      [ "HTTP 不是 200", [ 404, "Not Found" ], "HTTP 404" ],
      [ "回應不是 PDF（例如網站的錯誤頁）", [ 200, "<html>系統維護中</html>" ], "不是 PDF" ]
    ].each do |situation, (status_code, body), reason|
      it "#{situation}：結束碼 1，印出沒寫入與原因，檔案還是原本那份、沒有留下 .partial" do
        status, out = run({}, fetcher: fetcher(status_code, body))
        expect([ status, out.include?(reason), File.binread(path), File.exist?("#{path}.partial") ]).to eq([ 1, true, report, false ])
      end
    end
  end

  it "沒給 terms 時讀 config/depot_inspections.yml：TERM=115-1 下載那一期設定的網址" do
    out = StringIO.new
    described_class.run({ "TURNAROUND_DATA" => data_root, "TERM" => "115-1" }, out:, fetcher: fetcher(404, ""))
    expect(requested).to eq([ Rails.application.config_for(:depot_inspections).dig(:terms, :"115-1", :download_url) ])
  end

  # Executes a rake task of the app and returns the status it exits with.
  def rake_exit_status(name)
    Rails.application.load_tasks if Rake::Task.tasks.none? { it.name == name }
    Rake::Task[name].execute
  rescue SystemExit => e
    e.status
  end

  it "rake task external:pto_assessment 交給 .run 執行，結束碼是它回傳的值" do
    allow(described_class).to receive(:run).and_return(3)
    expect(rake_exit_status("external:pto_assessment")).to eq(3)
  end
end
