# frozen_string_literal: true

# The routes that have a route page, each with its latest stored day and a
# link to the page, or marked as having no data yet. Coverage only: no metric.
class RouteListComponent < ApplicationComponent
  def initialize(route_list:)
    @route_list = route_list
  end

  def entries = @route_list.entries

  def route_page_path(route_id) = helpers.route_path(route_id)
end
