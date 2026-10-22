class ApplicationComponent < ViewComponent::Base
  WEEKDAYS = %w[日 一 二 三 四 五 六].freeze

  # A day with its weekday, as in 2026-10-19（一）.
  def day_label(day) = "#{day.iso8601}（#{WEEKDAYS.fetch(day.wday)}）"
end
