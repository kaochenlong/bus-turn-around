# frozen_string_literal: true

# The routes that have a route page, each with its latest stored day and a
# link to the page, or marked as having no data yet. Its one metric: on that
# day, each stopping end's share of layovers under 15 minutes with their count,
# written as the route page's summary writes it, so the card and the page it
# links to read the same.
class RouteListComponent < ApplicationComponent
  def initialize(route_list:)
    @route_list = route_list
  end

  def entries = @route_list.entries

  # Without a stopping end, a statement takes the place of the figure lines,
  # as on the summary.
  def stopping_end?(route_id) = RoutePage.ends(route_id).stopping_go_backs.any?

  def short_minutes = RoutePage::LayoverStats::SHORT_MINUTES

  # Every route Id the entry's page counts as one route, the page route
  # first, joined by 「・」; the link and the data attributes keep the page
  # route alone.
  def route_ids_text(route_id) = RoutePage.member_route_ids(route_id).join("・")

  def route_page_path(route_id) = helpers.route_path(route_id)
end
