module RoutePage
  # The rest windows and driving stretches stored for any given route days, as
  # in the layover-metrics spec. A share's denominator is the windows that can
  # be judged, so a route with fewer complete trips is not made to look better
  # by having fewer windows. It reports numbers only: the data sees vehicles,
  # not drivers, so nothing here says whether a rule was kept, and no plate
  # leaves this object.
  class RestWindows
    RULES = { four_hours: "four_hours", six_hours: "six_hours" }.freeze
    FOUR_HOURS = 240
    SIX_HOURS = 360

    # flagged_share, day_low and day_high are nil without a window of the rule;
    # the day figures are over the days that have one.
    Rule = Data.define(:rule, :n_windows, :n_flagged, :flagged_share, :day_low, :day_high, :n_over_daily, :n_flagged_over_daily)
    # p50, p90 and longest are in minutes, nil without a stretch.
    Stretches = Data.define(:n_stretches, :p50, :p90, :longest, :n_over_four_hours, :n_over_six_hours)

    def initialize(route_days)
      @ids = route_days.ids
    end

    # The figures of a rule; a rule this object does not know raises.
    def rule(name)
      rule = RULES.fetch(name)
      counts = window_counts.select { it["rule"] == rule }
      shares = counts.map { it["n_flagged"].fdiv(it["n_windows"]) }
      n_windows, n_flagged = counts.sum { it["n_windows"] }, counts.sum { it["n_flagged"] }
      Rule.new(rule: name, n_windows:, n_flagged:, flagged_share: n_windows.zero? ? nil : n_flagged.fdiv(n_windows),
               day_low: shares.min, day_high: shares.max, n_over_daily: counts.sum { it["n_over_daily"] },
               n_flagged_over_daily: counts.sum { it["n_flagged_over_daily"] })
    end

    def stretches
      row = RouteDay.connection.select_one(RouteDay.sanitize_sql_array([ STRETCHES_SQL, { ids: @ids, four_hours: FOUR_HOURS, six_hours: SIX_HOURS } ]))
      Stretches.new(n_stretches: row["n_stretches"], p50: row["p50"]&.to_f, p90: row["p90"]&.to_f, longest: row["longest"]&.to_f,
                    n_over_four_hours: row["n_over_four_hours"], n_over_six_hours: row["n_over_six_hours"])
    end

    # Days stored before the windows existed have none until they are loaded
    # again, which the number of rows cannot tell from a day without a window.
    def needs_reload? = RouteDay.where(id: @ids, rest_windows_loaded: false).exists?

    private

    # One row per rule and day that has a window, read once.
    def window_counts
      @window_counts ||= RouteDay.connection.select_all(RouteDay.sanitize_sql_array([ WINDOWS_SQL, { ids: @ids } ])).to_a
    end

    WINDOWS_SQL = <<~SQL.freeze
      SELECT rule, route_day_id, count(*) AS n_windows,
             count(*) FILTER (WHERE flagged) AS n_flagged,
             count(*) FILTER (WHERE over_daily_driving) AS n_over_daily,
             count(*) FILTER (WHERE flagged AND over_daily_driving) AS n_flagged_over_daily
      FROM route_day_rest_windows
      WHERE route_day_id IN (:ids)
      GROUP BY rule, route_day_id
    SQL

    STRETCHES_SQL = <<~SQL.freeze
      WITH lengths AS (
          SELECT CAST(extract(epoch FROM end_time - start_time) / 60 AS double precision) AS minutes
          FROM route_day_driving_stretches
          WHERE route_day_id IN (:ids)
      )
      SELECT count(*) AS n_stretches,
             round(CAST(percentile_cont(0.5) WITHIN GROUP (ORDER BY minutes) AS numeric), 1) AS p50,
             round(CAST(percentile_cont(0.9) WITHIN GROUP (ORDER BY minutes) AS numeric), 1) AS p90,
             round(CAST(max(minutes) AS numeric), 1) AS longest,
             count(*) FILTER (WHERE minutes > :four_hours) AS n_over_four_hours,
             count(*) FILTER (WHERE minutes > :six_hours) AS n_over_six_hours
      FROM lengths
    SQL
    private_constant :WINDOWS_SQL, :STRETCHES_SQL
  end
end
