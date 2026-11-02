module RoutePage
  # One row per day of a route card's month, from the first loaded day on. A loaded
  # day has its figures; a day the coverage lists as missing has only its reason,
  # because the production host can no longer tell why a day is not there. The
  # missing-stop rate is the health card's: stops of the trip's own direction
  # without an event, over those stops, summed over the complete trips. It reads a
  # fixed number of grouped queries, however many days the month has.
  class MonthDays
    # stopping is { go_back => Stopping } for the given stopping ends. The figures
    # are nil, and stopping empty, on a day that is not loaded.
    Row = Data.define(:day, :day_type, :day_note, :n_trips, :complete_share, :missing_stop_rate, :n_vehicles, :stopping, :four_hours_share, :reason)
    Stopping = Data.define(:n_layovers, :short_share)

    def initialize(route_card, stop_go_backs:)
      @route_card = route_card
      @stop_go_backs = stop_go_backs
    end

    def rows
      @rows ||= begin
        first_day = stored.keys.min
        first_day ? (first_day..@route_card.month.end_of_month).map { row(it) } : []
      end
    end

    # The lowest and highest daily share under 15 minutes among the loaded days of
    # a day type at a stopping end, nil without one.
    def short_range(day_type, go_back)
      rows.select { it.day_type == day_type }.filter_map { it.stopping[go_back]&.short_share }.minmax.then { it.first && it }
    end

    private

    def row(day)
      route_day = stored[day]
      return Row.new(day:, day_type: nil, day_note: nil, n_trips: nil, complete_share: nil, missing_stop_rate: nil, n_vehicles: nil, stopping: {},
                     four_hours_share: nil, reason: reasons[day]) unless route_day

      id, day_type, day_note = route_day
      trips = trip_figures.fetch(id, { "n_trips" => 0, "n_complete" => 0, "n_vehicles" => 0 })
      Row.new(day:, day_type:, day_note:, n_trips: trips["n_trips"], complete_share: share(trips["n_complete"], trips["n_trips"]),
              missing_stop_rate: missing_stop_rates[id], n_vehicles: trips["n_vehicles"],
              stopping: @stop_go_backs.to_h { [ it, stopping_figures.fetch([ id, it ], Stopping.new(n_layovers: 0, short_share: nil)) ] },
              four_hours_share: four_hours_shares[id], reason: nil)
    end

    def share(part, whole) = whole.zero? ? nil : part.fdiv(whole)

    # Day => [id, day type, note], read once.
    def stored
      @stored ||= RouteDay.where(route_id: @route_card.route_id, day: @route_card.month_days).pluck(:day, :id, :day_type, :day_note).to_h { |day, *rest| [ day, rest ] }
    end

    def ids = stored.values.map(&:first)

    # Day => reason, each missing stretch of the coverage opened into its days.
    def reasons
      @reasons ||= @route_card.coverage.fetch("missing", []).flat_map do |entry|
        (Date.iso8601(entry["from"])..Date.iso8601(entry["to"])).map { [ it, entry["reason"] ] }
      end.to_h
    end

    def select_rows(sql) = RouteDay.connection.select_all(RouteDay.sanitize_sql_array([ sql, { ids: } ])).to_a

    def trip_figures = @trip_figures ||= select_rows(TRIPS_SQL).index_by { it["route_day_id"] }

    def missing_stop_rates
      @missing_stop_rates ||= select_rows(MISSING_STOPS_SQL).to_h { [ it["route_day_id"], share(it["missing_stops"].to_i, it["direction_stops"].to_i) ] }
    end

    def stopping_figures
      @stopping_figures ||= select_rows(LAYOVERS_SQL).to_h do |row|
        [ row.values_at("route_day_id", "go_back"), Stopping.new(n_layovers: row["n_layovers"], short_share: row["short_share"]) ]
      end
    end

    def four_hours_shares
      @four_hours_shares ||= select_rows(WINDOWS_SQL).to_h { [ it["route_day_id"], share(it["n_flagged"], it["n_windows"]) ] }
    end

    TRIPS_SQL = <<~SQL.freeze
      SELECT route_day_id, count(*) AS n_trips, count(*) FILTER (WHERE completeness = 'complete') AS n_complete, count(DISTINCT bus_id) AS n_vehicles
      FROM trips
      WHERE route_day_id IN (:ids)
      GROUP BY route_day_id
    SQL

    # A trip counts against the stop list of its own route Id, as in
    # analysis/50_quality.sql: a member route has a list of its own.
    MISSING_STOPS_SQL = <<~SQL.freeze
      WITH direction_sizes AS (
          SELECT route_day_id, route_id, go_back, count(*) AS n_stops
          FROM route_day_stops
          WHERE route_day_id IN (:ids)
          GROUP BY route_day_id, route_id, go_back
      )
      SELECT t.route_day_id, sum(d.n_stops - t.n_stops_observed) AS missing_stops, sum(d.n_stops) AS direction_stops
      FROM trips t
      JOIN direction_sizes d ON d.route_day_id = t.route_day_id AND d.route_id = t.route_id AND d.go_back = t.go_back
      WHERE t.route_day_id IN (:ids) AND t.completeness = 'complete'
      GROUP BY t.route_day_id
    SQL

    LAYOVERS_SQL = <<~SQL.freeze
      WITH minutes AS (
          SELECT route_day_id, go_back, #{LayoverStats::MINUTES_SQL} AS minutes
          FROM layovers
          WHERE route_day_id IN (:ids)
      )
      SELECT m.route_day_id, m.go_back, count(*) AS n_layovers, #{LayoverStats::SHORT_SHARE_SQL} AS short_share
      FROM minutes m
      GROUP BY m.route_day_id, m.go_back
    SQL

    WINDOWS_SQL = <<~SQL.freeze
      SELECT route_day_id, count(*) AS n_windows, count(*) FILTER (WHERE flagged) AS n_flagged
      FROM route_day_rest_windows
      WHERE route_day_id IN (:ids) AND rule = 'four_hours'
      GROUP BY route_day_id
    SQL
    private_constant :TRIPS_SQL, :MISSING_STOPS_SQL, :LAYOVERS_SQL, :WINDOWS_SQL
  end
end
