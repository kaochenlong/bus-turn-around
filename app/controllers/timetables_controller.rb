# The timetable page of a configured route, as in the timetable spec: the
# server reads the derived tables and embeds the measured data; the browser
# lays the timetable out and recomputes the dispatcher's edits. Nothing is
# stored, so there is only GET.
class TimetablesController < ApplicationController
  def show
    route_id = Integer(params[:route_id], exception: false)
    return render_not_found unless RoutePage.route_ids.include?(route_id)

    # The site name bar links to this timetable page as the current page.
    @timetable_route_id = route_id
    @timetable_page = true
    @coverage = RoutePage::Coverage.new(route_id:, day: params[:day], range: params[:range])
    @buffer = RoutePage::BufferTrade.minutes(params[:buffer])
    @percentile = RoutePage::Timetable.percentile(params[:p])
    return unless @coverage.data?

    @timetable = RoutePage::Timetable.new(route_days: @coverage.route_days, ends: RoutePage.ends(route_id), buffer: @buffer, percentile: @percentile)
  rescue RoutePage::Coverage::InvalidParameter
    head :bad_request
  end
end
