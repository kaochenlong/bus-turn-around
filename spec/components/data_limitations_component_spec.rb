# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataLimitationsComponent, type: :component do
  # The component's own translations, read from its file: sidecar translations
  # are not in the global I18n backend.
  def sidecar = YAML.load_file(Rails.root.join("app/components/data_limitations_component.yml"), aliases: true).fetch("tw")

  def rendered_items(...) = render_inline(described_class.new(...)).css("[data-section=limitations] li").map { it.text.squish }

  it "首頁的範圍恰好列 home_items 那四條" do
    expect(rendered_items(scope: :home)).to eq(sidecar.fetch("home_items")).and have_attributes(size: 4)
  end

  [ {}, { scope: :route } ].each do |args|
    it "路線頁的範圍（#{args.inspect}）列 items 的每一條，首頁那四條一條都不在裡面" do
      items = rendered_items(**args)
      expect([ items, items & sidecar.fetch("home_items") ]).to eq([ sidecar.fetch("items"), [] ])
    end
  end

  it "首頁那份帶上框線；路線頁那份放在卡片裡，不帶上框線" do
    sections = %i[home route].map { |scope| render_inline(described_class.new(scope:)).at_css("section[data-section=limitations]") }
    expect(sections.map { it.classes.include?("border-t") }).to eq([ true, false ])
  end

  [ :monthly, "home", nil ].each do |scope|
    it "不接受的 scope #{scope.inspect} 丟 ArgumentError" do
      expect { described_class.new(scope:) }.to raise_error(ArgumentError)
    end
  end
end
