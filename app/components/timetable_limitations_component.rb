# frozen_string_literal: true

# What the timetable can and cannot tell, listed under the sheets and
# printed with them: a sheet is a vehicle and not a driver, the planned run
# times are measured percentiles, the hold at a pass-through end is not rest,
# a negative stop means the trips do not connect, trips missing a terminal are
# left out of run times, and the default departures are the measured average.
class TimetableLimitationsComponent < ApplicationComponent
  def items = t(".items")
end
