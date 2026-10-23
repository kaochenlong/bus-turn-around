# frozen_string_literal: true

# What the numbers can and cannot tell: the route page's own list, or the four
# general limitations on the home page.
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

  def initialize(scope: :route)
    @keys = KEYS.fetch(scope) { raise ArgumentError, "scope must be one of #{KEYS.keys.inspect}, got #{scope.inspect}" }
    @styles = STYLES.fetch(scope)
  end

  def title = t(".#{@keys.fetch(:title)}")

  def items = t(".#{@keys.fetch(:items)}")
end
