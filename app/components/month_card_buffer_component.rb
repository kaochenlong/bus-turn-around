# frozen_string_literal: true

# What holding longer at the stopping ends would cost on the weekdays, as in the
# monthly-card spec: vehicles, not drivers' hours, and no recommendation. Whether to
# do it is for whoever reads it.
class MonthCardBufferComponent < MonthCardComponent
  def trades = month_card.buffer_trades(:weekday)

  def base = trades.first

  def n_trips = helpers.number_with_delimiter(base.n_trips)

  # The busiest hour of each bound; when they differ, each bound names its own, so
  # that neither figure is read against the other's hour.
  def peak_text(peak)
    return NONE unless peak

    lower, upper = peak.lower, peak.upper
    return t(".peak_same", lower: decimal(lower.vehicles), upper: decimal(upper.vehicles), hour: two_digits(upper.hour)) if lower.hour == upper.hour

    t(".peak_apart", lower: decimal(lower.vehicles), lower_hour: two_digits(lower.hour), upper: decimal(upper.vehicles), upper_hour: two_digits(upper.hour))
  end

  private

  def two_digits(hour) = format("%02d", hour)
end
