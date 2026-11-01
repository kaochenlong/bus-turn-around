module HomePage
  # The routes that have a route page, in the order of config/route_page.yml,
  # each with its latest stored route day, or nil when it has none, the
  # figures of that day at the route's stopping ends, and the districts it
  # qualifies in on that day. The latest day of every route comes from one
  # query, the figures of all of them from another and the districts from a
  # third; the nature of the ends comes from the configuration.
  class RouteList
    # districts_known is whether the latest day was loaded with a stop
    # district snapshot: a day loaded before districts existed has none.
    Entry = Data.define(:route_id, :route_day, :figures, :districts, :districts_known)

    def entries
      @entries ||= begin
        route_ids = RoutePage.route_ids
        latest = RouteDay.where(route_id: route_ids)
                         .select("DISTINCT ON (route_id) route_days.*")
                         .order(:route_id, day: :desc)
                         .index_by(&:route_id)
        figures = StopEndFigures.new(latest.values).rows.group_by(&:route_day_id)
        @districts = RouteDistricts.new(latest.values)
        names = @districts.names_by_route_day
        route_ids.map do |route_id|
          route_day = latest[route_id]
          Entry.new(route_id:, route_day:, figures: route_day ? stopping_figures(route_id, figures.fetch(route_day.id, [])) : [],
                    districts: route_day ? names.fetch(route_day.id, []) : [], districts_known: route_day&.stop_districts_day.present?)
        end
      end
    end

    # The names of every district some listed route qualifies in on its latest
    # day, in the filter's order.
    def district_options
      entries
      @districts.options
    end

    # The district shown on load, as RouteDistricts picks it; nil without any.
    def default_district
      entries
      @districts.default_option
    end

    # The listed routes with stored days whose latest day has no districts yet.
    def n_unknown = entries.count { it.route_day && !it.districts_known }

    private

    # The rows of the route's stopping ends, in direction order.
    def stopping_figures(route_id, rows)
      ends = RoutePage.ends(route_id)
      rows.select { ends.stopping?(it.go_back) }
    end
  end
end
