module RoutePage
  # The document title and share text of a route page that covers stored
  # days, as in the route-page spec: the route name before the site name, and
  # one sentence with the span, the covered days and every stopping end's
  # count, p50 and share under 15 minutes. The numbers are the layover table's
  # rows written in its format, so the share text and the summary's key
  # numbers never differ.
  class SharePreview
    P50 = LayoverStats::PERCENTILE_LEVELS.index(0.5)

    # Only for a page whose selected day is stored: without it there is no
    # route name to read, and the layout falls back to the site's own.
    def initialize(coverage:, route_days:, layover_stats:, ends:)
      raise ArgumentError, "route #{coverage.route_id}: no share preview without a stored selected day, got #{coverage.day.inspect}" unless coverage.data?

      @coverage = coverage
      @route_days = route_days
      @layover_stats = layover_stats
      @ends = ends
    end

    def title = I18n.t("share_preview.title", route_name: latest.route_name, site_name: I18n.t("site.name"))

    def description
      I18n.t("share_preview.description", span: I18n.t("share_preview.span", departure: latest.departure, destination: latest.destination),
                                          coverage: coverage_text, ends: ends_text, bound: I18n.t("share_preview.bound"))
    end

    private

    # The covered days, latest first. Coverage#route_days lists the oldest
    # first, so its order is replaced, not appended to.
    def days = @days ||= @route_days.reorder(day: :desc).to_a

    def latest = days.first

    def coverage_text
      day = Format.day_label(@coverage.day)
      day_type = I18n.t("day_types.#{@coverage.day_type}", raise: true)
      if @coverage.range == "7d"
        I18n.t("share_preview.coverage_7d", day:, day_type:, count: days.size)
      else
        I18n.t("share_preview.coverage_day", day:, day_type:)
      end
    end

    # One clause per stopping end that has a row in the layover table, in
    # direction order, or a statement when neither end is a stopping end.
    def ends_text
      return I18n.t("share_preview.no_stopping_end") if @ends.stopping_go_backs.empty?

      @layover_stats.rows.select { @ends.stopping?(it.go_back) }.map { clause(it) }.join(I18n.t("share_preview.ends_separator"))
    end

    def clause(row)
      return I18n.t("share_preview.stopping_end_without_layovers", stop: row.stop_name) if row.n_layovers.zero?

      I18n.t("share_preview.stopping_end", stop: row.stop_name, count: row.n_layovers, p50: Format.minutes(row.percentiles[P50]),
                                           share: Format.share(row.short_share), minutes: LayoverStats::SHORT_MINUTES)
    end
  end
end
