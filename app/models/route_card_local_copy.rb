require "json"

# The file of a printed version and what its row holds, kept under the raw data root
# of the machine that prints, as in the monthly-card-pdf spec. The production database
# is not backed up, because the derived tables can be recomputed; a printed card
# cannot be recomputed into the same card, so a rebuilt database gets it back from
# here. The row comes along because its summary would otherwise be recomputed with
# today's definitions, and its program version and reason not at all. A copy is the
# only record once the database is gone, so nothing here ever overwrites a file.
class RouteCardLocalCopy
  DIRECTORY = "cards".freeze

  # A file could not be written or does not hold together; the message names it.
  class Failure < StandardError; end

  # What a copy holds. attributes are what RouteCard#store_printed! takes besides the PDF.
  Kept = Data.define(:route_id, :month, :version, :pdf, :pdf_sha256, :attributes)

  def self.for(data_root, route_card)
    new(data_root, File.join(data_root, DIRECTORY, route_card.year_month, "#{route_card.route_id}-v#{route_card.version}"))
  end

  # The versions of a route's month with a PDF here, smallest first.
  def self.versions(data_root, route_id, month)
    Dir.glob("#{route_id}-v*.pdf", base: File.join(data_root, DIRECTORY, month.strftime("%Y-%m"))).filter_map { it[/\A#{route_id}-v(\d+)\.pdf\z/, 1]&.to_i }.sort
  end

  # Every copy under the data root, whatever its name: one that reads wrong is not
  # to be passed over in silence.
  def self.all(data_root)
    Dir.glob("#{DIRECTORY}/*/*.{pdf,json}", base: data_root).map { it.delete_suffix(File.extname(it)) }.uniq.sort.map { new(data_root, File.join(data_root, it)) }
  end

  # `stem` is the path of the two files without the extension.
  def initialize(data_root, stem)
    @data_root = data_root
    @stem = stem
  end

  def pdf_path = "#{@stem}.pdf"

  def json_path = "#{@stem}.json"

  def complete? = File.exist?(pdf_path) && File.exist?(json_path)

  # Writes both files; a file already there is a Failure and stays as it was.
  def write(route_card, pdf) = files(route_card, pdf).each { |path, content| place(path, content) }

  # Writes the files that are missing, after an earlier write failed or a file was lost.
  def fill_in(route_card, pdf) = files(route_card, pdf).reject { |path, _| File.exist?(path) }.each { |path, content| place(path, content) }

  # Returns a Kept; raises Failure when the files do not hold together.
  def read
    [ json_path, pdf_path ].each { raise Failure, "少 #{it}，這一份存不回去" unless File.exist?(it) }

    row = JSON.parse(File.read(json_path))
    route_id, version, year_month = row.fetch("route_id"), row.fetch("version"), row.fetch("month")
    raise Failure, "#{json_path} 寫的路線、月份或版本跟檔名不符" unless named_like?(route_id, version, year_month)

    kept(row, route_id, version, year_month)
  rescue JSON::ParserError, KeyError, TypeError, ArgumentError => e
    raise Failure, "#{json_path} 讀不出來：#{e.message}"
  end

  private

  def files(route_card, pdf) = { pdf_path => pdf, json_path => JSON.pretty_generate(row_of(route_card)) }

  def row_of(route_card)
    { "route_id" => route_card.route_id, "month" => route_card.year_month, "version" => route_card.version, "coverage" => route_card.coverage,
      "summary" => route_card.summary, "program_version" => route_card.program_version, "printed_at" => route_card.printed_at.utc.iso8601(6),
      "revision_reason" => route_card.revision_reason, "pdf_sha256" => route_card.pdf_sha256, "pdf_bytes" => route_card.pdf_bytes }
  end

  # The file appears whole or not at all.
  def place(path, content)
    temporary = "#{path}.tmp"
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(temporary, content)
    link(temporary, path)
  rescue SystemCallError => e
    raise Failure, "#{path} 寫不進去：#{e.message}"
  ensure
    FileUtils.rm_f(temporary)
  end

  # Unlike a rename, a hard link fails when the name is taken.
  def link(temporary, path)
    File.link(temporary, path)
  rescue Errno::EEXIST
    raise Failure, "#{path} 已經有了，不覆寫"
  end

  def named_like?(route_id, version, year_month)
    File.join(@data_root, DIRECTORY, year_month, "#{route_id}-v#{version}") == @stem
  end

  def kept(row, route_id, version, year_month)
    pdf = File.binread(pdf_path)
    raise Failure, "#{pdf_path} 的 SHA-256 跟 #{json_path} 寫的不同" unless Digest::SHA256.hexdigest(pdf) == row.fetch("pdf_sha256")

    Kept.new(route_id:, month: Date.iso8601("#{year_month}-01"), version:, pdf:, pdf_sha256: row.fetch("pdf_sha256"),
             attributes: { coverage: row.fetch("coverage"), summary: row.fetch("summary"), program_version: row.fetch("program_version"),
                           printed_at: Time.iso8601(row.fetch("printed_at")), revision_reason: row.fetch("revision_reason") })
  end
end
