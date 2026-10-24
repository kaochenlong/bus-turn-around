# frozen_string_literal: true

# The routes that have a route page, each with its latest stored day and a
# link to the page, or marked as having no data yet. Coverage only: no metric.
class RouteListComponent < ApplicationComponent
  def initialize(route_list:)
    @route_list = route_list
  end

  def entries = @route_list.entries

  # Every route Id the entry's page counts as one route, the page route
  # first, joined by 「・」; the link and the data attributes keep the page
  # route alone.
  def route_ids_text(route_id) = RoutePage.member_route_ids(route_id).join("・")

  def route_page_path(route_id) = helpers.route_path(route_id)
end
