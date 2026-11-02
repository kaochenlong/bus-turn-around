# frozen_string_literal: true

# The layovers of a month, as in the monthly-card spec: both ends on weekdays and
# holidays, then for each stopping end its distribution and its share under 15
# minutes by the hour the vehicle came back. A layover at a pass-through end is not
# rest, so that end has a row and no chart.
class MonthCardLayoversComponent < MonthCardComponent
  SETS = %i[weekday holiday].freeze

  # stat is nil when the set has no figures for that end.
  Row = Data.define(:set, :go_back, :stop_name, :stat)

  # Stopping ends first, on weekdays and then on holidays.
  def rows
    SETS.flat_map do |set|
      (month_card.ends.stopping_go_backs + month_card.ends.pass_through_go_backs).map do |go_back|
        Row.new(set:, go_back:, stop_name: stop_name(go_back), stat: stat(set, go_back))
      end
    end
  end

  def set_name(set) = day_type_label(RoutePage::MonthCard::DAY_TYPES.fetch(set))

  def nature_name(go_back) = t(".natures.#{month_card.ends.nature(go_back)}")

  def pass_through? = month_card.ends.pass_through?

  # The stopping ends with a weekday layover to draw.
  def charted_go_backs = month_card.stop_go_backs.select { stat(:weekday, it)&.n_layovers&.positive? }

  def distribution_counts(go_back) = month_card.layover_distribution(:weekday).directions.find { it.go_back == go_back }.counts

  def hour_rows(go_back) = month_card.layover_hours.rows(go_back)

  def distribution_caption(go_back) = t(".distribution_caption", end_name: end_name(go_back), count: stat(:weekday, go_back).n_layovers)

  def hours_caption(go_back) = t(".hours_caption", end_name: end_name(go_back))

  private

  def stat(set, go_back) = month_card.layover_stats(set).rows.find { it.go_back == go_back }

  def stop_name(go_back) = SETS.filter_map { stat(it, go_back)&.stop_name }.first || NONE

  # The end's name when there are two to tell apart.
  def end_name(go_back) = month_card.stop_go_backs.size > 1 ? stop_name(go_back) : t(".stopping_end")
end
