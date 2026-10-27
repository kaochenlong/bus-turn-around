# frozen_string_literal: true

# The site name at the top of every page, as a link to the home page, and
# links to the site's source on GitHub and to the article that introduces
# the site, rendered by the layout before the page. On a route page, its
# timetable page and its day dispatch page there are also links to that
# route's timetable and day dispatch, right beside the site name, the one of
# the page itself marked as the current page. The source and article links
# sit at the right end and open in a new tab: the source link, an icon, from
# 640 px up only, the article link showing the first part of its text only.
# It carries no data-section, so the block order of every page stays the
# same.
class SiteBarComponent < ApplicationComponent
  # The author's article on why and how the site was made. Unlike the site's
  # other links that leave it, it opens in a new tab.
  ABOUT_URL = "https://kaochenlong.com/bus-turn-around"

  # The site's source, the analysis SQL included, on GitHub; it opens in a
  # new tab too.
  REPOSITORY_URL = "https://github.com/kaochenlong/bus-turn-around"

  # The words that tell assistive technology the two links above open in a
  # new tab, which both name as their description.
  NEW_TAB_ID = "site-bar-new-tab"

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
