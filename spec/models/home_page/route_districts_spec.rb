require "rails_helper"

RSpec.describe HomePage::RouteDistricts, type: :model do
  # A stored day of the route with its snapshot day set and the given
  # districts, each [county, town, qualifies].
  def store_day(route_id, day, districts)
    create(:route_day, route_id:, day: Date.iso8601(day), stop_districts_day: Date.iso8601(day)).tap do |route_day|
      districts.each { |county, town, qualifies| create(:route_day_district, route_day:, county:, town:, qualifies:) }
    end
  end

  # The block's result with the SQL statements issued while it ran, schema
  # queries left out.
  def with_statements
    statements = []
    collect = ->(*, payload) { statements << payload[:sql] unless payload[:name] == "SCHEMA" }
    result = ActiveSupport::Notifications.subscribed(collect, "sql.active_record") { yield }
    [ result, statements ]
  end

  it "每個路線日達門檻的區的名稱：臺北市不帶市名、其他縣市帶，臺北市在前、再照縣市與區名；不達門檻的不算；選項是全部合起來的同一順序" do
    day = store_day(9001, "2026-10-20", [ [ "新北市", "甲區", true ], [ "臺北市", "測試區", true ], [ "臺北市", "乙區", false ] ])
    other = store_day(15373, "2026-10-21", [ [ "臺北市", "士林區", true ] ])
    districts = described_class.new([ day, other ])
    expect([ districts.names_by_route_day, districts.options ]).to eq([ { day.id => [ "測試區", "新北市甲區" ], other.id => [ "士林區" ] }, [ "士林區", "測試區", "新北市甲區" ] ])
  end

  it "兩個路線日只發一句 SELECT；沒有路線日時一句都不發" do
    days = [ store_day(9001, "2026-10-20", [ [ "臺北市", "測試區", true ] ]), store_day(15373, "2026-10-21", [ [ "臺北市", "士林區", true ] ]) ]
    _names, statements = with_statements { described_class.new(days).names_by_route_day }
    _none, none_statements = with_statements { described_class.new([]).options }
    expect([ statements.size, none_statements ]).to eq([ 1, [] ])
  end

  it "預設選項：選項裡有中山區就是中山區，沒有就是第一個，沒有任何選項是 nil" do
    with = store_day(9001, "2026-10-20", [ [ "臺北市", "士林區", true ], [ "臺北市", "中山區", true ] ])
    without = store_day(15373, "2026-10-21", [ [ "新北市", "甲區", true ], [ "臺北市", "測試區", true ] ])
    defaults = [ described_class.new([ with, without ]).default_option, described_class.new([ without ]).default_option, described_class.new([]).default_option ]
    expect(defaults).to eq([ "中山區", "測試區", nil ])
  end

  it "區名的規則：臺北市只寫區，其他縣市寫縣市加區" do
    expect([ described_class.name("臺北市", "中正區"), described_class.name("新北市", "新莊區") ]).to eq([ "中正區", "新北市新莊區" ])
  end
end
