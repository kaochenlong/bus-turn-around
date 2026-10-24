# frozen_string_literal: true

require "rails_helper"

RSpec.describe AttributionComponent, type: :component do
  it "報告書那一行的書名，是路線頁查核分數用的那一期報告書" do
    lines = render_inline(described_class.new).css("p").map(&:text)
    expect(lines.count { it.include?(RoutePage::DepotInspections.current.title) }).to eq(1)
  end
end
