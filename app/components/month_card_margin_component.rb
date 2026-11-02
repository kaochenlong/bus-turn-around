# frozen_string_literal: true

# What a printed month card carries in its page margin: the route, the month and,
# for a partial month, that it is one, next to the page number. The margin boxes of
# @page can only take literal text, so this is a style element of the page's own.
# The route name comes from the open data, so it is made safe for a CSS string and
# cannot close the style element.
class MonthCardMarginComponent < MonthCardComponent
  def margin_css
    <<~CSS
      @page month-card {
        @bottom-left { content: "#{css_string(left_text)}"; #{BOX_STYLE} }
        @bottom-right { content: "#{css_string(t('.page_before'))}" counter(page) "#{css_string(t('.page_between'))}" counter(pages) "#{css_string(t('.page_after'))}"; #{BOX_STYLE} }
      }
    CSS
  end

  BOX_STYLE = 'font: 7.5pt "Noto Sans TC", sans-serif; color: #64748b;'
  private_constant :BOX_STYLE

  private

  def left_text
    text = t(".left", site_name: t("site.name"), route_name: month_card.route_name, year: month_card.month.year, month: month_card.month.month)
    month_card.route_card.partial? ? "#{text}#{t('.partial')}" : text
  end

  # A quote or a backslash would end or bend the string, a line break is not allowed
  # in one, and a < could close the element; each takes CSS's own way of writing it.
  def css_string(text) = text.gsub(/[\\"]/) { "\\#{it}" }.gsub(/\s*[\r\n\f]+\s*/, " ").gsub("<") { "\\3C " }
end
