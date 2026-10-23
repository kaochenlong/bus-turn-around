# frozen_string_literal: true

# Run times per direction and departure hour, with the trips left out. From
# 640 px wide each row also has a bar from its p50 to its p95 with a mark at
# its p85, on one scale shared by both directions, so their lengths compare.
class RunTimeTableComponent < ApplicationComponent
  SCALE_STEP = 10

  # The minutes the bars span, and where a value sits on them in percent.
  Scale = Data.define(:from, :to) do
    def mid = (from + to) / 2

    def percent(minutes) = length_percent(minutes - from)

    def length_percent(minutes) = (minutes * 100.0 / (to - from)).round(1)
  end

  def initialize(run_times:)
    @run_times = run_times
  end

  def directions = RoutePage::RunTimes::DIRECTIONS

  def rows_for(go_back) = rows.select { it.go_back == go_back }

  def excluded = @excluded ||= @run_times.excluded

  def hour_label(hour) = format("%02d", hour)

  def minutes(value) = format("%.1f", value)

  # From the smallest p50 of both directions rounded down to a multiple of
  # SCALE_STEP to the largest p95 rounded up, at least SCALE_STEP long; a
  # direction without rows takes no part. Nil when neither has a row.
  def scale
    return @scale if defined?(@scale)
    return @scale = nil if rows.empty?

    from = floor_step(rows.map { it.percentiles.first }.min)
    to = ceil_step(rows.map { it.percentiles.last }.max)
    @scale = Scale.new(from:, to: [ to, from + SCALE_STEP ].max)
  end

  def range_style(p50, p95) = "left: #{scale.percent(p50)}%; width: #{scale.length_percent(p95 - p50)}%"

  def mark_style(p85) = "left: #{scale.percent(p85)}%"

  private

  def rows = @rows ||= @run_times.rows

  def floor_step(value) = (value / SCALE_STEP).floor * SCALE_STEP

  def ceil_step(value) = (value / SCALE_STEP).ceil * SCALE_STEP
end
