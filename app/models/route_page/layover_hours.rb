module RoutePage
  # The layovers of each direction of the ending trip by the Taipei hour the
  # vehicle came back, pooled over the given route days: how many, and the share
  # under LayoverStats::SHORT_MINUTES. It reads one query, once.
  class LayoverHours
    Row = Data.define(:hour, :n_layovers, :short_share)

    def initialize(route_days)
      @ids = route_days.ids
    end

    # The hours with a layover at the end of direction `go_back`, in hour order.
    def rows(go_back) = rows_by_direction.fetch(go_back, [])

    private

    def rows_by_direction
      @rows_by_direction ||= RouteDay.connection.select_all(RouteDay.sanitize_sql_array([ SQL, { ids: @ids } ])).to_a.group_by { it["go_back"] }
                                     .transform_values do |rows|
        rows.map { Row.new(hour: it["hour"], n_layovers: it["n_layovers"], short_share: it["short_share"]) }
      end
    end

    SQL = <<~SQL.freeze
      WITH minutes AS (
          SELECT go_back, CAST(extract(hour FROM end_time AT TIME ZONE 'Asia/Taipei') AS integer) AS hour,
                 #{LayoverStats::MINUTES_SQL} AS minutes
          FROM layovers
          WHERE route_day_id IN (:ids)
      )
      SELECT m.go_back, m.hour, count(*) AS n_layovers, #{LayoverStats::SHORT_SHARE_SQL} AS short_share
      FROM minutes m
      GROUP BY m.go_back, m.hour
      ORDER BY m.go_back, m.hour
    SQL
    private_constant :SQL
  end
end
