# frozen_string_literal: true

require "rails_helper"

RSpec.describe MonthCardAttributionComponent, type: :component do
  let(:text) { page.find("section[data-card-section='attribution']").text }

  # The quoted paragraphs of the 授權 section, the way the footer's spec takes them.
  def licence_paragraphs
    licence = Rails.root.join("docs/data-sources.md").read[/^### 授權\n(.*?)(?=^#)/m, 1]
    licence.lines.grep(/\A> /).map { it.delete_prefix("> ").chomp }
  end

  before { render_inline(described_class.new) }

  it "點名這份用到的每一支公運處 feed" do
    expect(text).to include("GetBusData", "GetBusEvent", "GetRoute", "GetStop", "GetPathDetail", "GetBusShape", "GetProvider", "GetSemiTimeTable", "GetTimeTable")
  end

  it "授權那兩段照 docs/data-sources.md" do
    expect(text).to include(*licence_paragraphs.drop(1))
  end

  it "辦公日曆那一行跟頁尾的一樣" do
    line = page.find("[data-office-calendar]").text
    expect(render_inline(AttributionComponent.new).text).to include(line)
  end

  it "分析程式的網址與版本" do
    expect(text).to include("github.com/kaochenlong/bus-turn-around", ProgramVersion.current)
  end

  it "提供資料不代表機關推薦" do
    expect(text).to include("提供資料不代表該機關推薦、同意或核准本專案。")
  end

  it "法規來源" do
    expect(text).to include("汽車運輸業管理規則")
  end

  it "這份沒用到的來源不列" do
    expect(text).not_to match(/BusSeatEvent|捷運車站出入口座標|全國公廁建檔資料|營運服務指標評鑑/)
  end
end
