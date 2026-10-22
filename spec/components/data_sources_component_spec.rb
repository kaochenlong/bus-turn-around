# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataSourcesComponent, type: :component do
  it "恰好三個連結，依序是定時車機資訊、公車車上擁擠度、捷運車站出入口座標的資料集頁" do
    links = render_inline(described_class.new).css("[data-section=sources] a").map { it["href"] }
    expect(links).to eq(%w[https://data.gov.tw/dataset/128710 https://data.gov.tw/dataset/175726 https://data.gov.tw/dataset/128428])
  end
end
