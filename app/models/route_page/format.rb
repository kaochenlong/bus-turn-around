module RoutePage
  # How the route page writes minutes, shares and days. The components use it
  # through ApplicationComponent and the share text uses it directly, so a
  # number reads the same in the tables, the key numbers and the share text.
  module Format
    WEEKDAYS = %w[日 一 二 三 四 五 六].freeze
    NONE = "—"

    module_function

    # A day with its weekday, as in 2026-10-19（一）.
    def day_label(day) = "#{day.iso8601}（#{WEEKDAYS.fetch(day.wday)}）"

    # Minutes to one decimal, or a dash without a value.
    def minutes(value) = value.nil? ? NONE : format("%.1f", value)

    # A share as a percentage to one decimal, or a dash without a value.
    def share(value) = value.nil? ? NONE : format("%.1f%%", value * 100)
  end
end
