# frozen_string_literal: true

# What the blocks of a month card share: the card, and how they write its figures.
# A figure with no data is a dash, so a block always renders.
class MonthCardComponent < ApplicationComponent
  def initialize(month_card:)
    @month_card = month_card
  end

  private

  attr_reader :month_card

  def whole_share(value) = RoutePage::Format.whole_share(value)

  def clock(minute) = RoutePage::Format.clock(minute)

  def span(low, high) = RoutePage::Format.span(low, high)

  # A figure to one decimal, or a dash without a value.
  def decimal(value) = value.nil? ? NONE : format("%.1f", value)

  # A figure as a whole number, or a dash without a value.
  def whole(value) = value.nil? ? NONE : value.round.to_s

  def direction_name(go_back) = I18n.t("directions.#{go_back}", raise: true)

  # The range of a share's daily values, as 35%–53%.
  def share_range(low, high) = low.nil? || high.nil? ? NONE : "#{whole_share(low)}–#{whole_share(high)}"
end
