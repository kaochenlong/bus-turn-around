# frozen_string_literal: true

# The cost of a buffer at every layover at the stopping ends, with a slider
# that reloads only this block. The layovers at a pass-through end are
# reported apart, as not counted. Only numbers: nothing is marked as meeting a
# rule or a target.
class BufferTradeComponent < ApplicationComponent
  # The grid column of each bound from 640 px wide, where every bound is a
  # column; written out whole so Tailwind finds the classes.
  COLUMNS = { "lower" => "sm:col-start-1", "upper" => "sm:col-start-2" }.freeze
  # The curve's drawing area in the SVG's user units: the minutes to hold run
  # from CHART_LEFT in steps of CHART_STEP, and the vehicle-hours from 0 at
  # CHART_BOTTOM up CHART_HEIGHT to the top of the vertical axis.
  CHART_LEFT = 36
  CHART_STEP = 6.8
  CHART_BOTTOM = 156
  CHART_HEIGHT = 144
  CHART_TICKS = [ 0, 10, 20, 30, 40 ].freeze

  def initialize(buffer_trade:, coverage:)
    @buffer_trade = buffer_trade
    @coverage = coverage
  end

  def minutes_range = RoutePage::BufferTrade::MINUTES_RANGE

  def late_range = RoutePage::BufferTrade::LATE_RANGE

  # The first hours offered: every hour below the selected last hour, so the
  # form cannot send a first hour that is not below the last.
  def first_hours = RoutePage::BufferTrade::FIRST_HOURS.begin...@buffer_trade.hour_range.end

  # The last hours offered: every hour above the selected first hour.
  def last_hours = (@buffer_trade.hour_range.begin + 1)..RoutePage::BufferTrade::LAST_HOURS.end

  # The end is a choice only when both ends of the route are stopping ends.
  def end_choice? = @buffer_trade.ends.stopping_go_backs.size > 1

  # Each stopping end's direction and the name of its last stop.
  def end_options = @buffer_trade.ends.stopping_go_backs.map { [ it, @buffer_trade.stopping_end_names.fetch(it, it.to_s) ] }

  # Differs on every response, so a test can tell a reloaded block from one
  # whose figures were only replaced in the browser.
  def rendered_mark = @rendered_mark ||= SecureRandom.hex(8)

  def layovers? = @buffer_trade.n_layovers.positive?

  # Hours or an end leave the base empty although layovers were measured at
  # the stopping ends over all hours.
  def filtered_out? = !layovers? && @buffer_trade.filtered? && @buffer_trade.n_stopping_layovers.positive?

  def late? = @buffer_trade.late.positive?

  # The selected hours and end as the block names them; nil when neither is
  # selected.
  def condition
    parts = []
    parts << t(".condition_hours", from: @buffer_trade.hour_range.begin, to: @buffer_trade.hour_range.end) if @buffer_trade.hour_range != RoutePage::BufferTrade::ALL_HOURS
    parts << t(".condition_end", stop: @buffer_trade.stopping_end_names.fetch(@buffer_trade.end_go_back, @buffer_trade.end_go_back.to_s)) if @buffer_trade.end_go_back
    parts.join(t(".condition_separator")).presence
  end

  # A number the browser replaces when a slider moves.
  def value_span(value, name) = tag.span(value, "data-value": name)

  # A bound's name, with the minutes to hold it adds up to.
  def bound_name(bound) = t(".#{bound}_html", hold: value_span(@buffer_trade.hold, "hold"))

  def next_minutes = { "lower" => @buffer_trade.next_minute.lower, "upper" => @buffer_trade.next_minute.upper }

  def curve = @buffer_trade.curve

  def chart_x(hold) = (CHART_LEFT + (hold * CHART_STEP)).round(1)

  def chart_y(vehicle_hours) = (CHART_BOTTOM - (vehicle_hours / chart_top * CHART_HEIGHT)).round(1)

  # The top of the vertical axis: the upper bound at the last point, before
  # rounding.
  def chart_top = curve.last.exact.upper

  def chart_right = chart_x(curve.last.hold)

  def line_points(bound) = curve.map { "#{chart_x(it.hold)},#{chart_y(it.exact.public_send(bound))}" }.join(" ")

  # Along the upper line and back along the lower one.
  def band_points
    upper = curve.map { "#{chart_x(it.hold)},#{chart_y(it.exact.upper)}" }
    lower = curve.reverse.map { "#{chart_x(it.hold)},#{chart_y(it.exact.lower)}" }
    (upper + lower).join(" ")
  end

  # Where a point's marker stands: the shared x and the y on each line.
  def marker(point) = { x: chart_x(point.hold), lower_y: chart_y(point.exact.lower), upper_y: chart_y(point.exact.upper) }

  def chart_aria = t(".chart_aria", lower: decimal(curve.last.vehicle_hours.lower), upper: decimal(curve.last.vehicle_hours.upper))

  # The curve for the browser: every figure the block shows, as the block
  # formats it, and the marker of every point, so that moving a slider only
  # copies strings and coordinates.
  def curve_json = ERB::Util.json_escape(curve_data.to_json)

  def curve_data = { hours: curve.first.hourly.map { hour_span(it.hour) }, points: curve.map { point_data(it) } }

  def point_data(point)
    { hold: point.hold, vehicle_hours: bound_strings(point.vehicle_hours), next_minute: bound_strings(point.next_minute),
      achieved: share(point.achieved_share), peak: [ point.peak.lower, point.peak.upper ].map { [ hour_span(it.hour), decimal(it.vehicles) ] },
      hourly: point.hourly.map { [ decimal(it.lower), decimal(it.upper) ] }, marker: marker(point) }
  end

  def bound_strings(bound) = [ decimal(bound.lower), decimal(bound.upper) ]

  def pass_through? = @buffer_trade.ends.pass_through?

  def share(value) = format("%.1f%%", value * 100)

  def decimal(value) = format("%.1f", value)

  def hour_span(hour) = format("%<from>02d:00–%<to>02d:00", from: hour, to: hour + 1)

  def vehicle_hours = { "lower" => @buffer_trade.vehicle_hours.lower, "upper" => @buffer_trade.vehicle_hours.upper }

  def peaks = { "lower" => @buffer_trade.peak.lower, "upper" => @buffer_trade.peak.upper }
end
