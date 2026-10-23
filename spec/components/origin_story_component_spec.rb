# frozen_string_literal: true

require "rails_helper"

RSpec.describe OriginStoryComponent, type: :component do
  def render_with_routes(route_ids)
    allow(RoutePage).to receive(:route_ids).and_return(route_ids)
    render_inline(described_class.new)
  end

  def route_hrefs(rendered) = rendered.css("[data-section=origin] a[href^='/routes/']").map { it["href"] }

  # The number of SQL queries, schema lookups aside, issued while the block is
  # rendered with the given route list.
  def queries_while_rendering(route_ids)
    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { render_with_routes(route_ids) }
    queries
  end

  it "路線清單設定有 15373 時，連到中山幹線路線頁的折返停留與換休息試算" do
    expect(route_hrefs(render_with_routes([ 15373, 9001 ]))).to contain_exactly("/routes/15373#layovers", "/routes/15373#buffer")
  end

  it "連到路線頁的錨點都是路線頁區塊導覽裡有的區塊" do
    fragments = route_hrefs(render_with_routes([ 15373, 9001 ])).map { URI(it).fragment }
    expect([ fragments.empty?, fragments - SectionNavComponent::SECTIONS ]).to eq([ false, [] ])
  end

  it "路線清單設定沒有 15373 時，沒有連到路線頁的連結，時刻清單與原文連結照舊" do
    rendered = render_with_routes([ 9001 ])
    article_links = rendered.css("[data-section=origin] a[href='#{described_class::ARTICLE_URL}']")
    expect([ route_hrefs(rendered), rendered.css("[data-section=origin] ol").size, article_links.size ]).to eq([ [], 1, 1 ])
  end

  it "render 時不查資料庫" do
    expect(queries_while_rendering([ 15373, 9001 ])).to eq(0)
  end
end
