# frozen_string_literal: true

# The timeline of the day dispatch, as in the day-dispatch-timeline spec: one
# lane per vehicle on one time axis, in a frame that scrolls with the axis and
# the mark of now held at its top, and a legend. The server writes the markup,
# the wording and the names of the route's ends; the day lives in the
# browser, which draws the lanes, the trips, the stops, the late returns, the
# vehicle changes, the selected trip's actions and what dragging shows from
# the templates here and the words in data-labels.
class DayTimelineComponent < ApplicationComponent
  # The rest window of the lanes' figures, the sheets' own.
  WINDOW_HOURS = TimetableSheetComponent::WINDOW_HOURS
  # The vehicle number, the time axis and the rest columns of the axis and of
  # every lane: narrower on a phone, where the axis scrolls sideways.
  COLUMNS = "grid-cols-[64px_minmax(0,1fr)_64px] sm:grid-cols-[104px_minmax(0,1fr)_88px]"
  # What lies over the time axis column alone: the hour lines and the line of
  # now.
  AXIS_INSETS = "left-16 right-16 sm:left-26 sm:right-22"
  VEHICLE_PADDING = "pl-1.5 sm:pl-2"
  # A swatch of the legend as large as on the canvas.
  SWATCH_CLASSES = "inline-block h-3 w-5.5 shrink-0"
  # The legend's small bus of each direction, coloured as its trips are:
  # direction 0 dark, direction 1 light, its windshield and rear window
  # shaded against its body.
  DIRECTION_BUSES = {
    0 => { body: "bg-slate-700", windshield: "bg-slate-400", rear: "bg-slate-500" },
    1 => { body: "bg-slate-300", windshield: "bg-slate-500", rear: "bg-slate-400" }
  }.freeze
  # The bus a trip is drawn as, seen from above with its front to the right:
  # its rear window, its windshield and its two mirrors sticking out 2px
  # above and below it, each shaded by the trip's direction (data-go-back).
  BUS_PARTS = [
    "absolute inset-y-1.5 left-0.5 w-0.5 rounded-[1px] group-data-[go-back=0]/trip:bg-slate-500 group-data-[go-back=1]/trip:bg-slate-400",
    "absolute inset-y-0.75 right-0.5 w-1.25 rounded-[2px_4px_4px_2px] group-data-[go-back=0]/trip:bg-slate-400 group-data-[go-back=1]/trip:bg-slate-500",
    "absolute right-2 -top-0.5 h-0.5 w-0.75 rounded-t-[1px] group-data-[go-back=0]/trip:bg-slate-700 group-data-[go-back=1]/trip:bg-slate-400",
    "absolute right-2 -bottom-0.5 h-0.5 w-0.75 rounded-b-[1px] group-data-[go-back=0]/trip:bg-slate-700 group-data-[go-back=1]/trip:bg-slate-400"
  ].freeze
  # The look of a recorded late return, the extension and its swatch.
  LATE_CLASSES = "border border-slate-600 bg-[repeating-linear-gradient(135deg,#94a3b8_0_2px,#ffffff_2px_6px)]"

  # stop_names: the first stop of each direction, by direction, missing ones
  # left out. actions: the words of the selected trip's actions, from the
  # panel's own words: vehicle, departure and deselect.
  def initialize(stop_names:, actions:)
    @stop_names = stop_names
    @actions = actions
  end

  # The two directions as the legend names them: the direction with the stop
  # it departs from and the stop it heads to when both are known, the
  # direction alone otherwise.
  def directions
    RoutePage::Ends::DIRECTIONS.map do |go_back|
      direction = t("directions.#{go_back}")
      from = @stop_names[go_back]
      to = @stop_names[1 - go_back]
      from && to ? t(".legend.direction", direction:, from:, to:) : direction
    end
  end

  def action(name) = @actions.fetch(name)

  # The parts of a trip's bus, written with nothing between them, so the text
  # of a trip's button is its departure alone.
  def bus_parts = safe_join(BUS_PARTS.map { tag.span(class: it, aria: { hidden: true }) })

  # The words the browser writes with the day's values, %{…} left for it to
  # fill, and the names of the two directions.
  def labels_json
    t(".labels").deep_transform_keys { it.to_s.camelize(:lower) }
                .merge("directions" => RoutePage::Ends::DIRECTIONS.to_h { [ it.to_s, t("directions.#{it}") ] }).to_json
  end
end
