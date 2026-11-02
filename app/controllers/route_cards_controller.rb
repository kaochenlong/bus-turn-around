# The month card of a page route, as in the monthly-card spec: the page a month's
# card is printed from. A month without a route card does not exist, so nothing is
# public until that month's card has been prepared. The printed file of a month, as
# in the monthly-card-pdf spec, is what gets cited: the bytes are read only here, and
# only for a client that does not have them yet.
class RouteCardsController < ApplicationController
  MONTH = /\A\d{4}-(0[1-9]|1[0-2])\z/

  # The printed months of a page route, as in the monthly-card-pdf spec.
  def index
    route_id = RoutePage.whole_number(params[:route_id])
    return render_not_found unless RoutePage.route_ids.include?(route_id)

    # The site name bar links to this route's pages, this one as the current page.
    @timetable_route_id = route_id
    @site_bar_current = :cards
    @route_name = RouteDay.where(route_id:).order(day: :desc).pick(:route_name) || route_id.to_s
    @route_cards = RouteCard.printed.where(route_id:)
    @first_to_print = CardMonths.from_config.first_to_print(now: Time.current)
  end

  def show
    route_id = RoutePage.whole_number(params[:route_id])
    route_card = RouteCard.newest(route_id, month) if month && RoutePage.route_ids.include?(route_id)
    return render_not_found unless route_card

    # The site name bar links to this route's pages, its cards as the current page.
    @timetable_route_id = route_id
    @site_bar_current = :cards
    @month_card = RoutePage::MonthCard.new(route_card)
  end

  def download
    route_id = RoutePage.whole_number(params[:route_id])
    route_card = printed_card(route_id) if month && RoutePage.route_ids.include?(route_id)
    return render_not_found unless route_card

    expires_in 1.day, public: true
    response.set_header("ETag", %("#{route_card.pdf_sha256}"))
    return head(:not_modified) if request.fresh?(response)

    send_data route_card.route_card_pdf.pdf, type: "application/pdf", filename: "turnaround-#{route_card.route_id}-#{route_card.year_month}.pdf"
  end

  private

  # The version the address names, the newest printed one when it names none.
  def printed_card(route_id)
    printed = RouteCard.printed.where(route_id:, month:)
    return printed.order(version: :desc).first unless params.key?(:version)

    version = RoutePage.whole_number(params[:version])
    printed.find_by(version:) if version
  end

  # The first day of the month the address names, nil when it names none.
  def month = (Date.iso8601("#{params[:month]}-01") if MONTH.match?(params[:month].to_s))
end
