module RoutePage
  # The months of a route up to a month card's month, as in the monthly-card spec:
  # one row per month with a route card, recomputed with today's definitions from
  # the same query objects, so that months compare like with like. Definitions do
  # change, and a printed card does not, so a month whose stored summary differs
  # from what it recomputes to is named.
  class CardTrend
    Row = Data.define(:month, :partial, :weekdays, :ends, :four_hours_share, :six_hours_share, :morning_on_road)
    EndFigures = Data.define(:go_back, :stop_name, :short_share, :day_low, :day_high, :p10)

    def initialize(month_card)
      @card = month_card
    end

    # Oldest first.
    def rows = @rows ||= month_cards.map { row(it) }

    def first_card? = month_cards.size == 1

    # The month card of the calendar's previous month, nil when it has no route card.
    def previous = month_cards.find { it.month == @card.month.prev_month }

    # The months before this one whose stored summary is not what they recompute to.
    def differing_months
      month_cards.select { it.month < @card.month && it.route_card.summary && it.route_card.summary != it.summary }.map(&:month)
    end

    private

    # The newest version of each month, up to this one; this month's is the card given.
    def month_cards
      @month_cards ||= begin
        earlier = RouteCard.where(route_id: @card.route_id, month: ...@card.month).order(:month, version: :desc).to_a.uniq(&:month)
        [ *earlier.map { MonthCard.new(it) }, @card ]
      end
    end

    def row(card)
      rules = card.rest_windows(:weekday)
      Row.new(month: card.month, partial: card.route_card.partial?, weekdays: card.weekdays.count, ends: end_figures(card),
              four_hours_share: rules.rule(:four_hours).flagged_share, six_hours_share: rules.rule(:six_hours).flagged_share,
              morning_on_road: card.morning_on_road)
    end

    def end_figures(card)
      card.stopping_stats(:weekday).map do |stat|
        day_low, day_high = card.days.short_range("weekday", stat.go_back)
        EndFigures.new(go_back: stat.go_back, stop_name: stat.stop_name, short_share: stat.short_share, day_low:, day_high:, p10: stat.percentiles.first)
      end
    end
  end
end
