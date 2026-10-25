module HomePage
  # The routes that have a route page, in the order of config/route_page.yml,
  # each with its latest stored route day, or nil when it has none, and the
  # figures of that day at the route's stopping ends. The latest day of every
  # route comes from one query and the figures of all of them from another;
  # the nature of the ends comes from the configuration.
  class RouteList
    Entry = Data.define(:route_id, :route_day, :figures)

    def entries
      @entries ||= begin
        route_ids = RoutePage.route_ids
        latest = RouteDay.where(route_id: route_ids)
                         .select("DISTINCT ON (route_id) route_days.*")
                         .order(:route_id, day: :desc)
                         .index_by(&:route_id)
        figures = StopEndFigures.new(latest.values).rows.group_by(&:route_day_id)
        route_ids.map do |route_id|
          route_day = latest[route_id]
          Entry.new(route_id:, route_day:, figures: route_day ? stopping_figures(route_id, figures.fetch(route_day.id, [])) : [])
        end
      end
    end

    private

    # The rows of the route's stopping ends, in direction order.
    def stopping_figures(route_id, rows)
      ends = RoutePage.ends(route_id)
      rows.select { ends.stopping?(it.go_back) }
    end
  end
end
