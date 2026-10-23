# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardComponent, type: :component do
  def render_card(**params) = render_inline(described_class.new(**params)) { "卡片裡的內容" }

  it "內容放在帶指定 id 的 div 裡，div 本身沒有 data-section" do
    div = render_card(id: "layovers").at_css("div#layovers")
    expect([ div&.text&.strip, div&.key?("data-section") ]).to eq([ "卡片裡的內容", false ])
  end

  it "沒給 id 時，div 沒有 id 屬性" do
    expect(render_card.at_css("div").key?("id")).to be(false)
  end
end
