# frozen_string_literal: true

# Run times per direction and departure hour, with the trips left out.
class RunTimeTableComponent < ApplicationComponent
  def initialize(run_times:)
    @run_times = run_times
  end

  def directions = RoutePage::RunTimes::DIRECTIONS

  def rows_for(go_back) = rows.select { it.go_back == go_back }

  def excluded = @excluded ||= @run_times.excluded

  def hour_label(hour) = format("%02d", hour)

  def minutes(value) = format("%.1f", value)

  private

  def rows = @rows ||= @run_times.rows
end
