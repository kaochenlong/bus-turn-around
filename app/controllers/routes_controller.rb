# The route page of one configured route, read from the derived tables.
class RoutesController < ApplicationController
  def show
    route_id = Integer(params[:route_id], exception: false)
    return head :not_found unless RoutePage.route_ids.include?(route_id)

    @ends = RoutePage.ends(route_id)
    @buffer_minutes = RoutePage::BufferTrade.minutes(params[:buffer])
    @coverage = RoutePage::Coverage.new(route_id:, day: params[:day], range: params[:range])
  rescue RoutePage::Coverage::InvalidParameter
    head :bad_request
  end
end
