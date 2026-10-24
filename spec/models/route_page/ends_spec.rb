require "rails_helper"

RSpec.describe RoutePage::Ends, type: :model do
  def from_config(hash) = described_class.from_config(hash, route_id: 9001)

  it "兩端齊全時，每個方向照設定是停車或直接折返" do
    ends = from_config({ 0 => "pass_through", 1 => "stop" })
    expect([ ends.nature(0), ends.nature(1) ]).to eq(%i[pass_through stop])
  end

  it "分出停車的方向與直接折返的方向" do
    ends = from_config({ 0 => "pass_through", 1 => "stop" })
    expect([ ends.stopping?(0), ends.stopping?(1), ends.stopping_go_backs, ends.pass_through_go_backs, ends.pass_through? ])
      .to eq([ false, true, [ 1 ], [ 0 ], true ])
  end

  it "兩端都停車時沒有直接折返的一端" do
    ends = from_config({ 0 => "stop", 1 => "stop" })
    expect([ ends.stopping_go_backs, ends.pass_through_go_backs, ends.pass_through? ]).to eq([ [ 0, 1 ], [], false ])
  end

  it "缺一個方向時丟錯，訊息寫出路線與方向" do
    expect { from_config({ 0 => "stop" }) }
      .to raise_error(described_class::InvalidConfiguration, a_string_including("9001", "direction 1"))
  end

  it "值不是 stop 或 pass_through 時丟錯，訊息寫出路線、方向與那個值" do
    expect { from_config({ 0 => "stop", 1 => "depot" }) }
      .to raise_error(described_class::InvalidConfiguration, a_string_including("9001", "direction 1", "depot"))
  end

  it "路線沒有寫任何一端時丟錯，指出方向 0" do
    expect { from_config(nil) }.to raise_error(described_class::InvalidConfiguration, a_string_including("9001", "direction 0"))
  end

  it "中山幹線去程結束的青年公園(馬場町) 那一端直接折返，返程結束的職能發展學院二那一端停車" do
    ends = RoutePage.ends(15373)
    expect([ ends.nature(0), ends.nature(1) ]).to eq(%i[pass_through stop])
  end

  it "251 去程結束的臺北車站(開封) 那一端直接折返，返程結束的福安居一那一端停車" do
    ends = RoutePage.ends(10712)
    expect([ ends.nature(0), ends.nature(1) ]).to eq(%i[pass_through stop])
  end

  it "251區 去程結束的捷運公館站那一端直接折返，返程結束的福安居一那一端停車" do
    ends = RoutePage.ends(11764)
    expect([ ends.nature(0), ends.nature(1) ]).to eq(%i[pass_through stop])
  end

  it "307 去程結束的莊敬里那一端停車，返程結束的臺北客運板橋前站(藝文) 那一端停車，19108 共用這兩端" do
    ends = RoutePage.ends(16111)
    expect([ ends.nature(0), ends.nature(1), RoutePage.member_route_ids(16111) ]).to eq([ :stop, :stop, [ 16111, 19108 ] ])
  end

  it "有路線頁的路線就是設定裡的路線：test 環境是 15373、10712、11764、16111 與 9001" do
    expect(RoutePage.route_ids).to contain_exactly(15373, 10712, 11764, 16111, 9001)
  end

  describe "同一頁的附屬路線" do
    def routes_config(routes) = allow(RoutePage).to receive(:routes).and_return(routes)

    let(:both_stop) { { 0 => "stop", 1 => "stop" } }

    it "頁面路線加上設定裡的成員：test 環境的 9001 掛 9050，10712 沒有成員就只有自己" do
      expect([ RoutePage.member_route_ids(9001), RoutePage.member_route_ids(10712) ]).to eq([ [ 9001, 9050 ], [ 10712 ] ])
    end

    it "成員同時是設定的鍵時丟錯，訊息寫出那個 Id" do
      routes_config(9001 => { ends: both_stop, member_routes: [ 9050 ] }, 9050 => { ends: both_stop })
      expect { RoutePage.member_route_ids(9001) }.to raise_error(RoutePage::Ends::InvalidConfiguration, a_string_including("9001", "9050"))
    end

    it "成員等於頁面路線本身時丟錯，訊息寫出那個 Id" do
      routes_config(9001 => { ends: both_stop, member_routes: [ 9001 ] })
      expect { RoutePage.member_route_ids(9001) }.to raise_error(RoutePage::Ends::InvalidConfiguration, a_string_including("9001"))
    end

    it "成員出現在別條路線的清單裡時丟錯，訊息寫出那個 Id" do
      routes_config(9001 => { ends: both_stop, member_routes: [ 9050 ] }, 9002 => { ends: both_stop, member_routes: [ 9050 ] })
      expect { RoutePage.member_route_ids(9001) }.to raise_error(RoutePage::Ends::InvalidConfiguration, a_string_including("9050", "9002"))
    end

    it "沒有設定的路線只有自己" do
      routes_config(9001 => { ends: both_stop })
      expect(RoutePage.member_route_ids(7777)).to eq([ 7777 ])
    end

    it "反查成員掛在哪一頁：9050 是 9001 的，頁面路線與沒設定的路線都不是誰的成員" do
      expect([ RoutePage.member_of(9050), RoutePage.member_of(9001), RoutePage.member_of(7777) ]).to eq([ 9001, nil, nil ])
    end
  end
end
