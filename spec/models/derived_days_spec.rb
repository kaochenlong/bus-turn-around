require "rails_helper"

RSpec.describe DerivedDays, type: :model do
  # Writes `yaml` into a file of its own and reads it as bin/nightly-load does.
  def from_yaml(yaml)
    Tempfile.create([ "derived_days", ".yml" ]) do |file|
      file.write(yaml)
      file.flush
      described_class.from_config(file.path)
    end
  end

  def typhoon_days = described_class.new(first_day: Date.new(2026, 10, 19), skipped_days: { Date.new(2026, 10, 23) => "颱風", Date.new(2026, 10, 24) => "颱風" })

  it "有效的設定：第一天 2026-10-19，跳過 2026-10-23 與 2026-10-24，各附理由" do
    days = from_yaml("first_day: 2026-10-19\nskipped_days:\n  2026-10-23: 薔琵颱風減班停駛\n  2026-10-24: 薔琵颱風第二天\n")
    expect([ days.first_day, days.skipped_days ]).to eq([ Date.new(2026, 10, 19), { Date.new(2026, 10, 23) => "薔琵颱風減班停駛", Date.new(2026, 10, 24) => "薔琵颱風第二天" } ])
  end

  it "skipped_days 可以是空的對應表" do
    expect(from_yaml("first_day: 2026-10-19\nskipped_days: {}\n").skipped_days).to eq({})
  end

  it "加了引號的日期照樣讀成那一天" do
    expect(from_yaml("first_day: \"2026-10-19\"\nskipped_days: {}\n").first_day).to eq(Date.new(2026, 10, 19))
  end

  it "repo 裡的 config/derived_days.yml 讀得出來" do
    expect { described_class.from_config(Rails.root.join("config/derived_days.yml")) }.not_to raise_error
  end

  describe "壞掉的設定：丟出 InvalidConfiguration，訊息點名不對的地方" do
    {
      "沒有 first_day" => [ "skipped_days: {}\n", "first_day" ],
      "first_day 是 2026-13-01" => [ "first_day: 2026-13-01\nskipped_days: {}\n", "2026-13-01" ],
      "跳過的 2026-10-23 理由空白" => [ "first_day: 2026-10-19\nskipped_days:\n  2026-10-23:\n", "2026-10-23" ],
      "跳過的日子的鍵是 yesterday" => [ "first_day: 2026-10-19\nskipped_days:\n  yesterday: 颱風\n", "yesterday" ],
      "多出 last_day" => [ "first_day: 2026-10-19\nlast_day: 2026-10-25\nskipped_days: {}\n", "last_day" ],
      "沒有 skipped_days" => [ "first_day: 2026-10-19\n", "skipped_days" ],
      "skipped_days 沒有寫值" => [ "first_day: 2026-10-19\nskipped_days:\n", "{}" ],
      "整份是空的" => [ "", "first_day" ],
      "YAML 寫壞了" => [ "first_day: [2026-10-19\n", "讀不出來" ]
    }.each do |fault, (yaml, named)|
      it "#{fault}：訊息含 #{named}" do
        expect { from_yaml(yaml) }.to raise_error(described_class::InvalidConfiguration, a_string_including(named))
      end
    end

    it "檔案不存在：訊息含檔名" do
      expect { described_class.from_config("/nonexistent/derived_days.yml") }.to raise_error(described_class::InvalidConfiguration, a_string_including("/nonexistent/derived_days.yml"))
    end
  end

  describe "#last_candidate_day：讀檔視窗以隔天 02:00 為界" do
    { "2026-10-26 01:59" => Date.new(2026, 10, 24), "2026-10-26 02:00" => Date.new(2026, 10, 25), "2026-10-26 23:59" => Date.new(2026, 10, 25) }.each do |now, last|
      it "台北時間 #{now} → #{last.iso8601}" do
        expect(typhoon_days.last_candidate_day(Time.zone.parse(now))).to eq(last)
      end
    end

    it "給 UTC 的時間也照台北時間算：UTC 2026-10-25 18:00 是台北 2026-10-26 02:00 → 2026-10-25" do
      expect(typhoon_days.last_candidate_day(Time.utc(2026, 10, 25, 18, 0))).to eq(Date.new(2026, 10, 25))
    end
  end

  describe "#candidates" do
    it "2026-10-26 02:00：2026-10-19 到 2026-10-25 去掉跳過的兩天，範圍內跳過的日子附理由" do
      candidates = typhoon_days.candidates(now: Time.zone.parse("2026-10-26 02:00"))
      expect([ candidates.first_day, candidates.last_day, candidates.days.map(&:iso8601), candidates.skipped_days ]).to eq(
        [ Date.new(2026, 10, 19), Date.new(2026, 10, 25), %w[2026-10-19 2026-10-20 2026-10-21 2026-10-22 2026-10-25],
          { Date.new(2026, 10, 23) => "颱風", Date.new(2026, 10, 24) => "颱風" } ]
      )
    end

    it "範圍外的跳過日子不列：2026-10-24 02:00 時最後一天是 2026-10-23，只列 2026-10-23" do
      candidates = typhoon_days.candidates(now: Time.zone.parse("2026-10-24 02:00"))
      expect([ candidates.days.last, candidates.skipped_days.keys ]).to eq([ Date.new(2026, 10, 22), [ Date.new(2026, 10, 23) ] ])
    end
  end
end
