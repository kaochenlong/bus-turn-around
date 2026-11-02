# frozen_string_literal: true

# The first page of a month card, as in the monthly-card spec: which route and
# month, the days it covers with the reasons for the others, the key figures of
# weekdays and holidays next to last month's weekdays, and what the month's numbers
# show. It can be handed around on its own.
class MonthCardSummaryComponent < MonthCardComponent
  Group = Data.define(:key, :title, :rows)
  # values holds the weekday, the holiday and last month's figure, in that order.
  Row = Data.define(:key, :label, :values)

  def month_label = t(".month", year: month_card.month.year, month: month_card.month.month)

  def route_line
    terminals = [ month_card.departure, month_card.destination ].compact.join("－")
    [ terminals, t(".route_ids", ids: month_card.route_ids.join("・")), month_card.operators.join("、") ].compact_blank.join("｜")
  end

  def coverage_sentence
    coverage = month_card.route_card.coverage
    [ t(".covered", weekdays: coverage["loaded_weekdays"], calendar_weekdays: coverage["calendar_weekdays"], holidays: coverage["loaded_holidays"],
                    calendar_holidays: coverage["calendar_holidays"]),
      missing_sentence(coverage.fetch("missing")),
      t(".generated", day: Date.current.iso8601, version: ProgramVersion.current) ].compact.join
  end

  def groups = [ *end_groups, driving_group, schedule_group, cycles_group ]

  def findings = month_card.findings

  private

  def missing_sentence(entries)
    return if entries.empty?

    t(".missing", days: entries.map { "#{missing_days(Date.iso8601(it['from']), Date.iso8601(it['to']))} #{it['reason']}" }.join("；"))
  end

  # One day, two days named one by one, or a stretch.
  def missing_days(from, to)
    return short_day(from) if from == to
    return "#{short_day(from)}、#{short_day(to)}" if to == from + 1

    "#{short_day(from)} 到 #{short_day(to)}"
  end

  def short_day(day) = day.strftime("%m-%d")

  # The columns' month cards and day types: last month's is nil without a route card.
  def columns = [ [ month_card, :weekday ], [ month_card, :holiday ], [ month_card.trend.previous, :weekday ] ]

  def row(key, label) = Row.new(key:, label:, values: columns.map { |card, set| card ? yield(card, set) : NONE })

  def end_groups
    month_card.stop_go_backs.map do |go_back|
      Group.new(key: "end-#{go_back}", title: end_title(go_back), rows: [
        row("short_share-#{go_back}", t(".short_share")) { |card, set| share(stat(card, set, go_back)&.short_share) },
        row("short_range-#{go_back}", t(".short_range")) { |card, set| short_range(card, set, go_back) },
        row("percentiles-#{go_back}", t(".percentiles")) { |card, set| percentiles(stat(card, set, go_back)) }
      ])
    end
  end

  # Named after the end's last stop, from whichever set has one.
  def end_title(go_back)
    name = %i[weekday holiday].filter_map { stat(month_card, it, go_back)&.stop_name }.first
    name ? t(".end_group_named", name:) : t(".end_group")
  end

  def stat(card, set, go_back) = card.stopping_stats(set).find { it.go_back == go_back }

  def short_range(card, set, go_back)
    low, high = card.days.short_range(RoutePage::MonthCard::DAY_TYPES.fetch(set), go_back)
    share_range(low, high)
  end

  def percentiles(stat)
    return NONE unless stat&.percentiles&.first

    t(".minutes_pair", first: decimal(stat.percentiles[0]), second: decimal(stat.percentiles[1]))
  end

  def driving_group
    Group.new(key: "driving", title: t(".driving_group"), rows: [
      row("four_hours", t(".four_hours")) { |card, set| rule_figure(card.rest_windows(set).rule(:four_hours)) },
      row("six_hours", t(".six_hours")) { |card, set| rule_figure(card.rest_windows(set).rule(:six_hours)) }
    ])
  end

  def rule_figure(rule)
    return NONE if rule.n_windows.zero?

    t(".rule_figure", share: share(rule.flagged_share), flagged: rule.n_flagged, windows: rule.n_windows)
  end

  def schedule_group
    Group.new(key: "schedule", title: t(".schedule_group"), rows: [
      row("peak_headway", t(".peak_headway")) { |card, set| peak_headway(card.peak_periods(set)) },
      row("peak_departures", t(".peak_departures")) { |card, set| per_peak(card.peak_periods(set)) { departures(it) } },
      row("peak_road", t(".peak_road")) { |card, set| per_peak(card.peak_periods(set)) { road(it) } }
    ])
  end

  def peak_headway(periods)
    return NONE if periods.empty?

    t(".headway", headway: span(periods.map(&:low_minutes).min, periods.map(&:high_minutes).max))
  end

  # One peak as it is; more than one, each marked as a morning or evening one.
  def per_peak(periods)
    return NONE if periods.empty?
    return yield(periods.first) if periods.one?

    periods.map { "#{peak_label(it)} #{yield(it)}" }.join("、")
  end

  def peak_label(period) = period.start_minute < RoutePage::MonthCard::NOON_MINUTE ? t(".morning") : t(".evening")

  def departures(period) = "#{decimal(period.departures_per_hour.fetch(0))}／#{decimal(period.departures_per_hour.fetch(1))}"

  def road(period) = "#{whole(period.on_road)}／#{span(period.needed_low, period.needed_high)}"

  def cycles_group
    Group.new(key: "cycles", title: t(".cycles_group"), rows: [ row("cycle", t(".cycle")) { |card, set| cycle_figure(card.cycles(set).total) } ])
  end

  def cycle_figure(total)
    round_trip, cycle = total.round_trip_percentiles.first, total.cycle_percentiles.first
    return NONE if round_trip.nil? && cycle.nil?

    t(".minutes_pair", first: decimal(round_trip), second: decimal(cycle))
  end
end
