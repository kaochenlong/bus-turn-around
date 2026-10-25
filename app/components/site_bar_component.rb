# frozen_string_literal: true

# The site name at the top of every page, as a link to the home page, and a
# link to the article that introduces the site, rendered by the layout before
# the page. On a route page and on its timetable page there is also a
# link to that route's timetable, marked as the current page on the timetable page
# itself. It carries no data-section, so the block order of every page stays
# the same.
class SiteBarComponent < ApplicationComponent
  # The author's article on why and how the site was made. Like the site's
  # other links that leave it, it opens in the same tab.
  ABOUT_URL = "https://kaochenlong.com/bus-turn-around"

  # timetable_route_id: the route whose timetable page gets a link, nil on pages that
  # belong to no route; timetable_page: whether this is that timetable page.
  def initialize(timetable_route_id: nil, timetable_page: false)
    @timetable_route_id = timetable_route_id
    @timetable_page = timetable_page
  end

  def timetable_link? = !@timetable_route_id.nil?

  def timetable_path = helpers.route_timetable_path(@timetable_route_id)

  def timetable_current = ("page" if @timetable_page)
end
