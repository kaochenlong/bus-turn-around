require "rails_helper"

RSpec.describe ProductionSession, type: :model do
  let(:dir) { Dir.mktmpdir("production-session") }
  let(:tunnel) { class_double(ProductionTunnel) }
  let(:out) { StringIO.new }
  let(:opened) { [] }

  before do
    allow(tunnel).to receive(:open) do |**target, &block|
      opened << target
      block.call
    end
  end

  after { FileUtils.remove_entry(dir) }

  def lock_path = File.join(dir, "lock")

  def versions = ActiveRecord::Base.connection_pool.migration_context.get_all_versions

  def database_host = { "accessories" => { "db" => { "host" => "203.0.113.5" } } }

  def session(action: "印", checkout_versions: versions, deploy: database_host)
    described_class.new(action:, out:, tunnel:, lock_path:, checkout_versions:, deploy:)
  end

  # Runs the block while the lock is held through another open of the file.
  def while_locked
    File.open(lock_path, File::RDWR | File::CREAT) do |held|
      held.flock(File::LOCK_EX)
      yield
    end
  end

  describe ".local_port" do
    { "15432" => 15432, "1" => 1, "65535" => 65535, "65536" => nil, "0" => nil, "abc" => nil, "" => nil, nil => nil }.each do |text, port|
      it "#{text.inspect}：#{port.inspect}" do
        expect(described_class.local_port(text)).to eq(port)
      end
    end
  end

  describe "#with_lock" do
    it "沒有人拿著鎖：跑區塊，回傳區塊的值" do
      expect(session.with_lock { 7 }).to eq(7)
    end

    it "跑的時候拿著鎖，別人拿不到" do
      other = session.with_lock { File.open(lock_path, File::RDWR) { it.flock(File::LOCK_EX | File::LOCK_NB) } }
      expect(other).to be(false)
    end

    it "另一個拿著鎖：說兩個指令裡有一個還在跑，不跑區塊，回傳 0" do
      ran = false
      status = while_locked { session.with_lock { ran = true } }
      expect([ status, ran, out.string.chomp ]).to eq([ 0, false, "另一個 bin/nightly-load 或 bin/monthly-cards 還在跑，這次不做" ])
    end

    it "鎖檔在 bin/nightly-load 用的那個位置：兩個指令預設共用一把" do
      expect(described_class.new(action: "印", out:).lock_path).to eq(Rails.root.join("tmp/nightly-load.lock").to_s)
    end
  end

  describe "#open" do
    it "開到 deploy 設定的資料庫主機，沒有 ssh.user 時用 root，回傳區塊的值" do
      value = session.open(local_port: 15432) { 7 }
      expect([ value, opened ]).to eq([ 7, [ { host: "203.0.113.5", user: "root", local_port: 15432 } ] ])
    end

    it "deploy 設定有 ssh.user：用它" do
      session(deploy: database_host.merge("ssh" => { "user" => "app" })).open(local_port: 15432) { nil }
      expect(opened.sole[:user]).to eq("app")
    end

    it "deploy 設定沒有資料庫主機：失敗，不開轉送" do
      expect { session(deploy: {}).open(local_port: 15432) { nil } }.to raise_error(described_class::Failure, /db\.host/)
    end

    it "開不了轉送：失敗，訊息帶 ssh 說的話" do
      allow(tunnel).to receive(:open).and_raise(ProductionTunnel::Error, "Connection refused")
      expect { session.open(local_port: 15432) { nil } }.to raise_error(described_class::Failure, /開不了到正式站的轉送：Connection refused/)
    end

    it "migration 版本一致：印出來，跑區塊" do
      session.open(local_port: 15432) { nil }
      expect(out.string).to include("migration 版本一致")
    end

    it "正式站多一個版本：訊息用這個指令的動詞" do
      expect { session(checkout_versions: versions - [ versions.first ]).open(local_port: 15432) { nil } }.to raise_error(described_class::Failure, /只在正式站：#{versions.first}.*兩邊一樣才印/m)
    end

    it "正式站多一個版本：不跑區塊" do
      ran = false
      suppress(described_class::Failure) { session(checkout_versions: versions - [ versions.first ]).open(local_port: 15432) { ran = true } }
      expect(ran).to be(false)
    end

    it "這份 checkout 多一個版本：不跑區塊，訊息用這個指令的動詞" do
      expect { session(action: "載入", checkout_versions: versions + [ 20991231000000 ]).open(local_port: 15432) { nil } }.to raise_error(described_class::Failure, /這次不載入.*只在這份 checkout：20991231000000/m)
    end
  end
end
