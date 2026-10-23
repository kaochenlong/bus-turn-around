# frozen_string_literal: true

# Where the site started: the 未來城市 article about a driver on 中山幹線, told
# in one paragraph and the times around his first layover, with the citation.
# It reads no stored data; the times and the interval it shows are the
# article's own. The links to the route page of 中山幹線 appear only while that
# route has a page, so the block never links to a 404.
class OriginStoryComponent < ApplicationComponent
  ARTICLE_URL = "https://futurecity.cw.com.tw/article/4090"
  ROUTE_ID = 15373

  # The blocks of the route page the block links to, keyed by their id there,
  # with the translation key of each link.
  ROUTE_LINKS = { "layovers" => :layovers_link, "buffer" => :buffer_link }.freeze

  def route_links? = RoutePage.route_ids.include?(ROUTE_ID)

  def route_section_path(anchor) = helpers.route_path(ROUTE_ID, anchor:)
end
