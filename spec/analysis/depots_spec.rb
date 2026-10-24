require "spec_helper"
require "json"
require "tmpdir"
require_relative "../support/duckdb"

# analysis/depots.sql reads the trips of stage 20 and the operators and
# stations file at provider_path, so these examples run the stages through 20
# and then the file: on the fixture day with the fixture snapshot's file, on
# files written for one example, and on the stop events of one injected trip.
RSpec.describe "analysis/depots.sql" do
  let(:fixture_file) { File.join(DuckdbHelpers::FIXTURE_DATA, "static/2026-10-19/GetProvider.gz") }

  # The rows of route_day_depots as [station_id, provider_name, station_name,
  # n_buses, n_trips], after `before`, SQL that replaces a table of the stages.
  def depots(provider_path: fixture_file, before: "")
    query = "#{before}#{File.read(File.join(DuckdbHelpers::ANALYSIS_DIR, 'depots.sql'))}\n" \
            "SELECT station_id, provider_name, station_name, n_buses, n_trips FROM route_day_depots ORDER BY station_id"
    run_sql_stages(through: "20_trips", query:, provider_path:).map(&:values)
  end

  # A file in `dir` shaped like GetProvider.gz, with `rows` as its BusInfo.
  def provider_file(dir, rows)
    File.join(dir, "providers.json").tap { File.write(it, JSON.generate("BusInfo" => rows)) }
  end

  def provider_row(station_id, provider) = { "id" => 9999, "nameZn" => provider, "stationId" => station_id, "stationNameZn" => "測試站" }

  # One outbound trip of TEST-0009 from 06:00, six events whose StationID are `stations` in time order.
  def one_trip(stations)
    stops = [ [ 0, 0, "06:00:00" ], [ 1, 1, "06:10:00" ], [ 2, 1, "06:20:00" ], [ 3, 1, "06:30:00" ], [ 4, 1, "06:40:00" ], [ 4, 0, "06:42:00" ] ]
    replace_stop_events_sql(stops.zip(stations).map { |(seq, car_on_stop, at), station| [ "TEST-0009", 0, seq, car_on_stop, at, 9001, 1, station ] })
  end

  it "fixture 2026-10-19：一個調度站 19001，測試客運 測試站，4 台車、27 趟" do
    expect(depots).to eq([ [ 19001, "測試客運", "測試站", 4, 27 ] ])
  end

  it "BusInfo 是空的檔（快照沒有 GetProvider.gz 時的替代檔）：照樣一列，兩個名稱是空字串" do
    expect(Dir.mktmpdir { depots(provider_path: provider_file(it, [])) }).to eq([ [ 19001, "", "", 4, 27 ] ])
  end

  it "同一個 stationId 有兩列：失敗，訊息點名 GetProvider.gz 與那個 stationId" do
    rows = [ provider_row(19001, "測試客運"), provider_row(19001, "測試客運二") ]
    expect { Dir.mktmpdir { depots(provider_path: provider_file(it, rows)) } }.to raise_error(/GetProvider\.gz.*19001/)
  end

  describe "每趟的調度站是事件裡出現最多的 StationID，同票取小" do
    [
      [ "五筆 19001、一筆 19002：算 19001", [ 19001, 19001, 19002, 19001, 19001, 19001 ], [ 19001, "測試客運", "測試站", 1, 1 ] ],
      [ "五筆 19002、一筆 19001：算 19002，名稱對不到是空字串", [ 19002, 19002, 19001, 19002, 19002, 19002 ], [ 19002, "", "", 1, 1 ] ],
      [ "19002 先出現、兩站各三筆：同票取小，算 19001", [ 19002, 19002, 19002, 19001, 19001, 19001 ], [ 19001, "測試客運", "測試站", 1, 1 ] ]
    ].each do |label, stations, row|
      it label do
        expect(depots(before: one_trip(stations))).to eq([ row ])
      end
    end
  end
end
