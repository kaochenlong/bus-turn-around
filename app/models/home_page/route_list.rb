module HomePage
  # The routes that have a route page, in the order of config/route_page.yml,
  # each with its latest stored route day, or nil when it has none. The latest
  # day of every route comes from one query; the ends of a route are the route
  # page's concern and are not read here.
  class RouteList
    Entry = Data.define(:route_id, :route_day)

    def entries
      @entries ||= begin
        route_ids = RoutePage.route_ids
        latest = RouteDay.where(route_id: route_ids)
                         .select("DISTINCT ON (route_id) route_days.*")
                         .order(:route_id, day: :desc)
                         .index_by(&:route_id)
        route_ids.map { Entry.new(route_id: it, route_day: latest[it]) }
      end
    end
  end
end
