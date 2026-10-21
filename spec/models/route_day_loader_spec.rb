require "rails_helper"
require_relative "../support/duckdb"

RSpec.describe RouteDayLoader, :duckdb, type: :model do
  let(:day) { Date.new(2026, 10, 19) }

  def load_day = described_class.new(route_id: 9001, day:, data_root: DuckdbHelpers::FIXTURE_DATA, duckdb: "duckdb").call

  def stored_counts = [ Trip.count, Layover.count, TripStopCount.count, RouteDayStop.count, RouteDay.count ]

  # Makes the next export write a trip stop count whose trip does not exist, so
  # the load fails after the old day has been deleted inside the transaction.
  def break_next_export
    allow(AnalysisRun).to receive(:run).and_wrap_original do |original, *args, **options|
      original.call(*args, **options).tap do
        File.open(File.join(args[1].fetch(:derived_dir), "trip_stop_counts.csv"), "a") { it.puts("TEST-9999,2026-10-19 06:00:00+08:00,0,1") }
      end
    end
  end

  it "fixture 2026-10-19 寫入兩次，趟次 27、折返停留 16、趟次站 96、站序 10、路線日 1，第二次後不變" do
    load_day
    expect { load_day }.not_to(change { stored_counts }.from([ 27, 16, 96, 10, 1 ]))
  end

  it "回傳寫入的趟次、折返停留與趟次站筆數" do
    expect(load_day).to eq(trips: 27, layovers: 16, trip_stop_counts: 96)
  end

  # Runs the load and swallows the loader's own failure.
  def load_day_ignoring_failure
    load_day
  rescue RouteDayLoader::Error
    nil
  end

  it "寫入途中失敗時丟出錯誤，指出對不上的那張表" do
    load_day.then { break_next_export }
    expect { load_day }.to raise_error(RouteDayLoader::Error, /trip_stop_counts/)
  end

  it "寫入途中失敗後，資料庫裡仍是先前那次的資料" do
    load_day.then { break_next_export }
    expect { load_day_ignoring_failure }.not_to(change { Trip.order(:id).ids })
  end

  it "時刻以台北時間存入：TEST-0001 的第一趟 06:00 發車" do
    load_day
    expect(Trip.where(bus_id: "TEST-0001").minimum(:start_time)).to eq(Time.zone.parse("2026-10-19 06:00"))
  end

  describe "DuckDB 失敗時（fixture 沒有 2026-10-30）" do
    let(:day) { Date.new(2026, 10, 30) }

    it "丟出錯誤，訊息帶出 DuckDB 的標準錯誤" do
      expect { load_day }.to raise_error(RouteDayLoader::Error, /2026-10-30/)
    end

    it "什麼都不寫" do
      expect { load_day_ignoring_failure }.not_to(change { stored_counts })
    end
  end
end
