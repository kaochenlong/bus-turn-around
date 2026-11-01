# frozen_string_literal: true

# The routes that have a route page, each with its latest stored day and a
# link to the page, or marked as having no data yet. Its one metric: on that
# day, each stopping end's share of layovers under 15 minutes with their count,
# written as the route page's summary writes it, so the card and the page it
# links to read the same. Above the cards, a district filter: a select of the
# districts some listed route qualifies in, one of them selected on load, which
# the browser applies by hiding cards (app/frontend/route_list/district_filter.js);
# the server lists every card and the options with the default district
# already applied, so the page shows that district without JavaScript too.
class RouteListComponent < ApplicationComponent
  # The same look as the route page's selects (BufferTradeComponent).
  SELECT_CLASSES = "min-h-11 rounded-lg border border-slate-300 bg-white px-2.5 text-table text-slate-900 select-none " \
                   "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700"

  def initialize(route_list:)
    @route_list = route_list
  end

  def entries = @route_list.entries

  # Whether any listed route's latest day was loaded with districts; without
  # one, a sentence takes the place of the filter.
  def districts? = entries.any?(&:districts_known)

  def district_options = @route_list.district_options

  def default_district = @route_list.default_district

  # Whether the entry's card shows under the default district, before any
  # script runs.
  def shown_by_default?(entry) = entry.districts.include?(default_district)

  # The count line as the server writes it for the default district; the
  # browser rewrites it from the templates when the selection changes.
  def default_count_text
    text = t(".district_count", district: default_district, count: entries.count { shown_by_default?(it) })
    n_unknown.positive? ? text + t(".district_unknown", count: n_unknown) : text
  end

  def n_unknown = @route_list.n_unknown

  # The count line's wording, with {district} and {count} for the browser to
  # fill in, since the line is written when a district is selected.
  def count_template = t(".district_count", district: "{district}", count: "{count}")

  def unknown_template = t(".district_unknown", count: "{count}")

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
