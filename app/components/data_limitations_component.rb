# frozen_string_literal: true

# What the numbers can and cannot tell: the route page's own list, or the four
# general limitations on the home page.
class DataLimitationsComponent < ApplicationComponent
  # The title and item keys in this component's translations, by scope.
  KEYS = {
    route: { title: "title", items: "items" },
    home: { title: "home_title", items: "home_items" }
  }.freeze

  def initialize(scope: :route)
    @keys = KEYS.fetch(scope) { raise ArgumentError, "scope must be one of #{KEYS.keys.inspect}, got #{scope.inspect}" }
  end

  def title = t(".#{@keys.fetch(:title)}")

  def items = t(".#{@keys.fetch(:items)}")
end
