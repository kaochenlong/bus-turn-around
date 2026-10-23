class ApplicationComponent < ViewComponent::Base
  WEEKDAYS = %w[日 一 二 三 四 五 六].freeze

  # A day with its weekday, as in 2026-10-19（一）.
  def day_label(day) = "#{day.iso8601}（#{WEEKDAYS.fetch(day.wday)}）"

  # The name of a day type of route_days (weekday or holiday) in the current
  # locale. A missing day type, or one without a name, raises instead of
  # showing a placeholder; a blank one would otherwise look up the whole
  # day_types table.
  def day_type_label(day_type)
    raise ArgumentError, "沒有日型別" if day_type.blank?

    I18n.t("day_types.#{day_type}", raise: true)
  end

  # The nature of a route end (buses stop there or drive straight on) as a
  # tag. Both natures share one look, so neither reads as better.
  def nature_tag(text)
    tag.span(text, class: "inline-block rounded-md border border-slate-300 bg-slate-50 px-2 text-label leading-5.5 font-medium whitespace-nowrap " \
                          "text-slate-700 sm:px-2.25")
  end
end
