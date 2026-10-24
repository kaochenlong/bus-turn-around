# frozen_string_literal: true

# What the numbers can and cannot tell: the route page's own list, or the four
# general limitations on the home page. A route page that counts member
# routes with its page route gets one more item saying which Ids it pools,
# with the trips of each Id over the covered days.
class DataLimitationsComponent < ApplicationComponent
  # The title and item keys in this component's translations, by scope.
  KEYS = {
    route: { title: "title", items: "items" },
    home: { title: "home_title", items: "home_items" }
  }.freeze

  # The classes of each scope: the route page puts the list in a card, the
  # home page keeps a rule above it.
  STYLES = {
    route: { section: "", title: "mb-3.5 text-subsection font-bold text-slate-900", list: "space-y-2.5 text-table" },
    home: { section: "mt-12 border-t border-slate-200 pt-6 text-note", title: "mb-2 font-semibold", list: "space-y-1" }
  }.freeze

  # member_trips: [route Id, trips] for the page route and its member routes
  # (RoutePage::Summary#trips_by_route); one entry or none means no member
  # routes and no extra item.
  def initialize(scope: :route, member_trips: [])
    @keys = KEYS.fetch(scope) { raise ArgumentError, "scope must be one of #{KEYS.keys.inspect}, got #{scope.inspect}" }
    @styles = STYLES.fetch(scope)
    @member_trips = member_trips
  end

  def title = t(".#{@keys.fetch(:title)}")

  def items = t(".#{@keys.fetch(:items)}")

  # The item about counting several route Ids as one route; nil without member routes.
  def member_item
    return if @member_trips.size < 2

    page_id, *member_ids = @member_trips.map(&:first)
    t(".member_item", page_id:, members: member_ids.join("、"), trip_counts: @member_trips.map { |id, count| t(".member_trips", id:, count:) }.join("、"))
  end
end
