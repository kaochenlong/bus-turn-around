# frozen_string_literal: true

# How much of the route runs near the MRT, and how many riders are on board
# along those stretches. Only numbers: no share is compared with a review
# threshold, because this definition is not the official one.
class MrtOverlapComponent < ApplicationComponent
  BANDS = %w[morning_peak daytime evening_peak other].freeze

  def initialize(mrt_overlap:)
    @mrt_overlap = mrt_overlap
  end

  def thresholds = RoutePage::MrtOverlap::THRESHOLDS

  def stretch_threshold = RoutePage::MrtOverlap::STRETCH_THRESHOLD

  def directions = @directions ||= @mrt_overlap.directions

  def stretches = @stretches ||= @mrt_overlap.stretches

  def share(value) = format("%.1f%%", value * 100)

  def decimal(value) = format("%.1f", value)

  def stretch_key(stretch) = "#{stretch.go_back}:#{stretch.first_seq}-#{stretch.last_seq}"

  def sorted_loads(stretch) = stretch.loads.sort_by { BANDS.index(it[:band]) || BANDS.size }
end
