require "rails_helper"

RSpec.describe RoutePage::Format, type: :model do
  it "分鐘數留一位小數、比例寫成留一位小數的百分比，沒有值時都是 —" do
    expect([ described_class.minutes(20.0), described_class.minutes(nil), described_class.share(1.0 / 3), described_class.share(nil) ]).to eq([ "20.0", "—", "33.3%", "—" ])
  end

  it "日期後面接全形括號的星期" do
    expect(described_class.day_label(Date.new(2026, 10, 19))).to eq("2026-10-19（一）")
  end
end
