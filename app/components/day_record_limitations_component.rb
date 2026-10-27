# frozen_string_literal: true

# What the printed day record can and cannot tell, on the record's last page
# before the attribution footer: the recorded arrivals and changes were typed
# in by the dispatcher and not measured, a sheet is a vehicle and not a
# driver, the planned run times are measured percentiles, and times past
# midnight are written one way on paper and another in the exported files.
class DayRecordLimitationsComponent < ApplicationComponent
  def items = t(".items")
end
