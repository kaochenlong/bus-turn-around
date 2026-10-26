# frozen_string_literal: true

# Today's plan on the day dispatch page, as in the day-dispatch spec: hidden
# until the browser finds no day to show. The server writes the plan's basis
# (the covered days and their day type), the day type, percentile and rest
# controls in one GET form back to this page, and the words; the browser lays
# the plan out from the data the page embeds, as the timetable page lays out
# its sheets before any edit, fills in how many vehicles and departures it
# makes, and starts the day from it. Without stored days of the day type
# there is no plan: one line says so, and the form keeps the percentile and
# the rest for another day type.
class DayStartComponent < ApplicationComponent
  DAY_TYPES = RoutePage::DispatchPlan::DAY_TYPES
  BUTTON_CLASSES = DayDispatchComponent::BUTTON_CLASSES
  PRIMARY_BUTTON_CLASSES = DayDispatchComponent::PRIMARY_BUTTON_CLASSES
  FIELD_CLASSES = DayDispatchComponent::FIELD_CLASSES

  # route_name: nil without stored days; timetable: today's plan, nil without
  # stored days of the day type; percentile and buffer: the values the
  # controls start from.
  def initialize(route_id:, route_name:, day_type:, timetable:, percentile:, buffer:)
    @route_id = route_id
    @route_name = route_name
    @day_type = day_type
    @timetable = timetable
    @percentile = percentile
    @buffer = buffer
  end

  attr_reader :route_name, :day_type, :timetable, :percentile, :buffer

  # This page, where the form goes when the day type changes.
  def dispatch_path = helpers.route_dispatch_path(@route_id)

  def percentiles = RoutePage::PlannedRunTimes::PERCENTILES

  def buffer_range = RoutePage::BufferTrade::MINUTES_RANGE

  def covered_days = timetable.covered.map(&:day)

  # What the plan is laid out from: the covered days and their day type.
  def basis
    days = covered_days
    type = day_type_label(day_type)
    return t(".basis_one", day: day_label(days.first), day_type: type) if days.one?

    t(".basis_range", first: day_label(days.first), last: day_label(days.last), day_type: type, count: days.size)
  end

  # How many vehicles and departures from each end the plan makes, the numbers
  # left for the browser; an end is named by its first stop, or by its
  # direction when none was stored.
  def summary
    t(".summary_html", vehicles: figure_slot("vehicles"), departures_0: figure_slot("departures-0"), departures_1: figure_slot("departures-1"),
                       end_0: end_name(0), end_1: end_name(1))
  end

  # The words the browser fills with a kept day's date, and how the site
  # writes a day with its weekday.
  def labels_json
    labels = t(".labels").deep_transform_keys { it.to_s.camelize(:lower) }
    labels.merge("dayLabel" => RoutePage::Format::DAY_LABEL, "weekdays" => RoutePage::Format::WEEKDAYS).to_json
  end

  private

  def end_name(go_back) = timetable.stop_names[go_back] || t("directions.#{go_back}")

  def figure_slot(name) = tag.b("", data: { slot: name }, class: "font-route-figure text-lead font-bold text-slate-900")
end
