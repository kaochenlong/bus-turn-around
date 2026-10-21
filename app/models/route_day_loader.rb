require "tmpdir"

# Writes one route on one Taipei day into the derived tables. DuckDB runs the
# stages of analysis/, analysis/mrt_overlap.sql with the newest MRT entrance
# snapshot, and analysis/derived_export.sql into CSV files; then, in
# one transaction, the stored day is deleted and the files are copied in. A
# failure anywhere leaves the stored day as it was, and loading the same input
# again leaves the same rows.
class RouteDayLoader
  # The day could not be written; the message says why.
  class Error < StandardError; end

  # Staging table columns, in the column order of each CSV file.
  STAGING = {
    "route_day" => "route_id integer, day date, route_name text, departure text, destination text, static_day date, " \
                   "mrt_exits_day date",
    "stops" => "go_back integer, seq integer, stop_name text, latitude double precision, longitude double precision, " \
               "nearest_exit_name text, nearest_exit_meters double precision",
    "trips" => "bus_id text, path_attribute_id integer, go_back integer, band text, start_time timestamptz, " \
               "end_time timestamptz, first_seq integer, last_seq integer, n_events integer, n_stops_observed integer, " \
               "completeness text, start_from_arrival boolean, end_from_departure boolean",
    "layovers" => "bus_id text, go_back integer, end_time timestamptz, next_start_time timestamptz",
    "trip_stop_counts" => "bus_id text, start_time timestamptz, seq integer, on_board integer"
  }.freeze

  # The staging table of each file, written out so that no table name is
  # ever built at run time.
  STAGING_TABLES = {
    "route_day" => "staging_route_day", "stops" => "staging_stops", "trips" => "staging_trips",
    "layovers" => "staging_layovers", "trip_stop_counts" => "staging_trip_stop_counts"
  }.freeze

  def initialize(route_id:, day:, data_root:, duckdb:)
    @route_id = route_id
    @day = day
    @data_root = data_root
    @duckdb = duckdb
  end

  # Returns the numbers of trips, layovers and trip stop counts written.
  def call
    Dir.mktmpdir("route-day") do |dir|
      export(dir)
      RouteDay.transaction(requires_new: true) { replace(dir) }
    end
  end

  private

  def export(dir)
    mrt_exits_path, mrt_exits_day = newest_mrt_exits
    variables = { data_root: @data_root, route_id: @route_id, day: @day, static_day: @day,
                  inspect_dir: dir, derived_dir: dir, mrt_exits_path:, mrt_exits_day: }
    AnalysisRun.run(@duckdb, variables, extra_files: %w[mrt_overlap.sql derived_export.sql])
  rescue AnalysisRun::Error => e
    raise Error, e.message
  end

  # The snapshot with the latest date in its file name, and that date. Which
  # one was used is stored with the route day.
  def newest_mrt_exits
    directory = File.join(@data_root, MrtExitsSnapshot::DIRECTORY)
    name = Dir.glob("*.csv", base: directory).grep(/\A\d{4}-\d{2}-\d{2}\.csv\z/).max
    raise Error, "沒有捷運出入口快照：先跑 bin/rails external:mrt_exits" unless name

    [ File.join(directory, name), Date.iso8601(File.basename(name, ".csv")) ]
  end

  def replace(dir)
    RouteDay.where(route_id: @route_id, day: @day).delete_all
    STAGING.each_key { stage(it, File.join(dir, "#{it}.csv")) }
    route_day_id = insert_route_day
    insert_stops(route_day_id)
    { trips: insert_trips(route_day_id), layovers: insert_layovers(route_day_id),
      trip_stop_counts: insert_trip_stop_counts(route_day_id) }
  end

  # A temporary table per file, emptied for each load because the
  # surrounding transaction may outlive this one.
  def stage(name, path)
    connection.execute("CREATE TEMPORARY TABLE IF NOT EXISTS #{STAGING_TABLES.fetch(name)} (#{STAGING.fetch(name)})")
    connection.execute("TRUNCATE #{STAGING_TABLES.fetch(name)}")
    raw = connection.raw_connection
    raw.copy_data("COPY #{STAGING_TABLES.fetch(name)} FROM STDIN WITH (FORMAT csv, HEADER true)") do
      raw.put_copy_data(File.binread(path))
    end
  end

  def insert_route_day
    connection.select_value(<<~SQL)
      INSERT INTO route_days (route_id, day, route_name, departure, destination, static_day, mrt_exits_day, loaded_at)
      SELECT route_id, day, route_name, departure, destination, static_day, mrt_exits_day, now() FROM staging_route_day
      RETURNING id
    SQL
  end

  def insert_stops(route_day_id)
    insert("route_day_stops", "stops", route_day_id, <<~SQL)
      INSERT INTO route_day_stops (route_day_id, go_back, seq, stop_name, latitude, longitude, nearest_exit_name,
                                   nearest_exit_meters)
      SELECT :route_day_id, go_back, seq, stop_name, latitude, longitude, nearest_exit_name, nearest_exit_meters
      FROM staging_stops
    SQL
  end

  def insert_trips(route_day_id)
    insert("trips", "trips", route_day_id, <<~SQL)
      INSERT INTO trips (route_day_id, bus_id, path_attribute_id, go_back, band, start_time, end_time, first_seq,
                         last_seq, n_events, n_stops_observed, completeness, start_from_arrival, end_from_departure)
      SELECT :route_day_id, bus_id, path_attribute_id, go_back, band, start_time, end_time, first_seq,
             last_seq, n_events, n_stops_observed, completeness, start_from_arrival, end_from_departure
      FROM staging_trips
    SQL
  end

  def insert_layovers(route_day_id)
    insert("layovers", "layovers", route_day_id, <<~SQL)
      INSERT INTO layovers (route_day_id, bus_id, go_back, end_time, next_start_time)
      SELECT :route_day_id, bus_id, go_back, end_time, next_start_time FROM staging_layovers
    SQL
  end

  # A count finds its trip by vehicle and start time.
  def insert_trip_stop_counts(route_day_id)
    insert("trip_stop_counts", "trip_stop_counts", route_day_id, <<~SQL)
      INSERT INTO trip_stop_counts (trip_id, seq, on_board)
      SELECT t.id, s.seq, s.on_board
      FROM staging_trip_stop_counts s
      JOIN trips t ON t.route_day_id = :route_day_id AND t.bus_id = s.bus_id AND t.start_time = s.start_time
    SQL
  end

  # Inserts and checks that every staged row arrived; a row that finds no
  # trip would otherwise vanish without a trace.
  def insert(table, name, route_day_id, sql)
    written = connection.exec_update(RouteDay.sanitize_sql_array([ sql, { route_day_id: } ]))
    staged = connection.select_value("SELECT count(*) FROM #{STAGING_TABLES.fetch(name)}")
    raise Error, "#{table} 寫入 #{written} 列，CSV 有 #{staged} 列" unless written == staged

    written
  end

  def connection = RouteDay.connection
end
