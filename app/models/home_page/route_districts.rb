module HomePage
  # The qualifying districts of the given route days, read with one
  # statement: per route day, the district names in the order the home page's
  # filter lists them, and the filter's options, every name once in the same
  # order. A district is named by its town alone in 臺北市 and by county and
  # town elsewhere; 臺北市 comes first, then the other counties by name and,
  # within a county, the towns by name, compared by code point here rather
  # than by the database's collation, so the order never changes with it.
  class RouteDistricts
    TAIPEI = "臺北市".freeze
    # The district the home page shows first, when some listed route
    # qualifies in it; otherwise the first option.
    DEFAULT = "中山區".freeze

    def self.name(county, town) = county == TAIPEI ? town : "#{county}#{town}"

    # Route day records already read; nothing is read for none.
    def initialize(route_days)
      @route_day_ids = route_days.map(&:id)
    end

    # Route day Id => the names of the districts it qualifies in.
    def names_by_route_day
      @names_by_route_day ||= rows.group_by(&:first).transform_values { |group| group.map { |(_, county, town)| self.class.name(county, town) } }
    end

    def options = @options ||= rows.map { |(_, county, town)| self.class.name(county, town) }.uniq

    # The option selected on load; nil without any option.
    def default_option = options.include?(DEFAULT) ? DEFAULT : options.first

    private

    # [route day Id, county, town] of every qualifying district, in the
    # filter's order.
    def rows
      @rows ||= if @route_day_ids.empty?
        []
      else
        RouteDayDistrict.where(route_day_id: @route_day_ids, qualifies: true).pluck(:route_day_id, :county, :town)
                        .sort_by { |(id, county, town)| [ county == TAIPEI ? 0 : 1, county, town, id ] }
      end
    end
  end
end
