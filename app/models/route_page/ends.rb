module RoutePage
  # Whether buses stop at each end of a route or drive on to the first stop of
  # the next trip, as in the turnaround-ends spec, keyed by the direction
  # (go_back) of the trips that end there. It is a fact verified route by
  # route and written into config/route_page.yml, never derived from the
  # layovers, so a route without both ends or with another value is a
  # configuration error, not an assumed stop.
  class Ends
    DIRECTIONS = [ 0, 1 ].freeze
    NATURES = %w[stop pass_through].freeze

    # A route in config/route_page.yml without the nature of a direction, or
    # with a value other than stop and pass_through.
    class InvalidConfiguration < StandardError; end

    # From the route's ends in the configuration, direction => "stop" or
    # "pass_through"; nil when the route has none.
    def self.from_config(hash, route_id:)
      configured = hash || {}
      natures = DIRECTIONS.to_h do |go_back|
        value = configured[go_back]
        unless NATURES.include?(value)
          raise InvalidConfiguration, "route #{route_id}, direction #{go_back}: the end nature in config/route_page.yml " \
                                      "must be stop or pass_through, got #{value.inspect}"
        end

        [ go_back, value.to_sym ]
      end
      new(natures)
    end
    private_class_method :new

    def initialize(natures)
      @natures = natures
    end

    # :stop or :pass_through.
    def nature(go_back) = @natures.fetch(go_back)

    def stopping?(go_back) = nature(go_back) == :stop

    def stopping_go_backs = DIRECTIONS.select { stopping?(it) }

    def pass_through_go_backs = DIRECTIONS.reject { stopping?(it) }

    # Whether either end is pass-through.
    def pass_through? = pass_through_go_backs.any?
  end
end
