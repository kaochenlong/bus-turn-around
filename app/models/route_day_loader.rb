require "csv"
require "tmpdir"

# Writes one page route, with the member routes its page counts with it, on
# one Taipei day into the derived tables. The route Ids of the run come from
# RoutePage.member_route_ids unless the caller gives them. DuckDB runs the
# stages of analysis/, analysis/mrt_overlap.sql with the newest MRT entrance
# snapshot, analysis/gps_reports.sql, analysis/turnaround_facilities.sql with
# the newest public toilet snapshot and the configured nature of the route's
# ends, analysis/route_shape.sql with the route shapes file of the day's static
# snapshot, analysis/depots.sql with its operators file, analysis/stop_speeds.sql
# and analysis/derived_export.sql into CSV files; then, in one transaction, the
# stored day is deleted and the files are copied in, together with the day
# type of the newest office calendar snapshot of the day's year. A failure
# anywhere leaves the stored day as it was, and loading the same input again
# leaves the same rows. A direction without a route shape, or a snapshot
# without the operators file, does not stop the day: it is printed instead.
class RouteDayLoader
  # The day could not be written; the message says why.
  class Error < StandardError; end

  # Staging table columns, in the column order of each CSV file.
  STAGING = {
    "route_day" => "route_id integer, day date, route_name text, departure text, destination text, static_day date, " \
                   "mrt_exits_day date, public_toilets_day date, member_names jsonb",
    "stops" => "go_back integer, seq integer, stop_name text, latitude double precision, longitude double precision, " \
               "nearest_exit_name text, nearest_exit_meters double precision, route_id integer, stop_location_id integer, " \
               "shape_meters double precision",
    "trips" => "bus_id text, path_attribute_id integer, go_back integer, band text, start_time timestamptz, " \
               "end_time timestamptz, first_seq integer, last_seq integer, n_events integer, n_stops_observed integer, " \
               "completeness text, start_from_arrival boolean, end_from_departure boolean, route_id integer",
    "layovers" => "bus_id text, go_back integer, end_time timestamptz, next_start_time timestamptz",
    "trip_stop_counts" => "bus_id text, start_time timestamptz, seq integer, on_board integer",
    "stop_speeds" => "bus_id text, start_time timestamptz, seq integer, band text, meters double precision, seconds integer",
    "ends" => "go_back integer, end_seq integer, end_stop_name text, end_latitude double precision, " \
              "end_longitude double precision, location_source text, latitude double precision, longitude double precision, " \
              "n_layovers integer, n_located_layovers integer, n_standstill_records integer, end_stop_meters double precision",
    "end_toilets" => "go_back integer, name text, category text, address text, latitude double precision, " \
                     "longitude double precision, meters double precision",
    "end_cells" => "go_back integer, cell_latitude double precision, cell_longitude double precision, n_records integer, " \
                   "n_buses integer, n_layovers integer",
    "shapes" => "go_back integer, shape_updated_at timestamptz, points jsonb, issue text",
    "depots" => "station_id integer, provider_name text, station_name text, n_buses integer, n_trips integer"
  }.freeze

  # The staging table of each file, written out so that no table name is
  # ever built at run time.
  STAGING_TABLES = {
    "route_day" => "staging_route_day", "stops" => "staging_stops", "trips" => "staging_trips",
    "layovers" => "staging_layovers", "trip_stop_counts" => "staging_trip_stop_counts",
    "stop_speeds" => "staging_stop_speeds", "ends" => "staging_ends",
    "end_toilets" => "staging_end_toilets", "end_cells" => "staging_end_cells", "shapes" => "staging_shapes",
    "depots" => "staging_depots"
  }.freeze

  # The line printed for each issue analysis/route_shape.sql gives a
  # direction: every issue but duplicate_rows leaves the direction without a
  # route shape.
  SHAPE_ISSUES = {
    "no_row" => "%{direction}沒有路線軌跡：GetBusShape.gz 沒有這個方向的列",
    "not_linestring" => "%{direction}沒有路線軌跡：那一列不是 LINESTRING",
    "too_few_points" => "%{direction}沒有路線軌跡：那一列的點太少，連不成線",
    "out_of_range" => "%{direction}沒有路線軌跡：那一列的座標超出範圍，可能是經緯度對調",
    "no_update_time" => "%{direction}沒有路線軌跡：那一列的 utime 讀不出來",
    "duplicate_rows" => "%{direction}在 GetBusShape.gz 不只一列，取了能用的列裡 utime 最新的那一列"
  }.freeze
  DIRECTION_NAMES = { 0 => "去程", 1 => "返程" }.freeze

  # How derived:load and bin/nightly-load word the counts call returns once a
  # route day is written.
  def self.summary(counts)
    "寫入：趟次 #{counts[:trips]}、折返停留 #{counts[:layovers]}、趟次站 #{counts[:trip_stop_counts]}、" \
      "兩端公廁 #{counts[:end_toilets]} 間、靜止格 #{counts[:end_cells]} 格"
  end

  def initialize(route_id:, day:, data_root:, duckdb:, out: $stdout, member_route_ids: RoutePage.member_route_ids(route_id))
    @route_id = route_id
    @member_route_ids = member_route_ids
    @day = day
    @data_root = data_root
    @duckdb = duckdb
    @out = out
  end

  # Returns the numbers of trips, layovers, trip stop counts, trip stop speeds,
  # ends, end toilets, end cells, route shapes and depots written.
  def call
    mrt_exits = newest_snapshot(MrtExitsSnapshot::DIRECTORY, "捷運出入口", "bin/rails external:mrt_exits")
    public_toilets = newest_snapshot(PublicToiletsSnapshot::DIRECTORY, "公廁", "bin/rails external:public_toilets")
    calendar = office_calendar_entry
    natures = end_natures
    bus_shapes = static_file_path("GetBusShape.gz")
    @out.puts("#{@day.iso8601}：靜態快照沒有 GetBusShape.gz，路線 #{@route_id} 這一天沒有路線軌跡") unless bus_shapes
    providers = static_file_path("GetProvider.gz")
    @out.puts("#{@day.iso8601}：靜態快照沒有 GetProvider.gz，路線 #{@route_id} 這一天的調度站沒有名稱") unless providers
    Dir.mktmpdir("route-day") do |dir|
      export(dir, mrt_exits:, public_toilets:, natures:, bus_shapes: bus_shapes || empty_array_file(dir),
                  providers: providers || empty_providers_file(dir))
      # A missing file was told about once, not once per direction.
      notes = bus_shapes ? shape_notes(dir) : []
      counts = RouteDay.transaction(requires_new: true) { replace(dir, calendar) }
      notes.each { @out.puts(it) }
      counts
    end
  end

  private

  def export(dir, mrt_exits:, public_toilets:, natures:, bus_shapes:, providers:)
    variables = { data_root: @data_root, route_id: @route_id, member_route_ids: @member_route_ids, day: @day, static_day: @day,
                  inspect_dir: dir, derived_dir: dir,
                  mrt_exits_path: mrt_exits.path, mrt_exits_day: mrt_exits.day,
                  public_toilets_path: public_toilets.path, public_toilets_day: public_toilets.day,
                  end_nature_0: natures.fetch(0), end_nature_1: natures.fetch(1), bus_shape_path: bus_shapes, provider_path: providers }
    AnalysisRun.run(@duckdb, variables, extra_files: %w[mrt_overlap.sql gps_reports.sql turnaround_facilities.sql route_shape.sql depots.sql stop_speeds.sql derived_export.sql])
  rescue AnalysisRun::Error => e
    raise Error, e.message
  end

  # The file `name` of the day's static snapshot, or nil when the snapshot has
  # none.
  def static_file_path(name)
    path = File.join(@data_root, "static", @day.iso8601, name)
    path if File.file?(path)
  end

  # What analysis/route_shape.sql reads in place of a missing route shapes
  # file: an array without rows, so both directions are left without a shape.
  def empty_array_file(dir) = File.join(dir, "no_bus_shapes.json").tap { File.write(it, "[]") }

  # What analysis/depots.sql reads in place of a missing operators file: an
  # object without rows, so every depot is left without names.
  def empty_providers_file(dir) = File.join(dir, "no_providers.json").tap { File.write(it, '{"BusInfo":[]}') }

  # A line for every direction of shapes.csv that has an issue. They are worded
  # before anything is written, so an issue without wording stops the day.
  def shape_notes(dir)
    CSV.foreach(File.join(dir, "shapes.csv"), headers: true).filter_map do |row|
      next unless row["issue"]

      wording = SHAPE_ISSUES.fetch(row["issue"]) { raise Error, "analysis/route_shape.sql 給了沒有說明的 issue：#{row['issue']}" }
      direction = DIRECTION_NAMES.fetch(Integer(row["go_back"]))
      "#{@day.iso8601}：路線 #{@route_id} #{format(wording, direction:)}（#{row['issue']}）"
    end
  end

  # The snapshot in `directory` with the latest date in its file name; which
  # one was used is stored with the route day. The entrance snapshot is looked
  # up before the toilet snapshot, so a data root missing both is told about
  # the entrance snapshot.
  def newest_snapshot(directory, label, task)
    NewestSnapshot.find(data_root: @data_root, directory:, label:, task:)
  rescue NewestSnapshot::Missing => e
    raise Error, e.message
  end

  # The day as the newest office calendar snapshot of its year has it. It is
  # looked up after the entrance and toilet snapshots, so a data root missing
  # several is told about those first.
  def office_calendar_entry
    OfficeCalendarSnapshot.entry(data_root: @data_root, day: @day)
  rescue OfficeCalendarSnapshot::Error => e
    raise Error, e.message
  end

  # The nature of each end as SQL reads it, keyed by direction. A route that
  # is not in config/route_page.yml yet is unknown at both ends and gets no
  # end rows; one that is there with an incomplete or unknown end fails the
  # day, because the nature is a verified fact, never assumed.
  def end_natures
    unless RoutePage.route_ids.include?(@route_id)
      @out.puts("#{@day.iso8601}：路線 #{@route_id} 在 config/route_page.yml 還沒有設定兩端，所以沒有設施的列")
      return RoutePage::Ends::DIRECTIONS.index_with("unknown")
    end

    ends = RoutePage.ends(@route_id)
    RoutePage::Ends::DIRECTIONS.index_with { ends.nature(it).to_s }
  rescue RoutePage::Ends::InvalidConfiguration => e
    raise Error, e.message
  end

  def replace(dir, calendar)
    RouteDay.where(route_id: @route_id, day: @day).delete_all
    STAGING.each_key { stage(it, File.join(dir, "#{it}.csv")) }
    route_day_id = insert_route_day(calendar)
    insert_stops(route_day_id)
    # The ends go in before their toilets and cells, which find their end by direction.
    { trips: insert_trips(route_day_id), layovers: insert_layovers(route_day_id),
      trip_stop_counts: insert_trip_stop_counts(route_day_id), trip_stop_speeds: insert_trip_stop_speeds(route_day_id),
      ends: insert_ends(route_day_id),
      end_toilets: insert_end_toilets(route_day_id), end_cells: insert_end_cells(route_day_id),
      shapes: insert_shapes(route_day_id), depots: insert_depots(route_day_id) }
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

  def insert_route_day(calendar)
    connection.select_value(RouteDay.sanitize_sql_array([ <<~SQL, calendar.to_h ]))
      INSERT INTO route_days (route_id, day, route_name, departure, destination, static_day, mrt_exits_day,
                              public_toilets_day, member_names, day_type, day_note, office_calendar_day, loaded_at)
      SELECT route_id, day, route_name, departure, destination, static_day, mrt_exits_day, public_toilets_day,
             member_names, :day_type, :note, CAST(:snapshot_day AS date), now()
      FROM staging_route_day
      RETURNING id
    SQL
  end

  def insert_stops(route_day_id)
    insert("route_day_stops", "stops", route_day_id, <<~SQL)
      INSERT INTO route_day_stops (route_day_id, go_back, seq, stop_name, latitude, longitude, nearest_exit_name,
                                   nearest_exit_meters, route_id, stop_location_id, shape_meters)
      SELECT :route_day_id, go_back, seq, stop_name, latitude, longitude, nearest_exit_name, nearest_exit_meters,
             route_id, stop_location_id, shape_meters
      FROM staging_stops
    SQL
  end

  def insert_trips(route_day_id)
    insert("trips", "trips", route_day_id, <<~SQL)
      INSERT INTO trips (route_day_id, bus_id, path_attribute_id, go_back, band, start_time, end_time, first_seq,
                         last_seq, n_events, n_stops_observed, completeness, start_from_arrival, end_from_departure, route_id)
      SELECT :route_day_id, bus_id, path_attribute_id, go_back, band, start_time, end_time, first_seq,
             last_seq, n_events, n_stops_observed, completeness, start_from_arrival, end_from_departure, route_id
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

  # A stop speed finds its trip by vehicle and start time, as a count does.
  def insert_trip_stop_speeds(route_day_id)
    insert("trip_stop_speeds", "stop_speeds", route_day_id, <<~SQL)
      INSERT INTO trip_stop_speeds (trip_id, seq, band, meters, seconds)
      SELECT t.id, s.seq, s.band, s.meters, s.seconds
      FROM staging_stop_speeds s
      JOIN trips t ON t.route_day_id = :route_day_id AND t.bus_id = s.bus_id AND t.start_time = s.start_time
    SQL
  end

  def insert_ends(route_day_id)
    insert("route_day_ends", "ends", route_day_id, <<~SQL)
      INSERT INTO route_day_ends (route_day_id, go_back, end_seq, end_stop_name, end_latitude, end_longitude,
                                  location_source, latitude, longitude, n_layovers, n_located_layovers,
                                  n_standstill_records, end_stop_meters)
      SELECT :route_day_id, go_back, end_seq, end_stop_name, end_latitude, end_longitude, location_source, latitude,
             longitude, n_layovers, n_located_layovers, n_standstill_records, end_stop_meters
      FROM staging_ends
    SQL
  end

  # A toilet finds its end by direction.
  def insert_end_toilets(route_day_id)
    insert("route_day_end_toilets", "end_toilets", route_day_id, <<~SQL)
      INSERT INTO route_day_end_toilets (route_day_end_id, name, category, address, latitude, longitude, meters)
      SELECT e.id, s.name, s.category, s.address, s.latitude, s.longitude, s.meters
      FROM staging_end_toilets s
      JOIN route_day_ends e ON e.route_day_id = :route_day_id AND e.go_back = s.go_back
    SQL
  end

  # A cell finds its end by direction.
  def insert_end_cells(route_day_id)
    insert("route_day_end_cells", "end_cells", route_day_id, <<~SQL)
      INSERT INTO route_day_end_cells (route_day_end_id, cell_latitude, cell_longitude, n_records, n_buses, n_layovers)
      SELECT e.id, s.cell_latitude, s.cell_longitude, s.n_records, s.n_buses, s.n_layovers
      FROM staging_end_cells s
      JOIN route_day_ends e ON e.route_day_id = :route_day_id AND e.go_back = s.go_back
    SQL
  end

  # Only the directions with points are stored. The others leave the staging
  # table first, so the insert still checks every row it keeps; they were
  # worded by shape_notes.
  def insert_shapes(route_day_id)
    connection.execute("DELETE FROM staging_shapes WHERE points IS NULL")
    insert("route_day_shapes", "shapes", route_day_id, <<~SQL)
      INSERT INTO route_day_shapes (route_day_id, go_back, shape_updated_at, points)
      SELECT :route_day_id, go_back, shape_updated_at, points FROM staging_shapes
    SQL
  end

  # A name the day's GetProvider.gz does not give arrives as an empty string,
  # which the CSV file quotes so that it is not read as NULL.
  def insert_depots(route_day_id)
    insert("route_day_depots", "depots", route_day_id, <<~SQL)
      INSERT INTO route_day_depots (route_day_id, station_id, provider_name, station_name, n_buses, n_trips)
      SELECT :route_day_id, station_id, provider_name, station_name, n_buses, n_trips FROM staging_depots
    SQL
  end

  # Inserts and checks that every staged row arrived; a row that finds no
  # trip or end would otherwise vanish without a trace.
  def insert(table, name, route_day_id, sql)
    written = connection.exec_update(RouteDay.sanitize_sql_array([ sql, { route_day_id: } ]))
    staged = connection.select_value("SELECT count(*) FROM #{STAGING_TABLES.fetch(name)}")
    raise Error, "#{table} 寫入 #{written} 列，CSV 有 #{staged} 列" unless written == staged

    written
  end

  def connection = RouteDay.connection
end
