# The route page of one configured route, read from the derived tables.
class RoutesController < ApplicationController
  def show
    route_id = Integer(params[:route_id], exception: false)
    return render_not_found unless RoutePage.route_ids.include?(route_id)

    # The site name bar links to this route's timetable.
    @timetable_route_id = route_id
    @ends = RoutePage.ends(route_id)
    @buffer_minutes = RoutePage::BufferTrade.minutes(params[:buffer])
    @buffer_late = RoutePage::BufferTrade.late(params[:late])
    @buffer_hours = RoutePage::BufferTrade.hour_range(params[:from], params[:to])
    @buffer_end = RoutePage::BufferTrade.end_go_back(params[:end], ends: @ends)
    @coverage = RoutePage::Coverage.new(route_id:, day: params[:day], range: params[:range])
  rescue RoutePage::Coverage::InvalidParameter
    head :bad_request
  end
end
