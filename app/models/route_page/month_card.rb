module RoutePage
  # A route card's month as the month card reads it, as in the monthly-card spec.
  # A month is just a set of route days, split by day type, handed to the query
  # objects the route page uses, so both read the same definitions; each object is
  # built once. A set is :weekday or :holiday.
  class MonthCard
    DAY_TYPES = { weekday: "weekday", holiday: "holiday" }.freeze
    # The minutes the buffer block tries holding.
    HOLD_MINUTES = [ 10, 15, 20 ].freeze
    # A peak starting before this minute of the day is the morning one.
    NOON_MINUTE = 12 * 60

    attr_reader :route_card

    def initialize(route_card)
      @route_card = route_card
      @memo = {}
    end

    def route_id = route_card.route_id

    # The page route first, then its member routes.
    def route_ids = RoutePage.member_route_ids(route_id)

    def month = route_card.month

    def ends = @ends ||= RoutePage.ends(route_id)

    def stop_go_backs = ends.stopping_go_backs

    def weekdays = route_days(:weekday)

    def holidays = route_days(:holiday)

    def route_days(set)
      RouteDay.where(route_id:, day: route_card.month_days, day_type: DAY_TYPES.fetch(set)).order(:day)
    end

    # The route's name on the latest covered day; without a covered day, its Id.
    def route_name = latest_day&.route_name || route_id.to_s

    def departure = latest_day&.departure

    def destination = latest_day&.destination

    # The first and the last stop of a direction of the page route on the latest
    # covered day, nil without a covered day.
    def first_and_last_stop(go_back)
      names = latest_day ? latest_day.stops.where(route_id:, go_back:).order(:seq).pluck(:stop_name) : []
      [ names.first, names.last ]
    end

    # The day of the newest static snapshot the published schedule was read from.
    def latest_published_schedule_day = all_days.maximum(:published_schedule_day)

    def layover_stats(set) = memoize(:layover_stats, set) { LayoverStats.new(route_days(set)) }

    def layover_distribution(set) = memoize(:layover_distribution, set) { LayoverDistribution.new(route_days(set)) }

    def cycles(set) = memoize(:cycles, set) { Cycles.new(route_days(set), ends:) }

    def run_times(set) = memoize(:run_times, set) { RunTimes.new(route_days(set)) }

    def buffer_trades(set)
      memoize(:buffer_trades, set) { HOLD_MINUTES.map { BufferTrade.new(route_days(set), minutes: it, ends:) } }
    end

    def rest_windows(set) = memoize(:rest_windows, set) { RestWindows.new(route_days(set)) }

    def schedule(set) = memoize(:schedule, set) { ScheduleComparison.new(route_days(set), route_id:, cycles: cycles(set)) }

    # The periods with the smallest low headway on the newest published schedule of
    # the set's days, in time order; the summary and the findings call them the peak.
    def peak_periods(set)
      periods = schedule(set).versions.last&.periods.to_a
      lowest = periods.map(&:low_minutes).min
      periods.select { it.low_minutes == lowest }
    end

    def slow_legs = @slow_legs ||= SlowLegs.new(StopSpeeds.new(weekdays))

    def layover_hours = @layover_hours ||= LayoverHours.new(weekdays)

    def days = @days ||= MonthDays.new(route_card, stop_go_backs:)

    def snapshot_changes = @snapshot_changes ||= SnapshotChanges.new(all_days)

    # The sentences of 這個月看到的事.
    def findings = @findings ||= MonthFindings.new(self).sentences

    def trend = @trend ||= CardTrend.new(self)

    # The layover figures of the stopping ends only.
    def stopping_stats(set) = layover_stats(set).rows.select { stop_go_backs.include?(it.go_back) }

    # The vehicles on the road in the peak that starts before noon, as a whole
    # number; nil without one.
    def morning_on_road = peak_periods(:weekday).find { it.start_minute < NOON_MINUTE }&.on_road&.round

    # What the printed card is compared with later: whole figures as the page shows
    # them, so that a difference smaller than what is printed does not count, with
    # string keys because it is stored as jsonb.
    def summary
      stats = stopping_stats(:weekday)
      rules = rest_windows(:weekday)
      { "weekdays" => weekdays.count,
        "short_share" => stats.to_h { [ it.go_back.to_s, percent(it.short_share) ] },
        "p10" => stats.to_h { [ it.go_back.to_s, it.percentiles.first&.round(1) ] },
        "four_hours_share" => percent(rules.rule(:four_hours).flagged_share),
        "six_hours_share" => percent(rules.rule(:six_hours).flagged_share),
        "morning_on_road" => morning_on_road }
    end

    # The operators on the latest covered day, the one with the most vehicles first.
    def operators
      return [] unless latest_day

      RouteDayDepot.where(route_day_id: latest_day.id).order(n_buses: :desc, station_id: :asc).pluck(:provider_name).compact_blank.uniq
    end

    # Whether a covered day was stored before the rest windows or the published
    # schedule existed, so that the figures read from them are incomplete.
    def needs_reload? = DAY_TYPES.each_key.any? { rest_windows(it).needs_reload? || schedule(it).needs_reload? }

    private

    def percent(share) = share && (share * 100).round(1)

    def memoize(name, set)
      DAY_TYPES.fetch(set)
      @memo.fetch([ name, set ]) { @memo[[ name, set ]] = yield }
    end

    def all_days = RouteDay.where(route_id:, day: route_card.month_days)

    def latest_day
      return @latest_day if defined?(@latest_day)

      @latest_day = all_days.order(day: :desc).first
    end
  end
end
