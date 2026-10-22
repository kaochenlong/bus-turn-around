# frozen_string_literal: true

# The cost of a buffer at every layover, with a slider that reloads only this
# block. Only numbers: nothing is marked as meeting a rule or a target.
class BufferTradeComponent < ApplicationComponent
  def initialize(buffer_trade:, coverage:)
    @buffer_trade = buffer_trade
    @coverage = coverage
  end

  def minutes_range = RoutePage::BufferTrade::MINUTES_RANGE

  def layovers? = @buffer_trade.n_layovers.positive?

  def share(value) = format("%.1f%%", value * 100)

  def decimal(value) = format("%.1f", value)

  def hour_span(hour) = format("%<from>02d:00–%<to>02d:00", from: hour, to: hour + 1)

  def peaks = { "lower" => @buffer_trade.peak.lower, "upper" => @buffer_trade.peak.upper }
end
