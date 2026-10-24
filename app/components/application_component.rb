class ApplicationComponent < ViewComponent::Base
  WEEKDAYS = %w[日 一 二 三 四 五 六].freeze
  NONE = "—"

  # A day with its weekday, as in 2026-10-19（一）.
  def day_label(day) = "#{day.iso8601}（#{WEEKDAYS.fetch(day.wday)}）"

  # Minutes to one decimal, or a dash without a value. The tables and the key
  # numbers of the route page share this and share, so a key number reads
  # exactly like the table cell it comes from.
  def minutes(value) = value.nil? ? NONE : format("%.1f", value)

  # A share as a percentage to one decimal, or a dash without a value.
  def share(value) = value.nil? ? NONE : format("%.1f%%", value * 100)

  # The name of a day type of route_days (weekday or holiday) in the current
  # locale. A missing day type, or one without a name, raises instead of
  # showing a placeholder; a blank one would otherwise look up the whole
  # day_types table.
  def day_type_label(day_type)
    raise ArgumentError, "沒有日型別" if day_type.blank?

    I18n.t("day_types.#{day_type}", raise: true)
  end

  # The metric a route page block belongs to, above its title, named as in
  # docs/spectra/LANGUAGE.md.
  def eyebrow(text) = tag.p(text, class: "mb-1.5 text-label font-semibold tracking-[0.04em] text-teal-700")

  # The nature of a route end (buses stop there or drive straight on) as a
  # tag. Both natures share one look, so neither reads as better.
  def nature_tag(text)
    tag.span(text, class: "inline-block rounded-md border border-slate-300 bg-slate-50 px-2 text-label leading-5.5 font-medium whitespace-nowrap " \
                          "text-slate-700 sm:px-2.25")
  end

  # The words maps/base_map.js writes on every map of the route page: the
  # notes shown when a gesture is meant for the page, {key} left for the
  # script to fill, and the full screen button's.
  def base_map_labels_json
    { wheelZoom: I18n.t("maps.gestures.wheel_zoom"), twoFingers: I18n.t("maps.gestures.two_fingers"),
      fullscreen: I18n.t("maps.fullscreen.enter"), exitFullscreen: I18n.t("maps.fullscreen.exit") }.to_json
  end
end
