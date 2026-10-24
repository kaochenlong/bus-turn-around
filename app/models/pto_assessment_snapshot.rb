require "digest"

# bin/rails external:pto_assessment TERM=115-1: saves the PDF of one term's
# 臺北市市區公車營運服務指標評鑑總體報告書 of 臺北市公共運輸處 under the data root,
# as external/pto-assessment/<term>/report.pdf, and prints its path and
# sha256. The depot inspection scores in config/depot_inspections.yml are
# copied by hand from that report, and the term's sha256 there names the file
# they were copied from: a download with another sha256 is still saved, with
# a warning, because it means the office replaced the file and the scores have
# to be copied again. A response that is not HTTP 200 or not a PDF is never
# written, and an existing snapshot stays.
class PtoAssessmentSnapshot
  DIRECTORY = "external/pto-assessment".freeze
  FILE_NAME = "report.pdf".freeze
  PDF_SIGNATURE = "%PDF-".b.freeze

  # The download is not usable; the message says why.
  class Error < StandardError; end

  # The rake task: returns the exit status. TERM has to be a term of the
  # configuration, so it never names any other directory.
  def self.run(env, out: $stdout, fetcher: HttpFetcher, terms: Rails.application.config_for(:depot_inspections).fetch(:terms))
    data_root, term = env.values_at("TURNAROUND_DATA", "TERM").map(&:presence)
    source = terms[term.to_sym] if term
    unless data_root && source
      out.puts("用法：TURNAROUND_DATA=<原始檔的資料根目錄> bin/rails external:pto_assessment TERM=<期別>\n" \
               "期別是 config/depot_inspections.yml 的 terms：#{terms.keys.join('、')}")
      return 1
    end

    snapshot = new(data_root:, term:, download_url: source.fetch(:download_url), fetcher:)
    digest = snapshot.call
    out.puts("#{snapshot.path}：sha256 #{digest}")
    unless digest == source.fetch(:sha256)
      out.puts("警告：下載到的檔 sha256 #{digest} 跟 config/depot_inspections.yml 記的 #{source.fetch(:sha256)} 不同，" \
               "公運處可能換了檔，查核分數要對著新檔重抄")
    end
    0
  rescue Error => e
    out.puts("沒有寫入報告書快照：#{e.message}")
    1
  end

  def initialize(data_root:, term:, download_url:, fetcher: HttpFetcher)
    @data_root = data_root
    @term = term
    @download_url = download_url
    @fetcher = fetcher
  end

  def path = File.join(@data_root, DIRECTORY, @term, FILE_NAME)

  # Writes the report and returns the sha256 of its bytes.
  def call
    status, body = @fetcher.call(@download_url)
    raise Error, "下載回應 HTTP #{status}" unless status == 200

    body = body.b
    raise Error, "下載到的內容不是 PDF（開頭不是 %PDF-）" unless body.start_with?(PDF_SIGNATURE)

    write(body)
    Digest::SHA256.hexdigest(body)
  end

  private

  # Written to a temporary file first, so a failed write leaves no half file.
  def write(body)
    FileUtils.mkdir_p(File.dirname(path))
    temporary = "#{path}.partial"
    File.binwrite(temporary, body)
    File.rename(temporary, path)
  end
end
