# The day dispatch page of a configured route, as in the day-dispatch spec:
# the day lives in the browser that keeps it, so the server hands over the
# page, the route's name and the names of its ends, and the measured data of
# today's plan, which the browser lays out when it has no day to show. The
# type, p and buffer parameters only say how today's plan is laid out.
# Nothing is stored, so there is only GET.
class DayDispatchesController < ApplicationController
  def show
    @route_id = Integer(params[:route_id], exception: false)
    return render_not_found unless RoutePage.route_ids.include?(@route_id)

    # The site name bar links to this route's timetable and to this day
    # dispatch page as the current page.
    @timetable_route_id = @route_id
    @site_bar_current = :dispatch
    @plan = RoutePage::DispatchPlan.new(route_id: @route_id, type: params[:type], today: Time.zone.today)
    @percentile = RoutePage::Timetable.percentile(params[:p])
    @buffer = RoutePage::BufferTrade.minutes(params[:buffer])
    @timetable = timetable(@plan.coverage)
    # The route's name and the names of its ends: today's plan's, or else the
    # latest stored day's; none without stored days.
    named = @timetable || timetable(RoutePage::Coverage.new(route_id: @route_id).then { it if it.data? })
    @route_name = named&.route_name
    @stop_names = named&.stop_names || {}
  rescue RoutePage::Coverage::InvalidParameter
    head :bad_request
  end

  private

  def timetable(coverage)
    return unless coverage

    RoutePage::Timetable.new(route_days: coverage.route_days, ends: RoutePage.ends(@route_id), buffer: @buffer, percentile: @percentile)
  end
end
