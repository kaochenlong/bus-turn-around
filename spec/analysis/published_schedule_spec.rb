require "spec_helper"
require "json"
require "tmpdir"
require_relative "../support/duckdb"

# analysis/published_schedule.sql reads the sub-routes of stage 10 and the two
# files at semi_time_table_path and time_table_path, so these examples run the
# stages through 10 and then the file: on the fixture snapshot's files, with
# member route 9050 in the run, and on files written for one example.
RSpec.describe "analysis/published_schedule.sql" do
  let(:headway_columns) { "route_id, path_attribute_id, date_value, start_minute, end_minute, low_minutes, high_minutes" }

  def fixture(name) = File.join(DuckdbHelpers::FIXTURE_DATA, "static/2026-10-19", name)

  def published(view, columns, semi_time_table_path: fixture("GetSemiTimeTable.gz"), time_table_path: fixture("GetTimeTable.gz"))
    query = "#{File.read(File.join(DuckdbHelpers::ANALYSIS_DIR, 'published_schedule.sql'))}\nSELECT #{columns} FROM #{view} ORDER BY ALL"
    run_sql_stages(through: "10_load", query:, member_route_ids: [ 9001, 9050 ], semi_time_table_path:, time_table_path:)
  end

  # A file in `dir` shaped like the snapshot files, with `rows` as its BusInfo.
  def bus_info_file(dir, rows)
    File.join(dir, "rows.json").tap { File.write(it, JSON.generate("BusInfo" => rows)) }
  end

  def headway_row(path: 9001, start: "0600", finish: "0800", long: "05", low: "10", date_type: "0", date_value: "2")
    { "Id" => 1, "PathAttributeId" => path, "StartTime" => start, "EndTime" => finish, "LongHeadway" => long, "LowHeadway" => low,
      "DateType" => date_type, "DateValue" => date_value }
  end

  def departure_row(path: 9001, time: "0700", date_type: "0", date_value: "2")
    { "Id" => 1, "PathAttributeId" => path, "DateType" => date_type, "DateValue" => date_value, "DepartureTime" => time, "IsLastBus" => "0" }
  end

  # The kept headway rows of a file holding `rows`, as arrays in column order.
  def headways_of(*rows)
    Dir.mktmpdir { |dir| published("published_headways", headway_columns, semi_time_table_path: bus_info_file(dir, rows)).map(&:values) }
  end

  def departures_of(*rows)
    Dir.mktmpdir { |dir| published("published_departures", "route_id, path_attribute_id, date_value, minute", time_table_path: bus_info_file(dir, rows)).map(&:values) }
  end

  describe "fixture 2026-10-19，路線 9001 掛成員路線 9050" do
    let(:headways) { published("published_headways", headway_columns) }
    let(:departures) { published("published_departures", "route_id, path_attribute_id, date_value, minute") }

    it "班距 18 列，只來自附屬路線 9001 與 9002，沒有對照路線 9100 也沒有指定日期 20260101" do
      expect(headways.map { it["path_attribute_id"] }.tally).to eq(9001 => 17, 9002 => 1)
    end

    it "沒有 DateValue 20260101" do
      expect(headways.map { it["date_value"] }.uniq.sort).to eq([ 1, 2, 3, 4, 5, 6, 7 ])
    end

    it "附屬路線 9002 的列記在路線 9001 底下" do
      expect(headways.find { it["path_attribute_id"] == 9002 }.values).to eq([ 9001, 9002, 2, 360, 480, 5, 10 ])
    end

    it "定時班次 6 列，9001 一列、9050 五列，沒有對照路線 9100" do
      expect(departures.map(&:values)).to eq(
        [ [ 9001, 9001, 2, 1350 ], [ 9050, 9050, 1, 540 ], [ 9050, 9050, 2, 420 ], [ 9050, 9050, 2, 510 ], [ 9050, 9050, 6, 420 ], [ 9050, 9050, 6, 510 ] ]
      )
    end
  end

  describe "欄位怎麼讀" do
    it "LongHeadway 是下界、LowHeadway 是上界" do
      expect(headways_of(headway_row(long: "04", low: "06"))).to eq([ [ 9001, 9001, 2, 360, 480, 4, 6 ] ])
    end

    it "1700 到 0000 存成 1020 到 1440" do
      expect(headways_of(headway_row(start: "1700", finish: "0000", long: "30", low: "30"))).to eq([ [ 9001, 9001, 2, 1020, 1440, 30, 30 ] ])
    end

    it "DateType 不是 0 的列不存" do
      expect(headways_of(headway_row(date_type: "1", date_value: "20260101"))).to eq([])
    end

    it "定時班次的 DateType 不是 0 的列也不存" do
      expect(departures_of(departure_row(date_type: "1", date_value: "20261026"))).to eq([])
    end

    it "BusInfo 是空的檔（快照沒有這支檔時的替代檔）：沒有列，不失敗" do
      expect(headways_of).to eq([])
    end

    it "定時班次的 BusInfo 是空的檔也沒有列" do
      expect(departures_of).to eq([])
    end
  end

  describe "本路線的列讀不懂就失敗，訊息指名檔案與值" do
    {
      "LongHeadway abc" => [ { long: "abc" }, /GetSemiTimeTable\.gz.*abc/ ],
      "LowHeadway 空的" => [ { low: "" }, /GetSemiTimeTable\.gz.*LowHeadway/ ],
      "LongHeadway 12.5" => [ { long: "12.5" }, /GetSemiTimeTable\.gz.*12\.5/ ],
      "班距 0 分鐘" => [ { long: "0" }, /GetSemiTimeTable\.gz.*LongHeadway 0/ ],
      "StartTime 2500" => [ { start: "2500" }, /GetSemiTimeTable\.gz.*2500/ ],
      "EndTime 三位數" => [ { finish: "800" }, /GetSemiTimeTable\.gz.*800/ ],
      "DateValue 讀不成整數" => [ { date_value: "週一" }, /GetSemiTimeTable\.gz.*週一/ ],
      "DateType 讀不成整數" => [ { date_type: "x" }, /GetSemiTimeTable\.gz.*DateType x/ ],
      "下界大於上界" => [ { long: "20", low: "10" }, /GetSemiTimeTable\.gz.*20.*10/ ]
    }.each do |label, (row, message)|
      it "班距的 #{label}" do
        expect { headways_of(headway_row(**row)) }.to raise_error(message)
      end
    end

    it "定時班次的 DepartureTime 讀不懂" do
      expect { departures_of(departure_row(time: "7點")) }.to raise_error(/GetTimeTable\.gz.*7點/)
    end

    it "定時班次的 DateValue 讀不懂" do
      expect { departures_of(departure_row(date_value: "x")) }.to raise_error(/GetTimeTable\.gz.*DateValue x/)
    end

    it "訊息只列出不同的值一次" do
      rows = [ headway_row(long: "abc", date_value: "2"), headway_row(long: "abc", date_value: "3") ]
      expect { headways_of(*rows) }.to raise_error(/LongHeadway abc(?!.*abc)/)
    end
  end

  describe "別條路線的列不檢查" do
    it "附屬路線 9100 的 LongHeadway 是 abc：照常匯出" do
      rows = [ headway_row(path: 9100, long: "abc"), headway_row ]
      expect(headways_of(*rows)).to eq([ [ 9001, 9001, 2, 360, 480, 5, 10 ] ])
    end

    it "附屬路線 9100 的 DepartureTime 是 abc：照常匯出" do
      rows = [ departure_row(path: 9100, time: "abc"), departure_row ]
      expect(departures_of(*rows)).to eq([ [ 9001, 9001, 2, 420 ] ])
    end
  end
end
