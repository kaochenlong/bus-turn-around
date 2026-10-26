# frozen_string_literal: true

# The top of the timetable page: the route, the covered days, the figures of
# the timetable, the print control, and the controls for the percentile, the
# rest minutes and the departures per hour. The server fills the figures it
# knows (the parameters and the measured vehicles per day); the browser fills
# the ones that follow from the layout. Changing a control lays the timetable
# out again in the browser and discards manual edits, and the page says so
# next to the controls.
class TimetableHeaderComponent < ApplicationComponent
  def initialize(timetable:, coverage:)
    @timetable = timetable
    @coverage = coverage
  end

  def covered = @timetable.covered

  # The latest covered day names the route.
  def route_day = covered.last

  # The figures that count departure cells, shown with the cells unit.
  CELL_FIGURES = %i[edited pushed].freeze

  # The figures shown: the translation key of each label, its value as the
  # server renders it (a dash where the browser fills it in) and the name the
  # browser and the tests read it by.
  def figures
    [ [ :percentile, @timetable.percentile, "percentile" ], [ :buffer, @timetable.buffer, "buffer" ], [ :vehicles_per_day, decimal(@timetable.vehicles_per_day), "vehicles-per-day" ],
      [ :vehicles, NONE, "vehicles" ], [ :departures_0, NONE, "departures-0" ], [ :departures_1, NONE, "departures-1" ], [ :edited, NONE, "edited" ], [ :pushed, NONE, "pushed" ] ]
  end

  def decimal(value) = format("%.1f", value)

  def percentiles = RoutePage::PlannedRunTimes::PERCENTILES

  def buffer_range = RoutePage::BufferTrade::MINUTES_RANGE

  def departures_range = RoutePage::Timetable::DEPARTURES_RANGE

  def hours = RoutePage::MeasuredDepartures::HOURS

  def directions = RoutePage::Ends::DIRECTIONS

  # The measured departures per hour, the controls' starting values.
  def departures(go_back, hour) = @timetable.departures.fetch(go_back).fetch(hour)

  def hour_label(hour) = format("%02d", hour)
end
