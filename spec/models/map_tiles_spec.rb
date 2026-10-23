require "rails_helper"

RSpec.describe MapTiles, type: :model do
  it "測試環境的底圖是內嵌的空白圖磚：網址以 data:image/png 開頭，顯名寫測試用空白底圖" do
    expect([ described_class.url.start_with?("data:image/png"), described_class.attribution ]).to eq([ true, "測試用空白底圖" ])
  end

  describe "設定少了一個鍵時" do
    # A map.yml in `dir` whose test environment has the tile address and the
    # maximum zoom but no attribution.
    def without_attribution(dir)
      Pathname(dir).join("map.yml").tap { it.write({ "test" => { "tiles" => { "url" => "data:image/png;base64,AA==", "max_zoom" => 18 } } }.to_yaml) }
    end

    it "讀的時候丟出錯誤，訊息指出 attribution" do
      expect { Dir.mktmpdir { described_class.load(without_attribution(it)) } }.to raise_error(described_class::InvalidConfiguration, /attribution/)
    end
  end
end
