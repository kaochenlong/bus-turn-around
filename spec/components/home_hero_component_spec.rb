# frozen_string_literal: true

require "rails_helper"

RSpec.describe HomeHeroComponent, type: :component do
  # The pixel width and height of a WebP file in app/assets/images, read from
  # its VP8X header, as tools/hero exports them.
  def webp_size(name)
    header = Rails.root.join("app/assets/images", name).binread(30)
    raise "#{name} is not an extended (VP8X) WebP" unless header.byteslice(12, 4) == "VP8X"

    [ 24, 27 ].map { (header.byteslice(it, 3) + "\0").unpack1("V") + 1 }
  end

  def picture = render_inline(described_class.new).at_css("[data-section=hero] picture")

  it "窄於 640 px 的螢幕用直式圖，其他用全景圖" do
    rendered = picture
    expect([ rendered.at_css('source[media="(max-width: 639px)"]')["srcset"], rendered.at_css("img")["src"] ])
      .to match([ include("home-hero-tall"), include("home-hero-wide") ])
  end

  it "伺服器輸出的 hero 等著動畫接手：data-hero 是 pending，掛著 homeHero 元件" do
    hero = render_inline(described_class.new).at_css("[data-section=hero]")
    expect([ hero["data-hero"], hero["x-data"] ]).to eq(%w[pending homeHero])
  end

  it "img 標了跟全景圖同比例的寬高，alt 不是空的" do
    img = picture.at_css("img")
    expect([ Rational(img["width"].to_i, img["height"].to_i), img["alt"].strip.empty? ]).to eq([ Rational(*webp_size("home-hero-wide.webp")), false ])
  end
end
