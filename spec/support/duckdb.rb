require "date"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

# Helpers for spec/analysis. Those specs run the DuckDB CLI as a subprocess and
# never load Rails; every example in them is skipped with an install hint when
# the duckdb executable is not on PATH.
#
# Results come back through DuckDB's JSON output, and CSV files are read back
# through DuckDB's read_csv: the csv library is a bundled gem since Ruby 3.4
# and this change does not touch the Gemfile.
module DuckdbHelpers
  ROOT = File.expand_path("../..", __dir__)
  ANALYSIS_DIR = File.join(ROOT, "analysis")
  FIXTURE_DATA = File.join(ROOT, "spec/fixtures/analysis")
  SKIP_MESSAGE = "需要 DuckDB CLI 才能跑 spec/analysis，安裝：brew install duckdb".freeze
  DUCKDB_FLAGS = %w[-no-init -bail -batch -json].freeze
  FIXTURE_VARIABLES = {
    data_root: FIXTURE_DATA,
    route_id: 9001,
    day: Date.new(2026, 10, 19),
    static_day: Date.new(2026, 10, 19)
  }.freeze
  TRIP_COLUMNS = %w[trip_id bus_id route_id path_attribute_id go_back start_time end_time first_seq last_seq
                    n_events n_stops_observed completeness start_from_arrival end_from_departure segment_no].freeze
  TRIP_DEFAULTS = { route_id: 9001, go_back: 0, completeness: "complete", n_stops_observed: 5 }.freeze

  def self.duckdb_on_path?(path = ENV.fetch("PATH", ""))
    path.split(File::PATH_SEPARATOR).any? do |dir|
      candidate = File.join(dir, "duckdb")
      File.file?(candidate) && File.executable?(candidate)
    end
  end

  # Outputs of bin/health-card kept for the whole run, keyed by argument list,
  # so examples that only read a card share one run of it.
  def self.shared_runs = @shared_runs ||= {}

  def self.sql_literal(value)
    case value
    when Integer then value.to_s
    when Date then "DATE '#{value.iso8601}'"
    else "'#{value.to_s.gsub("'", "''")}'"
    end
  end

  # Runs SQL through the DuckDB CLI and returns the rows of the one statement
  # that prints a result, as hashes keyed by column name.
  def duckdb_rows(sql)
    stdout, stderr, status = Open3.capture3("duckdb", *DUCKDB_FLAGS, stdin_data: sql)
    raise "duckdb exited #{status.exitstatus}: #{stderr}" unless status.success?

    stdout.strip.empty? ? [] : JSON.parse(stdout)
  end

  # Reads a CSV file with a header line; every value comes back as a string.
  def read_csv_rows(path)
    duckdb_rows("SELECT * FROM read_csv(#{DuckdbHelpers.sql_literal(path)}, header = true, all_varchar = true)")
  end

  # Runs analysis/params.sql and the numbered stages up to and including
  # `through` (for example "20_trips") against the fixture data, then `query`.
  # `through: "params"` runs params.sql alone. Keyword arguments override the
  # fixture variables.
  def run_sql_stages(through:, query:, **variables)
    Dir.mktmpdir("health-card-spec") do |inspect_dir|
      values = FIXTURE_VARIABLES.merge(inspect_dir: inspect_dir).merge(variables)
      statements = values.map { |name, value| "SET VARIABLE #{name} = #{DuckdbHelpers.sql_literal(value)};" }
      duckdb_rows([ *statements, *stage_files(through).map { File.read(it) }, query ].join("\n"))
    end
  end

  # SQL that replaces the stop events of stage 10 with route 9001 events on
  # 2026-10-19, each [bus_id, go_back, seq, car_on_stop, "HH:MM:SS",
  # path_attribute_id = 9001, duty_status = 1]. The views of stage 20 and later
  # rebuild their trips from these events when queried.
  def replace_stop_events_sql(events)
    values = events.map do |bus, go_back, seq, car_on_stop, at, path = 9001, duty = 1|
      "('#{bus}', 9001, #{path}, #{go_back}, #{seq}, #{91000 + seq}, #{car_on_stop}, #{duty}, 0, " \
        "TIMESTAMP '2026-10-19 #{at}', 'injected')"
    end
    <<~SQL
      CREATE OR REPLACE TABLE stop_events AS SELECT * FROM (VALUES #{values.join(', ')})
        AS t(bus_id, route_id, path_attribute_id, go_back, seq, stop_id, car_on_stop, duty_status, bus_status, data_time, source_file);
    SQL
  end

  # SQL that swaps the trips view of stage 20 for a table of the given trips,
  # so a later stage can be checked against exact values. Each trip is a hash
  # with bus_id, start and finish ("HH:MM" on 2026-10-19, or a full timestamp),
  # and optionally route_id, path_attribute_id (route_id when absent), go_back,
  # completeness and n_stops_observed. Views of later stages read the table,
  # because DuckDB binds a view's query when it is used.
  def replace_trips_sql(trips)
    rows = trips.each_with_index.map { |trip, index| trip_values(index + 1, TRIP_DEFAULTS.merge(trip)) }
    <<~SQL
      DROP VIEW trips;
      CREATE TABLE trips AS SELECT * FROM (VALUES #{rows.join(', ')}) AS t(#{TRIP_COLUMNS.join(', ')});
    SQL
  end

  # SQL that replaces the other_route_events table of stage 10 with the given
  # records, each [bus_id, "HH:MM" on 2026-10-19 or a full timestamp, stop_id,
  # path_attribute_id = 9100]. An empty list leaves the table empty, so the
  # fixture's records stay out of examples built on injected trips.
  def replace_other_route_events_sql(records)
    rows = records.map { |bus, at, stop, path = 9100| "('#{bus}', #{path}, #{stop}, #{timestamp_sql(at)})" }
    <<~SQL
      CREATE OR REPLACE TABLE other_route_events (bus_id VARCHAR, path_attribute_id BIGINT, stop_id BIGINT, data_time TIMESTAMP);
      #{"INSERT INTO other_route_events VALUES #{rows.join(', ')};" unless rows.empty?}
    SQL
  end

  # Runs bin/health-card with the current Ruby, so a test can narrow PATH
  # without losing the interpreter. It runs outside the bundle, the way an
  # operator runs it; `bundled: true` keeps the bundle of this process, whose
  # Gemfile has no csv. A nil value in `env` unsets that variable. Returns
  # stdout, stderr and the status.
  def run_health_card(*args, env: {}, bundled: false)
    base = bundled || !defined?(Bundler) ? ENV.to_h : Bundler.unbundled_env
    Open3.capture3(base.merge(env).compact, RbConfig.ruby, File.join(ROOT, "bin/health-card"), *args,
                   chdir: ROOT, unsetenv_others: true)
  end

  def path_without_duckdb
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR)
       .reject { |dir| File.executable?(File.join(dir, "duckdb")) }
       .join(File::PATH_SEPARATOR)
  end

  private

  def trip_values(trip_id, trip)
    first_seq, last_seq = trip[:go_back].zero? ? [ 0, 4 ] : [ 5, 9 ]
    [ trip_id, "'#{trip[:bus_id]}'", trip[:route_id], trip.fetch(:path_attribute_id, trip[:route_id]), trip[:go_back],
      timestamp_sql(trip[:start]), timestamp_sql(trip[:finish]), first_seq, last_seq, 10, trip[:n_stops_observed],
      "'#{trip[:completeness]}'", false, false, trip_id ].join(", ").then { "(#{it})" }
  end

  def timestamp_sql(text)
    text = "2026-10-19 #{text}" unless text.include?(" ")
    text = "#{text}:00" if text.count(":") == 1
    "TIMESTAMP '#{text}'"
  end

  def stage_files(through)
    return [ File.join(ANALYSIS_DIR, "params.sql") ] if through == "params"

    numbered = Dir[File.join(ANALYSIS_DIR, "[0-9]*.sql")].sort
    names = numbered.map { File.basename(it, ".sql") }
    raise ArgumentError, "no SQL stage named #{through}, have #{names.inspect}" unless names.include?(through)

    [ File.join(ANALYSIS_DIR, "params.sql"), *numbered.select { File.basename(it, ".sql") <= through } ]
  end
end

RSpec.configure do |config|
  config.define_derived_metadata(file_path: %r{/spec/analysis/}) do |metadata|
    metadata[:duckdb] = true
  end

  config.include DuckdbHelpers, :duckdb

  config.before(:each, :duckdb) do
    skip DuckdbHelpers::SKIP_MESSAGE unless DuckdbHelpers.duckdb_on_path?
  end
end
