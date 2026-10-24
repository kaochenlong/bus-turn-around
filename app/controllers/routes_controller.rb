# The route page of one configured route, read from the derived tables.
class RoutesController < ApplicationController
  def show
    route_id = Integer(params[:route_id], exception: false)
    # The page the server sends for an unknown address, rendered rather than
    # raised so that development and tests get it too. The file is a whole page:
    # render file: would otherwise wrap it in the layout.
    return render file: Rails.public_path.join("404.html"), status: :not_found, layout: false unless RoutePage.route_ids.include?(route_id)

    @ends = RoutePage.ends(route_id)
    @buffer_minutes = RoutePage::BufferTrade.minutes(params[:buffer])
    @coverage = RoutePage::Coverage.new(route_id:, day: params[:day], range: params[:range])
  rescue RoutePage::Coverage::InvalidParameter
    head :bad_request
  end
end
