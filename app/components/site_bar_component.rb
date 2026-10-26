# frozen_string_literal: true

# The site name at the top of every page, as a link to the home page, and a
# link to the article that introduces the site, rendered by the layout before
# the page, the links right beside the site name. On a route page, its
# timetable page and its day dispatch page there are also links to that
# route's timetable and day dispatch, the one of the page itself marked as
# the current page. On a phone the article link shows the first part of its
# text only. It carries no data-section, so the block order of every page
# stays the same.
class SiteBarComponent < ApplicationComponent
  # The author's article on why and how the site was made. Like the site's
  # other links that leave it, it opens in the same tab.
  ABOUT_URL = "https://kaochenlong.com/bus-turn-around"

  # timetable_route_id: the route whose timetable and day dispatch pages get
  # links, nil on pages that belong to no route; current: which of the two
  # this page is, :timetable or :dispatch, nil for neither.
  def initialize(timetable_route_id: nil, current: nil)
    @timetable_route_id = timetable_route_id
    @current = current
  end

  def timetable_link? = !@timetable_route_id.nil?

  def timetable_path = helpers.route_timetable_path(@timetable_route_id)

  def day_dispatch_path = helpers.route_dispatch_path(@timetable_route_id)

  # The aria-current of the link to `page`, :timetable or :dispatch.
  def current_for(page) = ("page" if @current == page)
end
