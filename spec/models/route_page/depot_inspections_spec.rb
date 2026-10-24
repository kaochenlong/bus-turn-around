require "rails_helper"

RSpec.describe RoutePage::DepotInspections, type: :model do
  # A small term of the configuration's shape, with two items; keywords replace its parts.
  def term_config(**overrides)
    { title: "測試報告書", page_url: "https://example.test/report", items: [ { name: "調度室環境", weight: 10 }, { name: "總分", weight: 100 } ],
      depots: [ depot_config ], not_in_appendix: [ { provider: "測試客運", station: "測試二站" } ] }.merge(overrides)
  end

  def depot_config(**overrides)
    { provider: "測試客運", station: "測試站", printed_as: "測試 測試站", inspected_on: "12月2日", printed_page: "A-99",
      scores: { 調度室環境: [ 8, 9 ], 總分: [ 98, 97 ] } }.merge(overrides)
  end

  describe "test 環境的 config/depot_inspections.yml" do
    let(:term) { described_class.current }

    it "用 115-1：115 年第 1 期，標題與公告頁照 shared 區" do
      expect([ term.name, term.year, term.period, term.title, term.page_url ]).to eq(
        [ "115-1", 115, 1, "115年第1期臺北市市區公車營運服務指標評鑑總體報告書",
          "https://pto.gov.taipei/News_Content.aspx?n=D95BCCD0723AEAC5&s=C104D9489EB993F2&sms=CBE6FC1D209236AE" ]
      )
    end

    it "九個項目照附錄表頭的順序與比重" do
      expect(term.items.map { [ it.name, it.weight ] }).to eq(
        [ [ "調度室環境", 10 ], [ "休憩室空間及環境", 10 ], [ "休憩室設施", 6 ], [ "盥洗室環境", 6 ], [ "禁菸環境", 5 ], [ "停車場使用情形", 5 ],
          [ "男女專用廁所或性別友善廁所", 2 ], [ "男女性專用休息室", 2 ], [ "總分", 100 ] ]
      )
    end

    it "test 區的調度站：測試客運 測試站有分數，兩欄照抄；測試二站不在名單；其他站還沒對" do
      scored, = term.status_of("測試客運", "測試站")
      expect([ scored, term.status_of("測試客運", "測試二站"), term.status_of("測試客運", "測試三站") ]).to eq([ :scored, [ :not_in_appendix, nil ], [ :unchecked, nil ] ])
    end

    it "有分數的那一站帶印的名稱、檢查日期、頁碼，九項各兩欄照項目順序" do
      inspection = term.status_of("測試客運", "測試站").last
      expect([ inspection.printed_as, inspection.inspected_on, inspection.printed_page, inspection.scores.map { [ it.item, it.columns ] }.values_at(0, 3, 8) ])
        .to eq([ "測試 測試站", "12月2日", "A-99", [ [ "調度室環境", [ 8, 9 ] ], [ "盥洗室環境", [ 5, 4 ] ], [ "總分", [ 98, 97 ] ] ] ])
    end
  end

  it "有兩期時用最新的一期：115-1 比 114-2 新" do
    term = described_class.newest({ "114-2": term_config(title: "舊的"), "115-1": term_config(title: "新的") })
    expect([ term.name, term.title ]).to eq([ "115-1", "新的" ])
  end

  it "業者與營業站要跟設定完全相同才算同一站：少了「站」字就是還沒對" do
    term = described_class.newest({ "115-1": term_config })
    expect(term.status_of("測試客運", "測試").first).to eq(:unchecked)
  end

  describe "設定不對時丟錯，訊息指出哪一期、哪一站與原因" do
    # Each case builds its terms inside the example, where the helpers above exist.
    [
      [ "期別不是「年-期」", -> { { "第一期": term_config } }, /第一期/ ],
      [ "沒有 items", -> { { "115-1": term_config(items: []) } }, /115-1.*items/ ],
      [ "調度站缺 printed_page", -> { { "115-1": term_config(depots: [ depot_config.except(:printed_page) ]) } }, /測試客運 測試站.*printed_page/ ],
      [ "業者是空的", -> { { "115-1": term_config(depots: [ depot_config(provider: "") ]) } }, /provider/ ],
      [ "scores 少了一個項目", -> { { "115-1": term_config(depots: [ depot_config(scores: { 調度室環境: [ 8, 9 ] }) ]) } }, /測試客運 測試站.*總分/ ],
      [ "scores 多了 items 沒有的項目", -> { { "115-1": term_config(depots: [ depot_config(scores: { 調度室環境: [ 8, 9 ], 總分: [ 98, 97 ], 酒測器: [ 10, 10 ] }) ]) } },
        /測試客運 測試站.*酒測器/ ],
      [ "一個項目不是兩個整數", -> { { "115-1": term_config(depots: [ depot_config(scores: { 調度室環境: [ 8 ], 總分: [ 98, 97 ] }) ]) } }, /測試客運 測試站.*調度室環境/ ],
      [ "同一站列了兩次", -> { { "115-1": term_config(depots: [ depot_config, depot_config ]) } }, /測試客運 測試站.*兩次/ ],
      [ "同一站同時有分數又不在名單", -> { { "115-1": term_config(not_in_appendix: [ { provider: "測試客運", station: "測試站" } ]) } }, /測試客運 測試站.*not_in_appendix/ ]
    ].each do |problem, terms, message|
      it problem do
        expect { described_class.newest(instance_exec(&terms)) }.to raise_error(described_class::InvalidConfiguration, message)
      end
    end
  end
end
