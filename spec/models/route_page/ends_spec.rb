require "rails_helper"

RSpec.describe RoutePage::Ends, type: :model do
  def from_config(hash) = described_class.from_config(hash, route_id: 9001)

  it "兩端齊全時，每個方向照設定是停車或開過去就走" do
    ends = from_config({ 0 => "pass_through", 1 => "stop" })
    expect([ ends.nature(0), ends.nature(1) ]).to eq(%i[pass_through stop])
  end

  it "分出停車的方向與開過去就走的方向" do
    ends = from_config({ 0 => "pass_through", 1 => "stop" })
    expect([ ends.stopping?(0), ends.stopping?(1), ends.stopping_go_backs, ends.pass_through_go_backs, ends.pass_through? ])
      .to eq([ false, true, [ 1 ], [ 0 ], true ])
  end

  it "兩端都停車時沒有開過去就走的一端" do
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

  it "中山幹線去程結束的青年公園(馬場町) 那一端開過去就走，返程結束的職能發展學院二那一端停車" do
    ends = RoutePage.ends(15373)
    expect([ ends.nature(0), ends.nature(1) ]).to eq(%i[pass_through stop])
  end

  it "251 去程結束的臺北車站(開封) 那一端開過去就走，返程結束的福安居一那一端停車" do
    ends = RoutePage.ends(10712)
    expect([ ends.nature(0), ends.nature(1) ]).to eq(%i[pass_through stop])
  end

  it "251區 去程結束的捷運公館站那一端開過去就走，返程結束的福安居一那一端停車" do
    ends = RoutePage.ends(11764)
    expect([ ends.nature(0), ends.nature(1) ]).to eq(%i[pass_through stop])
  end

  it "有路線頁的路線就是設定裡的路線：test 環境是 15373、10712、11764 與 9001" do
    expect(RoutePage.route_ids).to contain_exactly(15373, 10712, 11764, 9001)
  end
end
