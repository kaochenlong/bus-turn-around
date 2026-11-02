require "rails_helper"

RSpec.describe ProgramVersion, type: :model do
  it "Kamal 設了版本：取前 7 碼" do
    expect(described_class.read("KAMAL_VERSION" => "c47613a2deadbeef")).to eq("c47613a")
  end

  it "沒有 Kamal 的版本：取這份程式的 commit" do
    expect(described_class.read({})).to match(/\A\h{7}\z/)
  end

  it "取不到 commit：說不知道，不讓頁面壞掉" do
    allow(Open3).to receive(:capture2).and_raise(Errno::ENOENT)
    expect(described_class.read({})).to eq("unknown")
  end

  it "current 是這個環境的版本" do
    expect(described_class.current).to eq(described_class.read(ENV.to_h))
  end
end
