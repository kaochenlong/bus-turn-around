require "rails_helper"
require_relative "../support/duckdb"

RSpec.describe RawDayCheck, type: :model do
  let(:fixture) { DuckdbHelpers::FIXTURE_DATA }
  let(:day) { Date.new(2026, 10, 19) }

  def check(day, data_root: fixture) = described_class.check!(data_root:, day:)

  # A data root in `dir` that links the fixture's given feeds and the given
  # files of its static snapshot of 2026-10-19, so an example can leave some out.
  def data_root(dir, feeds: %w[bus_event bus_seat_event bus_data], static_files: %w[GetRoute.gz GetStop.gz GetPathDetail.gz])
    feeds.each { File.symlink(File.join(fixture, it), File.join(dir, it)) }
    static = File.join(dir, "static/2026-10-19").tap { FileUtils.mkdir_p(it) }
    static_files.each { File.symlink(File.join(fixture, "static/2026-10-19", it), File.join(static, it)) }
    dir
  end

  it "fixture 的 2026-10-19：通過" do
    expect { check(day) }.not_to raise_error
  end

  it "fixture 的 2026-10-20 沒有隔天的 01 時檔：丟 Failure，說讀檔視窗還沒結束、缺哪個檔" do
    expect { check(Date.new(2026, 10, 20)) }
      .to raise_error(described_class::Failure, "讀檔視窗還沒結束：沒有 #{fixture}/bus_event/2026-10-21/01.jsonl 或 01.jsonl.gz")
  end

  it "那一天沒有 bus_event 小時檔（fixture 沒有 2026-10-30）：訊息指出那一天的目錄" do
    expect { check(Date.new(2026, 10, 30)) }.to raise_error(described_class::Failure, "#{fixture}/bus_event/2026-10-30 沒有任何小時檔")
  end

  it "有 bus_event、沒有 bus_data 小時檔：訊息指出 bus_data 那一天的目錄" do
    Dir.mktmpdir do |dir|
      expect { check(day, data_root: data_root(dir, feeds: %w[bus_event bus_seat_event])) }
        .to raise_error(described_class::Failure, "#{dir}/bus_data/2026-10-19 沒有任何小時檔")
    end
  end

  it "靜態快照只有 GetRoute.gz：訊息依序列出缺的兩支檔" do
    Dir.mktmpdir do |dir|
      expect { check(day, data_root: data_root(dir, static_files: %w[GetRoute.gz])) }
        .to raise_error(described_class::Failure, "#{dir}/static/2026-10-19 缺 GetStop.gz、GetPathDetail.gz")
    end
  end
end
