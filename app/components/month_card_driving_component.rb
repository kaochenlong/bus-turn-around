# frozen_string_literal: true

# The rest rule of 汽車運輸業管理規則第 19 條之 2 against the rest windows of a
# month, as in the monthly-card spec: numbers only. The data sees vehicles, not who
# drives them, so nothing here says whether the rule was kept.
class MonthCardDrivingComponent < MonthCardComponent
  SETS = %i[weekday holiday].freeze
  RULES = %i[four_hours six_hours].freeze

  Row = Data.define(:set, :rule)

  def rows = SETS.product(RULES).map { |set, rule| Row.new(set:, rule:) }

  def figures(row) = month_card.rest_windows(row.set).rule(row.rule)

  def set_name(set) = day_type_label(RoutePage::MonthCard::DAY_TYPES.fetch(set))

  def over_daily_sentence
    rule = month_card.rest_windows(:weekday).rule(:four_hours)
    return if rule.n_windows.zero?

    t(".over_daily", count: rule.n_over_daily, share: whole_share(rule.n_over_daily.fdiv(rule.n_windows)))
  end

  def stretches_sentence
    stretches = month_card.rest_windows(:weekday).stretches
    return if stretches.n_stretches.zero?

    t(".stretches", p50: whole(stretches.p50), p90: whole(stretches.p90), total: stretches.n_stretches, over_four: stretches.n_over_four_hours, over_six: stretches.n_over_six_hours)
  end
end
