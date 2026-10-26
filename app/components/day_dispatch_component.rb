# frozen_string_literal: true

# The day dispatch view, as in the day-dispatch spec: hidden until the
# browser shows a day in it. It holds the header with the plan's basis and
# the day's figures, the place of the selected trip's actions, and the
# timeline of the day-dispatch-timeline spec as its main view, which ends
# every vehicle's lane with its rest in the tightest four hours, with a panel
# below it: one control per end and the departures from the selected end,
# beside them the vehicles standing at that end and due at it, the form that
# records a vehicle back there, and the change log. The server writes the
# markup, the wording and the route's name and ends; the day itself lives in
# the browser, which fills in the rest from the templates here and the words
# in data-labels.
class DayDispatchComponent < ApplicationComponent
  # The rest window of the vehicles' figures, the sheets' own.
  WINDOW_HOURS = TimetableSheetComponent::WINDOW_HOURS
  CARD_CLASSES = "flex min-w-0 flex-col gap-2.5 rounded-lg border border-slate-200 bg-white p-3.5"
  BUTTON_CLASSES = "min-h-10 rounded-md border border-slate-300 bg-white px-3.5 text-label text-slate-900 select-none hover:border-slate-400 " \
                   "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700"
  PRIMARY_BUTTON_CLASSES = "min-h-10 rounded-md border border-teal-700 bg-teal-700 px-4 text-label font-semibold text-white select-none hover:bg-teal-800 " \
                           "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700"
  # The selected end's control reads as pressed: dark, white text, bold.
  END_BUTTON_CLASSES = "#{BUTTON_CLASSES} aria-pressed:border-slate-900 aria-pressed:bg-slate-900 aria-pressed:font-semibold aria-pressed:text-white".freeze
  FIELD_CLASSES = "min-h-10 rounded-md border border-slate-300 bg-white px-2 text-label text-slate-900 aria-[invalid=true]:border-red-600 " \
                  "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700"
  # A header cell of the departures, held at the top of their frame with its
  # line drawn as a shadow, which a collapsed border would leave behind.
  HEADER_CLASSES = "sticky top-0 z-1 h-8 bg-white shadow-[inset_0_-1px_0_var(--color-slate-300)]"

  # An end of the route, named by the direction that departs from it: what
  # its control says, and its name in the view's sentences.
  End = Data.define(:go_back, :label, :name)

  # route_name: nil without stored days; stop_names: the first stop of each
  # direction on the latest stored day, by direction, missing ones left out.
  def initialize(route_id:, route_name:, stop_names:)
    @route_id = route_id
    @route_name = route_name
    @stop_names = stop_names
  end

  attr_reader :route_id, :route_name

  # The route's timetable page, where the plan's timetable leads; the browser
  # puts the shown day's basis into it.
  def timetable_path = helpers.route_timetable_path(route_id)

  # The two ends, each with the first stop and the name of the direction that
  # departs from it; with the direction only when no stop was stored for it.
  def ends
    RoutePage::Ends::DIRECTIONS.map do |go_back|
      direction = t("directions.#{go_back}")
      stop = @stop_names[go_back]
      End.new(go_back:, label: stop ? t(".end", stop:, direction:) : t(".end_without_stop", direction:), name: stop || direction)
    end
  end

  # The words of the selected trip's actions on the timeline, the panel's own:
  # giving the departure to another vehicle is the vehicle column's word.
  def actions = { vehicle: t(".columns.vehicle"), departure: t(".actions.departure"), deselect: t(".actions.deselect") }

  # The words the browser writes with the day's values, %{…} left for it to
  # fill; how the site writes a day with its weekday and names a day type;
  # and the words for times the sheets share.
  def labels_json
    labels = t(".labels").deep_transform_keys { it.to_s.camelize(:lower) }
    labels.merge("creditShorter" => t(".labels.credit_shorter", hours: WINDOW_HOURS), "creditPlannedShorter" => t(".labels.credit_planned_shorter", hours: WINDOW_HOURS),
                 "none" => NONE, "dayLabel" => RoutePage::Format::DAY_LABEL,
                 "weekdays" => RoutePage::Format::WEEKDAYS, "dayTypes" => DAY_TAG_COLORS.keys.index_with { day_type_label(it) },
                 "nextDay" => t("times.next_day", time: "%{time}"), "acceptedWritings" => t("times.accepted_writings"),
                 "rejectedTyped" => t("times.rejected_typed", typed: "%{typed}", writings: t("times.accepted_writings"))).to_json
  end
end
