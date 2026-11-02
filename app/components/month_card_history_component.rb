# frozen_string_literal: true

# What only keeping the data makes possible, as in the monthly-card spec: the months
# so far recomputed with today's definitions, what changed in the static snapshots,
# and every day of the month, a missing one with its reason.
class MonthCardHistoryComponent < MonthCardComponent
  # A row of the months table for one month and stopping end. first says whether it
  # opens the month, whose own cells span its ends.
  MonthEnd = Data.define(:row, :figures, :first, :span)
  # The office calendar's own word, in its data whatever the page's language.
  SUBSTITUTE_HOLIDAY_NOTE = "補假"

  def first_card? = trend.first_card?

  def two_ends? = month_card.stop_go_backs.size > 1

  def stop_go_backs = month_card.stop_go_backs

  # One entry per stopping end of each month, and one for a month with none.
  def month_ends
    trend.rows.flat_map do |row|
      ends = row.ends.presence || [ nil ]
      ends.each_with_index.map { |figures, index| MonthEnd.new(row:, figures:, first: index.zero?, span: ends.size) }
    end
  end

  def month_label(row)
    label = row.month.strftime("%Y-%m")
    row.partial ? t(".partial_month", month: label) : label
  end

  def differing_months = trend.differing_months.map { t(".month_name", year: it.year, month: it.month) }

  def on_road_text(row) = row.morning_on_road ? t(".vehicles", count: row.morning_on_road) : NONE

  def p10_text(figures) = figures&.p10 ? t(".minutes", minutes: decimal(figures.p10)) : NONE

  def snapshot_changes = month_card.snapshot_changes

  def snapshot_changes? = snapshot_changes.n_days.positive?

  def unchanged_sentence
    days = loaded_days
    t(".unchanged", first: days.first.iso8601, last: days.last.iso8601, count: snapshot_changes.n_days)
  end

  def change_text(change) = t(".change", day: short_day(change.day), kinds: change.kinds.map { t(".kinds.#{it}") }.join("、"))

  def shape_day = snapshot_changes.shape_updated_at&.to_date&.iso8601

  def day_rows = month_card.days.rows

  def day_label(day) = "#{short_day(day)}（#{WEEKDAYS.fetch(day.wday)}）"

  def day_type_text(row)
    name = day_type_label(row.day_type)
    row.day_note&.include?(SUBSTITUTE_HOLIDAY_NOTE) ? t(".day_type_noted", name:, note: row.day_note) : name
  end

  # What a missing day's reason spans: every column after the date.
  def figure_columns = 6 + (stop_go_backs.size * 2)

  def percent(share) = share.nil? ? 0 : (share * 100).round

  def end_name(go_back) = month_card.first_and_last_stop(go_back).last || NONE

  private

  def trend = month_card.trend

  def loaded_days = day_rows.select(&:day_type).map(&:day)

  def short_day(day) = day.strftime("%m-%d")
end
