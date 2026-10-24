require "date"
require "json"
require "open3"

# Runs the SQL of analysis/ in a DuckDB CLI subprocess. bin/health-card loads
# it with require_relative and never loads Rails, so it only requires default
# gems; the Rails app loads it through autoload_lib.
#
# The SQL is the variable settings, then params.sql, then the numbered stage
# files in file name order, then the files the caller appends. Sorting every
# file by name would put params.sql after the stages, and the stages would
# read its constants as NULL.
module AnalysisRun
  ANALYSIS_DIR = File.expand_path("../analysis", __dir__)
  DUCKDB_FLAGS = %w[-no-init -bail -batch -json].freeze

  # DuckDB returned non-zero; the message is its standard error as it is.
  class Error < StandardError; end

  module_function

  # The duckdb executable on the given PATH, or nil.
  def find_duckdb(path)
    path.to_s.split(File::PATH_SEPARATOR).reject(&:empty?).map { File.join(it, "duckdb") }
        .find { File.file?(it) && File.executable?(it) }
  end

  def sql(variables, analysis_dir: ANALYSIS_DIR, extra_files: [])
    stages = [ "params.sql", *Dir.glob("[0-9]*.sql", base: analysis_dir).sort, *extra_files ]
    settings = variables.map { |name, value| "SET VARIABLE #{name} = #{sql_literal(value)};" }
    [ *settings, *stages.map { File.read(File.join(analysis_dir, it)) } ].join("\n")
  end

  # The rows of the statements that print, as hashes keyed by column name.
  def run(duckdb, variables, analysis_dir: ANALYSIS_DIR, extra_files: [])
    stdout, stderr, status = Open3.capture3(duckdb, *DUCKDB_FLAGS,
                                            stdin_data: sql(variables, analysis_dir:, extra_files:))
    raise Error, (stderr.empty? ? "duckdb 失敗（#{status}），沒有印出錯誤訊息\n" : stderr) unless status.success?

    stdout.strip.empty? ? [] : JSON.parse(stdout)
  end

  # An Array becomes a DuckDB list literal, such as [16111, 19108] for the
  # route Ids of one page.
  def sql_literal(value)
    case value
    when Integer then value.to_s
    when Date then "DATE '#{value.iso8601}'"
    when Array then "[#{value.map { sql_literal(it) }.join(', ')}]"
    else "'#{value.to_s.gsub("'", "''")}'"
    end
  end
end
