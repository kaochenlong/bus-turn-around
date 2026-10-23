# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationComponent, type: :component do
  def label(day_type) = described_class.new.day_type_label(day_type)

  it "weekday 與 holiday 各用 day_types 底下自己的翻譯" do
    expect([ label("weekday"), label("holiday") ]).to eq([ I18n.t("day_types.weekday"), I18n.t("day_types.holiday") ])
  end

  [ nil, "" ].each do |day_type|
    it "日型別是 #{day_type.inspect} 時丟出 ArgumentError，不把整張 day_types 翻譯表印到頁面上" do
      expect { label(day_type) }.to raise_error(ArgumentError)
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
