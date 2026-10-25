# frozen_string_literal: true

# The timetable checked against the measured trips: for every percentile the timetable
# offers, the share of trips that ran longer than the planned run time at that
# percentile, the share whose excess reached the rest minutes, and the median
# excess. The row of the chosen percentile is emphasized. Trips are judged one
# by one; a late trip's effect on the next departure is not followed.
class TimetableOverrunTableComponent < ApplicationComponent
  # overruns: RoutePage::TimetableOverruns rows; percentile: the one the timetable
  # uses; buffer: the rest minutes an overrun has to reach to exhaust it.
  def initialize(overruns:, percentile:, buffer:)
    @overruns = overruns
    @percentile = percentile
    @buffer = buffer
  end

  def rows = @overruns

  def selected?(row) = row.percentile == @percentile

  def buffer = @buffer
end
