# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationComponent, type: :component do
  def label(day_type) = described_class.new.day_type_label(day_type)

  def tag_classes(day_type) = described_class.new.day_tag_class(day_type).split

  # Every key of a translation tree, as dotted paths.
  def translation_keys(tree, prefix = "") = tree.flat_map { |key, value| value.is_a?(Hash) ? translation_keys(value, "#{prefix}#{key}.") : [ "#{prefix}#{key}" ] }.sort

  # Sidecar translations are only looked up when a component renders, and the
  # tests render in tw; a key missing from en would only show in production.
  it "每個元件的翻譯檔裡，tw、zh-TW、en 三份的鍵都一樣" do
    mismatched = Rails.root.glob("app/components/*.yml").reject do |path|
      YAML.load_file(path, aliases: true).values_at("tw", "zh-TW", "en").map { translation_keys(it) }.uniq.size == 1
    end
    expect(mismatched.map { it.basename.to_s }).to eq([])
  end

  # The number formats the tables and the key numbers share.
  it "分鐘數留一位小數，沒有值時是 —" do
    expect([ described_class.new.minutes(20.0), described_class.new.minutes(nil) ]).to eq([ "20.0", "—" ])
  end

  it "比例寫成留一位小數的百分比，沒有值時是 —" do
    expect([ described_class.new.share(1.0 / 3), described_class.new.share(nil) ]).to eq([ "33.3%", "—" ])
  end

  it "weekday 與 holiday 各用 day_types 底下自己的翻譯" do
    expect([ label("weekday"), label("holiday") ]).to eq([ I18n.t("day_types.weekday"), I18n.t("day_types.holiday") ])
  end

  [ nil, "" ].each do |day_type|
    it "日型別是 #{day_type.inspect} 時丟出 ArgumentError，不把整張 day_types 翻譯表印到頁面上" do
      expect { label(day_type) }.to raise_error(ArgumentError)
    end
  end

  # The tags of the day type and the covered days at the top of the route and
  # timetable pages.
  it "假日的標籤用綠色，不用平日的灰底" do
    expect([ tag_classes("holiday").include?("bg-green-50"), tag_classes("holiday").include?("bg-slate-50") ]).to eq([ true, false ])
  end

  it "平日的標籤維持灰底，沒有任何綠色" do
    expect([ tag_classes("weekday").include?("bg-slate-50"), tag_classes("weekday").grep(/green-/) ]).to eq([ true, [] ])
  end

  [ nil, "", "typhoon" ].each do |day_type|
    it "標籤的日型別是 #{day_type.inspect} 時丟出 KeyError，不默默畫成灰色" do
      expect { described_class.new.day_tag_class(day_type) }.to raise_error(KeyError)
    end
  end

  # Test and development raise on any missing translation; production keeps
  # the i18n default, which returns a placeholder text instead.
  describe "用正式環境的缺翻譯處理時" do
    around do |example|
      handler = I18n.exception_handler
      I18n.exception_handler = I18n::ExceptionHandler.new
      example.run
    ensure
      I18n.exception_handler = handler
    end

    it "沒有翻譯的日型別仍然丟出錯誤，不在頁面上顯示缺翻譯的字" do
      expect { label("typhoon") }.to raise_error(I18n::MissingTranslationData)
    end
  end
end
