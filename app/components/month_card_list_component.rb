# frozen_string_literal: true

# The printed months of a route, as in the monthly-card-pdf spec: newest first, each
# with what it covers and a link to its file, and for a corrected month the reasons
# and the earlier versions. Without a printed month it says which comes first. It
# reads route_cards only: the bytes are in a table of their own.
class MonthCardListComponent < ApplicationComponent
  # The printed versions of one month.
  Month = Data.define(:newest, :earlier)

  # route_cards are the printed versions of the route, in any order; first_to_print
  # is the month to name when there are none.
  def initialize(route_name:, route_cards:, first_to_print:)
    @route_name = route_name
    @route_cards = route_cards
    @first_to_print = first_to_print
  end

  def months
    @route_cards.group_by(&:month).sort_by(&:first).reverse.map do |_, versions|
      newest, *earlier = versions.sort_by(&:version).reverse
      Month.new(newest:, earlier:)
    end
  end

  def month_label(month) = t(".month", year: month.year, month: month.month)

  def first_month_text
    t(".first_month", first: month_label(@first_to_print), printed_month: @first_to_print.next_month.month)
  end

  def coverage_text(route_card)
    covered = t(".covered", weekdays: route_card.coverage.fetch("loaded_weekdays"), holidays: route_card.coverage.fetch("loaded_holidays"))
    stretches = route_card.coverage.fetch("missing").map { stretch_text(it) }
    stretches.empty? ? covered : t(".covered_with_missing", covered:, missing: stretches.join(t(".separator")))
  end

  def size_text(route_card) = t(".size", megabytes: format("%.1f", (route_card.pdf_bytes / 1_000_000.0).round(1)))

  def pdf_path(route_card, **params) = helpers.route_card_pdf_path(route_card.route_id, route_card.year_month, **params)

  private

  def stretch_text(entry)
    from, to = entry.values_at("from", "to").map { it.delete_prefix(it[0, 5]) }
    from == to ? from : t(".stretch", from:, to:)
  end
end
