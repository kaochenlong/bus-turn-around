# frozen_string_literal: true

# The skeleton of a vehicle's sheet, as two templates the browser clones and
# fills: one sheet per vehicle (車次), laid out like the paper trip sheet
# (行車憑單) a dispatcher fills in, with the paper's columns in the paper's
# order, one row per round trip, blank cells for the driver number, name,
# dispatcher and mileage, a control that adds a row, and the rest in the
# tightest four hours if one person drove the whole sheet. On screen each row
# starts with its delete control and the blank cells are not shown: they stay
# empty there and only take room. The markup and the wording live here; the
# browser only fills values, and reads the few words it needs from the sheet
# template's data attributes. Printed, each sheet is a page of its own with
# the paper's heading (company and depot blanks, the route, the run number, a
# blank plate, date blanks), the paper's columns with the blank ones, and
# ruled rows padded to the paper's count.
class TimetableSheetComponent < ApplicationComponent
  # The columns in the paper's order; the two stops are ours, right after the
  # times they belong to.
  COLUMNS = %w[driver_number driver_name departure origin dispatcher arrival stop return_departure accumulated_mileage return_arrival next_stop trip_mileage dispatcher_again].freeze
  # Filled in by hand: printed as blank cells, not shown on screen.
  BLANK_COLUMNS = %w[driver_number driver_name dispatcher accumulated_mileage trip_mileage dispatcher_again].freeze
  # A printed sheet has at least this many rows, blank ones added after the
  # trips, like the ruled paper.
  MIN_ROWS = 14
  # The rest window the sheet's statement is about: the same 240 minutes as
  # app/frontend/timetable/rest_windows.js, which the component spec checks.
  WINDOW_HOURS = 4
  # A time field; red-bordered while its typed time is the one rejected, and
  # amber in a departure cell its trip was pushed out of (data-pushed), the
  # colours of the site's notices.
  FIELD_CLASSES = "w-18 rounded border border-slate-300 bg-white px-1.5 py-1 text-center text-table text-slate-900 aria-[invalid=true]:border-red-600 " \
                  "in-data-pushed:border-amber-300 in-data-pushed:bg-amber-50 " \
                  "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700 print:hidden"
  BUTTON_CLASSES = "min-h-9 rounded-md border border-slate-300 bg-white px-2.5 text-note text-slate-700 select-none hover:border-slate-400 hover:text-slate-900 " \
                   "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700"
  # A button with only an icon, one on every row: as large a target as
  # BUTTON_CLASSES, without its border so a column of them stays quiet.
  ICON_BUTTON_CLASSES = "inline-flex size-9 items-center justify-center rounded-md text-slate-500 select-none hover:bg-slate-100 hover:text-slate-900 " \
                        "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700"

  def initialize(timetable:, coverage:)
    @timetable = timetable
    @coverage = coverage
  end

  def small_sample = RoutePage::RunTimes::SMALL_SAMPLE

  def blank?(column) = BLANK_COLUMNS.include?(column)

  # The printed form's title: blanks for the company and the depot, then the route.
  def form_title = t(".form.title", route: @timetable.route_name)

  # What the sheet was laid out from: the covered day or days with their day
  # type, and the percentile and rest in use, which the browser fills in since
  # they change on the page.
  def print_header = t(".print_header", days: covered_days_text, percentile: "%{percentile}", buffer: "%{buffer}")

  private

  def covered_days_text
    days = @timetable.covered.map(&:day)
    day_type = day_type_label(@coverage.day_type)
    return t(".days_one", day: day_label(days.last), day_type:) if days.size == 1

    t(".days_range", first: day_label(days.first), last: day_label(days.last), day_type:, count: days.size)
  end
end
