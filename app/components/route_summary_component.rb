# frozen_string_literal: true

# The trip counts over the covered days.
class RouteSummaryComponent < ApplicationComponent
  def initialize(summary:)
    @summary = summary
  end
end
