module RoutePage
  # How the route page writes minutes, shares and days. The components use it
  # through ApplicationComponent and the share text uses it directly, so a
  # number reads the same in the tables, the key numbers and the share text.
  module Format
    WEEKDAYS = %w[日 一 二 三 四 五 六].freeze
    # A day with its weekday; the timetable page's script writes days the
    # same way from this.
    DAY_LABEL = "%{date}（%{weekday}）"
    NONE = "—"

    module_function

    # A day with its weekday, as in 2026-10-19（一）.
    def day_label(day) = format(DAY_LABEL, date: day.iso8601, weekday: WEEKDAYS.fetch(day.wday))

    # Minutes to one decimal, or a dash without a value.
    def minutes(value) = value.nil? ? NONE : format("%.1f", value)

    # A share as a percentage to one decimal, or a dash without a value.
    def share(value) = value.nil? ? NONE : format("%.1f%%", value * 100)

    # A share as a whole percentage, or a dash without a value.
    def whole_share(value) = value.nil? ? NONE : format("%d%%", (value * 100).round)

    # A minute of the day as a clock; the end of the day is 24:00.
    def clock(minute) = format("%02d:%02d", minute / 60, minute % 60)

    # A range of whole numbers, one number when both ends are the same, or a dash
    # when either end is missing.
    def span(low, high)
      return NONE if low.nil? || high.nil?

      low == high ? low.to_s : "#{low}–#{high}"
    end
  end
end
