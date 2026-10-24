require "rails_helper"
require "rake"

RSpec.describe TdxS2sTravelTimeSnapshot, type: :model do
  let(:data_root) { Dir.mktmpdir("tdx") }
  let(:api_body) { [ { "RouteName" => "307", "TravelTimes" => [] }, { "RouteName" => "307西藏三民", "TravelTimes" => [] } ].to_json }

  after { FileUtils.remove_entry(data_root) }

  def day = Date.new(2026, 10, 24)

  def credentials = { client_id: "an-id", client_secret: "a-secret" }

  def path = File.join(data_root, "external/tdx/2026-10-24/S2STravelTime_307.json")

  # A stand-in for the HTTP client: the token request and the API request
  # answer with the given [status, body]; every request is recorded.
  def client(token: [ 200, { access_token: "the-token" }.to_json ], api: [ 200, api_body ])
    requests = []
    fake = Object.new
    fake.define_singleton_method(:token) { |url, **options| requests << [ :token, url, options ]; token }
    fake.define_singleton_method(:get) { |url, headers| requests << [ :get, url, headers ]; api }
    [ fake, requests ]
  end

  def snapshot(client) = described_class.new(data_root:, route_name: "307", day:, client:, credentials:)

  def call_ignoring_failure(client)
    snapshot(client).call
  rescue described_class::Error
    nil
  end

  it "寫到 external/tdx/<台北日>/S2STravelTime_<路線名>.json，內容是回應原文，回傳項目數" do
    fake, = client
    expect([ snapshot(fake).call, File.read(path) ]).to eq([ 2, api_body ])
  end

  it "先用憑證換 token，再帶著 Bearer token 問 307 的站間旅行時間" do
    fake, requests = client
    snapshot(fake).call
    expect(requests).to eq([ [ :token, described_class::TOKEN_URL, credentials ],
                             [ :get, format(described_class::API_URL, route_name: "307"), { "Authorization" => "Bearer the-token" } ] ])
  end

  it "API 回 401 時丟錯，訊息帶狀態碼，不寫檔" do
    fake, = client(api: [ 401, "" ])
    expect { snapshot(fake).call }.to raise_error(described_class::Error, /401/)
  end

  it "token 拿不到時丟錯，不問 API，不寫檔" do
    fake, requests = client(token: [ 400, "" ])
    call_ignoring_failure(fake)
    expect([ requests.map(&:first), File.exist?(path) ]).to eq([ [ :token ], false ])
  end

  it "回應不是 JSON 時丟錯，不寫檔" do
    fake, = client(api: [ 200, "<html>" ])
    call_ignoring_failure(fake)
    expect(File.exist?(path)).to be(false)
  end

  describe ".run（rake task 用）" do
    def run_task(env, client: self.client.first, credentials: self.credentials)
      out = StringIO.new
      status = described_class.run(env, out:, client:, credentials:, day:)
      [ status, out.string ]
    end

    it "沒有 TURNAROUND_DATA 或 ROUTE_NAME 時印用法，結束碼 1" do
      results = [ run_task({ "ROUTE_NAME" => "307" }), run_task({ "TURNAROUND_DATA" => data_root }) ]
      expect(results.map { |status, text| [ status, text.include?("用法") ] }).to eq([ [ 1, true ], [ 1, true ] ])
    end

    it "credentials 的 tdx 底下沒有 client_id 與 client_secret 時說明怎麼加，結束碼 1，不寫檔" do
      status, text = run_task({ "TURNAROUND_DATA" => data_root, "ROUTE_NAME" => "307" }, credentials: nil)
      expect([ status, text.include?("credentials:edit"), text.include?("client_id"), File.exist?(path) ]).to eq([ 1, true, true, false ])
    end

    it "成功時印路徑與項目數，結束碼 0" do
      status, text = run_task({ "TURNAROUND_DATA" => data_root, "ROUTE_NAME" => "307" })
      expect([ status, text ]).to eq([ 0, "#{path}：2 個項目\n" ])
    end

    it "API 失敗時印沒有寫入與原因，結束碼 1" do
      status, text = run_task({ "TURNAROUND_DATA" => data_root, "ROUTE_NAME" => "307" }, client: client(api: [ 500, "" ]).first)
      expect([ status, text.include?("沒有寫入"), text.include?("500") ]).to eq([ 1, true, true ])
    end
  end

  # Executes a rake task of the app and returns the status it exits with.
  def rake_exit_status(name)
    Rails.application.load_tasks if Rake::Task.tasks.none? { it.name == name }
    Rake::Task[name].execute
  rescue SystemExit => e
    e.status
  end

  it "rake task external:tdx_s2s_travel_time 交給 .run 執行，結束碼是它回傳的值" do
    allow(described_class).to receive(:run).and_return(3)
    expect(rake_exit_status("external:tdx_s2s_travel_time")).to eq(3)
  end
end
