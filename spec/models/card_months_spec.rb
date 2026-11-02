require "rails_helper"

RSpec.describe CardMonths, type: :model do
  # Writes `yaml` into a file of its own and reads it as bin/monthly-cards does.
  def from_yaml(yaml)
    Tempfile.create([ "route_cards", ".yml" ]) do |file|
      file.write(yaml)
      file.flush
      described_class.from_config(file.path)
    end
  end

  def months = described_class.new(first_month: Date.new(2026, 11, 1))

  def taipei(time) = Time.find_zone("Taipei").parse(time)

  it "有效的設定：第一個月是 2026-11 的 1 號" do
    expect(from_yaml("first_month: 2026-11\n").first_month).to eq(Date.new(2026, 11, 1))
  end

  it "加了引號的月份照樣讀" do
    expect(from_yaml("first_month: \"2026-11\"\n").first_month).to eq(Date.new(2026, 11, 1))
  end

  it "repo 裡的 config/route_cards.yml 讀得出來" do
    expect { described_class.from_config }.not_to raise_error
  end

  { "不是對應表" => [ "- 2026-11\n", /first_month/ ],
    "缺 first_month" => [ "other: 1\n", /缺 first_month/ ],
    "多出不認得的鍵" => [ "first_month: 2026-11\nother: 1\n", /多出不認得的鍵：other/ ],
    "月份沒補零" => [ "first_month: 2026-1\n", /YYYY-MM：2026-1/ ],
    "沒有 13 月" => [ "first_month: 2026-13\n", /YYYY-MM：2026-13/ ],
    "寫成日期" => [ "first_month: 2026-11-01\n", /讀不出來/ ],
    "YAML 壞掉" => [ "first_month: [\n", /讀不出來/ ] }.each do |situation, (yaml, message)|
    it "#{situation}：設定錯誤，訊息說哪裡不對" do
      expect { from_yaml(yaml) }.to raise_error(described_class::InvalidConfiguration, message)
    end
  end

  it "檔案不存在：設定錯誤" do
    expect { described_class.from_config("/nonexistent/route_cards.yml") }.to raise_error(described_class::InvalidConfiguration, /讀不出來/)
  end

  describe ".parse" do
    it "YYYY-MM 讀成那個月的 1 號" do
      expect(described_class.parse("2026-11")).to eq(Date.new(2026, 11, 1))
    end

    [ "2026-13", "2026-00", "2026-1", "2026-11-01", "latest", "", nil ].each do |text|
      it "#{text.inspect} 不是月份：nil" do
        expect(described_class.parse(text)).to be_nil
      end
    end
  end

  describe "#due" do
    it "第一個月還沒過完：沒有到期的月份" do
      expect(months.due(now: taipei("2026-11-02 12:00"))).to eq([])
    end

    it "2026-12-15：只有 2026-11，當月不算" do
      expect(months.due(now: taipei("2026-12-15 12:00"))).to eq([ Date.new(2026, 11, 1) ])
    end

    it "台北已經過午夜進 12 月：2026-11 到期，UTC 還在 11 月也一樣" do
      expect(months.due(now: taipei("2026-12-01 00:30").utc)).to eq([ Date.new(2026, 11, 1) ])
    end

    it "台北還在 11-30 深夜：還沒到期" do
      expect(months.due(now: taipei("2026-11-30 23:30"))).to eq([])
    end

    it "跨年：從第一個月到上個月" do
      expect(months.due(now: taipei("2027-02-01 12:00"))).to eq([ Date.new(2026, 11, 1), Date.new(2026, 12, 1), Date.new(2027, 1, 1) ])
    end
  end

  describe "#first_to_print" do
    it "第一個月還沒過完：是第一個月" do
      expect(months.first_to_print(now: taipei("2026-11-02 12:00"))).to eq(Date.new(2026, 11, 1))
    end

    it "第一個月已經過了：是上個月" do
      expect(months.first_to_print(now: taipei("2027-02-15 12:00"))).to eq(Date.new(2027, 1, 1))
    end
  end
end
